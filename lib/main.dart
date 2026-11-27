import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:media_kit/media_kit.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:universal_io/io.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:jellyflix/components/adaptive.dart';
import 'package:jellyflix/providers/router_provider.dart';
import 'package:jellyflix/providers/theme_mode_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:jellyflix/providers/scaffold_key.dart';
import 'package:jellyflix/services/database_service.dart';
import 'package:jellyflix/widgets/input_detector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    await FlutterDownloader.initialize(
        debug: kDebugMode ? true : false,
        ignoreSsl:
            true // option: set to false to disable working with http links (default: false)
        );
  }
  await DatabaseService.initialize();

  // await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  // // save to file
  // var fileName = "NotoSans-Regular.ttf";

  // Necessary initialization for package:media_kit.
  MediaKit.ensureInitialized();
  runApp(ProviderScope(
    child: Shortcuts(shortcuts: <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
    }, child: const MyApp()),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.read(routerProvider).router;
    return InputDetector(
      child: MaterialApp.router(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        // localization
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // routing
        routeInformationParser: appRouter.routeInformationParser,
        routerDelegate: appRouter.routerDelegate,
        routeInformationProvider: appRouter.routeInformationProvider,
        debugShowCheckedModeBanner: false,
        // Some dependencies (filter_list, media_kit_video, skeletonizer,
        // cached_network_image...) still use the deprecated
        // package:flutter/material.dart. Without this bridge they would read
        // that library's default light theme instead of ours. Remove once
        // they have migrated to material_ui.
        builder: (context, child) => SkeletonizerConfig(
          // Loading placeholders follow the light/dark theme.
          data: Theme.of(context).brightness == Brightness.dark
              ? const SkeletonizerConfigData.dark()
              : const SkeletonizerConfigData(),
          // ignore: deprecated_member_use
          child: MaterialUiCompatibilityBridge(child: child!),
        ),
        title: "Jellyflix",
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
      ),
    );
  }
}

/// The app theme for [brightness]. Dark keeps the original look (pale green
/// on a deep purple-tinted surface); light uses a darker green so the accent
/// reads on white.
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      primary: dark ? const Color(0xFFDBEBC0) : const Color(0xFF4C662B),
      brightness: brightness);
  return ThemeData(
    // iOS has no ink ripple: taps only highlight.
    splashFactory: isCupertinoPlatform ? NoSplash.splashFactory : null,
    // iOS has no snackbar; show messages as a floating rounded toast
    // above the tab bar instead of a full-width Material bar.
    snackBarTheme: isCupertinoPlatform
        ? SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xF02C2C2E),
            contentTextStyle:
                const TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
            actionTextColor: colorScheme.primary,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          )
        : null,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: colorScheme,
    useMaterial3: true,
    // iOS only: Cupertino widgets (tab bar, nav bars, lists) use the
    // app's accent and bar colours. Android never builds
    // Cupertino widgets, so this has no effect there.
    cupertinoOverrideTheme: isCupertinoPlatform
        ? CupertinoThemeData(
            brightness: brightness,
            primaryColor: colorScheme.primary,
            // The page colour, slightly see-through so the bars blur
            // what scrolls under them.
            barBackgroundColor: colorScheme.surface.withValues(alpha: 0.94),
            scaffoldBackgroundColor: colorScheme.surface,
          )
        : null,
  );
}
