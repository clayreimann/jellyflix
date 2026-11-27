import 'package:material_ui/material_ui.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/download_controls.dart';
import 'package:jellyflix/components/jellyfin_image.dart';
import 'package:jellyflix/components/media_row.dart';
import 'package:jellyflix/components/offline_dimmed.dart';
import 'package:jellyflix/components/playback_progress_overlay.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/providers/offline_provider.dart';
import 'package:jellyflix/providers/player_helper_provider.dart';
import 'package:jellyflix/services/download_service.dart';
import 'package:tentacle/tentacle.dart';

class EpisodeListTile extends ConsumerWidget {
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
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(downloadStateProvider(episode.id!)).value;
    final downloaded = state?.status == DownloadStatus.complete;
    final played = episode.userData?.played ?? false;
    final offline = ref.watch(isOfflineProvider);

    return OfflineDimmed(
      item: episode,
      child: MediaRow(
        image: JellyfinImage(
            id: episode.id!,
            type: ImageType.primary,
            blurHash: episode.imageBlurHashes?.primary?[episode.id!]),
        imageOverlay: episode.userData?.playedPercentage != null
            ? PlaybackProgressOverlay(
                progress: (episode.userData!.playedPercentage! / 100))
            : played
                ? Positioned(
                    bottom: 5.0,
                    right: 5.0,
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  )
                : null,
        title:
            "${episode.indexNumber == null ? "" : "${episode.indexNumber!}. "}${episode.name ?? ""}",
        details: [
          episode.runTimeTicks == null
              ? l10n.na
              : l10n.minutes((episode.runTimeTicks! / 10000000 / 60).round()),
          if (downloaded) "✓ ${l10n.downloaded}",
          if (offline && !downloaded) l10n.notDownloaded,
        ].join(" · "),
        overview: episode.overview,
        // downloading needs the server
        trailing: offline ? null : DownloadStateButton(itemId: episode.id!),
        // marking played and downloading both need the server
        menuEntries: offline
            ? null
            : [
                PopupMenuItem<String>(
                  value: 'mark_as_played',
                  child: ListTile(
                    leading: Icon(played ? Icons.close : Icons.check),
                    iconColor: played
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.primary,
                    title:
                        Text(played ? l10n.markAsUnplayed : l10n.markAsPlayed),
                  ),
                ),
                downloadMenuItem(context, state),
              ],
        onMenuSelected: (value) {
          if (value == downloadMenuValue) {
            runDownloadAction(context, ref, episode.id!,
                shown: downloadActionFor(state));
          } else {
            onSelected(value);
          }
        },
        onTap: () async {
          if (offline) {
            // offline: play the downloaded copy, if there is one
            if (!downloaded) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l10n.notAvailableOffline),
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
      ),
    );
  }
}
