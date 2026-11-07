import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/geo-cell-service.dart';
import '../../../services/location-service.dart';
import '../../../services/settings-service.dart';
import '../../../widgets/app-divider.widget.dart';
import '../../../services/geo-catalog-service.dart';
import '../../../services/map-download-service.dart';

import 'world-selection-painter.dart';

/// Pointer drag tool active on the world selection map.
enum MapInteractionTool {
  pan,
  lasso,
}
/// Interactive zoomable world map allowing search by city/region/country, tap/click cell selection, freehand lasso circling, and download/remove mode execution.
class WorldSelectionMap extends StatefulWidget {
  const WorldSelectionMap({ super.key });
  @override
  State<WorldSelectionMap> createState() => _WorldSelectionMapState();
}
/// State for [WorldSelectionMap] managing camera projection, gestures, place search, and selection actions.
class _WorldSelectionMapState extends State<WorldSelectionMap> {
  static const double _minPixelsPerDegree       = 1.1;
  static const double _maxPixelsPerDegree       = 220.0;
  static const double _defaultPixelsPerDegree   = 18.0;
  static const double _defaultLongitude         = 12.5;
  static const double _defaultLatitude          = 42.2;
  final LocationService _locationService        = LocationService();
  final MapDownloadService _mapDownloadService  = MapDownloadService();
  final SettingsService _settingsService        = SettingsService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode              = FocusNode();
  double _cameraLongitude                       = _defaultLongitude;
  double _cameraLatitude                        = _defaultLatitude;
  double _pixelsPerDegree                       = _defaultPixelsPerDegree;
  double _scaleStartPixelsPerDegree             = _defaultPixelsPerDegree;
  Offset _lastFocalPoint                        = Offset.zero;
  MapInteractionTool _interactionTool           = MapInteractionTool.pan;
  MapSelectionActionMode _actionMode            = MapSelectionActionMode.base;
  bool _isDrawingLasso                          = false;
  bool _isApplyingAction                        = false;
  bool _isSearchDropdownOpen                    = false;
  String _searchQuery                           = '';
  SearchableGeoPlaceModel? _selectedPlace;
  final List<Offset> _lassoScreenPointList         = [];
  final Map<String, GeoCellModel> _selectedCellMap = {};
  @override
  void initState() {
    super.initState();
    final Position? currentPos = _locationService.currentPosition;
    if (currentPos != null) {
      _cameraLongitude = currentPos.longitude;
      _cameraLatitude  = currentPos.latitude;
    }
  }
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  /// Converts a local canvas [screenOffset] to geographic `(longitude, latitude)` degrees.
  math.Point<double> _screenToGeo(Offset screenOffset, Size canvasSize) {
    final Offset center          = Offset(canvasSize.width / 2.0, canvasSize.height / 2.0);
    final double pixelsPerLatDeg = _pixelsPerDegree * WorldSelectionPainter.latitudeAspectFactor;
    final double lon             = _cameraLongitude + ((screenOffset.dx - center.dx) / _pixelsPerDegree);
    final double lat             = _cameraLatitude - ((screenOffset.dy - center.dy) / pixelsPerLatDeg);
    return math.Point<double>(
      lon.clamp(-180.0, 180.0),
      lat.clamp(-85.0, 85.0),
    );
  }
  /// Clamps camera center coordinates to valid global bounds.
  void _clampCameraBounds() {
    _cameraLongitude = _cameraLongitude.clamp(-180.0, 180.0);
    _cameraLatitude  = _cameraLatitude.clamp(-80.0, 80.0);
  }
  /// Zooms the map by [zoomFactor] anchored around [focalScreenOffset].
  void _zoomAroundScreenPoint(double zoomFactor, Offset focalScreenOffset, Size canvasSize) {
    final math.Point<double> anchorGeo = _screenToGeo(focalScreenOffset, canvasSize);
    final double targetScale           = (_pixelsPerDegree * zoomFactor).clamp(_minPixelsPerDegree, _maxPixelsPerDegree);
    final Offset center                = Offset(canvasSize.width / 2.0, canvasSize.height / 2.0);
    final double targetLatScale        = targetScale * WorldSelectionPainter.latitudeAspectFactor;
    setState(() {
      _pixelsPerDegree = targetScale;
      _cameraLongitude = anchorGeo.x - ((focalScreenOffset.dx - center.dx) / targetScale);
      _cameraLatitude  = anchorGeo.y + ((focalScreenOffset.dy - center.dy) / targetLatScale);
      _clampCameraBounds();
    });
  }
  /// Frames a geographic bounding box `[minLon, minLat, maxLon, maxLat]` inside [canvasSize].
  void _frameBoundingBox(
    double minLon,
    double minLat,
    double maxLon,
    double maxLat,
    Size canvasSize,
  ) {
    final double spanLon       = math.max((maxLon - minLon).abs(), 0.9) * 1.55;
    final double spanLat       = math.max((maxLat - minLat).abs(), 0.9) * 1.65;
    final double usableWidth   = math.max(canvasSize.width - 64.0, 120.0);
    final double usableHeight  = math.max(canvasSize.height - 150.0, 100.0);
    final double scaleByWidth  = usableWidth / spanLon;
    final double scaleByHeight = usableHeight / (spanLat * WorldSelectionPainter.latitudeAspectFactor);
    final double targetScale   = math.min(scaleByWidth, scaleByHeight).clamp(_minPixelsPerDegree, _maxPixelsPerDegree);
    setState(() {
      _cameraLongitude = (minLon + maxLon) / 2.0;
      _cameraLatitude  = (minLat + maxLat) / 2.0;
      _pixelsPerDegree = targetScale;
      _clampCameraBounds();
    });
  }
  /// Resets the camera to show the full world overview.
  void _showWorldOverview(Size canvasSize) {
    final double worldScale = math.max(canvasSize.width / 340.0, _minPixelsPerDegree);
    setState(() {
      _cameraLongitude = 10.0;
      _cameraLatitude  = 20.0;
      _pixelsPerDegree = worldScale.clamp(_minPixelsPerDegree, _maxPixelsPerDegree);
    });
  }
  /// Displays an informative dialog explaining what the Base, Detailed, and Complete levels mean.
  Future _showDetailLevelsInfoAsync(AppLocalizations l10n) async {
    final List<MapDetailLevel> levelList = [
      MapDetailLevel.base,
      MapDetailLevel.detailed,
      MapDetailLevel.complete,
    ];
    await naShowDialogAsync(
      context: context,
      builder: (BuildContext dialogContext) {
        return NaAlertDialog(
          title  : Text(l10n.mapDownloadDetailLevelsInfoTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize      : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children          : [
                // Subtitle explanation
                Text(
                  l10n.mapDownloadDetailLevelsInfoSubtitle,
                  style: TextStyle(
                    fontSize: AppSizes.font12,
                    color   : AppColors.textSecondary(dialogContext),
                  ),
                ),
                // Spacing
                const SizedBox(height: AppSizes.p12),
                // Cards for each detail level
                for (final MapDetailLevel level in levelList) ...[
                  Container(
                    margin    : const EdgeInsets.only(bottom: AppSizes.p8),
                    padding   : const EdgeInsets.all(AppSizes.p10),
                    decoration: BoxDecoration(
                      color       : level.getColor(dialogContext).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                      border      : Border.all(
                        color: level.getColor(dialogContext).withValues(alpha: 0.4),
                        width: AppSizes.borderWidthThin,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize      : MainAxisSize.min,
                      children          : [
                        // Level title and badge indicator
                        Row(
                          children: [
                            // Level color dot
                            Container(
                              width     : AppSizes.p8,
                              height    : AppSizes.p8,
                              decoration: BoxDecoration(
                                color: level.getColor(dialogContext),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Spacing
                            const SizedBox(width: AppSizes.p6),
                            // Title
                            Expanded(
                              child: Text(
                                level.getTitle(l10n),
                                style: TextStyle(
                                  fontSize  : AppSizes.font13,
                                  fontWeight: FontWeight.bold,
                                  color     : AppColors.textPrimary(dialogContext),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Spacing
                        const SizedBox(height: AppSizes.p4),
                        // Description
                        Text(
                          level.getDescription(l10n),
                          style: TextStyle(
                            fontSize: AppSizes.font12,
                            color   : AppColors.textSecondary(dialogContext),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            NaDialogAction(
              child    : Text(l10n.commonClose),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
  /// Centers the camera on the user's GPS position or default European coordinates.
  void _recenterOnUser() {
    final Position? currentPos = _locationService.currentPosition;
    setState(() {
      if (currentPos != null) {
        _cameraLongitude = currentPos.longitude;
        _cameraLatitude  = currentPos.latitude;
      }else {
        _cameraLongitude = _defaultLongitude;
        _cameraLatitude  = _defaultLatitude;
      }
      if (_pixelsPerDegree < _defaultPixelsPerDegree) {
        _pixelsPerDegree = _defaultPixelsPerDegree;
      }
    });
  }
  /// Handles mouse scroll wheel zooming on desktop platforms.
  void _handlePointerSignal(PointerSignalEvent signalEvent, Size canvasSize) {
    if (signalEvent is PointerScrollEvent) {
      final double zoomFactor = (signalEvent.scrollDelta.dy < 0.0) ? 1.22 : (1.0 / 1.22);
      _zoomAroundScreenPoint(zoomFactor, signalEvent.localPosition, canvasSize);
    }
  }
  /// Toggles selection of the single 0.5° × 0.5° cell tapped by finger or clicked by mouse.
  void _handleMapTapUp(TapUpDetails tapDetails, Size canvasSize) {
    if (_isApplyingAction) {
      return;
    }
    if (_isSearchDropdownOpen) {
      _searchFocusNode.unfocus();
      setState(() {
        _isSearchDropdownOpen = false;
      });
      return;
    }
    final math.Point<double> tappedGeo = _screenToGeo(tapDetails.localPosition, canvasSize);
    final GeoCellModel tappedCell      = GeoCellService.getCellForCoordinates(tappedGeo.x, tappedGeo.y);
    setState(() {
      _selectedPlace = null;
      if (_selectedCellMap.containsKey(tappedCell.cellId)) {
        _selectedCellMap.remove(tappedCell.cellId);
      }else {
        _selectedCellMap[tappedCell.cellId] = tappedCell;
      }
    });
  }
  /// Begins either a camera pan/pinch gesture or a freehand lasso circle stroke.
  void _handleScaleStart(ScaleStartDetails details) {
    if (_isApplyingAction) {
      return;
    }
    _scaleStartPixelsPerDegree = _pixelsPerDegree;
    _lastFocalPoint            = details.localFocalPoint;
    if (_isSearchDropdownOpen) {
      _searchFocusNode.unfocus();
      setState(() {
        _isSearchDropdownOpen = false;
      });
    }
    if ((details.pointerCount == 1) && (_interactionTool == MapInteractionTool.lasso)) {
      setState(() {
        _isDrawingLasso = true;
        _lassoScreenPointList.clear();
        _lassoScreenPointList.add(details.localFocalPoint);
      });
    }
  }
  /// Updates camera pan/pinch-zoom or appends points to the active freehand lasso.
  void _handleScaleUpdate(ScaleUpdateDetails details, Size canvasSize) {
    if (_isApplyingAction) {
      return;
    }
    // Multi-touch pinch always zooms and pans smoothly even if lasso tool is active
    if (details.pointerCount >= 2) {
      if (_isDrawingLasso) {
        _isDrawingLasso = false;
        _lassoScreenPointList.clear();
      }
      final Offset center                   = Offset(canvasSize.width / 2.0, canvasSize.height / 2.0);
      final math.Point<double> anchorBefore = _screenToGeo(_lastFocalPoint, canvasSize);
      final double newScale                 = (_scaleStartPixelsPerDegree * details.scale).clamp(_minPixelsPerDegree, _maxPixelsPerDegree);
      final double newLatScale              = newScale * WorldSelectionPainter.latitudeAspectFactor;
      setState(() {
        _pixelsPerDegree = newScale;
        _cameraLongitude = anchorBefore.x - ((details.localFocalPoint.dx - center.dx) / newScale);
        _cameraLatitude  = anchorBefore.y + ((details.localFocalPoint.dy - center.dy) / newLatScale);
        _clampCameraBounds();
      });
      _lastFocalPoint = details.localFocalPoint;
      return;
    }
    if (_isDrawingLasso && (_interactionTool == MapInteractionTool.lasso)) {
      setState(() {
        _lassoScreenPointList.add(details.localFocalPoint);
      });
      return;
    }
    // Single-pointer camera pan
    final Offset deltaScreen     = details.localFocalPoint - _lastFocalPoint;
    _lastFocalPoint              = details.localFocalPoint;
    final double pixelsPerLatDeg = _pixelsPerDegree * WorldSelectionPainter.latitudeAspectFactor;
    setState(() {
      _cameraLongitude -= deltaScreen.dx / _pixelsPerDegree;
      _cameraLatitude  += deltaScreen.dy / pixelsPerLatDeg;
      _clampCameraBounds();
    });
  }
  /// Completes a gesture, resolving intersecting cells if a freehand lasso was drawn.
  void _handleScaleEnd(ScaleEndDetails details, Size canvasSize) {
    if (!_isDrawingLasso) {
      return;
    }
    final List<Offset> capturedPointList = List<Offset>.from(_lassoScreenPointList);
    setState(() {
      _isDrawingLasso = false;
      _lassoScreenPointList.clear();
    });
    if (capturedPointList.length < 3) {
      return;
    }
    final List<math.Point<double>> geoPolygonPointList = [];
    for (final Offset screenPoint in capturedPointList) {
      geoPolygonPointList.add(_screenToGeo(screenPoint, canvasSize));
    }
    final List<GeoCellModel> circledCellList = GeoCellService.getIntersectingCellListForPolygon(geoPolygonPointList);
    if (circledCellList.isEmpty) {
      return;
    }
    setState(() {
      _selectedPlace = null;
      for (final GeoCellModel cell in circledCellList) {
        _selectedCellMap[cell.cellId] = cell;
      }
    });
  }
  /// Selects all cells belonging to [place] completely and frames it on the map.
  void _selectSearchedPlace(SearchableGeoPlaceModel place, String localeCode, Size canvasSize) {
    final List<GeoCellModel> placeCellList = place.resolveCellList();
    final String displayName               = place.getDisplayName(localeCode);
    _searchController.text = displayName;
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery          = displayName;
      _isSearchDropdownOpen = false;
      _selectedPlace        = place;
      _selectedCellMap.clear();
      for (final GeoCellModel cell in placeCellList) {
        _selectedCellMap[cell.cellId] = cell;
      }
    });
    _frameBoundingBox(
      place.minLongitude,
      place.minLatitude,
      place.maxLongitude,
      place.maxLatitude,
      canvasSize,
    );
  }
  /// Clears all currently selected cells and resets any selected place reference.
  void _clearSelection() {
    if (_isApplyingAction) {
      return;
    }
    setState(() {
      _selectedCellMap.clear();
      _selectedPlace = null;
      _lassoScreenPointList.clear();
    });
  }
  /// Executes either the offline map download at the chosen detail level or local cell removal.
  Future _applySelectionActionAsync(
    AppLocalizations l10n,
    String localeCode,
    Map<String, MapDetailLevel> downloadedCellLevelMap,
  ) async {
    if (_selectedCellMap.isEmpty || _isApplyingAction) {
      return;
    }
    final List<String> selectedCellIdList = _selectedCellMap.keys.toList()
      ..sort((String firstId, String secondId) => firstId.compareTo(secondId))
    ;
    // Handle Remove mode locally (works completely offline)
    if (_actionMode == MapSelectionActionMode.remove) {
      final List<String> removableCellIdList = selectedCellIdList
        .where((String cellId) => downloadedCellLevelMap.containsKey(cellId))
        .toList()
      ;
      if (removableCellIdList.isEmpty) {
        return;
      }
      await _mapDownloadService.removeCellListAsync(removableCellIdList);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCellMap.clear();
        _selectedPlace = null;
      });
      return;
    }
    // Handle Download mode (Base / Detailed / Complete)
    final MapDetailLevel targetLevel = _actionMode.toDetailLevel() ?? MapDetailLevel.base;
    final String zoneName            = (_selectedPlace != null)
      ? _selectedPlace!.getDisplayName(localeCode)
      : l10n.mapDownloadCustomZoneLabel(
          MapDownloadService.formatCustomAreaCoordinates(selectedCellIdList),
          selectedCellIdList.length,
        )
    ;
    setState(() {
      _isApplyingAction = true;
    });
    final bool success = await _mapDownloadService.downloadSelectionAsync(
      cellIdList     : selectedCellIdList,
      level          : targetLevel,
      zoneDisplayName: zoneName,
      place          : _selectedPlace,
    );
    if (!mounted) {
      return;
    }
    final bool isPaused = _mapDownloadService.isItemPaused(MapDownloadService.activeSelectionDownloadId);
    if (isPaused) {
      return;
    }
    setState(() {
      _isApplyingAction = false;
    });
    if (success) {
      setState(() {
        _selectedCellMap.clear();
        _selectedPlace = null;
      });
    }else {
      final DownloadTaskStatus status = _mapDownloadService.getTaskStatus(MapDownloadService.activeSelectionDownloadId);
      if (status != DownloadTaskStatus.idle) {
        await naShowDialogAsync(
          context: context,
          builder: (BuildContext dialogContext) {
            return NaAlertDialog(
              title  : Text(l10n.mapDownloadServerOffline(_settingsService.mapServerUrl)),
              content: Text(l10n.mapDownloadServerOfflineError(_settingsService.mapServerUrl)),
              actions: [
                NaDialogAction(
                  child    : Text(l10n.commonClose),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      }
    }
  }
  /// Builds a circular floating map tool button.
  Widget _buildFloatingToolButton({
    required BuildContext context,
    required NaIconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final Color backgroundColor = isActive
      ? AppColors.primary(context)
      : AppColors.surface(context).withValues(alpha: 0.94)
    ;
    final Color foregroundColor = isActive
      ? AppColors.white(context)
      : AppColors.textPrimary(context)
    ;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width     : AppSizes.mapToolButtonSize,
        height    : AppSizes.mapToolButtonSize,
        alignment : Alignment.center,
        decoration: BoxDecoration(
          color : backgroundColor,
          shape : BoxShape.circle,
          border: Border.all(
            color: isActive ? AppColors.primary(context) : AppColors.cardBorder(context),
            width: AppSizes.borderWidthThin,
          ),
          boxShadow: [
            BoxShadow(
              color     : AppColors.shadow(context),
              blurRadius: AppSizes.shadowBlur6,
              offset    : AppSizes.shadowOffset2,
            ),
          ],
        ),
        child: NaIcon(
          icon,
          size : AppSizes.icon18,
          color: foregroundColor,
        ),
      ),
    );
  }
  /// Builds a compact legend dot + label item.
  Widget _buildLegendItem(BuildContext context, Color dotColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children    : [
        // Colored dot
        Container(
          width     : AppSizes.p8,
          height    : AppSizes.p8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        // Dot-to-label spacing
        const SizedBox(width: AppSizes.p4),
        // Legend text
        Text(
          label,
          style: TextStyle(
            fontSize  : AppSizes.font10,
            fontWeight: FontWeight.w600,
            color     : AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
  /// Builds one segment in the 4-option download/remove mode selector.
  Widget _buildActionModeChip(
    BuildContext context,
    MapSelectionActionMode mode,
    AppLocalizations l10n,
  ) {
    final bool isSelected = _actionMode == mode;
    final Color modeColor = mode.getColor(context);
    final bool isRemove   = mode == MapSelectionActionMode.remove;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap   : () {
          if (!_isApplyingAction) {
            setState(() {
              _actionMode = mode;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p4,
            vertical  : AppSizes.p6,
          ),
          decoration: BoxDecoration(
            color: isSelected
              ? modeColor.withValues(alpha: 0.16)
              : AppColors.transparent(context),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border      : Border.all(
              color: isSelected ? modeColor : AppColors.cardBorder(context),
              width: isSelected ? AppSizes.borderWidthRegular : AppSizes.borderWidthThin,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize     : MainAxisSize.min,
            children         : [
              // Mode indicator dot or remove icon
              if (isRemove) ...[
                NaIcon(
                  NaIcons.deleteOutline,
                  size : AppSizes.icon14,
                  color: modeColor,
                ),
              ]else ...[
                Container(
                  width     : AppSizes.p8,
                  height    : AppSizes.p8,
                  decoration: BoxDecoration(
                    color: modeColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              // Indicator-to-label spacing
              const SizedBox(width: AppSizes.p4),
              // Mode short badge label
              Flexible(
                child: Text(
                  mode.getBadge(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style   : TextStyle(
                    fontSize  : AppSizes.font11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color     : isSelected ? modeColor : AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// Builds the icon representing a [GeoPlaceType] in the search dropdown.
  NaIconData _getIconForPlaceType(GeoPlaceType type) {
    if (type == GeoPlaceType.country) {
      return NaIcons.flag;
    }
    if (type == GeoPlaceType.region) {
      return NaIcons.map;
    }
    return NaIcons.locationOn;
  }
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String localeCode     = Localizations.localeOf(context).languageCode;
    return ListenableBuilder(
      listenable: Listenable.merge([_mapDownloadService, _locationService]),
      builder   : (BuildContext context, Widget? child) {
        final Map<String, MapDetailLevel> downloadedCellLevelMap = _mapDownloadService.getDownloadedCellLevelMap();
        final List<GeoCellModel> selectedCellList                = _selectedCellMap.values.toList();
        final Position? userPosition                             = _locationService.currentPosition;
        final List<SearchableGeoPlaceModel> searchResultList     = _isSearchDropdownOpen
          ? GeoCatalogService.searchPlaceList(_searchQuery)
          : const []
        ;
        final int selectedCount = selectedCellList.length;
        int removableCount      = 0;
        for (final GeoCellModel cell in selectedCellList) {
          if (downloadedCellLevelMap.containsKey(cell.cellId)) {
            removableCount++;
          }
        }
        final MapDetailLevel activeDetailLevel = _actionMode.toDetailLevel() ?? MapDetailLevel.base;
        final double estimatedMb               = MapDownloadService.calculateEstimatedMb(selectedCount, activeDetailLevel);
        final String estimatedMbText           = estimatedMb.toStringAsFixed(1);
        final double? activeProgress           = _mapDownloadService.getItemProgress(MapDownloadService.activeSelectionDownloadId);
        final int progressPercent              = ((activeProgress ?? 0.0) * 100.0).round();
        return NaCard(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            child       : LayoutBuilder(
              builder: (BuildContext layoutContext, BoxConstraints constraints) {
                final Size canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    // 1. Zoomable & interactive world map canvas
                    Positioned.fill(
                      child: Listener(
                        onPointerSignal: (PointerSignalEvent event) => _handlePointerSignal(event, canvasSize),
                        child          : GestureDetector(
                          behavior     : HitTestBehavior.opaque,
                          onTapUp      : (TapUpDetails details) => _handleMapTapUp(details, canvasSize),
                          onScaleStart : _handleScaleStart,
                          onScaleUpdate: (ScaleUpdateDetails details) => _handleScaleUpdate(details, canvasSize),
                          onScaleEnd   : (ScaleEndDetails details) => _handleScaleEnd(details, canvasSize),
                          child        : CustomPaint(
                            size   : canvasSize,
                            painter: WorldSelectionPainter(
                              cameraLongitude            : _cameraLongitude,
                              cameraLatitude             : _cameraLatitude,
                              pixelsPerDegree            : _pixelsPerDegree,
                              currentLassoScreenPointList: _lassoScreenPointList,
                              selectedCellList           : selectedCellList,
                              downloadedCellLevelMap     : downloadedCellLevelMap,
                              isDrawingLasso             : _isDrawingLasso,
                              userLongitude              : userPosition?.longitude,
                              userLatitude               : userPosition?.latitude,
                              backgroundColor            : AppColors.mapVoid(context),
                              continentFillColor         : AppColors.mapContinent(context),
                              continentBorderColor       : AppColors.mapContinentBorder(context),
                              minorGridColor             : AppColors.mapGridMinor(context),
                              majorGridColor             : AppColors.mapGridMajor(context),
                              selectionColor             : _actionMode.getColor(context),
                              selectionContrastColor     : AppColors.white(context),
                              detailBaseColor            : AppColors.detailBase(context),
                              detailDetailedColor        : AppColors.detailDetailed(context),
                              detailCompleteColor        : AppColors.detailComplete(context),
                              userMarkerColor            : AppColors.primary(context),
                              textColor                  : AppColors.textPrimary(context),
                              mapHighwayColor            : AppColors.mapHighway(context),
                              mapCityMarkerColor         : AppColors.mapCityMarker(context),
                              mapCityLabelColor          : AppColors.mapCityLabel(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 2. Top search bar (city / region / country) + Downloaded levels legend
                    Positioned(
                      top  : AppSizes.p8,
                      left : AppSizes.p8,
                      right: AppSizes.mapToolButtonSize + AppSizes.p16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize      : MainAxisSize.min,
                        children          : [
                          // Search input bar
                          NaSearchBar(
                            controller: _searchController,
                            focusNode : _searchFocusNode,
                            hintText  : l10n.mapDownloadSearchPlaceholder,
                            onTap     : () {
                              if (_searchQuery.trim().isNotEmpty) {
                                setState(() {
                                  _isSearchDropdownOpen = true;
                                });
                              }
                            },
                            onChanged: (String queryText) {
                              setState(() {
                                _searchQuery          = queryText;
                                _isSearchDropdownOpen = queryText.trim().isNotEmpty;
                              });
                            },
                            optionsBuilder: (BuildContext searchContext, NaUiType uiType) {
                              if (uiType == NaUiType.cupertino) {
                                return NaSearchBarOptionsCupertino(
                                  padding   : const EdgeInsets.symmetric(horizontal: AppSizes.p8, vertical: AppSizes.p6),
                                  itemColor : AppColors.textSecondary(searchContext),
                                  itemSize  : AppSizes.icon16,
                                  decoration: BoxDecoration(
                                    color       : AppColors.surface(searchContext).withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(AppSizes.radius10),
                                    border      : Border.all(
                                      color: AppColors.cardBorder(searchContext),
                                      width: AppSizes.borderWidthThin,
                                    ),
                                  ),
                                );
                              }
                              return NaSearchBarOptionsMaterial(
                                elevation      : const WidgetStatePropertyAll<double>(0.0),
                                backgroundColor: WidgetStatePropertyAll<Color>(
                                  AppColors.surface(searchContext).withValues(alpha: 0.95),
                                ),
                                constraints: const BoxConstraints(
                                  minHeight: AppSizes.mapSearchBarHeight,
                                  maxHeight: AppSizes.mapSearchBarHeight,
                                ),
                                trailing: (_searchQuery.isNotEmpty)
                                  ? [
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery          = '';
                                            _isSearchDropdownOpen = false;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p4),
                                          child  : NaIcon(
                                            NaIcons.close,
                                            size : AppSizes.icon16,
                                            color: AppColors.textSecondary(searchContext),
                                          ),
                                        ),
                                      ),
                                    ]
                                  : null,
                              );
                            },
                          ),
                          // Spacing below search bar
                          const SizedBox(height: AppSizes.p6),
                          // Search autocomplete dropdown OR Downloaded color legend
                          if (_isSearchDropdownOpen && _searchQuery.trim().isNotEmpty) ...[
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: AppSizes.searchDropdownMaxHeight,
                              ),
                              child: NaCard(
                                child: searchResultList.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(AppSizes.p12),
                                      child  : Text(
                                        l10n.mapDownloadSearchNoResults,
                                        style: TextStyle(
                                          fontSize: AppSizes.font12,
                                          color   : AppColors.textSecondary(context),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap : true,
                                      padding    : EdgeInsets.zero,
                                      itemCount  : searchResultList.length,
                                      itemBuilder: (BuildContext itemContext, int resultIndex) {
                                        final SearchableGeoPlaceModel place = searchResultList[resultIndex];
                                        final String placeName              = place.getDisplayName(localeCode);
                                        final String parentLabel            = place.getParentLabel(localeCode);
                                        final String typeLabel              = place.type.getLocalizedLabel(l10n);
                                        final bool isLastResult             = resultIndex == (searchResultList.length - 1);
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children    : [
                                            // Search result tappable row
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap   : () => _selectSearchedPlace(place, localeCode, canvasSize),
                                              child   : Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: AppSizes.p12,
                                                  vertical  : AppSizes.p8,
                                                ),
                                                child: Row(
                                                  children: [
                                                    // Place type icon
                                                    NaIcon(
                                                      _getIconForPlaceType(place.type),
                                                      size : AppSizes.icon16,
                                                      color: AppColors.primary(itemContext),
                                                    ),
                                                    // Spacing
                                                    const SizedBox(width: AppSizes.p8),
                                                    // Place name and administrative context
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisSize      : MainAxisSize.min,
                                                        children          : [
                                                          // Place primary name
                                                          Text(
                                                            placeName,
                                                            style: TextStyle(
                                                              fontSize  : AppSizes.font13,
                                                              fontWeight: FontWeight.w600,
                                                              color     : AppColors.textPrimary(itemContext),
                                                            ),
                                                          ),
                                                          // Place type and parent subtitle
                                                          Text(
                                                            '$typeLabel • $parentLabel',
                                                            style: TextStyle(
                                                              fontSize: AppSizes.font11,
                                                              color   : AppColors.textSecondary(itemContext),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Result divider
                                            if (!isLastResult) ...[
                                              const AppDivider(indent: AppSizes.p32),
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                              ),
                            ),
                          ]else ...[
                            // Downloaded zones color legend pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.p10,
                                vertical  : AppSizes.p4,
                              ),
                              decoration: BoxDecoration(
                                color       : AppColors.surface(context).withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(AppSizes.radius16),
                                border      : Border.all(
                                  color: AppColors.cardBorder(context),
                                  width: AppSizes.borderWidthThin,
                                ),
                              ),
                              child: Wrap(
                                spacing           : AppSizes.p8,
                                runSpacing        : AppSizes.p4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children          : [
                                  // Legend title
                                  Text(
                                    l10n.mapDownloadLegendLabel,
                                    style: TextStyle(
                                      fontSize  : AppSizes.font10,
                                      fontWeight: FontWeight.bold,
                                      color     : AppColors.textSecondary(context),
                                    ),
                                  ),
                                  // Base legend entry
                                  _buildLegendItem(
                                    context,
                                    AppColors.detailBase(context),
                                    l10n.mapDownloadDetailBaseBadge,
                                  ),
                                  // Detailed legend entry
                                  _buildLegendItem(
                                    context,
                                    AppColors.detailDetailed(context),
                                    l10n.mapDownloadDetailDetailedBadge,
                                  ),
                                  // Complete legend entry
                                  _buildLegendItem(
                                    context,
                                    AppColors.detailComplete(context),
                                    l10n.mapDownloadDetailCompleteBadge,
                                  ),
                                  // Information button explaining detail levels
                                  GestureDetector(
                                    onTap: () => _showDetailLevelsInfoAsync(l10n),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: AppSizes.p2),
                                      child  : NaIcon(
                                        NaIcons.info,
                                        size : AppSizes.icon14,
                                        color: AppColors.primary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 3. Right floating tool & zoom controls
                    Positioned(
                      top   : AppSizes.p8,
                      right : AppSizes.p8,
                      bottom: AppSizes.mapRightDockBottomInset,
                      child : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children    : [
                            // Pan / explore tool button
                            _buildFloatingToolButton(
                              context  : context,
                              icon     : NaIcons.openWith,
                              isActive : _interactionTool == MapInteractionTool.pan,
                              onPressed: () {
                                setState(() {
                                  _interactionTool = MapInteractionTool.pan;
                                });
                              },
                            ),
                            // Spacing
                            const SizedBox(height: AppSizes.p6),
                            // Freehand circle / lasso tool button
                            _buildFloatingToolButton(
                              context  : context,
                              icon     : NaIcons.brush,
                              isActive : _interactionTool == MapInteractionTool.lasso,
                              onPressed: () {
                                setState(() {
                                  _interactionTool = MapInteractionTool.lasso;
                                });
                              },
                            ),
                            // Spacing
                            const SizedBox(height: AppSizes.p6),
                            // Zoom in button
                            _buildFloatingToolButton(
                              context  : context,
                              icon     : NaIcons.add,
                              onPressed: () => _zoomAroundScreenPoint(
                                1.45,
                                Offset(canvasSize.width / 2.0, canvasSize.height / 2.0),
                                canvasSize,
                              ),
                            ),
                            // Spacing
                            const SizedBox(height: AppSizes.p6),
                            // Zoom out button
                            _buildFloatingToolButton(
                              context  : context,
                              icon     : NaIcons.remove,
                              onPressed: () => _zoomAroundScreenPoint(
                                1.0 / 1.45,
                                Offset(canvasSize.width / 2.0, canvasSize.height / 2.0),
                                canvasSize,
                              ),
                            ),
                            // Spacing
                            const SizedBox(height: AppSizes.p6),
                            // Full world overview button
                            _buildFloatingToolButton(
                              context  : context,
                              icon     : NaIcons.public,
                              onPressed: () => _showWorldOverview(canvasSize),
                            ),
                            // Spacing
                            const SizedBox(height: AppSizes.p6),
                            // Recenter on GPS location button
                            _buildFloatingToolButton(
                              context  : context,
                              icon     : NaIcons.myLocation,
                              onPressed: _recenterOnUser,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 4. Bottom control dock: Mode selector (all levels + remove) & selection action bar
                    Positioned(
                      left  : AppSizes.p8,
                      right : AppSizes.p8,
                      bottom: AppSizes.p8,
                      child : NaCard(
                        padding: const EdgeInsets.all(AppSizes.p8),
                        child  : Column(
                          mainAxisSize      : MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children          : [
                            // 4-option Mode Selector row (Base, Detailed, Complete, Remove)
                            Row(
                              children: [
                                // Base level chip
                                _buildActionModeChip(context, MapSelectionActionMode.base, l10n),
                                // Chip spacing
                                const SizedBox(width: AppSizes.p4),
                                // Detailed level chip
                                _buildActionModeChip(context, MapSelectionActionMode.detailed, l10n),
                                // Chip spacing
                                const SizedBox(width: AppSizes.p4),
                                // Complete level chip
                                _buildActionModeChip(context, MapSelectionActionMode.complete, l10n),
                                // Chip spacing
                                const SizedBox(width: AppSizes.p4),
                                // Remove mode chip
                                _buildActionModeChip(context, MapSelectionActionMode.remove, l10n),
                              ],
                            ),
                            // Spacing between mode selector and action summary
                            const SizedBox(height: AppSizes.p6),
                            // Selection summary / action area
                            if (selectedCount == 0) ...[
                              // Hint when no cells are selected
                              Row(
                                children: [
                                  // Touch hint icon
                                  NaIcon(
                                    NaIcons.touchApp,
                                    size : AppSizes.icon14,
                                    color: AppColors.textSecondary(context),
                                  ),
                                  // Spacing
                                  const SizedBox(width: AppSizes.p6),
                                  // Hint label
                                  Expanded(
                                    child: Text(
                                      l10n.mapDownloadSelectionEmptyHint,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style   : TextStyle(
                                        fontSize: AppSizes.font11,
                                        color   : AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ]else if (_isApplyingAction) ...[
                              // Active download progress bar with pause and cancel controls
                              () {
                                final bool isSelectionPaused = _mapDownloadService.isItemPaused(MapDownloadService.activeSelectionDownloadId);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize      : MainAxisSize.min,
                                  children          : [
                                    // Progress status row with Pause, Resume, and Cancel buttons
                                    Row(
                                      children: [
                                        // Status label
                                        Expanded(
                                          child: Text(
                                            isSelectionPaused
                                              ? l10n.mapDownloadStatusPaused(progressPercent)
                                              : l10n.mapDownloadStatusDownloading(progressPercent),
                                            style: TextStyle(
                                              fontSize  : AppSizes.font12,
                                              fontWeight: FontWeight.bold,
                                              color     : isSelectionPaused
                                                ? AppColors.detailDetailed(context)
                                                : _actionMode.getColor(context),
                                            ),
                                          ),
                                        ),
                                        // Spacing
                                        const SizedBox(width: AppSizes.p8),
                                        // Pause or Resume button
                                        if (isSelectionPaused) ...[
                                          GestureDetector(
                                            onTap: () {
                                              _mapDownloadService.resumeDownloadAsync(MapDownloadService.activeSelectionDownloadId);
                                            },
                                            child: Container(
                                              padding   : const EdgeInsets.symmetric(horizontal: AppSizes.p8, vertical: AppSizes.p4),
                                              decoration: BoxDecoration(
                                                color       : AppColors.detailDetailed(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(AppSizes.radius6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children    : [
                                                  NaIcon(NaIcons.playArrow, size: AppSizes.icon14, color: AppColors.detailDetailed(context)),
                                                  const SizedBox(width: AppSizes.p2),
                                                  Text(
                                                    l10n.commonResume,
                                                    style: TextStyle(
                                                      fontSize  : AppSizes.font11,
                                                      fontWeight: FontWeight.bold,
                                                      color     : AppColors.detailDetailed(context),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ]else ...[
                                          GestureDetector(
                                            onTap: () {
                                              _mapDownloadService.pauseDownload(MapDownloadService.activeSelectionDownloadId);
                                            },
                                            child: Container(
                                              padding   : const EdgeInsets.symmetric(horizontal: AppSizes.p8, vertical: AppSizes.p4),
                                              decoration: BoxDecoration(
                                                color       : _actionMode.getColor(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(AppSizes.radius6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children    : [
                                                  NaIcon(NaIcons.pause, size: AppSizes.icon14, color: _actionMode.getColor(context)),
                                                  const SizedBox(width: AppSizes.p2),
                                                  Text(
                                                    l10n.commonPause,
                                                    style: TextStyle(
                                                      fontSize  : AppSizes.font11,
                                                      fontWeight: FontWeight.bold,
                                                      color     : _actionMode.getColor(context),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                        // Spacing
                                        const SizedBox(width: AppSizes.p6),
                                        // Cancel download button
                                        GestureDetector(
                                          onTap: () {
                                            _mapDownloadService.cancelDownloadAsync(MapDownloadService.activeSelectionDownloadId);
                                            setState(() {
                                              _isApplyingAction = false;
                                            });
                                          },
                                          child: Container(
                                            padding   : const EdgeInsets.symmetric(horizontal: AppSizes.p8, vertical: AppSizes.p4),
                                            decoration: BoxDecoration(
                                              color       : AppColors.error(context).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(AppSizes.radius6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children    : [
                                                NaIcon(NaIcons.close, size: AppSizes.icon14, color: AppColors.error(context)),
                                                const SizedBox(width: AppSizes.p2),
                                                Text(
                                                  l10n.commonCancel,
                                                  style: TextStyle(
                                                    fontSize  : AppSizes.font11,
                                                    fontWeight: FontWeight.bold,
                                                    color     : AppColors.error(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Spacing
                                    const SizedBox(height: AppSizes.p6),
                                    // Progress track
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(AppSizes.radius6),
                                      child       : Container(
                                        height: AppSizes.p6,
                                        color : AppColors.border(context),
                                        child : FractionallySizedBox(
                                          alignment  : Alignment.centerLeft,
                                          widthFactor: (activeProgress ?? 0.0).clamp(0.0, 1.0),
                                          child      : Container(
                                            color: isSelectionPaused
                                              ? AppColors.detailDetailed(context)
                                              : _actionMode.getColor(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }(),
                            ]else ...[
                              // Active selection summary + Deselect + Download/Remove button
                              Row(
                                children: [
                                  // Summary text & clear action
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize      : MainAxisSize.min,
                                      children          : [
                                        // Cell/place count summary
                                        Text(
                                          (_actionMode == MapSelectionActionMode.remove)
                                            ? l10n.mapDownloadRemoveSummary(removableCount)
                                            : (_selectedPlace != null)
                                              ? l10n.mapDownloadNamedSelectionSummary(
                                                  _selectedPlace!.getDisplayName(localeCode),
                                                  selectedCount,
                                                )
                                              : l10n.mapDownloadSelectedCellsSummary(selectedCount),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style   : TextStyle(
                                            fontSize  : AppSizes.font12,
                                            fontWeight: FontWeight.w600,
                                            color     : AppColors.textPrimary(context),
                                          ),
                                        ),
                                        // Clear selection link
                                        GestureDetector(
                                          onTap: _clearSelection,
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: AppSizes.p2),
                                            child  : Text(
                                              l10n.mapDownloadClearSelectionAction,
                                              style: TextStyle(
                                                fontSize  : AppSizes.font11,
                                                fontWeight: FontWeight.w600,
                                                color     : AppColors.textSecondary(context),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Spacing before action button
                                  const SizedBox(width: AppSizes.p8),
                                  // Primary Download or Remove button
                                  GestureDetector(
                                    onTap: ((_actionMode == MapSelectionActionMode.remove) && (removableCount == 0))
                                      ? null
                                      : () => _applySelectionActionAsync(l10n, localeCode, downloadedCellLevelMap),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSizes.p12,
                                        vertical  : AppSizes.p8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ((_actionMode == MapSelectionActionMode.remove) && (removableCount == 0))
                                          ? AppColors.disabled(context)
                                          : _actionMode.getColor(context),
                                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children    : [
                                          // Action icon
                                          NaIcon(
                                            (_actionMode == MapSelectionActionMode.remove)
                                              ? NaIcons.deleteOutline
                                              : NaIcons.cloudDownload,
                                            size : AppSizes.icon16,
                                            color: AppColors.white(context),
                                          ),
                                          // Spacing
                                          const SizedBox(width: AppSizes.p6),
                                          // Action label
                                          Text(
                                            (_actionMode == MapSelectionActionMode.remove)
                                              ? l10n.mapDownloadApplyRemoveAction(removableCount)
                                              : l10n.mapDownloadApplyDownloadAction(
                                                  activeDetailLevel.getBadge(l10n),
                                                  estimatedMbText,
                                                ),
                                            style: TextStyle(
                                              fontSize  : AppSizes.font12,
                                              fontWeight: FontWeight.bold,
                                              color     : AppColors.white(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
