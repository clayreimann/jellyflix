import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/services/download_service.dart';

void main() {
  const tick = Duration(milliseconds: 1);

  test('a failed check is retried instead of freezing the state', () async {
    int calls = 0;
    Future<DownloadState> getState() async {
      calls++;
      if (calls == 1) return DownloadState(DownloadStatus.downloading, 50);
      // e.g. the file list changed while it was being read
      if (calls == 2) throw Exception("FileSystemException");
      return DownloadState(DownloadStatus.complete, 100);
    }

    final states =
        await pollDownloadState(getState, interval: tick).toList();
    expect(states.map((s) => s.status),
        [DownloadStatus.downloading, DownloadStatus.complete]);
  });

  test('many downloads finishing at once all end up complete', () async {
    // Simulates "Download season": every episode polls at the same time and
    // the checks of the others interfere (throw) as they finish.
    const episodes = 12;
    final finishedAt = List.generate(episodes, (i) => 2 + i % 4);
    int globalCalls = 0;

    Stream<DownloadState> poll(int i) {
      int calls = 0;
      return pollDownloadState(() async {
        calls++;
        globalCalls++;
        await Future.delayed(Duration(microseconds: (i * 37) % 200));
        if (globalCalls % 3 == 0) {
          throw Exception("task was removed by another download");
        }
        return calls >= finishedAt[i]
            ? DownloadState(DownloadStatus.complete, 100)
            : DownloadState(DownloadStatus.downloading, calls * 10);
      }, interval: tick);
    }

    final results = await Future.wait(
        List.generate(episodes, (i) => poll(i).last));
    expect(results.every((s) => s.status == DownloadStatus.complete), isTrue);
  });

  test('stops polling when there is no download', () async {
    int calls = 0;
    final states = await pollDownloadState(() async {
      calls++;
      return DownloadState(DownloadStatus.notDownloaded, null);
    }, interval: tick)
        .toList();
    expect(states.length, 1);
    expect(calls, 1);
  });

  test('saved paths follow the app folder after a reinstall', () {
    const now = "/var/mobile/Containers/Data/Application/NEW-ID/Documents/jellyflix/downloads";
    expect(
        DownloadService.relocatePath(
            "/var/mobile/Containers/Data/Application/OLD-ID/Documents/jellyflix/downloads/abc/main.m3u8",
            now),
        "$now/abc/main.m3u8");
    expect(DownloadService.relocatePath("$now/abc/abc.mp4", now),
        "$now/abc/abc.mp4");
    expect(DownloadService.relocatePath("/somewhere/else.mp4", now),
        "/somewhere/else.mp4");
  });

  test('download paths are saved relative and resolved against today\'s folder',
      () {
    const before = "/var/mobile/Containers/Data/Application/OLD/Documents/jellyflix/downloads";
    const after = "/var/mobile/Containers/Data/Application/NEW/Documents/jellyflix/downloads";
    final stored = DownloadService.toStoredPath("$before/abc/main.m3u8", before);
    expect(stored, "abc/main.m3u8");
    expect(DownloadService.resolveStoredPath(stored, after),
        "$after/abc/main.m3u8");
    // absolute paths written by earlier builds still resolve
    expect(DownloadService.resolveStoredPath("$before/abc/sub.vtt", after),
        "$after/abc/sub.vtt");
    // and are converted to relative when saved again
    expect(DownloadService.toStoredPath("$before/abc/sub.vtt", after),
        "abc/sub.vtt");
  });
}
