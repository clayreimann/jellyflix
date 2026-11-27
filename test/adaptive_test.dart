import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/components/adaptive.dart';

Widget _app(TargetPlatform platform, Widget child) => MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  for (final platform in TargetPlatform.values) {
    final ios = platform == TargetPlatform.iOS;

    testWidgets('isCupertino on $platform', (tester) async {
      late bool result;
      await tester.pumpWidget(_app(platform, Builder(builder: (context) {
        result = isCupertino(context);
        return const SizedBox();
      })));
      // macOS stays Material even though Flutter's .adaptive widgets don't.
      expect(result, ios);
    });

    testWidgets('spinner on $platform', (tester) async {
      await tester
          .pumpWidget(_app(platform, const AdaptiveProgressIndicator()));
      expect(find.byType(CupertinoActivityIndicator),
          ios ? findsOneWidget : findsNothing);
    });

    testWidgets('alert on $platform', (tester) async {
      await tester.pumpWidget(_app(
          platform,
          AdaptiveAlertDialog(
            title: const Text('t'),
            actions: [
              AdaptiveDialogAction(onPressed: () {}, child: const Text('Ok')),
            ],
          )));
      expect(find.byType(CupertinoAlertDialog),
          ios ? findsOneWidget : findsNothing);
      expect(find.byType(CupertinoDialogAction),
          ios ? findsOneWidget : findsNothing);
      expect(find.byType(TextButton), ios ? findsNothing : findsOneWidget);
    });
  }
}
