import 'dart:async';
import 'dart:convert';

import 'package:jellyflix/services/download_service.dart';
import 'package:jellyflix/services/locks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tentacle/tentacle.dart';
import 'package:universal_io/io.dart';

/// A local copy of the server's library metadata (libraries, movies, shows,
/// episodes), so the library can be browsed while offline.
///
/// It's filled two ways: a full sync of every library when the server is
/// reachable (see [ApiService.syncOfflineLibrary]), and every item the app
/// fetches while online. Everything is stored as JSON in one file per
/// server/user.
class OfflineLibraryCache {
  final String _key;
  bool _loaded = false;
  Timer? _saveTimer;

  List<String> _folderIds = [];
  final Map<String, Map<String, dynamic>> _items = {};
  // deserialized objects, so browsing offline doesn't re-parse every query
  final Map<String, BaseItemDto> _objects = {};
  final Map<String, List<String>> _episodesBySeries = {};
  final Map<String, List<String>> _itemsByLibrary = {};
  DateTime? syncedAt;

  OfflineLibraryCache._(this._key);

  static bool _excludedFromBackup = false;

  static final Map<String, OfflineLibraryCache> _instances = {};

  factory OfflineLibraryCache.forUser(String serverAddress, String userId) {
    final key =
        "${serverAddress.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}_$userId";
    return _instances.putIfAbsent(key, () => OfflineLibraryCache._(key));
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory(
        "${dir.path}${Platform.pathSeparator}jellyflix${Platform.pathSeparator}library_cache");
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    if (!_excludedFromBackup) {
      _excludedFromBackup = true;
      await DownloadService.excludeFromBackup(cacheDir.path);
    }
    return File("${cacheDir.path}${Platform.pathSeparator}$_key.json");
  }

  Future<void>? _loading;

  /// Loads the cache from disk. Must complete before anything is stored,
  /// otherwise the file on disk could be overwritten with partial data.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString());
      _folderIds = List<String>.from(data["folders"] ?? []);
      (data["items"] as Map? ?? {}).forEach((k, v) {
        _items[k] = Map<String, dynamic>.from(v);
      });
      (data["episodes"] as Map? ?? {}).forEach((k, v) {
        _episodesBySeries[k] = List<String>.from(v);
      });
      (data["libraries"] as Map? ?? {}).forEach((k, v) {
        _itemsByLibrary[k] = List<String>.from(v);
      });
      syncedAt =
          data["syncedAt"] == null ? null : DateTime.tryParse(data["syncedAt"]);
    } catch (_) {
      // corrupt cache: start over
      _items.clear();
    }
    _loaded = true;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), save);
  }

  final AsyncLock _saveLock = AsyncLock();

  /// Saves one at a time: the timer and the end of a sync can both save,
  /// and two writers sharing the temporary file could corrupt it.
  Future<void> save() {
    _saveTimer?.cancel();
    return _saveLock.run(_save);
  }

  Future<void> _save() async {
    if (!_loaded) return;
    final file = await _file();
    // encoded in one go, before any await, so it's a consistent snapshot
    final contents = jsonEncode({
      "folders": _folderIds,
      "items": _items,
      "episodes": _episodesBySeries,
      "libraries": _itemsByLibrary,
      "syncedAt": syncedAt?.toIso8601String(),
    });
    final tmp = File("${file.path}.tmp");
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(file.path);
  }

  Map<String, dynamic> _serialize(BaseItemDto item) =>
      Map<String, dynamic>.from(
          standardSerializers.serializeWith(BaseItemDto.serializer, item)
              as Map);

  BaseItemDto? _deserialize(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return standardSerializers.deserializeWith(BaseItemDto.serializer, json);
    } catch (_) {
      return null;
    }
  }

  void putItem(BaseItemDto item, {bool overwrite = true}) {
    if (item.id == null) return;
    if (!overwrite && _items.containsKey(item.id)) return;
    _items[item.id!] = _serialize(item);
    _objects[item.id!] = item;
    _scheduleSave();
  }

  void putItems(Iterable<BaseItemDto> items, {bool overwrite = true}) {
    for (var item in items) {
      if (item.id == null) continue;
      if (!overwrite && _items.containsKey(item.id)) continue;
      _items[item.id!] = _serialize(item);
      _objects[item.id!] = item;
    }
    _scheduleSave();
  }

  void putFolders(List<BaseItemDto> folders) {
    putItems(folders);
    _folderIds = folders.map((e) => e.id!).toList();
    _scheduleSave();
  }

  void putEpisodes(String seriesId, List<BaseItemDto> episodes) {
    putItems(episodes);
    _episodesBySeries[seriesId] = episodes.map((e) => e.id!).toList();
    _scheduleSave();
  }

  void putLibraryItems(String libraryId, List<BaseItemDto> items) {
    putItems(items);
    _itemsByLibrary[libraryId] = items.map((e) => e.id!).toList();
    _scheduleSave();
  }

  BaseItemDto? getItem(String id) {
    final cached = _objects[id];
    if (cached != null) return cached;
    final item = _deserialize(_items[id]);
    if (item != null) _objects[id] = item;
    return item;
  }

  List<BaseItemDto> getFolders() =>
      _folderIds.map(getItem).whereType<BaseItemDto>().toList();

  List<BaseItemDto> getEpisodes(String seriesId) {
    final ids = _episodesBySeries[seriesId];
    if (ids != null) {
      return ids.map(getItem).whereType<BaseItemDto>().toList();
    }
    // fall back to scanning for episodes that were cached individually
    final episodes = _items.values
        .where((j) => j["SeriesId"] == seriesId && j["Type"] == "Episode")
        .map((j) => getItem(j["Id"]))
        .whereType<BaseItemDto>()
        .toList();
    episodes.sort((a, b) {
      final s = (a.parentIndexNumber ?? 0).compareTo(b.parentIndexNumber ?? 0);
      return s != 0 ? s : (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0);
    });
    return episodes;
  }

  /// Library browsing offline: filter and sort the cached items like the
  /// server would.
  List<BaseItemDto> queryItems({
    String? parentId,
    List<BaseItemKind>? includeItemTypes,
    List<String>? genreIds,
    String? searchTerm,
    List<ItemFilter>? filters,
    ItemSortBy? sortBy,
    SortOrder? sortOrder,
    int? startIndex,
    int? limit,
  }) {
    Iterable<BaseItemDto> items;
    if (parentId != null && _itemsByLibrary.containsKey(parentId)) {
      items = _itemsByLibrary[parentId]!.map(getItem).whereType<BaseItemDto>();
    } else if (parentId != null) {
      items = _items.values
          .where((j) => j["ParentId"] == parentId)
          .map((j) => getItem(j["Id"]))
          .whereType<BaseItemDto>();
    } else {
      final seen = <String>{};
      final libraryItems = _itemsByLibrary.values.expand((ids) => ids);
      final ids = libraryItems.isNotEmpty ? libraryItems : _items.keys;
      items = ids
          .where(seen.add)
          .map(getItem)
          .whereType<BaseItemDto>();
    }
    final types = includeItemTypes?.toSet();
    var list = items.where((item) {
      if (types != null && !types.contains(item.type)) return false;
      if (genreIds != null && genreIds.isNotEmpty) {
        final itemGenres = item.genreItems?.map((g) => g.id).toSet() ?? {};
        if (!genreIds.any(itemGenres.contains)) return false;
      }
      if (searchTerm != null && searchTerm.isNotEmpty) {
        if (!(item.name ?? "")
            .toLowerCase()
            .contains(searchTerm.toLowerCase())) {
          return false;
        }
      }
      for (var f in filters ?? <ItemFilter>[]) {
        if (f == ItemFilter.isPlayed && item.userData?.played != true) {
          return false;
        }
        if (f == ItemFilter.isUnplayed && item.userData?.played == true) {
          return false;
        }
        if (f == ItemFilter.isFavorite && item.userData?.isFavorite != true) {
          return false;
        }
        if (f == ItemFilter.isResumable &&
            (item.userData?.playbackPositionTicks ?? 0) == 0) {
          return false;
        }
      }
      return true;
    }).toList();

    int compare(BaseItemDto a, BaseItemDto b) {
      switch (sortBy) {
        case ItemSortBy.dateCreated:
          return (a.dateCreated ?? DateTime(0))
              .compareTo(b.dateCreated ?? DateTime(0));
        case ItemSortBy.premiereDate:
        case ItemSortBy.productionYear:
          return (a.productionYear ?? 0).compareTo(b.productionYear ?? 0);
        case ItemSortBy.communityRating:
          return (a.communityRating ?? 0).compareTo(b.communityRating ?? 0);
        case ItemSortBy.criticRating:
          return (a.criticRating ?? 0).compareTo(b.criticRating ?? 0);
        case ItemSortBy.runtime:
          return (a.runTimeTicks ?? 0).compareTo(b.runTimeTicks ?? 0);
        case ItemSortBy.random:
          return 0;
        default:
          return (a.sortName ?? a.name ?? "")
              .toLowerCase()
              .compareTo((b.sortName ?? b.name ?? "").toLowerCase());
      }
    }

    list.sort(compare);
    if (sortOrder == SortOrder.descending) {
      list = list.reversed.toList();
    }
    final start = startIndex ?? 0;
    if (start >= list.length) return [];
    final end = limit == null ? list.length : (start + limit);
    return list.sublist(start, end > list.length ? list.length : end);
  }

  /// Genres present in the cached items.
  List<BaseItemDto> genres({List<BaseItemKind>? includeItemTypes}) {
    final types = includeItemTypes?.toSet();
    final Map<String, BaseItemDto> genres = {};
    for (var id in _items.keys) {
      final item = getItem(id);
      if (item == null) continue;
      if (types != null && !types.contains(item.type)) continue;
      for (var g in item.genreItems ?? <NameGuidPair>[]) {
        if (g.id == null) continue;
        genres.putIfAbsent(
            g.id!,
            () => BaseItemDto((b) => b
              ..id = g.id
              ..name = g.name));
      }
    }
    final list = genres.values.toList()
      ..sort((a, b) => (a.name ?? "").compareTo(b.name ?? ""));
    return list;
  }
}
