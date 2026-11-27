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
    final searchQuery = useState<String?>(null);

    final l10n = AppLocalizations.of(context)!;
    final searchField = AdaptiveSearchField(
      hintText: l10n.search,
      onChanged: (value) {
        searchQuery.value = value != "" ? value : null;
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
          future: ref.read(apiProvider).getFilterItems(
            searchTerm: searchQuery.value,
            includeItemTypes: [BaseItemKind.movie],
          ),
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
            future: ref.read(apiProvider).getFilterItems(
              searchTerm: searchQuery.value,
              includeItemTypes: [BaseItemKind.series],
            ),
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
            future: ref.read(apiProvider).getFilterItems(
              searchTerm: searchQuery.value,
              includeItemTypes: [BaseItemKind.episode],
            ),
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
          future: ref.read(apiProvider).getFilterItems(
            searchTerm: searchQuery.value,
            includeItemTypes: [
              BaseItemKind.boxSet,
            ],
          ),
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
            if ((searchQuery.value ?? "").isEmpty)
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
                child: (searchQuery.value ?? "").isEmpty
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
