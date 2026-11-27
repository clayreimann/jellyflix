import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/services/download_queue.dart';
import 'package:jellyflix/services/download_service.dart';
import 'package:universal_io/io.dart';

/// A fake downloader: started items transfer until [finish] is called.
class _Fake {
  final Set<String> transferring = {};
  final List<String> started = [];
  int maxSeen = 0;
  bool failStarts = false;

  Future<void> start(QueuedDownload d) async {
    await Future.delayed(const Duration(milliseconds: 1));
    if (failStarts) throw StateError("offline");
    transferring.add(d.itemId);
    started.add(d.itemId);
    if (transferring.length > maxSeen) maxSeen = transferring.length;
  }

  Future<bool> isDone(String id) async => !transferring.contains(id);

  void finish(Iterable<String> ids) => transferring.removeAll(ids.toList());
}

DownloadQueue _queue(_Fake fake,
        {int max = 5, Future<File?> Function()? storage}) =>
    DownloadQueue(
      start: fake.start,
      isDone: fake.isDone,
      maxConcurrent: () => max,
      storage: storage,
      checkInterval: const Duration(milliseconds: 20),
    );

List<QueuedDownload> _items(int n) => [
      for (var i = 0; i < n; i++) QueuedDownload("ep$i", downloadBitrate: 1)
    ];

void main() {
  test('30 episodes never run more than 5 at once, and all finish in order',
      () async {
    final fake = _Fake();
    final queue = _queue(fake);
    await Future.wait(_items(30).map(queue.add));
    expect(fake.transferring.length, 5);
    expect(queue.waitingCount, 25);

    while (fake.started.length < 30 || fake.transferring.isNotEmpty) {
      fake.finish(fake.transferring.take(2));
      await Future.delayed(const Duration(milliseconds: 30));
    }
    expect(fake.maxSeen, 5);
    expect(fake.started, [for (var i = 0; i < 30; i++) "ep$i"]);
    expect(queue.waitingCount, 0);
    queue.dispose();
  });

  test('adding the same item twice queues it once', () async {
    final fake = _Fake();
    final queue = _queue(fake, max: 1);
    await queue.add(QueuedDownload("a", downloadBitrate: 1));
    await queue.add(QueuedDownload("b", downloadBitrate: 1));
    await queue.add(QueuedDownload("b", downloadBitrate: 1));
    await queue.add(QueuedDownload("a", downloadBitrate: 1));
    expect(queue.waitingCount, 1);
    queue.dispose();
  });

  test('a waiting download can be canceled', () async {
    final fake = _Fake();
    final queue = _queue(fake, max: 1);
    await Future.wait(_items(3).map(queue.add));
    expect(queue.isWaiting("ep2"), isTrue);
    expect(await queue.remove("ep2"), isTrue);
    expect(queue.isWaiting("ep2"), isFalse);
    // ep0 is transferring, not waiting
    expect(await queue.remove("ep0"), isFalse);
    fake.finish(["ep0"]);
    await Future.delayed(const Duration(milliseconds: 60));
    fake.finish(["ep1"]);
    await Future.delayed(const Duration(milliseconds: 60));
    expect(fake.started, ["ep0", "ep1"]);
    queue.dispose();
  });

  test('a start that fails (offline) keeps the item waiting', () async {
    final fake = _Fake()..failStarts = true;
    final queue = _queue(fake, max: 2);
    await Future.wait(_items(3).map(queue.add));
    expect(queue.waitingCount, 3);
    expect(fake.started, isEmpty);
    fake.failStarts = false;
    await Future.delayed(const Duration(milliseconds: 60));
    expect(fake.started, ["ep0", "ep1"]);
    expect(queue.waitingCount, 1);
    queue.dispose();
  });

  test('the waiting list survives a restart', () async {
    final dir = await Directory.systemTemp.createTemp("jfx_queue");
    final file = File("${dir.path}/_queue.json");
    final fake = _Fake();
    final first = _queue(fake, max: 2, storage: () async => file);
    await Future.wait(_items(5).map(first.add));
    first.dispose();
    // let the saves finish
    await Future.delayed(const Duration(milliseconds: 20));

    final fake2 = _Fake()..transferring.addAll(["ep0", "ep1"]);
    final second = DownloadQueue(
      start: fake2.start,
      isDone: fake2.isDone,
      maxConcurrent: () => 2,
      storage: () async => file,
      // the two started before the restart are still transferring
      restoreActive: () async => ["ep0", "ep1"],
      checkInterval: const Duration(milliseconds: 20),
    );
    await second.pump();
    expect(second.waitingCount, 3);
    expect(fake2.started, isEmpty, reason: "both slots are still taken");
    fake2.finish(["ep0"]);
    await Future.delayed(const Duration(milliseconds: 60));
    expect(fake2.started, ["ep2"]);
    second.dispose();
    await dir.delete(recursive: true);
  });

  group('hlsProgress', () {
    const playlist = "#EXTM3U\n#EXT-X-TARGETDURATION:6\n"
        "#EXTINF:6.0,\nhls1/main/0.ts?api_key=x\n"
        "#EXTINF:6.0,\nhls1/main/1.ts?api_key=x\n"
        "#EXTINF:6.0,\nhls1/main/2.ts?api_key=x\n"
        "#EXTINF:6.0,\nhls1/main/3.ts?api_key=x\n"
        "#EXT-X-ENDLIST\n";

    test('counts downloaded segments against the whole playlist', () {
      expect(DownloadService.hlsProgress(playlist, []), 0);
      expect(DownloadService.hlsProgress(playlist, ["0.ts", "main.m3u8"]), 25);
      expect(DownloadService.hlsProgress(playlist, ["0.ts", "1.ts", "2.ts"]),
          75);
      expect(
          DownloadService.hlsProgress(
              playlist, ["0.ts", "1.ts", "2.ts", "3.ts"]),
          100);
    });

    test('works with a playlist already rewritten to local names', () {
      const local = "#EXTM3U\n#EXTINF:6.0,\n0.ts\n#EXTINF:6.0,\n1.ts\n";
      expect(DownloadService.hlsProgress(local, ["0.ts"]), 50);
    });

    test('an empty or cut-off playlist gives no answer instead of 100%', () {
      expect(DownloadService.hlsProgress("", ["0.ts"]), isNull);
      expect(DownloadService.hlsProgress("#EXTM3U\n#EXT-X-TARGET", ["0.ts"]),
          isNull);
    });
  });
}
