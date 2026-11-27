import 'package:flutter/material.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/download_controls.dart';
import 'package:jellyflix/components/media_row.dart';
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
    final itemId = metadata.id;
    final state = ref.watch(downloadStateProvider(itemId)).value;
    final size = ref.watch(downloadSizeProvider(itemId)).value;
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

    return MediaRow(
      image: _LocalImage(itemId: itemId),
      imageOverlay: complete
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.downloading_rounded, size: 32),
              ),
            ),
      title: title,
      details: details.join(" · "),
      status: complete ? null : _StatusLine(state: state),
      overview: metadata.overview,
      trailing: DownloadStateButton(itemId: itemId),
      menuEntries: [downloadMenuItem(context, state)],
      onMenuSelected: (value) async {
        if (value == downloadMenuValue) {
          await runDownloadAction(context, ref, itemId,
              shown: downloadActionFor(state));
          if (state?.status != DownloadStatus.paused &&
              state?.status != DownloadStatus.failed) {
            onRemoved?.call();
          }
        }
      },
      onTap: () => _play(context, ref, state),
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
      case DownloadStatus.queued:
        label = l10n.downloadStatusQueued;
        color = theme.colorScheme.onSurfaceVariant;
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
            value: state?.status == DownloadStatus.queued
                ? 0
                : (progress == null ? null : progress / 100),
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
