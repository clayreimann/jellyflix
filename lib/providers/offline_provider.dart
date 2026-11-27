import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/models/auth_state.dart';
import 'package:jellyflix/models/download_metadata.dart';
import 'package:jellyflix/providers/auth_provider.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:tentacle/tentacle.dart';

/// Whether the app is currently in offline mode (server unreachable).
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider) == AuthState.offline;
});

/// Answers "can this be watched without a connection?" from local downloads.
class OfflineAvailability {
  final DownloadLibrary library;
  OfflineAvailability(this.library);

  bool isAvailable(BaseItemDto item) {
    if (item.id == null) return false;
    switch (item.type) {
      case BaseItemKind.series:
        return library.seriesIds.contains(item.id);
      case BaseItemKind.season:
        return library.shows
            .any((s) => s.episodes.any((e) => e.seasonId == item.id));
      default:
        return library.itemIds.contains(item.id);
    }
  }

  /// Downloaded episodes of a series, in season/episode order.
  List<DownloadMetadata> episodesOf(String seriesId) =>
      library.show(seriesId)?.episodes ?? [];
}

final offlineAvailabilityProvider =
    FutureProvider.autoDispose<OfflineAvailability>((ref) async {
  return OfflineAvailability(await ref.watch(downloadLibraryProvider.future));
});

/// A minimal [BaseItemDto] built from download metadata, used offline when
/// the full library metadata isn't cached.
BaseItemDto baseItemFromDownload(DownloadMetadata m) {
  return BaseItemDto((b) => b
    ..id = m.id
    ..name = m.name
    ..type = m.type
    ..runTimeTicks = m.runTimeTicks
    ..seriesName = m.seriesName
    ..seriesId = m.normalizedSeriesId
    ..indexNumber = m.indexNumber
    ..parentIndexNumber = m.parentIndexNumber
    ..seasonId = m.seasonId ?? "season-${m.parentIndexNumber ?? 0}"
    ..seasonName = m.seasonName ??
        ((m.parentIndexNumber ?? 0) == 0
            ? "Specials"
            : "Season ${m.parentIndexNumber}")
    ..overview = m.overview
    ..productionYear = m.productionYear
    ..userData.played = false
    ..userData.playbackPositionTicks = 0);
}
