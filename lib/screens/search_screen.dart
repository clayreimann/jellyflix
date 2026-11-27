import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:jellyflix/components/adaptive.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/future_item_carousel.dart';
import 'package:jellyflix/components/jfx_text_theme.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:tentacle/tentacle.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';

class SearchScreen extends HookConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // What's typed, and the query actually searched: the latter waits
    // until typing pauses, so each keystroke doesn't start a new search.
    final typed = useState<String?>(null);
    final searchQuery = useState<String?>(null);
    useEffect(() {
      if (typed.value == null) {
        searchQuery.value = null;
        return null;
      }
      final timer = Timer(const Duration(milliseconds: 300),
          () => searchQuery.value = typed.value);
      return timer.cancel;
    }, [typed.value]);

    // One request per kind per query. Building the futures inline started a
    // fresh search on every rebuild, which flashed the placeholders again.
    final futures = useMemoized(
      () => {
        for (final kind in [
          BaseItemKind.movie,
          BaseItemKind.series,
          BaseItemKind.episode,
          BaseItemKind.boxSet,
        ])
          // Before the first query lands, a future that never completes
          // keeps the placeholders up. Later queries keep showing the
          // previous results until the new ones arrive.
          kind: searchQuery.value == null
              ? Completer<List<BaseItemDto>>().future
              : ref.read(apiProvider).getFilterItems(
                  searchTerm: searchQuery.value,
                  includeItemTypes: [kind],
                ),
      },
      [searchQuery.value],
    );

    final l10n = AppLocalizations.of(context)!;
    final searchField = AdaptiveSearchField(
      hintText: l10n.search,
      onChanged: (value) {
        typed.value = value != "" ? value : null;
      },
    );
    final emptyHint = Center(
        child: Text(l10n.startTypingSearch,
            style: JfxTextTheme.scalingTheme(context).titleMedium));
    final Widget results = Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureItemCarousel(
          title: AppLocalizations.of(context)!.movies,
          titleMapping: (e) => e.name!,
          imageMapping: (e) => e.id!,
          blurHashMapping: (e) => e.imageBlurHashes?.primary?.values.first,
          future: futures[BaseItemKind.movie]!,
          onTap: (p0, p1) {
            context.pushNamed(ScreenPaths.search + ScreenPaths.detail,
                queryParameters: {
                  "id": p1,
                });
          },
        ),
        FutureItemCarousel(
            title: AppLocalizations.of(context)!.series,
            titleMapping: (e) => e.name!,
            imageMapping: (e) => e.id!,
            blurHashMapping: (e) => e.imageBlurHashes?.primary?.values.first,
            future: futures[BaseItemKind.series]!,
            onTap: (p0, p1) {
              context.pushNamed(ScreenPaths.search + ScreenPaths.detail,
                  queryParameters: {
                    "id": p1,
                  });
            }),
        FutureItemCarousel(
            title: AppLocalizations.of(context)!.episodes,
            titleMapping: (e) => e.name!,
            imageMapping: (e) => e.id!,
            blurHashMapping: (e) => e.imageBlurHashes?.primary?.values.first,
            future: futures[BaseItemKind.episode]!,
            onTap: (p0, p1) {
              context.pushNamed(ScreenPaths.search + ScreenPaths.detail,
                  queryParameters: {
                    "id": p1,
                  });
            }),
        FutureItemCarousel(
          title: AppLocalizations.of(context)!.collections,
          titleMapping: (e) => e.name!,
          imageMapping: (e) => e.id!,
          blurHashMapping: (e) => e.imageBlurHashes?.primary?.values.first,
          future: futures[BaseItemKind.boxSet]!,
          onTap: (p0, p1) {
            context.pushNamed(ScreenPaths.search + ScreenPaths.detail,
                queryParameters: {
                  "id": p1,
                });
          },
        ),
        // FutureItemCarousel(
        //     title: AppLocalizations.of(context)!.play,
        //     titleMapping: (e) => e.name!,
        //     imageMapping: (e) => e.id!,
        //     blurHashMapping: (e) =>
        //         e.imageBlurHashes?.primary?.values.first,
        //     future: ref.read(apiProvider).getFilterItems(
        //         searchTerm: searchQuery.value,
        //         includeItemTypes: [BaseItemKind.playlist])),
      ],
    );

    if (isCupertino(context)) {
      // iOS: a large "Search" title that shrinks into the nav bar as the
      // results scroll, with the search field under it.
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(l10n.search),
              border: null,
              transitionBetweenRoutes: false,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              sliver: SliverToBoxAdapter(child: searchField),
            ),
            if ((typed.value ?? "").isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: emptyHint)
            else
              SliverToBoxAdapter(child: results),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchField,
              const SizedBox(
                height: 20,
              ),
              Expanded(
                child: (typed.value ?? "").isEmpty
                    ? emptyHint
                    : SingleChildScrollView(child: results),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
