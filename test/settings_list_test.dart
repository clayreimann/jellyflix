import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/components/settings_list.dart';
import 'package:jellyflix/components/switch_settings_tile.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(TargetPlatform platform, Widget child) => MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(body: ListView(children: [child])),
    );

Widget _section() => SettingsSection(children: [
      SettingsTile(
        icon: Icons.video_file_outlined,
        title: const Text('Bitrate'),
        value: const Text('8 Mb/s'),
        opensMore: true,
        onTap: () {},
      ),
      SwitchSettingsTile(
        leading: const Icon(Icons.image_outlined),
        title: const Text('Caching'),
        value: true,
        onChanged: (_) {},
      ),
    ]);

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    final ios = platform == TargetPlatform.iOS;
    testWidgets('settings list on $platform', (tester) async {
      await tester.pumpWidget(_app(platform, _section()));
      expect(find.byType(CupertinoListSection),
          ios ? findsOneWidget : findsNothing);
      expect(find.byType(CupertinoListTile),
          ios ? findsNWidgets(2) : findsNothing);
      expect(find.byType(CupertinoListTileChevron),
          ios ? findsOneWidget : findsNothing);
      expect(find.byType(ListTile), ios ? findsNothing : findsNWidgets(2));
      expect(find.text('8 Mb/s'), findsOneWidget);
    });
  }

  testWidgets('iOS choice list returns the picked value', (tester) async {
    int? picked;
    await tester.pumpWidget(_app(
        TargetPlatform.iOS,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showIosChoicePicker<int>(
                context: context,
                title: 'Bitrate',
                options: const {1: 'One', 2: 'Two'},
                selected: 1,
              );
            },
            child: const Text('open'),
          ),
        )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoListTile), findsNWidgets(2));
    // the tick sits at the end of the current row only
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(picked, 2);
  });

  testWidgets('iOS destructive confirm', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(_app(
        TargetPlatform.iOS,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await showIosDestructiveConfirm(
                  context: context,
                  confirmLabel: 'Log out',
                  cancelLabel: 'Cancel');
            },
            child: const Text('open'),
          ),
        )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(confirmed, false);
  });
}
