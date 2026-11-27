import 'package:jellyflix/components/adaptive.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/mpv_config_dialog.dart';
import 'package:jellyflix/components/profile_image.dart';
import 'package:jellyflix/components/quick_connect_dialog.dart';
import 'package:jellyflix/components/set_download_bitrate_dialog.dart';
import 'package:jellyflix/components/ios_sheets.dart';
import 'package:jellyflix/components/settings_list.dart';
import 'package:jellyflix/components/switch_settings_tile.dart';
import 'package:jellyflix/models/bitrates.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/providers/display_preferences_provider.dart';
import 'package:jellyflix/providers/auth_provider.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:jellyflix/providers/database_provider.dart';
import 'package:jellyflix/providers/device_info_provider.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/providers/logger_provider.dart';
import 'package:jellyflix/providers/theme_mode_provider.dart';

class ProfileScreen extends HookConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadBitrate = useState(
        ref.read(databaseProvider("settings")).get("downloadBitrate") ??
            BitRates.defaultBitrate());
    final maxConcurrentDownloads = useState<int>(
        ref.read(databaseProvider("settings")).get(maxConcurrentDownloadsKey) ??
            defaultMaxConcurrentDownloads);
    final disableImageCaching = useState(
        ref.read(databaseProvider("settings")).get("disableImageCaching") ??
            false);
    final disableWatchlist = useState(
        ref.read(databaseProvider("settings")).get("disableWatchlist") ??
            false);

    // Watch the Jellyfin server-side setting for episode image display.
    final useEpisodeImagesAsync = ref.watch(useEpisodeImagesProvider);

    final loggingEnabled = useState(
        ref.read(databaseProvider("settings")).get("loggingEnabled") ?? false);

    final mpvConfig = useState(
        ref.read(databaseProvider("settings")).get("mpvConfig") ??
            MpvConfigDialog.getDefaultConfig());

    final ios = isCupertino(context);
    final Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SettingsSection(
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: const ProfileImage(),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.read(authProvider).currentProfile?.name ??
                            AppLocalizations.of(context)!.offlineNotice,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        ref.read(authProvider).currentProfile?.serverAdress ??
                            AppLocalizations.of(context)!.na,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SettingsTile(
              icon: Icons.group_rounded,
              iosIcon: CupertinoIcons.person_2_fill,
              iosColor: CupertinoColors.systemIndigo,
              title: Text(AppLocalizations.of(context)!.changeProfile),
              onTap: () {
                ref.read(authProvider).updateCurrentProfileId(null);
                context.go(ScreenPaths.login);
              },
            ),
          ],
        ),
        if (!ios) const SizedBox(height: 20),
        SettingsSection(
          children: [
            SettingsTile(
              icon: Icons.connected_tv_rounded,
              iosIcon: CupertinoIcons.tv,
              iosColor: CupertinoColors.systemBlue,
              title: Text(AppLocalizations.of(context)!.quickConnect),
              onTap: () {
                showAdaptivePlatformDialog(
                    context: context,
                    builder: (context) => const QuickConnectDialog());
              },
            ),
            SettingsTile(
              icon: Icons.qr_code_rounded,
              iosIcon: CupertinoIcons.arrow_clockwise,
              iosColor: CupertinoColors.systemTeal,
              title: Text(AppLocalizations.of(context)!.scanLibrary),
              onTap: () async {
                await ref.read(apiProvider).startLibraryScan();
                // show snack bar
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.scanStarted),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        if (!ios) const SizedBox(height: 20),
        SettingsSection(
          children: [
            SettingsTile(
              icon: Icons.video_file_outlined,
              iosIcon: CupertinoIcons.speedometer,
              iosColor: CupertinoColors.systemGreen,
              title:
                  Text(AppLocalizations.of(context)!.setLocalDownloadBitrate),
              value: Text(BitRates().map[downloadBitrate.value] ?? ""),
              opensMore: true,
              onTap: () async {
                // show dialog
                final l10n = AppLocalizations.of(context)!;
                var result = ios
                    ? await showIosChoicePicker<int>(
                        context: context,
                        title: l10n.setLocalDownloadBitrate,
                        footer: l10n.maxDownloadBitrateText,
                        options: BitRates().map,
                        selected: downloadBitrate.value,
                      )
                    : await showDialog(
                        context: context,
                        builder: (context) {
                          return SetDownloadBitrateDialog(
                              downloadBitrate: downloadBitrate.value);
                        });
                if (result != null) {
                  downloadBitrate.value = result;
                  await ref
                      .read(databaseProvider("settings"))
                      .put("downloadBitrate", downloadBitrate.value);
                }
              },
            ),
            SettingsTile(
              icon: Icons.downloading_rounded,
              iosIcon: CupertinoIcons.arrow_down_circle_fill,
              iosColor: CupertinoColors.systemOrange,
              title: Text(AppLocalizations.of(context)!.simultaneousDownloads),
              value: Text(maxConcurrentDownloads.value.toString()),
              opensMore: true,
              onTap: () async {
                final l10n = AppLocalizations.of(context)!;
                final int? result = ios
                    ? await showIosChoicePicker<int>(
                        context: context,
                        title: l10n.simultaneousDownloads,
                        footer: l10n.simultaneousDownloadsText,
                        options: {
                          for (final option
                              in _SimultaneousDownloadsDialog.options)
                            option: option.toString()
                        },
                        selected: maxConcurrentDownloads.value,
                      )
                    : await showDialog<int>(
                        context: context,
                        builder: (context) => _SimultaneousDownloadsDialog(
                            value: maxConcurrentDownloads.value));
                if (result != null) {
                  maxConcurrentDownloads.value = result;
                  await ref
                      .read(databaseProvider("settings"))
                      .put(maxConcurrentDownloadsKey, result);
                  // a higher limit can start waiting ones now
                  ref.read(downloadQueueProvider).pump();
                }
              },
            ),
            SettingsTile(
              icon: Icons.delete_outline_rounded,
              iosIcon: CupertinoIcons.trash_fill,
              title: Text(
                  AppLocalizations.of(context)!.cancelAndRemoveAllDownloads),
              destructive: ios,
              onTap: () async {
                // iOS asks before destructive actions.
                if (ios &&
                    !await showIosDestructiveConfirm(
                      context: context,
                      confirmLabel: AppLocalizations.of(context)!
                          .cancelAndRemoveAllDownloads,
                      cancelLabel: AppLocalizations.of(context)!.cancel,
                    )) {
                  return;
                }
                await ref.read(cancelAndDeleteDownloadProvider)();
              },
            ),
          ],
        ),
        if (!ios) const SizedBox(height: 20),
        SettingsSection(children: [
          SettingsTile(
            icon: Icons.video_settings_rounded,
            iosIcon: CupertinoIcons.slider_horizontal_3,
            title: Text(AppLocalizations.of(context)!.customMpvConfig),
            onTap: () async {
              final result = ios
                  ? await Navigator.of(context, rootNavigator: true)
                      .push<String>(CupertinoPageRoute(
                      fullscreenDialog: true,
                      builder: (context) =>
                          MpvConfigDialog(mpvConfig: mpvConfig.value),
                    ))
                  : await showDialog<String>(
                      context: context,
                      builder: (context) => MpvConfigDialog(
                        mpvConfig: mpvConfig.value,
                      ),
                    );
              if (result != null) {
                mpvConfig.value = result;
                ref.read(databaseProvider("settings")).put("mpvConfig", result);
              }
            },
          ),
        ]),
        if (!ios) const SizedBox(height: 20),
        SettingsSection(
          children: [
            SettingsTile(
              icon: Icons.brightness_6_outlined,
              iosIcon: CupertinoIcons.circle_lefthalf_fill,
              iosColor: CupertinoColors.systemBlue,
              title: Text(AppLocalizations.of(context)!.appearance),
              value:
                  Text(_themeModeLabel(context, ref.watch(themeModeProvider))),
              opensMore: true,
              onTap: () async {
                final l10n = AppLocalizations.of(context)!;
                final options = {
                  for (final mode in [
                    ThemeMode.system,
                    ThemeMode.light,
                    ThemeMode.dark
                  ])
                    mode: _themeModeLabel(context, mode)
                };
                final current = ref.read(themeModeProvider);
                final ThemeMode? result = ios
                    ? await showIosChoicePicker<ThemeMode>(
                        context: context,
                        title: l10n.appearance,
                        options: options,
                        selected: current,
                      )
                    : await showDialog<ThemeMode>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text(l10n.appearance),
                          children: [
                            for (final entry in options.entries)
                              ListTile(
                                leading: Icon(entry.key == current
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked),
                                title: Text(entry.value),
                                onTap: () => Navigator.pop(context, entry.key),
                              ),
                          ],
                        ),
                      );
                if (result != null) {
                  await ref.read(themeModeProvider.notifier).set(result);
                }
              },
            ),
            SwitchSettingsTile(
              leading: const Icon(Icons.image_outlined),
              iosIcon: CupertinoIcons.photo_fill,
              iosColor: CupertinoColors.systemPurple,
              title: Text(AppLocalizations.of(context)!.disableImageCaching),
              value: disableImageCaching.value,
              onChanged: (value) {
                disableImageCaching.value = value;
                ref
                    .read(databaseProvider("settings"))
                    .put("disableImageCaching", value);

                showAdaptivePlatformDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) {
                    return AdaptiveAlertDialog(
                      title: Text(AppLocalizations.of(context)!.restartApp),
                      content: Text(
                          AppLocalizations.of(context)!.restartAppDescription),
                      actions: [
                        AdaptiveDialogAction(
                          isDefaultAction: true,
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(AppLocalizations.of(context)!.ok),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            SwitchSettingsTile(
              leading: const Icon(Icons.remove_red_eye_outlined),
              iosIcon: CupertinoIcons.eye_slash_fill,
              iosColor: CupertinoColors.systemPink,
              title: Text(AppLocalizations.of(context)!.disableWatchlist),
              value: disableWatchlist.value,
              onChanged: (value) {
                disableWatchlist.value = value;
                ref
                    .read(databaseProvider("settings"))
                    .put("disableWatchlist", value);

                showAdaptivePlatformDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) {
                    return AdaptiveAlertDialog(
                      title: Text(
                        AppLocalizations.of(context)!.info,
                      ),
                      content: Text(
                          AppLocalizations.of(context)!.deletePlaylistNotice),
                      actions: [
                        AdaptiveDialogAction(
                          isDefaultAction: true,
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(AppLocalizations.of(context)!.ok),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            SwitchSettingsTile(
              leading: const Icon(Icons.amp_stories_rounded),
              iosIcon: CupertinoIcons.photo_on_rectangle,
              iosColor: CupertinoColors.systemOrange,
              title: Text(AppLocalizations.of(context)!.showPrimaryForEpisodes),
              value: useEpisodeImagesAsync.valueOrNull ?? false,
              onChanged: (value) async {
                try {
                  await ref
                      .read(useEpisodeImagesProvider.notifier)
                      .toggle(value);
                } catch (e) {
                  if (context.mounted) await showSaveFailedAlert(context, e);
                }
              },
            ),
          ],
        ),
        if (!ios) const SizedBox(height: 20),
        SettingsSection(
          children: [
            SwitchSettingsTile(
              leading: const Icon(Icons.file_open_outlined),
              iosIcon: CupertinoIcons.doc_text_fill,
              title: Text(AppLocalizations.of(context)!.enableLogging),
              value: loggingEnabled.value,
              onChanged: (value) async {
                loggingEnabled.value = value;
                ref
                    .read(databaseProvider("settings"))
                    .put("loggingEnabled", value);
                if (loggingEnabled.value) {
                  ref.read(loggerProvider).alwaysLog();
                } else {
                  ref.read(loggerProvider).resetLogger();
                  await ref.read(loggerProvider).exportLog();
                  // show snack bar
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(AppLocalizations.of(context)!.logExported),
                      ),
                    );
                  }
                }
              },
            ),
            SettingsTile(
              icon: Icons.info_rounded,
              iosIcon: CupertinoIcons.info,
              title: Text(AppLocalizations.of(context)!.about),
              onTap: () async {
                ref.read(appVersionProvider).whenData((versionNumber) =>
                    showLicensePage(
                        context: context, applicationVersion: versionNumber));
              },
            ),
          ],
        ),
        if (!ios) const SizedBox(height: 40),
        SettingsSection(children: [
          SettingsTile(
            icon: Icons.logout,
            iosIcon: CupertinoIcons.square_arrow_right,
            destructive: true,
            title: Text(AppLocalizations.of(context)!.logout),
            onTap: () async {
              if (ios &&
                  !await showIosDestructiveConfirm(
                    context: context,
                    confirmLabel: AppLocalizations.of(context)!.logout,
                    cancelLabel: AppLocalizations.of(context)!.cancel,
                  )) {
                return;
              }
              await ref.read(authProvider).logoutAndDeleteProfile();

              if (context.mounted) {
                context.go(ScreenPaths.login);
              }
            },
          ),
        ]),
      ],
    );

    if (ios) {
      // iOS: a large title over Settings-style grouped lists.
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(AppLocalizations.of(context)!.profile),
              border: null,
              transitionBetweenRoutes: false,
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 750),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20),
              child: SingleChildScrollView(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimultaneousDownloadsDialog extends StatelessWidget {
  final int value;
  const _SimultaneousDownloadsDialog({required this.value});

  static const options = [1, 2, 3, 5, 10];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SimpleDialog(
      title: Text(l10n.simultaneousDownloads),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(l10n.simultaneousDownloadsText),
        ),
        for (var option in options)
          ListTile(
            leading: Icon(option == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked),
            title: Text(option.toString()),
            onTap: () => Navigator.pop(context, option),
          ),
      ],
    );
  }
}

String _themeModeLabel(BuildContext context, ThemeMode mode) {
  final l10n = AppLocalizations.of(context)!;
  switch (mode) {
    case ThemeMode.light:
      return l10n.appearanceLight;
    case ThemeMode.dark:
      return l10n.appearanceDark;
    case ThemeMode.system:
      return l10n.appearanceSystem;
  }
}
