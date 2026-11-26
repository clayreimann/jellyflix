import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/models/download_metadata.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/providers/offline_provider.dart';
import 'package:jellyflix/services/offline_library_cache.dart';
import 'package:tentacle/tentacle.dart';

DownloadMetadata episode(String id, int season, int number,
        {String name = "Ep", String seriesId = "s1"}) =>
    DownloadMetadata(
      id: id,
      name: name,
      type: BaseItemKind.episode,
      runTimeTicks: 7 * 60 * 10000000,
      seriesName: "Show",
      seriesId: seriesId,
      indexNumber: number,
      parentIndexNumber: season,
      path: "/x",
    );

void main() {
  group('DownloadMetadata', () {
    test('reads metadata written by older versions', () {
      final old = jsonDecode('{"Id":"a","Name":"Keepy Uppy","Type":"episode",'
          '"RunTimeTicks":4200000000,"SeriesName":"Bluey","SeriesId":"s",'
          '"IndexNumber":3,"ParentIndexNumber":1,"Path":"/p","DownloadSize":null}');
      final m = DownloadMetadata.fromJson(old);
      expect(m.name, "Keepy Uppy");
      expect(m.overview, isNull);
      expect(m.runTimeMinutes, 7);
    });

    test('round-trips new fields', () {
      final m = episode("a", 1, 3)
        ..overview = "desc"
        ..seasonName = "Season 1";
      final back = DownloadMetadata.fromJson(jsonDecode(jsonEncode(m.toJson())));
      expect(back.overview, "desc");
      expect(back.seasonName, "Season 1");
    });

    test('numeric-only names fall back to an episode label', () {
      String label(int n) => "Episode $n";
      expect(episode("a", 1, 3, name: "4").displayEpisodeTitle(label),
          "Episode 3");
      expect(episode("a", 1, 3, name: "Keepy Uppy").displayEpisodeTitle(label),
          "Keepy Uppy");
    });
  });

  test('DownloadedShow groups by season with specials last', () {
    final show = DownloadedShow("s1", "Show", [
      episode("c", 2, 1),
      episode("a", 1, 2),
      episode("sp", 0, 1),
      episode("b", 1, 1),
    ]);
    final seasons = show.seasons;
    expect(seasons.map((s) => s.seasonNumber), [1, 2, 0]);
    expect(seasons.first.episodes.map((e) => e.id), ["b", "a"]);
  });

  test('OfflineAvailability', () {
    final lib = DownloadLibrary([
      DownloadedShow("s1", "Show", [episode("e1", 1, 1)])
    ], []);
    final availability = OfflineAvailability(lib);
    expect(
        availability.isAvailable(BaseItemDto((b) => b
          ..id = "s1"
          ..type = BaseItemKind.series)),
        isTrue);
    expect(
        availability.isAvailable(BaseItemDto((b) => b
          ..id = "m1"
          ..type = BaseItemKind.movie)),
        isFalse);
  });

  test('OfflineLibraryCache filters and sorts like the server', () {
    final cache = OfflineLibraryCache.forUser("http://test", "user");
    BaseItemDto item(String id, String name, BaseItemKind type,
            {bool played = false, int year = 2000}) =>
        BaseItemDto((b) => b
          ..id = id
          ..name = name
          ..type = type
          ..productionYear = year
          ..userData.played = played);
    cache.putLibraryItems("lib1", [
      item("1", "Zebra", BaseItemKind.movie, year: 2001),
      item("2", "apple", BaseItemKind.movie, played: true, year: 1999),
      item("3", "Mango", BaseItemKind.series),
    ]);
    expect(
        cache
            .queryItems(parentId: "lib1", includeItemTypes: [
              BaseItemKind.movie,
              BaseItemKind.series
            ])
            .map((e) => e.name),
        ["apple", "Mango", "Zebra"]);
    expect(
        cache.queryItems(
            parentId: "lib1",
            includeItemTypes: [BaseItemKind.movie],
            filters: [ItemFilter.isUnplayed]).map((e) => e.id),
        ["1"]);
    expect(
        cache
            .queryItems(
                includeItemTypes: [BaseItemKind.movie],
                sortBy: ItemSortBy.productionYear,
                sortOrder: SortOrder.descending)
            .map((e) => e.id),
        ["1", "2"]);
    expect(cache.queryItems(startIndex: 1, limit: 1).length, 1);
    // round trip through JSON serialization
    expect(cache.getItem("3")!.name, "Mango");
  });

  test('BaseItemDto survives the JSON round trip used by the cache', () {
    final item = BaseItemDto((b) => b
      ..id = "x"
      ..name = "Keepy Uppy"
      ..type = BaseItemKind.episode
      ..indexNumber = 3
      ..userData.played = true);
    final json = jsonDecode(jsonEncode(
        standardSerializers.serializeWith(BaseItemDto.serializer, item)));
    final back =
        standardSerializers.deserializeWith(BaseItemDto.serializer, json)!;
    expect(back.name, "Keepy Uppy");
    expect(back.type, BaseItemKind.episode);
    expect(back.userData!.played, isTrue);
  });
}
