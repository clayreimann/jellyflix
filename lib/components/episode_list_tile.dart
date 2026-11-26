import 'package:flutter/material.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/download_settings_dialog.dart';
import 'package:jellyflix/components/item_list_tile.dart';
import 'package:jellyflix/components/jellyfin_image.dart';
import 'package:jellyflix/components/playback_progress_overlay.dart';
import 'package:jellyflix/models/bitrates.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/providers/player_helper_provider.dart';
import 'package:tentacle/tentacle.dart';
import 'package:jellyflix/providers/connectivity_provider.dart';
import 'package:jellyflix/providers/database_provider.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/services/download_service.dart';
import 'package:jellyflix/providers/offline_provider.dart';
import 'package:jellyflix/components/offline_dimmed.dart';
import 'package:universal_io/io.dart';

class EpisodeListTile extends HookConsumerWidget {
  const EpisodeListTile(
      {super.key,
      required this.episode,
      required this.onSelected,
      required this.parentPath});

  final BaseItemDto episode;
  final Function(String) onSelected;
  final String parentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ValueNotifier<bool?> mark = useState(null);

    final ValueNotifier<int?> isDownloaded = useState(null);
    final isDownloading =
        useState(ref.read(downloadProvider(episode.id!)).isDownloading);

    mark.value = episode.userData!.played!;

    ref.read(downloadProvider(episode.id!)).calculateProgress().then((value) {
      isDownloaded.value = value;
    });

    final offline = ref.watch(isOfflineProvider);

    return OfflineDimmed(
      item: episode,
      child: ItemListTile<BaseItemDto, String>(
        item: episode,
        title: Text(
          ("${episode.indexNumber == null ? "" : "${episode.indexNumber!}. "}${episode.name!}"),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        subtitle: Text([
          episode.runTimeTicks == null
              ? AppLocalizations.of(context)!.na
              : AppLocalizations.of(context)!
                  .minutes((episode.runTimeTicks! / 10000000 / 60).round()),
          if (isDownloaded.value == 100)
            "✓ ${AppLocalizations.of(context)!.downloaded}",
          if (offline && isDownloaded.value != 100)
            AppLocalizations.of(context)!.notDownloaded,
        ].join(" · ")),
        leading: JellyfinImage(
            id: episode.id!,
            type: ImageType.primary,
            blurHash: episode.imageBlurHashes?.primary?[episode.id!]),
        onTap: () async {
          if (offline) {
            // offline: play the downloaded copy, if there is one
            if (isDownloaded.value != 100) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.notAvailableOffline),
                duration: const Duration(seconds: 2),
              ));
              return;
            }
            var offlineHelper =
                await ref.read(offlinePlayerHelperProvider(episode.id!).future);
            if (context.mounted) {
              context.pushNamed(parentPath + ScreenPaths.player,
                  queryParameters: {
                    "startTimeTicks": "0",
                    "title": episode.name!
                  },
                  extra: offlineHelper);
            }
            return;
          }
          var playbackInfo =
              await ref.read(streamPlayerHelperProvider(episode.id!).future);
          if (context.mounted) {
            context.pushNamed(parentPath + ScreenPaths.player,
                queryParameters: {
                  "startTimeTicks":
                      episode.userData?.playbackPositionTicks?.toString(),
                  "title": episode.name!
                },
                extra: playbackInfo);
          }
        },
        onSelectedMenuItem: (value) {
          // the download entry handles itself in its onTap
          if (value != 'download_action') onSelected(value);
        },
        trailing: offline
            ? null
            : _EpisodeDownloadButton(
                episodeId: episode.id!,
                isDownloaded: isDownloaded,
                isDownloading: isDownloading,
                onPressed: () =>
                    _downloadAction(context, ref, isDownloaded, isDownloading),
              ),
        // marking played and downloading both need the server
        popupMenuEntries: offline
            ? null
            : [
                PopupMenuItem<String>(
                  value: 'mark_as_played',
                  child: !mark.value!
                      ? ListTile(
                          leading: const Icon(Icons.check),
                          iconColor: Theme.of(context).colorScheme.primary,
                          title: Text(
                            AppLocalizations.of(context)!.markAsPlayed,
                          ),
                        )
                      : ListTile(
                          leading: const Icon(Icons.close),
                          iconColor: Theme.of(context).colorScheme.tertiary,
                          title: Text(
                            AppLocalizations.of(context)!.markAsUnplayed,
                          ),
                        ),
                ),
                PopupMenuItem<String>(
                  value: 'download_action',
                  onTap: () => _downloadAction(
                      context, ref, isDownloaded, isDownloading),
                  child: ListTile(
                    leading: Icon(_downloadActionIcon(
                        isDownloaded.value, isDownloading.value)),
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: Text(_downloadActionLabel(
                        context, isDownloaded.value, isDownloading.value)),
                  ),
                ),
              ],
        overlay: episode.userData!.playedPercentage != null
            ? PlaybackProgressOverlay(
                progress: (episode.userData!.playedPercentage! / 100))
            : mark.value == true
                ? Positioned(
                    bottom: 5.0,
                    right: 5.0,
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }

  IconData _downloadActionIcon(int? progress, bool downloading) {
    if (progress == 100) return Icons.delete_outline;
    if (downloading) return Icons.cancel_outlined;
    if (progress != null) return Icons.file_download_outlined;
    return Icons.file_download_outlined;
  }

  String _downloadActionLabel(
      BuildContext context, int? progress, bool downloading) {
    final l10n = AppLocalizations.of(context)!;
    if (progress == 100) return l10n.removeDownload;
    if (downloading) return l10n.cancelDownload;
    if (progress != null) return l10n.resumeDownload;
    return l10n.download;
  }

  /// Download, cancel, resume or remove, depending on the current state.
  Future<void> _downloadAction(
      BuildContext context,
      WidgetRef ref,
      ValueNotifier<int?> isDownloaded,
      ValueNotifier<bool> isDownloading) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(downloadProvider(episode.id!));
    void snack(String text) => messenger.showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 1)));

    if (isDownloaded.value == 100) {
      await service.removeDownload();
      isDownloaded.value = null;
      isDownloading.value = false;
      snack(l10n.removedDownload);
      return;
    }
    if (isDownloading.value) {
      await service.cancelDownload();
      isDownloaded.value = null;
      isDownloading.value = false;
      snack(l10n.canceledDownload);
      return;
    }
    if (isDownloaded.value != null) {
      await service.resumeDownload();
      isDownloading.value = true;
      snack(l10n.resumedDownload);
      return;
    }
    if ((Platform.isAndroid || Platform.isIOS) &&
        !(ref.read(connectivityProvider).isConnected)) {
      return;
    }
    int downloadBitrate =
        await ref.read(databaseProvider("settings")).get("downloadBitrate") ??
            BitRates.defaultBitrate();

    PlaybackInfoResponse downloadInfo =
        await service.getDownloadInfo(downloadBitrate: downloadBitrate);

    int audioCount = downloadInfo.mediaSources![0].mediaStreams!
        .where((element) =>
            element.type == MediaStreamType.audio &&
            downloadInfo.mediaSources!.first.transcodingUrl != null)
        .length;
    int subtitleCount = downloadInfo.mediaSources![0].mediaStreams!
        .where((element) =>
            element.type == MediaStreamType.subtitle &&
            element.deliveryMethod == SubtitleDeliveryMethod.external_)
        .length;

    if (context.mounted && (audioCount > 1 || subtitleCount > 0)) {
      var selectedSettings = await showDialog(
        context: context,
        builder: (context) {
          return DownloadSettingsDialog(downloadInfo: downloadInfo);
        },
      );
      if (selectedSettings == null ||
          (selectedSettings?.$1 == null && selectedSettings?.$2 == null)) {
        return;
      }
      service.downloadItem(
          audioStreamIndex: selectedSettings.$1,
          subtitleStreamIndex: selectedSettings.$2,
          downloadBitrate: downloadBitrate);
    } else {
      service.downloadItem(downloadBitrate: downloadBitrate);
    }
    isDownloading.value = true;
    isDownloaded.value = 0;
    snack(l10n.startedDownload);
  }
}

/// Download button at the end of an episode row: a download icon, a progress
/// ring while downloading, or a check mark once it's on the device.
class _EpisodeDownloadButton extends ConsumerWidget {
  final String episodeId;
  final ValueNotifier<int?> isDownloaded;
  final ValueNotifier<bool> isDownloading;
  final VoidCallback onPressed;

  const _EpisodeDownloadButton({
    required this.episodeId,
    required this.isDownloaded,
    required this.isDownloading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final started = isDownloading.value || isDownloaded.value != null;
    int? progress = isDownloaded.value;
    bool active = isDownloading.value;
    if (started && progress != 100) {
      // only poll once a download exists
      final state = ref.watch(downloadStateProvider(episodeId)).value;
      if (state != null) {
        progress = state.progress ?? progress;
        active = state.status == DownloadStatus.downloading;
        if (state.status == DownloadStatus.complete &&
            isDownloaded.value != 100) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            isDownloaded.value = 100;
            isDownloading.value = false;
          });
        }
      }
    }
    Widget icon;
    if (progress == 100) {
      icon = Icon(Icons.download_done_rounded,
          color: Theme.of(context).colorScheme.primary);
    } else if (started) {
      icon = Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            value: progress == null ? null : progress / 100,
            strokeWidth: 2.5,
          ),
        ),
        Icon(active ? Icons.stop_rounded : Icons.file_download_outlined,
            size: 16),
      ]);
    } else {
      icon = const Icon(Icons.file_download_outlined);
    }
    return IconButton(onPressed: onPressed, icon: icon);
  }
}
