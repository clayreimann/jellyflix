import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/components/download_controls.dart';
import 'package:jellyflix/components/media_row.dart';
import 'package:jellyflix/services/download_service.dart';

void main() {
  testWidgets('menu button is vertically centered on the row',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          MediaRow(
            image: Container(color: Colors.red),
            title: "1. Keepy Uppy",
            details: "7 min · ✓ Downloaded",
            overview: "A long description " * 20,
            trailing: const Icon(Icons.download_done_rounded),
            menuEntries: const [
              PopupMenuItem(value: "a", child: Text("A")),
            ],
          ),
        ]),
      ),
    ));
    final row = tester.getRect(find.byType(MediaRow));
    final menu = tester.getRect(find.byIcon(Icons.more_vert));
    final trailing = tester.getRect(find.byIcon(Icons.download_done_rounded));
    expect((menu.center.dy - row.center.dy).abs(), lessThan(1.0));
    expect((trailing.center.dy - row.center.dy).abs(), lessThan(1.0));
  });

  test('completed downloads offer Remove, never Cancel', () {
    expect(downloadActionFor(DownloadState(DownloadStatus.complete, 100)),
        DownloadAction.remove);
    expect(downloadActionFor(DownloadState(DownloadStatus.downloading, 40)),
        DownloadAction.cancel);
    expect(downloadActionFor(DownloadState(DownloadStatus.failed, 40)),
        DownloadAction.resume);
    expect(downloadActionFor(DownloadState(DownloadStatus.notDownloaded, null)),
        DownloadAction.download);
    expect(downloadActionFor(null), DownloadAction.download);
  });
}
