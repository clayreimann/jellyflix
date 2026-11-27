import 'dart:async';
import 'dart:convert';

import 'package:universal_io/io.dart';

/// A download waiting for a free slot.
class QueuedDownload {
  final String itemId;
  final int downloadBitrate;
  final int? audioStreamIndex;
  final int? subtitleStreamIndex;

  QueuedDownload(this.itemId,
      {required this.downloadBitrate,
      this.audioStreamIndex,
      this.subtitleStreamIndex});

  Map<String, dynamic> toJson() => {
        "ItemId": itemId,
        "Bitrate": downloadBitrate,
        "Audio": audioStreamIndex,
        "Subtitle": subtitleStreamIndex,
      };

  static QueuedDownload fromJson(Map<String, dynamic> json) =>
      QueuedDownload(json["ItemId"],
          downloadBitrate: json["Bitrate"],
          audioStreamIndex: json["Audio"],
          subtitleStreamIndex: json["Subtitle"]);
}

/// Limits how many downloads transfer at once. Downloads beyond the limit
/// wait here (persisted, so they survive an app restart) and start, in
/// order, as earlier ones finish.
class DownloadQueue {
  /// Starts the transfer. Completes once the download is set up. Throwing
  /// leaves the download waiting, at the front, to be tried again later.
  final Future<void> Function(QueuedDownload download) start;

  /// Whether a started download no longer needs a slot (finished, failed,
  /// paused or removed).
  final Future<bool> Function(String itemId) isDone;

  /// The current limit (read every time, so a settings change applies).
  final int Function() maxConcurrent;

  /// Where the waiting list is saved; null keeps it in memory only.
  final Future<File?> Function()? storage;

  /// Called whenever an item joins or leaves the queue.
  final void Function(String itemId)? onChanged;

  /// Downloads already transferring when the queue is first used (after an
  /// app restart), so they count against the limit.
  final Future<Iterable<String>> Function()? restoreActive;

  final Duration checkInterval;

  final List<QueuedDownload> _waiting = [];
  final Set<String> _active = {};
  Future<void>? _pumping;
  bool _pumpAgain = false;
  Timer? _timer;
  Future<void>? _loading;

  DownloadQueue({
    required this.start,
    required this.isDone,
    required this.maxConcurrent,
    this.storage,
    this.onChanged,
    this.restoreActive,
    this.checkInterval = const Duration(seconds: 3),
  });

  int get waitingCount => _waiting.length;
  int get activeCount => _active.length;
  bool isWaiting(String itemId) => _waiting.any((d) => d.itemId == itemId);

  Future<void> _load() => _loading ??= _doLoad();

  Future<void> _doLoad() async {
    try {
      _active.addAll(await restoreActive?.call() ?? const []);
    } catch (_) {
      // nothing to restore
    }
    try {
      final file = await storage?.call();
      if (file == null || !await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      for (var json in list) {
        final d = QueuedDownload.fromJson(Map<String, dynamic>.from(json));
        if (!isWaiting(d.itemId)) _waiting.add(d);
      }
    } catch (_) {
      // unreadable queue file: start empty
    }
  }

  Future<void> _saving = Future.value();

  /// Saves run one after another, each writing the list as it is then.
  Future<void> _save() => _saving = _saving.then((_) => _write());

  Future<void> _write() async {
    try {
      final file = await storage?.call();
      if (file == null) return;
      await file.parent.create(recursive: true);
      final tmp = File("${file.path}.tmp");
      await tmp.writeAsString(
          jsonEncode(_waiting.map((d) => d.toJson()).toList()));
      await tmp.rename(file.path);
    } catch (_) {
      // not fatal: the queue just won't survive a restart
    }
  }

  /// Queues a download; it starts right away if a slot is free.
  Future<void> add(QueuedDownload download) async {
    await _load();
    if (isWaiting(download.itemId) || _active.contains(download.itemId)) {
      return;
    }
    _waiting.add(download);
    await _save();
    onChanged?.call(download.itemId);
    await pump();
  }

  /// Takes a waiting download off the queue. Returns false if it wasn't
  /// waiting (it may already be transferring).
  Future<bool> remove(String itemId) async {
    await _load();
    final before = _waiting.length;
    _waiting.removeWhere((d) => d.itemId == itemId);
    if (_waiting.length == before) return false;
    await _save();
    onChanged?.call(itemId);
    return true;
  }

  /// Forgets every waiting download (used when all downloads are removed).
  Future<void> clear() async {
    await _load();
    final ids = _waiting.map((d) => d.itemId).toList();
    _waiting.clear();
    _active.clear();
    await _save();
    ids.forEach(onChanged ?? (_) {});
  }

  /// Frees slots of finished downloads and starts waiting ones. Calls made
  /// while a pump is running are folded into one more pass.
  Future<void> pump() {
    if (_pumping != null) {
      _pumpAgain = true;
      return _pumping!;
    }
    _pumping = _pumpLoop().whenComplete(() => _pumping = null);
    return _pumping!;
  }

  Future<void> _pumpLoop() async {
    await _load();
    do {
      _pumpAgain = false;
      for (var id in _active.toList()) {
        bool done;
        try {
          done = await isDone(id);
        } catch (_) {
          done = false;
        }
        if (done) _active.remove(id);
      }
      while (_active.length < maxConcurrent().clamp(1, 100) &&
          _waiting.isNotEmpty) {
        final next = _waiting.removeAt(0);
        _active.add(next.itemId);
        await _save();
        try {
          await start(next);
        } catch (_) {
          // can't start now (offline, say): keep its place and try again on
          // the next check
          _active.remove(next.itemId);
          _waiting.insert(0, next);
          await _save();
          break;
        }
        onChanged?.call(next.itemId);
      }
    } while (_pumpAgain);
    _schedule();
  }

  void _schedule() {
    final busy = _waiting.isNotEmpty || _active.isNotEmpty;
    if (busy && _timer == null) {
      _timer = Timer.periodic(checkInterval, (_) => pump());
    } else if (!busy) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
