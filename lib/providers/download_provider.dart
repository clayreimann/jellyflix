import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/models/download_metadata.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/providers/connectivity_provider.dart';
import 'package:jellyflix/providers/logger_provider.dart';
import 'package:jellyflix/services/download_service.dart';

final downloadProvider = Provider.family<DownloadService, String>(
    (ref, itemId) => DownloadService(ref.read(apiProvider),
        itemId: itemId,
        connectivityService: ref.read(connectivityProvider),
        logger: ref.read(loggerProvider)));

final getDownloadsProvider = Provider.autoDispose<Future<List<String>>>(
    (ref) => DownloadService.getDownloadedItems());

final cancelAndDeleteDownloadProvider = Provider(
  (ref) => DownloadService.cancelAndDeleteAllDownloads(),
);

final downloadProgressProvider = StreamProvider.autoDispose
    .family<int?, String>((ref, itemId) =>
        ref.read(downloadProvider(itemId)).downloadProgress(1));

/// The single source of truth for one item's download state, used by every
/// screen. Polls while a download is in progress; when the item is complete
/// or not downloaded it stops polling and waits for [DownloadService.changes]
/// (a download being started, resumed, canceled or removed).
final downloadStateProvider = StreamProvider.autoDispose
    .family<DownloadState, String>((ref, itemId) {
  final sub = DownloadService.changes
      .where((id) => id == itemId)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  final service = ref.read(downloadProvider(itemId));
  return () async* {
    while (true) {
      final state = await service.getState();
      yield state;
      if (state.status == DownloadStatus.complete ||
          state.status == DownloadStatus.notDownloaded) {
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }();
});

/// Size on disk of a single download, in bytes.
final downloadSizeProvider =
    FutureProvider.autoDispose.family<int, String>((ref, itemId) {
  return ref.read(downloadProvider(itemId)).sizeOnDisk();
});

class DownloadedSeason {
  final int seasonNumber;
  final String? seasonName;
  final List<DownloadMetadata> episodes;
  DownloadedSeason(this.seasonNumber, this.seasonName, this.episodes);
}

class DownloadedShow {
  final String seriesId;
  final String seriesName;
  final List<DownloadMetadata> episodes;

  DownloadedShow(this.seriesId, this.seriesName, this.episodes);

  /// The first episode (by season, episode) — used for fallback artwork.
  DownloadMetadata get firstEpisode => episodes.first;

  List<DownloadedSeason> get seasons {
    final Map<int, List<DownloadMetadata>> bySeason = {};
    for (var e in episodes) {
      bySeason.putIfAbsent(e.parentIndexNumber ?? 0, () => []).add(e);
    }
    final keys = bySeason.keys.toList()..sort();
    // put specials (season 0) last
    if (keys.remove(0)) keys.add(0);
    return keys.map((k) {
      final list = bySeason[k]!
        ..sort((a, b) => (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0));
      return DownloadedSeason(
          k, list.map((e) => e.seasonName).whereType<String>().firstOrNull,
          list);
    }).toList();
  }
}

class DownloadLibrary {
  final List<DownloadedShow> shows;
  final List<DownloadMetadata> movies;
  DownloadLibrary(this.shows, this.movies);

  int get itemCount =>
      movies.length + shows.fold(0, (sum, s) => sum + s.episodes.length);

  bool get isEmpty => shows.isEmpty && movies.isEmpty;

  Set<String> get itemIds => {
        ...movies.map((m) => m.id),
        for (var s in shows) ...s.episodes.map((e) => e.id),
      };

  Set<String> get seriesIds => shows.map((s) => s.seriesId).toSet();

  DownloadedShow? show(String seriesId) =>
      shows.where((s) => s.seriesId == seriesId).firstOrNull;
}

/// Everything that has been downloaded (or started downloading), grouped by
/// show and season. Built purely from local files so it works offline.
final downloadLibraryProvider =
    FutureProvider.autoDispose<DownloadLibrary>((ref) async {
  // rebuild when a download starts or is removed anywhere in the app
  Timer? debounce;
  final sub = DownloadService.changes.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
  final ids = await DownloadService.getDownloadedItems();
  final List<DownloadMetadata> all = [];
  for (var id in ids) {
    try {
      all.add(await ref.read(downloadProvider(id)).getMetadata());
    } catch (_) {
      // folder without metadata (e.g. a download that failed to start)
    }
  }
  final Map<String, DownloadedShow> shows = {};
  final List<DownloadMetadata> movies = [];
  for (var m in all) {
    final seriesId = m.normalizedSeriesId;
    if (m.isEpisode && seriesId != null) {
      shows
          .putIfAbsent(
              seriesId,
              () => DownloadedShow(
                  seriesId, m.seriesName ?? m.name, <DownloadMetadata>[]))
          .episodes
          .add(m);
    } else {
      movies.add(m);
    }
  }
  for (var s in shows.values) {
    s.episodes.sort((a, b) {
      final season =
          (a.parentIndexNumber ?? 0).compareTo(b.parentIndexNumber ?? 0);
      return season != 0
          ? season
          : (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0);
    });
  }
  final showList = shows.values.toList()
    ..sort((a, b) =>
        a.seriesName.toLowerCase().compareTo(b.seriesName.toLowerCase()));
  movies.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return DownloadLibrary(showList, movies);
});

String formatBytes(int bytes) {
  if (bytes <= 0) return "0 MB";
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) return "${(bytes / gb).toStringAsFixed(1)} GB";
  return "${(bytes / mb).round()} MB";
}
