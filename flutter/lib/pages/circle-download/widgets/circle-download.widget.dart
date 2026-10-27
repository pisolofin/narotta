import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nanna_platform/nanna_platform.dart';

import 'circle-download-painter.dart';
import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/geo-cell-service.dart';
import '../../../services/location-service.dart';
import '../../../services/settings-service.dart';
import '../../../services/map-server-service.dart';
import '../../../services/map-download-service.dart';

/// Interaction modes for the Circle and Download view.
enum CircleInteractionMode {
  draw,
  pan,
}

/// Interactive body content for the "Cerchia e scarica" (Circle & Download) page.
class CircleDownload extends StatefulWidget {
  const CircleDownload({ super.key });

  @override
  State<CircleDownload> createState() => _CircleDownloadState();
}

/// State for [CircleDownload] handling world map gestures, cell calculation, detail level selection, and simulated download.
class _CircleDownloadState extends State<CircleDownload> {
  static const double _metersPerDegreeLat = 111320.0;
  static const double _baseCellMb = 12.0;

  final LocationService _locationService = LocationService();
  final MapDownloadService _mapDownloadService = MapDownloadService();
  final MapServerService _mapServerService = MapServerService();
  final SettingsService _settingsService = SettingsService();

  CircleInteractionMode _interactionMode = CircleInteractionMode.draw;
  Offset _cameraWorldMeters = Offset.zero;
  double _zoom = 0.0003; // Overview scale showing Europe and continents
  double _referenceLat = 45.4642; // Milan default
  double _referenceLon = 9.1900;

  final List<Offset> _lassoScreenPointList = [];
  List<GeoCellModel> _selectedCellList = [];

  bool _isDrawing = false;
  MapDetailLevel _selectedDetailLevel = MapDetailLevel.base;

  bool _isDownloading = false;
  int _downloadPercent = 0;
  bool _downloadSuccess = false;
  Timer? _downloadTimer;

  @override
  void initState() {
    super.initState();
    final Position? position = _locationService.currentPosition;
    if (position != null) {
      _referenceLat = position.latitude;
      _referenceLon = position.longitude;
    }
  }

  @override
  void dispose() {
    _downloadTimer?.cancel();
    super.dispose();
  }

  /// Calculates the total estimated MB based on selected cells and selected detail level.
  double _calculateTotalEstimatedMb() {
    if (_selectedCellList.isEmpty) {
      return 0.0;
    }
    final double perCellMb = _baseCellMb * _selectedDetailLevel.sizeMultiplier;
    return double.parse((perCellMb * _selectedCellList.length).toStringAsFixed(1));
  }

  /// Converts screen offset coordinates to geographic (lon, lat) Point.
  math.Point<double> _screenToGeo(Offset screenPos, Size size) {
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double latRadians = _referenceLat * math.pi / 180.0;
    final double metersPerDegreeLon = _metersPerDegreeLat * math.cos(latRadians);

    final double worldX = _cameraWorldMeters.dx + ((screenPos.dx - center.dx) / _zoom);
    final double worldY = _cameraWorldMeters.dy - ((screenPos.dy - center.dy) / _zoom);

    final double lon = _referenceLon + (worldX / metersPerDegreeLon);
    final double lat = _referenceLat + (worldY / _metersPerDegreeLat);

    return math.Point<double>(lon, lat);
  }

  /// Handles finger press down on canvas.
  void _onPanStart(DragStartDetails details, Size size) {
    if (_interactionMode == CircleInteractionMode.draw) {
      setState(() {
        _isDrawing = true;
        _downloadSuccess = false;
        _lassoScreenPointList.clear();
        _lassoScreenPointList.add(details.localPosition);
      });
    }
  }

  /// Handles finger drag movement.
  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_interactionMode == CircleInteractionMode.draw) {
      setState(() {
        _lassoScreenPointList.add(details.localPosition);
      });
    }else {
      // Pan camera mode
      setState(() {
        final double deltaWorldX = -details.delta.dx / _zoom;
        final double deltaWorldY = details.delta.dy / _zoom;
        _cameraWorldMeters = Offset(
          _cameraWorldMeters.dx + deltaWorldX,
          _cameraWorldMeters.dy + deltaWorldY,
        );
      });
    }
  }

  /// Handles finger lift from screen, calculating intersecting cells.
  Future _onPanEndAsync(DragEndDetails details, Size size) async {
    if (_interactionMode != CircleInteractionMode.draw) {
      return;
    }

    setState(() {
      _isDrawing = false;
    });

    if (_lassoScreenPointList.length < 3) {
      return;
    }

    final List<math.Point<double>> geoPointList = [];
    for (final Offset screenPos in _lassoScreenPointList) {
      geoPointList.add(_screenToGeo(screenPos, size));
    }

    final List<GeoCellModel> cellList = GeoCellService.getIntersectingCellListForPolygon(geoPointList);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedCellList = cellList;
    });
  }

  /// Clears the current lasso and cell selection.
  void _clearSelection() {
    setState(() {
      _lassoScreenPointList.clear();
      _selectedCellList = [];
      _downloadSuccess = false;
      _downloadPercent = 0;
      _isDownloading = false;
    });
    _downloadTimer?.cancel();
  }

  /// Recenters the camera on the user's current GPS position or default coordinates.
  void _recenter() {
    final Position? position = _locationService.currentPosition;
    if (position != null) {
      setState(() {
        _referenceLat = position.latitude;
        _referenceLon = position.longitude;
        _cameraWorldMeters = Offset.zero;
      });
    }else {
      setState(() {
        _cameraWorldMeters = Offset.zero;
      });
    }
  }

  /// Starts downloading the selected cells with progress updates.
  Future _startDownloadAsync(AppLocalizations l10n) async {
    if ((_selectedCellList.isEmpty) || _isDownloading) {
      return;
    }

    final bool isOnline = await _mapServerService.checkHealthAsync();
    if (!mounted) {
      return;
    }

    if (!isOnline) {
      await naShowDialog(
        context: context,
        builder: (BuildContext dialogContext) => NaAlertDialog(
          title  : Text(l10n.mapDownloadServerOffline(_settingsService.mapServerUrl)),
          content: Text(l10n.mapDownloadServerOfflineError(_settingsService.mapServerUrl)),
          actions: [
            NaDialogAction(
              child    : Text(l10n.commonClose),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadPercent = 0;
      _downloadSuccess = false;
    });

    final List<String> cellIdList = _selectedCellList.map((GeoCellModel c) => c.cellId).toList();

    _downloadTimer?.cancel();
    _downloadTimer = Timer.periodic(const Duration(milliseconds: 80), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_downloadPercent < 90) {
        setState(() {
          _downloadPercent += 10;
        });
      }
    });

    final bool success = await _mapDownloadService.downloadCellListAsync(cellIdList, _selectedDetailLevel);
    _downloadTimer?.cancel();

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _downloadPercent = 100;
        _isDownloading   = false;
        _downloadSuccess = true;
      });
    }else {
      setState(() {
        _downloadPercent = 0;
        _isDownloading   = false;
        _downloadSuccess = false;
      });
    }
  }

  /// Builds a selectable card for a detail level choice.
  Widget _buildDetailLevelOption(
    BuildContext context,
    MapDetailLevel level,
    AppLocalizations l10n,
  ) {
    final bool isSelected = _selectedDetailLevel == level;
    final Color levelColor = level.getColor(context);
    final double mbForSelection = (_baseCellMb * level.sizeMultiplier * _selectedCellList.length);
    final String sizeString = mbForSelection.toStringAsFixed(1);

    return GestureDetector(
      onTap: () {
        if (!_isDownloading) {
          setState(() {
            _selectedDetailLevel = level;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p10,
          vertical  : AppSizes.p8,
        ),
        decoration: BoxDecoration(
          color       : isSelected ? levelColor.withValues(alpha: 0.16) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border      : Border.all(
            color: isSelected ? levelColor : AppColors.border(context),
            width: isSelected ? AppSizes.borderWidthThick : AppSizes.borderWidthRegular,
          ),
        ),
        child: Row(
          children: [
            // Level indicator colored dot
            Container(
              width     : AppSizes.p12,
              height    : AppSizes.p12,
              decoration: BoxDecoration(
                color: levelColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSizes.p8),

            // Level title
            Expanded(
              child: Text(
                level.getBadge(l10n),
                style: TextStyle(
                  fontSize  : AppSizes.font13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color     : isSelected ? levelColor : AppColors.textPrimary(context),
                ),
              ),
            ),

            // Size badge
            Text(
              '$sizeString MB',
              style: TextStyle(
                fontSize  : AppSizes.font12,
                fontWeight: FontWeight.w600,
                color     : AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double totalMb        = _calculateTotalEstimatedMb();
    final String sizeString     = totalMb.toStringAsFixed(1);

    return ListenableBuilder(
      listenable: _mapDownloadService,
      builder   : (BuildContext context, Widget? child) {
        // Collect currently downloaded cells and their levels
        final Map<String, MapDetailLevel> downloadedCellLevelMap = {};
        for (final String cellId in _mapDownloadService.getDownloadedCellIdList()) {
          final MapDetailLevel? level = _mapDownloadService.getCellDetailLevel(cellId);
          if (level != null) {
            downloadedCellLevelMap[cellId] = level;
          }
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              children: [
                // 1. Interactive drawing canvas with world continent map and cell grid
                Positioned.fill(
                  child: GestureDetector(
                    onPanStart : (DragStartDetails details) => _onPanStart(details, canvasSize),
                    onPanUpdate: (DragUpdateDetails details) => _onPanUpdate(details, canvasSize),
                    onPanEnd   : (DragEndDetails details) => _onPanEndAsync(details, canvasSize),
                    child      : CustomPaint(
                      size   : canvasSize,
                      painter: CircleDownloadPainter(
                        cameraWorldMeters          : _cameraWorldMeters,
                        zoom                       : _zoom,
                        referenceLat               : _referenceLat,
                        referenceLon               : _referenceLon,
                        currentLassoScreenPointList: _lassoScreenPointList,
                        selectedCellList           : _selectedCellList,
                        downloadedCellLevelMap     : downloadedCellLevelMap,
                        isDrawing                  : _isDrawing,
                        backgroundColor            : AppColors.mapVoid(context),
                        continentFillColor         : AppColors.mapContinent(context),
                        continentBorderColor       : AppColors.mapContinentBorder(context),
                        gridLineColor              : AppColors.mapGridMinor(context),
                        lassoStrokeColor           : AppColors.primary(context),
                        lassoFillColor             : AppColors.primary(context).withValues(alpha: 0.15),
                        cellSelectedFillColor      : AppColors.primary(context).withValues(alpha: 0.28),
                        cellSelectedBorderColor    : AppColors.primary(context),
                        detailBaseColor            : AppColors.detailBase(context),
                        detailDetailedColor        : AppColors.detailDetailed(context),
                        detailCompleteColor        : AppColors.detailComplete(context),
                        textColor                  : AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ),

                // 2. Top instruction and legend header
                Positioned(
                  top  : AppSizes.p16,
                  left : AppSizes.p16,
                  right: AppSizes.p16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children    : [
                      // Instruction pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p16,
                          vertical  : AppSizes.p8,
                        ),
                        decoration: BoxDecoration(
                          color       : AppColors.surface(context).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(AppSizes.radius24),
                          border      : Border.all(
                            color: AppColors.border(context),
                            width: AppSizes.borderWidthRegular,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color     : AppColors.shadow(context),
                              blurRadius: AppSizes.shadowBlur10,
                              offset    : AppSizes.shadowOffset4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children    : [
                            // Brush icon
                            const NaIcon(NaIcons.brush),
                            const SizedBox(width: AppSizes.p8),
                            // Instruction label
                            Text(
                              l10n.circleDownloadDrawInstruction,
                              style: TextStyle(
                                fontSize  : AppSizes.font12,
                                fontWeight: FontWeight.w600,
                                color     : AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Color Legend for downloaded levels
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p12,
                          vertical  : AppSizes.p6,
                        ),
                        decoration: BoxDecoration(
                          color       : AppColors.surface(context).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppSizes.radius16),
                          border      : Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children    : [
                            Text(
                              l10n.circleDownloadLegendTitle,
                              style: TextStyle(
                                fontSize  : AppSizes.font10,
                                fontWeight: FontWeight.bold,
                                color     : AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(width: AppSizes.p8),

                            // Base color dot & label
                            Container(
                              width     : AppSizes.p8,
                              height    : AppSizes.p8,
                              decoration: BoxDecoration(
                                color: AppColors.detailBase(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSizes.p4),
                            Text(
                              l10n.circleDownloadLegendBase,
                              style: TextStyle(
                                fontSize: AppSizes.font10,
                                color   : AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(width: AppSizes.p8),

                            // Detailed color dot & label
                            Container(
                              width     : AppSizes.p8,
                              height    : AppSizes.p8,
                              decoration: BoxDecoration(
                                color: AppColors.detailDetailed(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSizes.p4),
                            Text(
                              l10n.circleDownloadLegendDetailed,
                              style: TextStyle(
                                fontSize: AppSizes.font10,
                                color   : AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(width: AppSizes.p8),

                            // Complete color dot & label
                            Container(
                              width     : AppSizes.p8,
                              height    : AppSizes.p8,
                              decoration: BoxDecoration(
                                color: AppColors.detailComplete(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSizes.p4),
                            Text(
                              l10n.circleDownloadLegendComplete,
                              style: TextStyle(
                                fontSize: AppSizes.font10,
                                color   : AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Floating mode controls (Draw / Pan / Zoom / Recenter / Clear)
                Positioned(
                  top  : AppSizes.p64 + AppSizes.p32,
                  right: AppSizes.p16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children    : [
                      // Draw mode button
                      Container(
                        decoration: BoxDecoration(
                          color: (_interactionMode == CircleInteractionMode.draw)
                            ? AppColors.primary(context)
                            : AppColors.surface(context),
                          shape : BoxShape.circle,
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: NaIconButton(
                          icon     : const NaIcon(NaIcons.brush),
                          onPressed: () {
                            setState(() {
                              _interactionMode = CircleInteractionMode.draw;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Pan mode button
                      Container(
                        decoration: BoxDecoration(
                          color: (_interactionMode == CircleInteractionMode.pan)
                            ? AppColors.primary(context)
                            : AppColors.surface(context),
                          shape : BoxShape.circle,
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: NaIconButton(
                          icon     : const NaIcon(NaIcons.openWith),
                          onPressed: () {
                            setState(() {
                              _interactionMode = CircleInteractionMode.pan;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Zoom In button
                      Container(
                        decoration: BoxDecoration(
                          color : AppColors.surface(context),
                          shape : BoxShape.circle,
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: NaIconButton(
                          icon     : const NaIcon(NaIcons.add),
                          onPressed: () {
                            setState(() {
                              _zoom *= 1.45;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Zoom Out button
                      Container(
                        decoration: BoxDecoration(
                          color : AppColors.surface(context),
                          shape : BoxShape.circle,
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: NaIconButton(
                          icon     : const NaIcon(NaIcons.remove),
                          onPressed: () {
                            setState(() {
                              _zoom /= 1.45;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Recenter button
                      Container(
                        decoration: BoxDecoration(
                          color : AppColors.surface(context),
                          shape : BoxShape.circle,
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: NaIconButton(
                          icon     : const NaIcon(NaIcons.myLocation),
                          onPressed: _recenter,
                        ),
                      ),

                      // Conditional clear button if lasso exists
                      if (_lassoScreenPointList.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.p8),
                        Container(
                          decoration: BoxDecoration(
                            color : AppColors.surface(context),
                            shape : BoxShape.circle,
                            border: Border.all(color: AppColors.border(context)),
                          ),
                          child: NaIconButton(
                            icon     : const NaIcon(NaIcons.close),
                            onPressed: _clearSelection,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 4. Bottom card / Detail level selection drawer
                Positioned(
                  left  : AppSizes.p16,
                  right : AppSizes.p16,
                  bottom: AppSizes.p16,
                  child : NaCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.p16),
                      child  : Column(
                        mainAxisSize      : MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children          : [
                          if (_selectedCellList.isEmpty) ...[
                            // Empty state hint
                            Row(
                              children: [
                                // Info icon
                                const NaIcon(NaIcons.touchApp),
                                const SizedBox(width: AppSizes.p12),
                                // Hint text
                                Expanded(
                                  child: Text(
                                    l10n.circleDownloadNoSelectionHint,
                                    style: TextStyle(
                                      fontSize: AppSizes.font14,
                                      color   : AppColors.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ]else ...[
                            // Selection header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children         : [
                                // Cell count badge
                                Text(
                                  l10n.circleDownloadSelectedCellsCount(_selectedCellList.length),
                                  style: TextStyle(
                                    fontSize  : AppSizes.font16,
                                    fontWeight: FontWeight.bold,
                                    color     : AppColors.textPrimary(context),
                                  ),
                                ),
                                // Size badge
                                Text(
                                  l10n.circleDownloadEstimatedSize(sizeString),
                                  style: TextStyle(
                                    fontSize  : AppSizes.font14,
                                    fontWeight: FontWeight.w600,
                                    color     : _selectedDetailLevel.getColor(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p12),

                            // Detail Level Selector Section
                            Text(
                              l10n.circleDownloadDetailModalTitle,
                              style: TextStyle(
                                fontSize  : AppSizes.font12,
                                fontWeight: FontWeight.bold,
                                color     : AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p6),

                            // 3 Detail levels options list
                            Column(
                              children: [
                                _buildDetailLevelOption(context, MapDetailLevel.base, l10n),
                                const SizedBox(height: AppSizes.p6),
                                _buildDetailLevelOption(context, MapDetailLevel.detailed, l10n),
                                const SizedBox(height: AppSizes.p6),
                                _buildDetailLevelOption(context, MapDetailLevel.complete, l10n),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p12),

                            // Download status and progress
                            if (_isDownloading) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children          : [
                                  Text(
                                    l10n.circleDownloadProgressPercent(_downloadPercent),
                                    style: TextStyle(
                                      fontSize  : AppSizes.font12,
                                      fontWeight: FontWeight.w600,
                                      color     : _selectedDetailLevel.getColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.p6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                                    child       : Container(
                                      height: AppSizes.p8,
                                      color : AppColors.surface(context),
                                      child : FractionallySizedBox(
                                        alignment  : Alignment.centerLeft,
                                        widthFactor: _downloadPercent / 100.0,
                                        child      : Container(
                                          color: _selectedDetailLevel.getColor(context),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.p12),
                            ],

                            // Success notification
                            if (_downloadSuccess) ...[
                              Row(
                                children: [
                                  const NaIcon(NaIcons.check),
                                  const SizedBox(width: AppSizes.p8),
                                  Expanded(
                                    child: Text(
                                      l10n.circleDownloadCompleted,
                                      style: TextStyle(
                                        fontSize  : AppSizes.font12,
                                        fontWeight: FontWeight.bold,
                                        color     : AppColors.success(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.p12),
                            ],

                            // Action buttons row
                            Row(
                              children: [
                                // Clear button
                                Expanded(
                                  flex : 1,
                                  child: NaButton(
                                    onPressed: _clearSelection,
                                    child    : Text(l10n.circleDownloadActionClear),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p12),

                                // Download button
                                Expanded(
                                  flex : 2,
                                  child: NaButtonFilled(
                                    onPressed: _isDownloading ? null : () => _startDownloadAsync(l10n),
                                    child    : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children         : [
                                        const NaIcon(NaIcons.cloudDownload),
                                        const SizedBox(width: AppSizes.p8),
                                        Text(l10n.circleDownloadActionDownload),
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
                ),
              ],
            );
          },
        );
      },
    );
  }
}
