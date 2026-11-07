import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings-service.dart';
import '../../../widgets/app-divider.widget.dart';
import '../../../services/map-download-service.dart';

/// Modal dialog presenting the list of downloaded geographic zones with multi-selection to change detail level or remove them.
class DownloadedZonesModal extends StatefulWidget {
  const DownloadedZonesModal({ super.key });

  /// Opens the downloaded zones management modal.
  static Future showAsync(BuildContext context) {
    return naShowDialogAsync(
      context: context,
      builder: (BuildContext dialogContext) => const DownloadedZonesModal(),
    );
  }

  @override
  State<DownloadedZonesModal> createState() => _DownloadedZonesModalState();
}

/// State for [DownloadedZonesModal] managing multi-selection, detail level updates, and zone deletion.
class _DownloadedZonesModalState extends State<DownloadedZonesModal> {
  final MapDownloadService _mapDownloadService = MapDownloadService();
  final SettingsService _settingsService       = SettingsService();
  final Set<String> _selectedZoneIdSet         = {};

  bool _isUpdatingLevel = false;

  /// Toggles selection for a single zone ID.
  void _toggleZoneSelection(String zoneId) {
    if (_isUpdatingLevel) {
      return;
    }
    setState(() {
      if (_selectedZoneIdSet.contains(zoneId)) {
        _selectedZoneIdSet.remove(zoneId);
      }else {
        _selectedZoneIdSet.add(zoneId);
      }
    });
  }

  /// Selects all zones or clears selection if all are already selected.
  void _toggleSelectAll(List<DownloadedZoneModel> zoneList) {
    if (_isUpdatingLevel) {
      return;
    }
    setState(() {
      if (_selectedZoneIdSet.length == zoneList.length) {
        _selectedZoneIdSet.clear();
      }else {
        _selectedZoneIdSet.clear();
        for (final DownloadedZoneModel zone in zoneList) {
          _selectedZoneIdSet.add(zone.id);
        }
      }
    });
  }

  /// Displays an alert dialog when the Map Server cannot be reached for a level change download.
  Future _showOfflineErrorDialogAsync(AppLocalizations l10n) async {
    await naShowDialogAsync(
      context: context,
      builder: (BuildContext errorDialogContext) {
        return NaAlertDialog(
          title  : Text(l10n.mapDownloadServerOffline(_settingsService.mapServerUrl)),
          content: Text(l10n.mapDownloadServerOfflineError(_settingsService.mapServerUrl)),
          actions: [
            NaDialogAction(
              child    : Text(l10n.commonClose),
              onPressed: () => Navigator.of(errorDialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  /// Prompts the user for a new [MapDetailLevel] and updates all selected zones.
  Future _handleChangeLevelAsync(AppLocalizations l10n) async {
    if (_selectedZoneIdSet.isEmpty || _isUpdatingLevel) {
      return;
    }

    final List<NaSelectionItem<MapDetailLevel>> levelItemList = [
      NaSelectionItem<MapDetailLevel>(
        value   : MapDetailLevel.base,
        title   : Text(MapDetailLevel.base.getTitle(l10n)),
        subtitle: Text(MapDetailLevel.base.getDescription(l10n)),
      ),
      NaSelectionItem<MapDetailLevel>(
        value   : MapDetailLevel.detailed,
        title   : Text(MapDetailLevel.detailed.getTitle(l10n)),
        subtitle: Text(MapDetailLevel.detailed.getDescription(l10n)),
      ),
      NaSelectionItem<MapDetailLevel>(
        value   : MapDetailLevel.complete,
        title   : Text(MapDetailLevel.complete.getTitle(l10n)),
        subtitle: Text(MapDetailLevel.complete.getDescription(l10n)),
      ),
    ];

    final MapDetailLevel? chosenLevel = await naShowSelectionModalAsync<MapDetailLevel>(
      context     : context,
      title       : Text(l10n.mapDownloadZonesChangeLevelTitle),
      cancelButton: Text(l10n.commonCancel),
      itemList    : levelItemList,
    );

    if ((chosenLevel == null) || (!mounted)) {
      return;
    }

    setState(() {
      _isUpdatingLevel = true;
    });

    final List<String> targetZoneIdList = _selectedZoneIdSet.toList();
    final bool success                  = await _mapDownloadService.changeZoneListLevelAsync(
      targetZoneIdList,
      chosenLevel,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdatingLevel = false;
    });

    if (!success) {
      await _showOfflineErrorDialogAsync(l10n);
    }
  }

  /// Confirms and removes all selected zones from local storage.
  Future _handleRemoveSelectedAsync(AppLocalizations l10n) async {
    if (_selectedZoneIdSet.isEmpty || _isUpdatingLevel) {
      return;
    }

    final int selectedCount = _selectedZoneIdSet.length;
    final bool? confirmed   = await naShowDialogAsync<bool>(
      context: context,
      builder: (BuildContext confirmContext) {
        return NaAlertDialog(
          title  : Text(l10n.mapDownloadZonesRemoveConfirmTitle),
          content: Text(l10n.mapDownloadZonesRemoveConfirmMsg(selectedCount)),
          actions: [
            NaDialogAction(
              child    : Text(l10n.commonCancel),
              onPressed: () => Navigator.of(confirmContext).pop(false),
            ),
            NaDialogAction(
              optionsBuilder: (BuildContext actionContext, NaUiType uiType) {
                if (uiType == NaUiType.cupertino) {
                  return NaDialogActionOptionsCupertino(
                    isDestructiveAction: true,
                  );
                }
                return null;
              },
              child: Text(
                l10n.mapDownloadZonesRemoveBtn,
                style: TextStyle(color: AppColors.error(confirmContext)),
              ),
              onPressed: () => Navigator.of(confirmContext).pop(true),
            ),
          ],
        );
      },
    );

    if ((confirmed == true) && mounted) {
      final List<String> targetZoneIdList = _selectedZoneIdSet.toList();
      await _mapDownloadService.removeZoneListAsync(targetZoneIdList);
      if (mounted) {
        setState(() {
          _selectedZoneIdSet.clear();
        });
      }
    }
  }

  /// Builds a single selectable downloaded zone row.
  Widget _buildZoneItemRow(
    BuildContext context,
    DownloadedZoneModel zone,
    AppLocalizations l10n,
  ) {
    final bool isSelected  = _selectedZoneIdSet.contains(zone.id);
    final Color levelColor = zone.level.getColor(context);
    final String typeLabel = zone.getLocalizedTypeLabel(l10n);
    final String sizeText  = zone.estimatedMb.toStringAsFixed(1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap   : () => _toggleZoneSelection(zone.id),
      child   : Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p12,
          vertical  : AppSizes.p10,
        ),
        child: Row(
          children: [
            // Multi-select checkbox
            NaCheckbox(
              value    : isSelected,
              onChanged: (bool? checkedValue) => _toggleZoneSelection(zone.id),
            ),

            // Spacing after checkbox
            const SizedBox(width: AppSizes.p8),

            // Zone title and metadata subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize      : MainAxisSize.min,
                children          : [
                  // Zone display name
                  Text(
                    zone.name,
                    style: TextStyle(
                      fontSize  : AppSizes.font14,
                      fontWeight: FontWeight.w600,
                      color     : AppColors.textPrimary(context),
                    ),
                  ),

                  // Vertical spacing
                  const SizedBox(height: AppSizes.p2),

                  // Zone type, cell count, and size subtitle
                  Text(
                    l10n.mapDownloadZoneItemSubtitle(
                      typeLabel,
                      zone.cellIdList.length,
                      sizeText,
                    ),
                    style: TextStyle(
                      fontSize: AppSizes.font12,
                      color   : AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            // Spacing before level badge
            const SizedBox(width: AppSizes.p8),

            // Detail level colored badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p8,
                vertical  : AppSizes.p4,
              ),
              decoration: BoxDecoration(
                color       : levelColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                border      : Border.all(
                  color: levelColor,
                  width: AppSizes.borderWidthRegular,
                ),
              ),
              child: Text(
                zone.level.getBadge(l10n),
                style: TextStyle(
                  fontSize  : AppSizes.font11,
                  fontWeight: FontWeight.bold,
                  color     : levelColor,
                ),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child  : ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth : AppSizes.zoneModalMaxWidth,
            maxHeight: AppSizes.zoneModalMaxHeight,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize  : AppSizes.font14,
              color     : AppColors.textPrimary(context),
              decoration: TextDecoration.none,
            ),
            child: NaCard(
              child: ListenableBuilder(
                listenable: _mapDownloadService,
                builder   : (BuildContext builderContext, Widget? child) {
                  final List<DownloadedZoneModel> zoneList = _mapDownloadService.getDownloadedZoneList();
                  final Set<String> validIdSet             = zoneList.map((DownloadedZoneModel item) => item.id).toSet();
                  _selectedZoneIdSet.removeWhere((String selectedId) => !validIdSet.contains(selectedId));

                  final bool hasZones       = zoneList.isNotEmpty;
                  final bool allSelected    = hasZones && (_selectedZoneIdSet.length == zoneList.length);
                  final bool hasSelection   = _selectedZoneIdSet.isNotEmpty;
                  final double? progress    = _mapDownloadService.getItemProgress(MapDownloadService.activeSelectionDownloadId);
                  final int progressPercent = ((progress ?? 0.0) * 100.0).round();

                  return Column(
                    mainAxisSize      : MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children          : [
                      // Modal header bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.p16,
                          AppSizes.p12,
                          AppSizes.p8,
                          AppSizes.p12,
                        ),
                        child: Row(
                          children: [
                            // Header icon
                            const NaIcon(
                              NaIcons.checklist,
                              size: AppSizes.icon20,
                            ),

                            // Spacing
                            const SizedBox(width: AppSizes.p8),

                            // Modal title
                            Expanded(
                              child: Text(
                                l10n.mapDownloadZonesModalTitle,
                                style: TextStyle(
                                  fontSize  : AppSizes.font16,
                                  fontWeight: FontWeight.bold,
                                  color     : AppColors.textPrimary(builderContext),
                                ),
                              ),
                            ),

                            // Close dialog button
                            NaIconButton(
                              icon     : const NaIcon(NaIcons.close, size: AppSizes.icon20),
                              onPressed: () => Navigator.of(builderContext).pop(),
                            ),
                          ],
                        ),
                      ),

                      // Header bottom divider
                      const AppDivider(indent: AppSizes.p0),

                      // Empty state when no zones are downloaded
                      if (!hasZones) ...[
                        Padding(
                          padding: const EdgeInsets.all(AppSizes.p32),
                          child  : Column(
                            mainAxisSize: MainAxisSize.min,
                            children    : [
                              // Empty icon
                              NaIcon(
                                NaIcons.map,
                                size : AppSizes.icon48,
                                color: AppColors.textSecondary(builderContext),
                              ),

                              // Spacing
                              const SizedBox(height: AppSizes.p12),

                              // Empty state title
                              Text(
                                l10n.mapDownloadZonesEmptyTitle,
                                textAlign: TextAlign.center,
                                style    : TextStyle(
                                  fontSize  : AppSizes.font15,
                                  fontWeight: FontWeight.bold,
                                  color     : AppColors.textPrimary(builderContext),
                                ),
                              ),

                              // Spacing
                              const SizedBox(height: AppSizes.p6),

                              // Empty state description
                              Text(
                                l10n.mapDownloadZonesEmptyDesc,
                                textAlign: TextAlign.center,
                                style    : TextStyle(
                                  fontSize: AppSizes.font13,
                                  color   : AppColors.textSecondary(builderContext),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]else ...[
                        // Selection count and Select All / Deselect All toolbar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.p16,
                            vertical  : AppSizes.p8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children         : [
                              // Selected count text
                              Text(
                                l10n.mapDownloadZonesSelectedCount(_selectedZoneIdSet.length),
                                style: TextStyle(
                                  fontSize  : AppSizes.font12,
                                  fontWeight: FontWeight.w500,
                                  color     : AppColors.textSecondary(builderContext),
                                ),
                              ),

                              // Select all / Deselect all toggle link
                              GestureDetector(
                                onTap: () => _toggleSelectAll(zoneList),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
                                  child  : Text(
                                    allSelected ? l10n.mapDownloadZonesDeselectAll : l10n.mapDownloadZonesSelectAll,
                                    style: TextStyle(
                                      fontSize  : AppSizes.font12,
                                      fontWeight: FontWeight.bold,
                                      color     : AppColors.primary(builderContext),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Toolbar divider
                        const AppDivider(indent: AppSizes.p0),

                        // Scrollable list of downloaded zones
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap : true,
                            itemCount  : zoneList.length,
                            itemBuilder: (BuildContext itemContext, int zoneIndex) {
                              final DownloadedZoneModel zone = zoneList[zoneIndex];
                              final bool isLastItem          = zoneIndex == (zoneList.length - 1);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children    : [
                                  // Zone row
                                  _buildZoneItemRow(itemContext, zone, l10n),

                                  // Row divider
                                  if (!isLastItem) ...[
                                    const AppDivider(),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),

                        // Progress bar while changing detail level
                        if (_isUpdatingLevel) ...[
                          // Progress top divider
                          const AppDivider(indent: AppSizes.p0),

                          // Progress bar container
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.p16,
                              vertical  : AppSizes.p10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize      : MainAxisSize.min,
                              children          : [
                                // Progress label
                                Text(
                                  l10n.mapDownloadStatusDownloading(progressPercent),
                                  style: TextStyle(
                                    fontSize  : AppSizes.font12,
                                    fontWeight: FontWeight.bold,
                                    color     : AppColors.primary(builderContext),
                                  ),
                                ),

                                // Spacing
                                const SizedBox(height: AppSizes.p6),

                                // Progress bar track
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                                  child       : Container(
                                    height: AppSizes.p6,
                                    color : AppColors.border(builderContext),
                                    child : FractionallySizedBox(
                                      alignment  : Alignment.centerLeft,
                                      widthFactor: (progress ?? 0.0).clamp(0.0, 1.0),
                                      child      : Container(
                                        color: AppColors.primary(builderContext),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Footer divider
                        const AppDivider(indent: AppSizes.p0),

                        // Action buttons footer (Change Level + Remove)
                        Padding(
                          padding: const EdgeInsets.all(AppSizes.p12),
                          child  : Row(
                            children: [
                              // Change detail level button
                              Expanded(
                                child: NaButtonFilled(
                                  onPressed: (hasSelection && (!_isUpdatingLevel))
                                    ? () => _handleChangeLevelAsync(l10n)
                                    : null,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize     : MainAxisSize.min,
                                    children         : [
                                      // Layers icon
                                      const NaIcon(NaIcons.layers, size: AppSizes.icon16),

                                      // Spacing
                                      const SizedBox(width: AppSizes.p6),

                                      // Change level text
                                      Flexible(
                                        child: Text(
                                          l10n.mapDownloadZonesChangeLevelBtn,
                                          overflow: TextOverflow.ellipsis,
                                          style   : const TextStyle(fontSize: AppSizes.font13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Horizontal spacing between buttons
                              const SizedBox(width: AppSizes.p10),

                              // Remove selected zones button
                              Expanded(
                                child: GestureDetector(
                                  onTap: (hasSelection && (!_isUpdatingLevel))
                                    ? () => _handleRemoveSelectedAsync(l10n)
                                    : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSizes.p12,
                                      vertical  : AppSizes.p10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (hasSelection && (!_isUpdatingLevel))
                                        ? AppColors.error(builderContext).withValues(alpha: 0.12)
                                        : AppColors.border(builderContext).withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                                      border      : Border.all(
                                        color: (hasSelection && (!_isUpdatingLevel))
                                          ? AppColors.error(builderContext)
                                          : AppColors.border(builderContext),
                                        width: AppSizes.borderWidthRegular,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize     : MainAxisSize.min,
                                      children         : [
                                        // Delete icon
                                        NaIcon(
                                          NaIcons.deleteOutline,
                                          size : AppSizes.icon16,
                                          color: (hasSelection && (!_isUpdatingLevel))
                                            ? AppColors.error(builderContext)
                                            : AppColors.disabled(builderContext),
                                        ),

                                        // Spacing
                                        const SizedBox(width: AppSizes.p6),

                                        // Remove label
                                        Flexible(
                                          child: Text(
                                            l10n.mapDownloadZonesRemoveBtn,
                                            overflow: TextOverflow.ellipsis,
                                            style   : TextStyle(
                                              fontSize  : AppSizes.font13,
                                              fontWeight: FontWeight.w600,
                                              color     : (hasSelection && (!_isUpdatingLevel))
                                                ? AppColors.error(builderContext)
                                                : AppColors.disabled(builderContext),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
