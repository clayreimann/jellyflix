import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:jellyflix/components/download_item_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/models/auth_state.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/providers/auth_provider.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/services/download_service.dart';
import 'package:universal_io/io.dart';

/// Total bytes used by all downloads.
final downloadsTotalSizeProvider = FutureProvider.autoDispose<int>((ref) async {
  final library = await ref.watch(downloadLibraryProvider.future);
  int total = 0;
  for (var id in library.itemIds) {
    total += await ref.read(downloadProvider(id)).sizeOnDisk();
  }
  return total;
});

bool _refreshedMetadataThisSession = false;

/// When online, re-fetch titles/descriptions for downloads once per app
/// session so older downloads (saved with less info) browse nicely offline.
Future<void> refreshDownloadMetadata(WidgetRef ref) async {
  if (_refreshedMetadataThisSession) return;
  if (ref.read(authStateProvider.notifier).state != AuthState.loggedIn) return;
  _refreshedMetadataThisSession = true;
  final ids = await DownloadService.getDownloadedItems();
  for (var id in ids) {
    try {
      await ref.read(downloadProvider(id)).refreshMetadata();
    } catch (_) {
      // keep going; one missing item shouldn't stop the rest
    }
  }
  ref.invalidate(downloadLibraryProvider);
}

class DownloadScreen extends HookConsumerWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final library = ref.watch(downloadLibraryProvider);
    final totalSize = ref.watch(downloadsTotalSizeProvider).value;

    useEffect(() {
      refreshDownloadMetadata(ref);
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.downloads),
            if (library.value != null && !library.value!.isEmpty)
              Text(
                l10n.downloadsSummary(library.value!.itemCount,
                    totalSize == null ? "…" : formatBytes(totalSize)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.resumeAllDownloads,
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () async {
              final count = await DownloadService.resumeStalledDownloads(
                  (id) => ref.read(downloadProvider(id)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l10n.resumedDownloadsCount(count)),
                  duration: const Duration(seconds: 2),
                ));
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(downloadLibraryProvider);
          await ref.read(downloadLibraryProvider.future);
        },
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text("$e")),
          data: (lib) {
            if (lib.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 200),
                Center(child: Text(l10n.noDownloads)),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _ActiveDownloads(library: lib),
                if (lib.shows.isNotEmpty) ...[
                  _SectionHeader(l10n.shows),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (var show in lib.shows) _ShowCard(show: show),
                      ],
                    ),
                  ),
                ],
                if (lib.movies.isNotEmpty) ...[
                  _SectionHeader(l10n.movies),
                  for (var movie in lib.movies)
                    DownloadItemTile(
                      key: ValueKey(movie.id),
                      metadata: movie,
                      parentBranch: ScreenPaths.downloads,
                      onRemoved: () => ref.invalidate(downloadLibraryProvider),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Everything still transferring, with live progress, at the top of the list.
class _ActiveDownloads extends ConsumerWidget {
  final DownloadLibrary library;
  const _ActiveDownloads({required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [
      for (var show in library.shows) ...show.episodes,
      ...library.movies,
    ];
    final active = all.where((m) {
      final state = ref.watch(downloadStateProvider(m.id)).value;
      return state != null &&
          state.status != DownloadStatus.complete &&
          state.status != DownloadStatus.notDownloaded;
    }).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            "${AppLocalizations.of(context)!.downloadingHeader} (${active.length})"),
        for (var m in active)
          DownloadItemTile(
            key: ValueKey("active-${m.id}"),
            metadata: m,
            parentBranch: ScreenPaths.downloads,
            showSeriesName: true,
            onRemoved: () => ref.invalidate(downloadLibraryProvider),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _ShowCard extends ConsumerWidget {
  final DownloadedShow show;
  const _ShowCard({required this.show});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.of(context).size.width >= 640;
    final width = isWide ? 160.0 : 120.0;
    final downloading = show.episodes.length -
        show.episodes
            .where((e) =>
                ref.watch(downloadStateProvider(e.id)).value?.status ==
                DownloadStatus.complete)
            .length;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.pushNamed(
          ScreenPaths.downloads + ScreenPaths.downloadedShow,
          queryParameters: {"seriesId": show.seriesId}),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SeriesPoster(show: show),
              ),
            ),
            const SizedBox(height: 6),
            Text(show.seriesName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              downloading > 0
                  ? "${l10n.episodeCount(show.episodes.length)} · ${l10n.downloadStatusDownloading(((show.episodes.length - downloading) / show.episodes.length * 100).round())}"
                  : l10n.episodeCount(show.episodes.length),
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The series poster saved alongside downloads, falling back to the first
/// episode's image when the poster wasn't saved (older downloads).
class SeriesPoster extends ConsumerWidget {
  final DownloadedShow show;
  const SeriesPoster({super.key, required this.show});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: () async {
        final poster = await DownloadService.getSeriesPosterPath(show.seriesId);
        if (await File(poster).exists()) return poster;
        return ref
            .read(downloadProvider(show.firstEpisode.id))
            .getMetadataImagePath();
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container(color: Colors.white10);
        return Image.file(
          File(snapshot.data!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.white10,
            child: const Icon(Icons.tv_rounded),
          ),
        );
      },
    );
  }
}
