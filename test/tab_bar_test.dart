import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/responsive_navigation_bar.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:jellyflix/models/auth_state.dart';
import 'package:jellyflix/providers/auth_provider.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(TargetPlatform platform) {
  final router = GoRouter(initialLocation: '/0', routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          ResponsiveNavigationBar(navigationShell: shell),
      branches: [
        for (var i = 0; i < 5; i++)
          StatefulShellBranch(routes: [
            GoRoute(path: '/$i', builder: (_, __) => Text('tab $i')),
          ]),
      ],
    ),
  ]);
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => AuthState.loggedIn),
    ],
    child: MaterialApp.router(
      theme: ThemeData(platform: platform),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('iPhone gets the iOS tab bar', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(TargetPlatform.iOS));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(tester.getSize(find.byType(CupertinoTabBar)).height, 50.0 + 0);

    await tester.tap(find.byIcon(CupertinoIcons.search));
    await tester.pumpAndSettle();
    expect(find.text('tab 1'), findsOneWidget);
    // Same glyph when not selected; only the tint changes.
    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
  });

  testWidgets('iPhone in landscape keeps the iOS tab bar', (tester) async {
    tester.view.physicalSize = const Size(844 * 3, 390 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(TargetPlatform.iOS));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    testWidgets('$platform phone keeps the Material bar', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(platform));
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(CupertinoTabBar), findsNothing);
    });
  }
}
