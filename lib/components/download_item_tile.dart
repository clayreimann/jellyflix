import 'package:flutter/material.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/models/download_metadata.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/providers/player_helper_provider.dart';
import 'package:jellyflix/services/download_service.dart';
import 'package:jellyflix/services/player_helper.dart';
import 'package:universal_io/io.dart';

/// A row for one downloaded movie or episode: artwork, title, description,
/// runtime, size on disk, and live download status.
class DownloadItemTile extends ConsumerWidget {
  final DownloadMetadata metadata;
  final String parentBranch;

  /// Show "Series · S01E03" above the title (used outside the show screen).
  final bool showSeriesName;

  /// Called after the download was deleted or canceled.
  final VoidCallback? onRemoved;

  const DownloadItemTile({
    super.key,
    required this.metadata,
    required this.parentBranch,
    this.showSeriesName = false,
    this.onRemoved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final itemId = metadata.id;
    final state = ref.watch(downloadStateProvider(itemId)).value;
    final size = ref.watch(downloadSizeProvider(itemId)).value;
    final isWide = MediaQuery.of(context).size.width >= 640;
    final complete = state?.status == DownloadStatus.complete;

    String title;
    if (metadata.isEpisode) {
      final episodeTitle = metadata.displayEpisodeTitle(l10n.episodeNumber);
      title = metadata.indexNumber == null
          ? episodeTitle
          : "${metadata.indexNumber}. $episodeTitle";
    } else {
      title = metadata.name;
    }

    final details = <String>[
      if (metadata.isEpisode && showSeriesName)
        "${metadata.seriesName ?? ""} · S${(metadata.parentIndexNumber ?? 0).toString().padLeft(2, '0')}E${(metadata.indexNumber ?? 0).toString().padLeft(2, '0')}",
      if (!metadata.isEpisode && metadata.productionYear != null)
        metadata.productionYear.toString(),
      if (metadata.runTimeTicks > 0) l10n.minutes(metadata.runTimeMinutes),
      if (size != null && size > 0) formatBytes(size),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(10.0),
      onTap: () => _play(context, ref, state),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: isWide ? 220 : 140,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _LocalImage(itemId: itemId),
                    ),
                    if (!complete)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.downloading_rounded, size: 32),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  if (details.isNotEmpty)
                    Text(
                      details.join(" · "),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  if (!complete) ...[
                    const SizedBox(height: 6),
                    _StatusLine(state: state),
                  ],
                  if (metadata.overview != null &&
                      metadata.overview!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      metadata.overview!,
                      maxLines: isWide ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            // vertically centered on the artwork
            SizedBox(
              height: (isWide ? 220 : 140) * 9 / 16,
              child: Center(child: _menu(context, ref, state)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, WidgetRef ref, DownloadState? state) {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(downloadProvider(metadata.id));
    final active = state?.status == DownloadStatus.downloading;
    final canResume = state?.status == DownloadStatus.paused ||
        state?.status == DownloadStatus.failed;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        if (canResume)
          PopupMenuItem(
            value: "resume",
            child: ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: Text(l10n.resumeDownload),
            ),
          ),
        PopupMenuItem(
          value: "delete",
          child: ListTile(
            leading: Icon(
                active ? Icons.close_rounded : Icons.delete_outline_rounded),
            title: Text(active ? l10n.cancelDownload : l10n.removeDownload),
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == "resume") {
          await service.resumeDownload();
          ref.invalidate(downloadStateProvider(metadata.id));
        } else if (value == "delete") {
          if (active) {
            await service.cancelDownload();
          } else {
            await service.removeDownload();
          }
          onRemoved?.call();
        }
      },
    );
  }

  Future<void> _play(
      BuildContext context, WidgetRef ref, DownloadState? state) async {
    if (state?.status != DownloadStatus.complete) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.stillDownloading),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    PlayerHelper playerHelper =
        await ref.read(offlinePlayerHelperProvider(metadata.id).future);
    if (context.mounted) {
      context.pushNamed(parentBranch + ScreenPaths.player,
          queryParameters: {"startTimeTicks": "0", "title": metadata.name},
          extra: playerHelper);
    }
  }
}

class _StatusLine extends StatelessWidget {
  final DownloadState? state;
  const _StatusLine({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = state?.progress;
    String label;
    Color color = theme.colorScheme.primary;
    switch (state?.status) {
      case DownloadStatus.downloading:
        label = progress == null
            ? l10n.downloadStatusWaiting
            : l10n.downloadStatusDownloading(progress);
        break;
      case DownloadStatus.failed:
        label = l10n.downloadStatusFailed(progress ?? 0);
        color = theme.colorScheme.error;
        break;
      case DownloadStatus.paused:
        label = l10n.downloadStatusPaused(progress ?? 0);
        color = theme.colorScheme.tertiary;
        break;
      default:
        label = l10n.downloadStatusWaiting;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        const SizedBox(height: 4),
        SizedBox(
          width: 220,
          child: LinearProgressIndicator(
            value: progress == null ? null : progress / 100,
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _LocalImage extends ConsumerWidget {
  final String itemId;
  const _LocalImage({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(downloadProvider(itemId)).getMetadataImagePath(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(color: Colors.white10);
        }
        return Image.file(
          File(snapshot.data!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.white10,
            child: const Icon(Icons.movie_outlined),
          ),
        );
      },
    );
  }
}
