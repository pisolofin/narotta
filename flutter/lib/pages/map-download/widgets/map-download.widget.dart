import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings-service.dart';
import '../../../services/map-server-service.dart';
import '../../../services/map-download-service.dart';

import 'world-selection-map.widget.dart';
import 'downloaded-zones-modal.widget.dart';

/// Unified body widget for "Scarica mappe" featuring Server configuration, World Base Map, and interactive World Selection.
class MapDownload extends StatefulWidget {
  const MapDownload({ super.key });
  @override
  State<MapDownload> createState() => _MapDownloadState();
}
/// State for [MapDownload] managing server health status, base map actions, and fullscreen map toggle.
class _MapDownloadState extends State<MapDownload> {
  static const String _customServerChoiceValue     = 'custom';
  final MapDownloadService _mapDownloadService     = MapDownloadService();
  final MapServerService _mapServerService         = MapServerService();
  final SettingsService _settingsService           = SettingsService();
  final GlobalKey _worldMapKey                     = GlobalKey();
  final TextEditingController _customUrlController = TextEditingController();
  bool _isCheckingServer                           = true;
  bool? _isServerOnline;
  bool _isMapFullscreen  = false;
  @override
  void initState() {
    super.initState();
    _checkServerConnectivityAsync();
  }
  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }
  /// Checks whether the currently configured Map Server URL responds to `/health`.
  Future _checkServerConnectivityAsync() async {
    if (mounted) {
      setState(() {
        _isCheckingServer = true;
      });
    }
    final bool isOnline = await _mapServerService.checkHealthAsync();
    if (!mounted) {
      return;
    }
    setState(() {
      _isCheckingServer = false;
      _isServerOnline   = isOnline;
    });
  }
  /// Opens the platform-adaptive selection modal to pick a Map Server preset or enter a custom URL.
  Future _openServerSelectorAsync(
    BuildContext context,
    String currentUrl,
    AppLocalizations l10n,
  ) async {
    final bool isCustomUrl                             = SettingsService.isCustomServerUrl(currentUrl);
    final List<NaSelectionItem<String>> serverItemList = [
      NaSelectionItem<String>(
        value     : SettingsService.serverLocalhost,
        title     : Text(l10n.settingsMapServerLocalhost),
        subtitle  : Text(l10n.settingsMapServerLocalhostDesc),
        isSelected: currentUrl == SettingsService.serverLocalhost,
      ),
      NaSelectionItem<String>(
        value     : SettingsService.serverAndroidEmulator,
        title     : Text(l10n.settingsMapServerAndroidEmulator),
        subtitle  : Text(l10n.settingsMapServerAndroidEmulatorDesc),
        isSelected: currentUrl == SettingsService.serverAndroidEmulator,
      ),
      NaSelectionItem<String>(
        value     : SettingsService.serverLan,
        title     : Text(l10n.settingsMapServerLan),
        subtitle  : Text(l10n.settingsMapServerLanDesc),
        isSelected: currentUrl == SettingsService.serverLan,
      ),
      NaSelectionItem<String>(
        value     : SettingsService.serverProduction,
        title     : Text(l10n.settingsMapServerProduction),
        subtitle  : Text(l10n.settingsMapServerProductionDesc),
        isSelected: currentUrl == SettingsService.serverProduction,
      ),
      NaSelectionItem<String>(
        value     : _customServerChoiceValue,
        title     : Text(l10n.settingsMapServerCustom),
        subtitle  : Text(isCustomUrl ? currentUrl : l10n.settingsMapServerCustomDesc),
        isSelected: isCustomUrl,
      ),
    ];
    final String? selectedChoice = await naShowSelectionModalAsync<String>(
      context     : context,
      title       : Text(l10n.settingsMapServerUrlDialogTitle),
      cancelButton: Text(l10n.commonCancel),
      itemList    : serverItemList,
    );
    if ((selectedChoice == null) || (!context.mounted)) {
      return;
    }
    if (selectedChoice == _customServerChoiceValue) {
      await _openCustomServerUrlDialogAsync(context, currentUrl, l10n);
    }else {
      await _settingsService.updateMapServerUrlAsync(selectedChoice);
      await _checkServerConnectivityAsync();
    }
  }
  /// Opens the dialog allowing manual entry of a custom Map Server URL.
  Future _openCustomServerUrlDialogAsync(
    BuildContext context,
    String currentUrl,
    AppLocalizations l10n,
  ) async {
    _customUrlController.text      = currentUrl;
    _customUrlController.selection = TextSelection(baseOffset: 0, extentOffset: currentUrl.length);
    final bool? confirmed = await naShowDialogAsync<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return NaAlertDialog(
          title  : Text(l10n.settingsMapServerUrlDialogTitle),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
              child  : Column(
                mainAxisSize      : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children          : [
                  // Dialog description
                  Text(
                    l10n.settingsMapServerCustomDesc,
                    style: TextStyle(
                      fontSize: AppSizes.font12,
                      color   : AppColors.textSecondary(dialogContext),
                    ),
                  ),
                  // Spacing
                  const SizedBox(height: AppSizes.p12),
                  // Custom URL input field
                  NaTextField(
                    controller     : _customUrlController,
                    keyboardType   : TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autofocus      : true,
                    onSubmitted    : (String submittedValue) => Navigator.of(dialogContext).pop(true),
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
              child    : Text(l10n.commonSave),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    final String trimmedUrl = _customUrlController.text.trim();
    if ((confirmed == true) && trimmedUrl.isNotEmpty) {
      await _settingsService.updateMapServerUrlAsync(trimmedUrl);
      await _checkServerConnectivityAsync();
    }
  }
  /// Downloads the world base overview map, displaying an alert dialog if the server is offline.
  Future _downloadWorldMapAsync(AppLocalizations l10n) async {
    final bool success = await _mapDownloadService.downloadWorldMapAsync();
    if (!mounted) {
      return;
    }
    setState(() {
      _isCheckingServer = false;
      _isServerOnline   = success ? true : _isServerOnline;
    });
    if (!success) {
      setState(() {
        _isServerOnline = false;
      });
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
  /// Confirms and deletes the downloaded world base map.
  Future _confirmDeleteWorldMapAsync(BuildContext context, AppLocalizations l10n) async {
    final bool? confirmed = await naShowDialogAsync<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return NaAlertDialog(
          title  : Text(l10n.mapDownloadActionDeleteConfirmTitle),
          content: Text(l10n.mapDownloadActionDeleteConfirmMsg(l10n.mapDownloadBaseMapTitle)),
          actions: [
            NaDialogAction(
              child    : Text(l10n.commonCancel),
              onPressed: () => Navigator.of(dialogContext).pop(false),
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
                l10n.commonDelete,
                style: TextStyle(color: AppColors.error(dialogContext)),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _mapDownloadService.deleteWorldMapAsync();
    }
  }
  /// Builds the status badge displayed inside the Server card.
  Widget _buildServerStatusBadge(BuildContext context, AppLocalizations l10n) {
    if (_isCheckingServer) {
      return Text(
        l10n.mapDownloadServerChecking,
        style: TextStyle(
          fontSize: AppSizes.font12,
          color   : AppColors.textSecondary(context),
        ),
      );
    }
    final bool isOnline    = _isServerOnline == true;
    final Color badgeColor = isOnline ? AppColors.success(context) : AppColors.error(context);
    final String labelText = isOnline ? l10n.mapDownloadServerStatusOnline : l10n.mapDownloadServerStatusOffline;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p8,
        vertical  : AppSizes.p3,
      ),
      decoration: BoxDecoration(
        color       : badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        border      : Border.all(
          color: badgeColor.withValues(alpha: 0.6),
          width: AppSizes.borderWidthThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children    : [
          // Status indicator dot
          Container(
            width     : AppSizes.p6,
            height    : AppSizes.p6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          // Spacing
          const SizedBox(width: AppSizes.p4),
          // Status text
          Text(
            labelText,
            style: TextStyle(
              fontSize  : AppSizes.font11,
              fontWeight: FontWeight.w600,
              color     : badgeColor,
            ),
          ),
        ],
      ),
    );
  }
  /// Builds Section 1: Server configuration card.
  Widget _buildServerSection(BuildContext context, AppLocalizations l10n) {
    final String activeUrl  = _settingsService.mapServerUrl;
    final String shortLabel = SettingsService.getServerShortLabel(activeUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize      : MainAxisSize.min,
      children          : [
        // Server section header
        Padding(
          padding: const EdgeInsets.only(
            left  : AppSizes.p8,
            bottom: AppSizes.p6,
          ),
          child: Text(
            l10n.mapDownloadServerSection,
            style: TextStyle(
              fontSize  : AppSizes.font13,
              fontWeight: FontWeight.bold,
              color     : AppColors.textSecondary(context),
            ),
          ),
        ),
        // Server selector card
        NaCard(
          child: NaListTile(
            leading   : const NaIcon(NaIcons.dns),
            title     : Text(shortLabel),
            trailing  : _buildServerStatusBadge(context, l10n),
            hasChevron: true,
            onTap     : () => _openServerSelectorAsync(context, activeUrl, l10n),
          ),
        ),
      ],
    );
  }
  /// Builds Section 2: World Base Map (`Mappa base`) card.
  Widget _buildBaseMapSection(BuildContext context, AppLocalizations l10n) {
    final bool isWorldDownloaded  = _mapDownloadService.isWorldMapDownloaded;
    final bool isWorldDownloading = _mapDownloadService.isItemDownloading(MapDownloadService.worldOverviewId);
    final bool isWorldPaused      = _mapDownloadService.isItemPaused(MapDownloadService.worldOverviewId);
    final double worldProgress    = _mapDownloadService.getItemProgress(MapDownloadService.worldOverviewId) ?? 0.0;
    final int worldPercent        = (worldProgress * 100.0).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize      : MainAxisSize.min,
      children          : [
        // Base Map section header
        Padding(
          padding: const EdgeInsets.only(
            left  : AppSizes.p8,
            bottom: AppSizes.p6,
          ),
          child: Text(
            l10n.mapDownloadBaseMapSection,
            style: TextStyle(
              fontSize  : AppSizes.font13,
              fontWeight: FontWeight.bold,
              color     : AppColors.textSecondary(context),
            ),
          ),
        ),
        // Base Map status & action card
        NaCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p14,
            vertical  : AppSizes.p10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize      : MainAxisSize.min,
            children          : [
              // Main row: icon, title/subtitle, and trailing action
              Row(
                children: [
                  // Globe icon badge
                  Container(
                    padding   : const EdgeInsets.all(AppSizes.p8),
                    decoration: BoxDecoration(
                      color       : AppColors.primary(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radius10),
                    ),
                    child: const NaIcon(
                      NaIcons.public,
                      size: AppSizes.icon20,
                    ),
                  ),
                  // Spacing
                  const SizedBox(width: AppSizes.p12),
                  // Base map title and zoom/size subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize      : MainAxisSize.min,
                      children          : [
                        // Title
                        Text(
                          l10n.mapDownloadBaseMapTitle,
                          style: TextStyle(
                            fontSize  : AppSizes.font14,
                            fontWeight: FontWeight.w600,
                            color     : AppColors.textPrimary(context),
                          ),
                        ),
                        // Spacing
                        const SizedBox(height: AppSizes.p2),
                        // Subtitle
                        Text(
                          l10n.mapDownloadBaseMapSubtitle(MapDownloadService.worldMapEstimatedMb),
                          style: TextStyle(
                            fontSize: AppSizes.font12,
                            color   : AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Spacing before trailing control
                  const SizedBox(width: AppSizes.p8),
                  // Trailing status or download button
                  if (isWorldDownloading) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        // Percent text
                        Text(
                          l10n.commonPercentValue(worldPercent),
                          style: TextStyle(
                            fontSize  : AppSizes.font13,
                            fontWeight: FontWeight.bold,
                            color     : AppColors.primary(context),
                          ),
                        ),
                        // Spacing
                        const SizedBox(width: AppSizes.p4),
                        // Pause button
                        NaIconButton(
                          icon     : const NaIcon(NaIcons.pause, size: AppSizes.icon18),
                          onPressed: () => _mapDownloadService.pauseDownload(MapDownloadService.worldOverviewId),
                        ),
                        // Cancel button
                        NaIconButton(
                          icon     : const NaIcon(NaIcons.close, size: AppSizes.icon18),
                          onPressed: () => _mapDownloadService.cancelDownloadAsync(MapDownloadService.worldOverviewId),
                        ),
                      ],
                    ),
                  ]else if (isWorldPaused) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        // Paused percent text
                        Text(
                          l10n.mapDownloadStatusPaused(worldPercent),
                          style: TextStyle(
                            fontSize  : AppSizes.font12,
                            fontWeight: FontWeight.bold,
                            color     : AppColors.detailDetailed(context),
                          ),
                        ),
                        // Spacing
                        const SizedBox(width: AppSizes.p4),
                        // Resume button
                        NaIconButton(
                          icon     : const NaIcon(NaIcons.playArrow, size: AppSizes.icon18),
                          onPressed: () => _mapDownloadService.resumeDownloadAsync(MapDownloadService.worldOverviewId),
                        ),
                        // Cancel button
                        NaIconButton(
                          icon     : const NaIcon(NaIcons.close, size: AppSizes.icon18),
                          onPressed: () => _mapDownloadService.cancelDownloadAsync(MapDownloadService.worldOverviewId),
                        ),
                      ],
                    ),
                  ]else if (isWorldDownloaded) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        // Downloaded badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.p8,
                            vertical  : AppSizes.p4,
                          ),
                          decoration: BoxDecoration(
                            color       : AppColors.detailBase(context).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppSizes.radius8),
                            border      : Border.all(
                              color: AppColors.detailBase(context),
                              width: AppSizes.borderWidthThin,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children    : [
                              // Checkmark icon
                              NaIcon(
                                NaIcons.check,
                                size : AppSizes.icon14,
                                color: AppColors.detailBase(context),
                              ),
                              // Spacing
                              const SizedBox(width: AppSizes.p4),
                              // Downloaded label
                              Text(
                                l10n.mapDownloadWorldDownloaded,
                                style: TextStyle(
                                  fontSize  : AppSizes.font11,
                                  fontWeight: FontWeight.bold,
                                  color     : AppColors.detailBase(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Spacing
                        const SizedBox(width: AppSizes.p4),
                        // Delete base map button
                        NaIconButton(
                          icon     : const NaIcon(NaIcons.deleteOutline, size: AppSizes.icon18),
                          onPressed: () => _confirmDeleteWorldMapAsync(context, l10n),
                        ),
                      ],
                    ),
                  ]else ...[
                    // Download button
                    GestureDetector(
                      onTap: () => _downloadWorldMapAsync(l10n),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p12,
                          vertical  : AppSizes.p8,
                        ),
                        decoration: BoxDecoration(
                          color       : AppColors.primary(context),
                          borderRadius: BorderRadius.circular(AppSizes.radius8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children    : [
                            // Cloud download icon
                            NaIcon(
                              NaIcons.cloudDownload,
                              size : AppSizes.icon16,
                              color: AppColors.white(context),
                            ),
                            // Spacing
                            const SizedBox(width: AppSizes.p6),
                            // Download button text
                            Text(
                              l10n.mapDownloadBaseMapDownloadAction,
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
                ],
              ),
              // Progress bar when downloading world base map
              if (isWorldDownloading || isWorldPaused) ...[
                // Spacing above progress bar
                const SizedBox(height: AppSizes.p8),
                // Progress bar track
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radius6),
                  child       : Container(
                    height: AppSizes.p6,
                    color : AppColors.border(context),
                    child : FractionallySizedBox(
                      alignment  : Alignment.centerLeft,
                      widthFactor: worldProgress.clamp(0.0, 1.0),
                      child      : Container(
                        color: isWorldPaused
                          ? AppColors.detailDetailed(context)
                          : AppColors.primary(context),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  /// Builds the Section 3 (`Selezione`) header bar with the "Zone scaricate" modal button and fullscreen toggle.
  Widget _buildSelectionHeader(BuildContext context, AppLocalizations l10n) {
    final int downloadedCount = _mapDownloadService.downloadedZoneCount;
    return Padding(
      padding: const EdgeInsets.only(
        left  : AppSizes.p8,
        bottom: AppSizes.p6,
      ),
      child: Row(
        children: [
          // Section title
          Expanded(
            child: Text(
              l10n.mapDownloadSelectionSection,
              style: TextStyle(
                fontSize  : AppSizes.font13,
                fontWeight: FontWeight.bold,
                color     : AppColors.textSecondary(context),
              ),
            ),
          ),
          // Button to open the Downloaded Zones list modal
          GestureDetector(
            onTap: () => DownloadedZonesModal.showAsync(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p10,
                vertical  : AppSizes.p6,
              ),
              decoration: BoxDecoration(
                color       : AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                border      : Border.all(
                  color: AppColors.cardBorder(context),
                  width: AppSizes.borderWidthThin,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children    : [
                  // Checklist icon
                  NaIcon(
                    NaIcons.checklist,
                    size : AppSizes.icon16,
                    color: AppColors.primary(context),
                  ),
                  // Spacing
                  const SizedBox(width: AppSizes.p6),
                  // Downloaded zones button label with count
                  Text(
                    l10n.mapDownloadDownloadedZonesBtn(downloadedCount),
                    style: TextStyle(
                      fontSize  : AppSizes.font12,
                      fontWeight: FontWeight.w600,
                      color     : AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Spacing before fullscreen toggle
          const SizedBox(width: AppSizes.p6),
          // Fullscreen map expand/collapse toggle button
          GestureDetector(
            onTap: () {
              setState(() {
                _isMapFullscreen = !_isMapFullscreen;
              });
            },
            child: Container(
              width     : AppSizes.p32,
              height    : AppSizes.p32,
              alignment : Alignment.center,
              decoration: BoxDecoration(
                color       : AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                border      : Border.all(
                  color: AppColors.cardBorder(context),
                  width: AppSizes.borderWidthThin,
                ),
              ),
              child: NaIcon(
                _isMapFullscreen ? NaIcons.shrink : NaIcons.expand,
                size : AppSizes.icon16,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([_mapDownloadService, _settingsService]),
      builder   : (BuildContext context, Widget? child) {
        return Container(
          width : double.infinity,
          height: double.infinity,
          color : AppColors.background(context),
          child : LayoutBuilder(
            builder: (BuildContext layoutContext, BoxConstraints constraints) {
              final bool useScrollableFallback = (!_isMapFullscreen) &&
                  (constraints.maxHeight < AppSizes.mapDownloadCompactThreshold);
              if (useScrollableFallback) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.p12),
                  child  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children          : [
                      // 1. Server section
                      _buildServerSection(context, l10n),
                      // Spacing
                      const SizedBox(height: AppSizes.p12),
                      // 2. Base Map section
                      _buildBaseMapSection(context, l10n),
                      // Spacing
                      const SizedBox(height: AppSizes.p12),
                      // 3. Selection header
                      _buildSelectionHeader(context, l10n),
                      // Interactive world map with minimum height
                      SizedBox(
                        height: AppSizes.mapSelectionMinHeight,
                        child : WorldSelectionMap(key: _worldMapKey),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(AppSizes.p12),
                child  : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children          : [
                    // 1. Server & 2. Base Map sections (hidden when map is expanded fullscreen)
                    if (!_isMapFullscreen) ...[
                      // Server section
                      _buildServerSection(context, l10n),
                      // Spacing
                      const SizedBox(height: AppSizes.p12),
                      // Base Map section
                      _buildBaseMapSection(context, l10n),
                      // Spacing
                      const SizedBox(height: AppSizes.p12),
                    ],
                    // 3. Selection header
                    _buildSelectionHeader(context, l10n),
                    // Interactive world map filling remaining viewport height
                    Expanded(
                      child: WorldSelectionMap(key: _worldMapKey),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
