import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/download_item_tile.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/screens/download_screen.dart';

/// Offline view of one downloaded show: its seasons and episodes, built
/// entirely from locally saved metadata.
class DownloadedShowScreen extends ConsumerWidget {
  final String seriesId;
  const DownloadedShowScreen({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final library = ref.watch(downloadLibraryProvider);
    final show = library.value?.show(seriesId);
    final showSize = show == null
        ? 0
        : ref
                .watch(downloadItemsSizeProvider(downloadSizeKey(show.episodes)))
                .value ??
            0;

    return Scaffold(
      appBar: AppBar(
        title: Text(show?.seriesName ?? ""),
        actions: [
          if (show != null)
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: "deleteAll",
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: Text(l10n.deleteShowDownloads),
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == "deleteAll") {
                  for (var e in show.episodes) {
                    final service = ref.read(downloadProvider(e.id));
                    if (service.isDownloading) {
                      await service.cancelDownload();
                    } else {
                      await service.removeDownload();
                    }
                  }
                  ref.invalidate(downloadLibraryProvider);
                  if (context.mounted) Navigator.of(context).maybePop();
                }
              },
            ),
        ],
      ),
      body: library.isLoading && show == null
          ? const Center(child: CircularProgressIndicator())
          : show == null
              ? Center(child: Text(l10n.noDownloads))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 120,
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SeriesPoster(show: show),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(show.seriesName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text([
                                  l10n.episodeCount(show.episodes.length),
                                  if (showSize > 0) formatBytes(showSize),
                                ].join(" · ")),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var season in show.seasons) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          season.seasonNumber == 0
                              ? (season.seasonName ?? l10n.specials)
                              : (season.seasonName ??
                                  l10n.seasonNumber(season.seasonNumber)),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      for (var episode in season.episodes)
                        DownloadItemTile(
                          key: ValueKey(episode.id),
                          metadata: episode,
                          parentBranch: ScreenPaths.downloads,
                          onRemoved: () =>
                              ref.invalidate(downloadLibraryProvider),
                        ),
                    ],
                  ],
                ),
    );
  }
}
