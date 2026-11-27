import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/components/ios_sheets.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

Widget _app(Widget Function(BuildContext) body) => MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => Scaffold(body: body(context))),
    );

void main() {
  test('describeError includes the server status and message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 403,
        statusMessage: 'Forbidden',
        data: {'message': 'User policy forbids this'},
      ),
    );
    expect(describeError(error), '403 Forbidden: User policy forbids this');
  });

  testWidgets('save failure shows an iOS alert with the detail',
      (tester) async {
    await tester.pumpWidget(_app((context) => CupertinoButton(
          onPressed: () => showSaveFailedAlert(context, Exception('boom')),
          child: const Text('go'),
        )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('menu entries become an iOS action sheet', (tester) async {
    String? picked;
    await tester.pumpWidget(_app((context) => AdaptivePopupMenuButton<String>(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'a', child: ListTile(title: Text('Alpha'))),
            PopupMenuItem(value: 'b', child: Text('Beta')),
          ],
          onSelected: (v) => picked = v,
        )));
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.byType(CupertinoButton));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(picked, 'b');
  });

  testWidgets('list picker returns the checked items', (tester) async {
    List<String>? result;
    await tester.pumpWidget(_app((context) => CupertinoButton(
          onPressed: () async => result = await showIosListPicker<String>(
            context: context,
            title: 'Genre',
            items: const ['Comedy', 'Drama'],
            label: (s) => s,
            selected: const ['Drama'],
          ),
          child: const Text('go'),
        )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comedy'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, unorderedEquals(['Drama', 'Comedy']));
  });
}
