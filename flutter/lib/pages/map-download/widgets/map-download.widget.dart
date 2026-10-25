import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings-service.dart';
import '../../../services/map-server-service.dart';
import '../../../services/map-download-service.dart';
import '../../circle-download/circle-download.page.dart';

/// Body content widget for managing offline map downloads including World Base Map, Countries, and Regions.
class MapDownload extends StatefulWidget {
  const MapDownload({ super.key });

  @override
  State<MapDownload> createState() => _MapDownloadState();
}

/// State for [MapDownload] managing search query, catalog expansion, and detail level modals.
class _MapDownloadState extends State<MapDownload> {
  final MapDownloadService _mapDownloadService = MapDownloadService();
  final MapServerService _mapServerService     = MapServerService();
  final SettingsService _settingsService       = SettingsService();

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCountryIdSet       = { 'europe/italy' };

  String _searchFilterText = '';
  bool? _isServerOnline;

  @override
  void initState() {
    super.initState();
    _checkServerConnectivityAsync();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Checks whether the configured map distribution server is currently online.
  Future _checkServerConnectivityAsync() async {
    final bool online = await _mapServerService.checkHealthAsync();
    if (!mounted) {
      return;
    }
    setState(() {
      _isServerOnline = online;
    });
  }

  /// Toggles country expansion in the list.
  void _toggleCountryExpansion(String countryId) {
    setState(() {
      if (_expandedCountryIdSet.contains(countryId)) {
        _expandedCountryIdSet.remove(countryId);
      }else {
        _expandedCountryIdSet.add(countryId);
      }
    });
  }

  /// Downloads the world base map, alerting if the server is offline.
  Future _downloadWorldMapAsync(
    AppLocalizations l10n,
  ) async {
    final bool success = await _mapDownloadService.downloadWorldMapAsync(MapDetailLevel.base);
    if (!mounted) {
      return;
    }
    if (!success) {
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
    }
  }

  /// Opens the detail level selection dialog/modal for a country or region.
  Future _openDetailLevelPickerAsync(
    RegionCatalogItemModel item,
    AppLocalizations l10n,
  ) async {
    final MapDetailLevel? currentLevel = _mapDownloadService.getItemDetailLevel(item.id);
    MapDetailLevel selectedLevel = currentLevel ?? MapDetailLevel.base;

    final bool? confirmed = await naShowDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext _, StateSetter setModalState) {
            return NaAlertDialog(
              title  : Text(l10n.mapDownloadDetailSelectFor(item.name)),
              content: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
                  child  : Column(
                    mainAxisSize      : MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children          : [
                      // Base option card
                      _buildModalDetailLevelOption(
                        dialogContext,
                        item,
                        MapDetailLevel.base,
                        selectedLevel,
                        l10n,
                        onSelected: (MapDetailLevel level) => setModalState(() => selectedLevel = level),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Detailed option card
                      _buildModalDetailLevelOption(
                        dialogContext,
                        item,
                        MapDetailLevel.detailed,
                        selectedLevel,
                        l10n,
                        onSelected: (MapDetailLevel level) => setModalState(() => selectedLevel = level),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Complete option card
                      _buildModalDetailLevelOption(
                        dialogContext,
                        item,
                        MapDetailLevel.complete,
                        selectedLevel,
                        l10n,
                        onSelected: (MapDetailLevel level) => setModalState(() => selectedLevel = level),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                NaDialogAction(
                  child    : Text(l10n.commonCancel),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                NaDialogAction(
                  child: Text(
                    currentLevel == null
                      ? l10n.mapDownloadActionDownload(item.getEstimatedMb(selectedLevel).toString())
                      : l10n.mapDownloadActionUpdate,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final bool success = await _mapDownloadService.downloadRegionAsync(item, selectedLevel);
      if (!mounted) {
        return;
      }
      if (!success) {
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
      }
    }
  }

  /// Builds a clickable detail level option inside the modal dialog.
  Widget _buildModalDetailLevelOption(
    BuildContext context,
    RegionCatalogItemModel item,
    MapDetailLevel level,
    MapDetailLevel currentSelected,
    AppLocalizations l10n, {
    required ValueChanged<MapDetailLevel> onSelected,
  }) {
    final bool isSelected = level == currentSelected;
    final Color levelColor = level.getColor(context);
    final String sizeMb = item.getEstimatedMb(level).toString();

    return GestureDetector(
      onTap: () => onSelected(level),
      child: Container(
        padding   : const EdgeInsets.all(AppSizes.p12),
        decoration: BoxDecoration(
          color       : isSelected ? levelColor.withValues(alpha: 0.14) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border      : Border.all(
            color: isSelected ? levelColor : AppColors.border(context),
            width: isSelected ? AppSizes.borderWidthThick : AppSizes.borderWidthRegular,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children          : [
            // Title and size row
            Row(
              children: [
                Container(
                  width     : AppSizes.p12,
                  height    : AppSizes.p12,
                  decoration: BoxDecoration(
                    color: levelColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSizes.p8),
                Expanded(
                  child: Text(
                    level.getTitle(l10n),
                    style: TextStyle(
                      fontSize  : AppSizes.font14,
                      fontWeight: FontWeight.bold,
                      color     : isSelected ? levelColor : AppColors.textPrimary(context),
                    ),
                  ),
                ),
                Text(
                  l10n.commonMegabytesValue(sizeMb),
                  style: TextStyle(
                    fontSize  : AppSizes.font13,
                    fontWeight: FontWeight.w600,
                    color     : isSelected ? levelColor : AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.p4),

            // Description
            Padding(
              padding: const EdgeInsets.only(left: AppSizes.p20),
              child  : Text(
                level.getDescription(l10n),
                style: TextStyle(
                  fontSize: AppSizes.font12,
                  color   : AppColors.textSecondary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirms deletion of a downloaded map package.
  Future _confirmDeleteMapAsync(
    BuildContext context,
    String itemId,
    String itemName,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await naShowDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return NaAlertDialog(
          title  : Text(l10n.mapDownloadActionDeleteConfirmTitle),
          content: Text(l10n.mapDownloadActionDeleteConfirmMsg(itemName)),
          actions: [
            NaDialogAction(
              child    : Text(l10n.commonCancel),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            NaDialogAction(
              child    : Text(l10n.commonDelete),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _mapDownloadService.deleteItemAsync(itemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _mapDownloadService,
      builder   : (BuildContext context, Widget? child) {
        final bool isWorldDownloaded = _mapDownloadService.isWorldMapDownloaded;
        final bool isWorldDownloading = _mapDownloadService.isItemDownloading(MapDownloadService.worldOverviewId);
        final double worldProgress = _mapDownloadService.getItemProgress(MapDownloadService.worldOverviewId) ?? 0.0;
        final int worldPercent = (worldProgress * 100.0).round();

        // Catalog filtering based on search text
        final List<RegionCatalogItemModel> filteredCatalogList = [];
        final String query = _searchFilterText.trim().toLowerCase();

        for (final RegionCatalogItemModel country in _mapDownloadService.getCatalogList()) {
          if (query.isEmpty) {
            filteredCatalogList.add(country);
          }else {
            final bool countryMatches = country.name.toLowerCase().contains(query);
            final List<RegionCatalogItemModel> matchedSubList = country.subRegionList
              .where((RegionCatalogItemModel r) => r.name.toLowerCase().contains(query))
              .toList()
            ;

            if (countryMatches || matchedSubList.isNotEmpty) {
              filteredCatalogList.add(
                RegionCatalogItemModel(
                  id             : country.id,
                  parentId       : country.parentId,
                  name           : country.name,
                  countryCode    : country.countryCode,
                  baseSizeBytes  : country.baseSizeBytes,
                  boundingBoxList: country.boundingBoxList,
                  cellIdList     : country.cellIdList,
                  subRegionList  : countryMatches ? country.subRegionList : matchedSubList,
                ),
              );
            }
          }
        }

        return Container(
          width : double.infinity,
          height: double.infinity,
          color : AppColors.background(context),
          child : ListView(
            padding : const EdgeInsets.all(AppSizes.p16),
            children: [
              // -------------------------------------------------------------
              // Server Connectivity Status Banner
              // -------------------------------------------------------------
              if (_isServerOnline != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p12,
                    vertical  : AppSizes.p8,
                  ),
                  decoration: BoxDecoration(
                    color: (_isServerOnline == true)
                      ? AppColors.success(context).withValues(alpha: 0.12)
                      : AppColors.error(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                    border      : Border.all(
                      color: (_isServerOnline == true)
                        ? AppColors.success(context)
                        : AppColors.error(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      NaIcon(
                        (_isServerOnline == true) ? NaIcons.checkCircle : NaIcons.warning,
                        size: AppSizes.icon16,
                      ),
                      const SizedBox(width: AppSizes.p8),
                      Expanded(
                        child: Text(
                          (_isServerOnline == true)
                            ? l10n.mapDownloadServerOnline(_settingsService.mapServerUrl)
                            : l10n.mapDownloadServerOffline(_settingsService.mapServerUrl),
                          style: TextStyle(
                            fontSize  : AppSizes.font12,
                            fontWeight: FontWeight.w500,
                            color     : (_isServerOnline == true)
                              ? AppColors.success(context)
                              : AppColors.error(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
              ],

              // -------------------------------------------------------------
              // 1. World Base Map Section
              // -------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(left: AppSizes.p8, bottom: AppSizes.p8),
                child  : Text(
                  l10n.mapDownloadWorldSection,
                  style: TextStyle(
                    fontSize  : AppSizes.font14,
                    fontWeight: FontWeight.bold,
                    color     : AppColors.textSecondary(context),
                  ),
                ),
              ),

              NaCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children          : [
                      Row(
                        children: [
                          Container(
                            padding   : const EdgeInsets.all(AppSizes.p10),
                            decoration: BoxDecoration(
                              color       : AppColors.primary(context).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppSizes.radius12),
                            ),
                            child: const NaIcon(
                              NaIcons.public,
                              size: AppSizes.icon28,
                            ),
                          ),
                          const SizedBox(width: AppSizes.p12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children          : [
                                Text(
                                  l10n.mapDownloadWorldSection,
                                  style: TextStyle(
                                    fontSize  : AppSizes.font16,
                                    fontWeight: FontWeight.bold,
                                    color     : AppColors.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: AppSizes.p4),
                                Text(
                                  l10n.mapDownloadWorldDesc,
                                  style: TextStyle(
                                    fontSize: AppSizes.font12,
                                    color   : AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p12),

                      // Progress bar if downloading
                      if (isWorldDownloading) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children          : [
                            Text(
                              l10n.mapDownloadStatusDownloading(worldPercent),
                              style: TextStyle(
                                fontSize  : AppSizes.font12,
                                fontWeight: FontWeight.bold,
                                color     : AppColors.primary(context),
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
                                  widthFactor: worldProgress,
                                  child      : Container(
                                    color: AppColors.primary(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ]else if (isWorldDownloaded) ...[
                        // Already downloaded badge and delete action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children         : [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.p10,
                                vertical  : AppSizes.p4,
                              ),
                              decoration: BoxDecoration(
                                color       : AppColors.detailBase(context).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppSizes.radius8),
                                border      : Border.all(color: AppColors.detailBase(context)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children    : [
                                  const NaIcon(NaIcons.check, size: AppSizes.icon16),
                                  const SizedBox(width: AppSizes.p6),
                                  Text(
                                    l10n.mapDownloadWorldDownloaded,
                                    style: TextStyle(
                                      fontSize  : AppSizes.font12,
                                      fontWeight: FontWeight.bold,
                                      color     : AppColors.detailBase(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            NaIconButton(
                              icon     : const NaIcon(NaIcons.delete),
                              onPressed: () => _confirmDeleteMapAsync(
                                context,
                                MapDownloadService.worldOverviewId,
                                l10n.mapDownloadWorldSection,
                                l10n,
                              ),
                            ),
                          ],
                        ),
                      ]else ...[
                        // Download action button
                        NaButtonFilled(
                          onPressed: () => _downloadWorldMapAsync(l10n),
                          child    : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children         : [
                              const NaIcon(NaIcons.cloudDownload),
                              const SizedBox(width: AppSizes.p8),
                              Text(l10n.mapDownloadWorldDownloadBtn('40')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p20),

              // -------------------------------------------------------------
              // 2. Circle and Download Interactive Canvas Shortcut Card
              // -------------------------------------------------------------
              NaCard(
                child: NaListTile(
                  leading: Container(
                    padding   : const EdgeInsets.all(AppSizes.p8),
                    decoration: BoxDecoration(
                      color       : AppColors.primary(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radius10),
                    ),
                    child: const NaIcon(NaIcons.brush, size: AppSizes.icon24),
                  ),
                  title   : Text(l10n.mapDownloadCircleActionTitle),
                  subtitle: Text(
                    l10n.mapDownloadCircleActionDesc,
                    style: TextStyle(
                      fontSize: AppSizes.font12,
                      color   : AppColors.textSecondary(context),
                    ),
                  ),
                  hasChevron: true,
                  onTap     : () {
                    Navigator.of(context).push(
                      NaPageRoute.create(
                        context,
                        builder: (BuildContext pageContext) => const CircleDownloadPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSizes.p20),

              // -------------------------------------------------------------
              // 3. Countries and Regions Section Header & Legend
              // -------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(left: AppSizes.p8, bottom: AppSizes.p8),
                child  : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children          : [
                    Text(
                      l10n.mapDownloadRegionsSection,
                      style: TextStyle(
                        fontSize  : AppSizes.font14,
                        fontWeight: FontWeight.bold,
                        color     : AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p4),
                    Text(
                      l10n.mapDownloadRegionsDesc,
                      style: TextStyle(
                        fontSize: AppSizes.font12,
                        color   : AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p8),

                    // Color Legend row
                    Row(
                      children: [
                        // Base legend
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
                          l10n.mapDownloadDetailBaseBadge,
                          style: TextStyle(
                            fontSize: AppSizes.font12,
                            color   : AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(width: AppSizes.p12),

                        // Detailed legend
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
                          l10n.mapDownloadDetailDetailedBadge,
                          style: TextStyle(
                            fontSize: AppSizes.font12,
                            color   : AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(width: AppSizes.p12),

                        // Complete legend
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
                          l10n.mapDownloadDetailCompleteBadge,
                          style: TextStyle(
                            fontSize: AppSizes.font12,
                            color   : AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search bar
              NaSearchBar(
                controller: _searchController,
                hintText  : l10n.mapDownloadRegionsSearchHint,
                leading   : const NaIcon(NaIcons.search),
                onChanged : (String value) {
                  setState(() {
                    _searchFilterText = value;
                  });
                },
              ),
              const SizedBox(height: AppSizes.p12),

              // Countries & Regions expandable list
              NaCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    for (int i = 0; i < filteredCatalogList.length; i++) ...[
                      _buildCountryItem(
                        context,
                        filteredCatalogList[i],
                        l10n,
                        isLast: (i == filteredCatalogList.length - 1),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds a single country row and its nested subregions if expanded.
  Widget _buildCountryItem(
    BuildContext context,
    RegionCatalogItemModel country,
    AppLocalizations l10n, {
    required bool isLast,
  }) {
    final bool isExpanded = _expandedCountryIdSet.contains(country.id);
    final bool hasSubRegions = country.subRegionList.isNotEmpty;
    final MapDetailLevel? downloadLevel = _mapDownloadService.getItemDetailLevel(country.id);
    final bool isDownloading = _mapDownloadService.isItemDownloading(country.id);
    final double? progress = _mapDownloadService.getItemProgress(country.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children    : [
        // Main country row
        NaListTile(
          leading: const NaIcon(NaIcons.flag),
          title  : Text(
            country.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            l10n.commonApproximateMegabytesValue(country.getEstimatedMb(MapDetailLevel.base).toString()),
            style: TextStyle(
              fontSize: AppSizes.font12,
              color   : AppColors.textSecondary(context),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children    : [
              // Download status badge with color
              if (isDownloading) ...[
                Text(
                  l10n.commonPercentValue(((progress ?? 0.0) * 100.0).round()),
                  style: TextStyle(
                    fontSize  : AppSizes.font12,
                    fontWeight: FontWeight.bold,
                    color     : AppColors.primary(context),
                  ),
                ),
              ]else if (downloadLevel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p8,
                    vertical  : AppSizes.p4,
                  ),
                  decoration: BoxDecoration(
                    color       : downloadLevel.getColor(context).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                    border      : Border.all(color: downloadLevel.getColor(context)),
                  ),
                  child: Text(
                    downloadLevel.getBadge(l10n),
                    style: TextStyle(
                      fontSize  : AppSizes.font10,
                      fontWeight: FontWeight.bold,
                      color     : downloadLevel.getColor(context),
                    ),
                  ),
                ),
              ]else ...[
                const NaIcon(NaIcons.cloudDownload, size: AppSizes.icon20),
              ],

              // Expand / collapse subregions toggle button
              if (hasSubRegions) ...[
                const SizedBox(width: AppSizes.p8),
                NaIconButton(
                  icon     : NaIcon(isExpanded ? NaIcons.expandLess : NaIcons.expandMore),
                  onPressed: () => _toggleCountryExpansion(country.id),
                ),
              ],
            ],
          ),
          onTap: () => _openDetailLevelPickerAsync(country, l10n),
        ),

        // Subregions list when expanded
        if (hasSubRegions && isExpanded) ...[
          Container(
            color: AppColors.surface(context).withValues(alpha: 0.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children    : [
                for (final RegionCatalogItemModel subRegion in country.subRegionList) ...[
                  _buildSubRegionRow(context, subRegion, l10n),
                ],
              ],
            ),
          ),
        ],

        if (!isLast) ...[
          Container(
            height: AppSizes.borderWidthRegular,
            color : AppColors.border(context),
          ),
        ],
      ],
    );
  }

  /// Builds a nested subregion row (e.g. Italian regions).
  Widget _buildSubRegionRow(
    BuildContext context,
    RegionCatalogItemModel region,
    AppLocalizations l10n,
  ) {
    final MapDetailLevel? downloadLevel = _mapDownloadService.getItemDetailLevel(region.id);
    final bool isDownloading = _mapDownloadService.isItemDownloading(region.id);
    final double? progress = _mapDownloadService.getItemProgress(region.id);

    return Padding(
      padding: const EdgeInsets.only(left: AppSizes.p24),
      child  : NaListTile(
        leading: const NaIcon(NaIcons.locationOn, size: AppSizes.icon16),
        title  : Text(
          region.name,
          style: const TextStyle(fontSize: AppSizes.font14),
        ),
        subtitle: Text(
          l10n.commonApproximateMegabytesValue(region.getEstimatedMb(MapDetailLevel.base).toString()),
          style: TextStyle(
            fontSize: AppSizes.font12,
            color   : AppColors.textSecondary(context),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children    : [
            if (isDownloading) ...[
              Text(
                l10n.commonPercentValue(((progress ?? 0.0) * 100.0).round()),
                style: TextStyle(
                  fontSize  : AppSizes.font12,
                  fontWeight: FontWeight.bold,
                  color     : AppColors.primary(context),
                ),
              ),
            ]else if (downloadLevel != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.p8,
                  vertical  : AppSizes.p2,
                ),
                decoration: BoxDecoration(
                  color       : downloadLevel.getColor(context).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                  border      : Border.all(color: downloadLevel.getColor(context)),
                ),
                child: Text(
                  downloadLevel.getBadge(l10n),
                  style: TextStyle(
                    fontSize  : AppSizes.font10,
                    fontWeight: FontWeight.bold,
                    color     : downloadLevel.getColor(context),
                  ),
                ),
              ),
            ]else ...[
              const NaIcon(NaIcons.cloudDownload, size: AppSizes.icon16),
            ],
          ],
        ),
        onTap: () => _openDetailLevelPickerAsync(region, l10n),
      ),
    );
  }
}
