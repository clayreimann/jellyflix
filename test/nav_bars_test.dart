import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/adaptive.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:jellyflix/screens/search_screen.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(TargetPlatform platform, Widget home) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

class _BarPage extends StatelessWidget {
  const _BarPage();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: adaptiveAppBar(context, title: const Text('Title')),
        body: const SizedBox(),
      );
}

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    final ios = platform == TargetPlatform.iOS;

    testWidgets('app bar on $platform', (tester) async {
      await tester.pumpWidget(_app(platform, const _BarPage()));
      expect(find.byType(CupertinoNavigationBar),
          ios ? findsOneWidget : findsNothing);
      expect(find.byType(AppBar), ios ? findsNothing : findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('search screen on $platform', (tester) async {
      await tester.pumpWidget(_app(platform, const SearchScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoSliverNavigationBar),
          ios ? findsOneWidget : findsNothing);
      expect(find.byType(CupertinoSearchTextField),
          ios ? findsOneWidget : findsNothing);
      expect(find.byType(SearchBar), ios ? findsNothing : findsOneWidget);
    });
  }
}
