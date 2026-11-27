import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:jellyflix/components/adaptive.dart';
import 'dart:async';
import 'dart:ui';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:jellyflix/providers/player_helper_provider.dart';
import 'package:tentacle/tentacle.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:jellyflix/components/jellyfin_image.dart';
import 'package:jellyflix/components/jfx_layout.dart';
import 'package:jellyflix/components/jfx_tile.dart';
import 'package:jellyflix/components/jfx_button_row.dart';
import 'package:jellyflix/components/item_carousel.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/models/skeleton_item.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/providers/offline_provider.dart';
import 'package:jellyflix/components/description_text.dart';
import 'package:jellyflix/components/episode_list.dart';
import 'package:jellyflix/components/item_information_details.dart';
import 'package:jellyflix/components/future_item_carousel.dart';

class DetailScreen extends HookConsumerWidget {
  final String itemId;
  final String parentPath;

  const DetailScreen(
      {super.key, required this.itemId, required this.parentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ValueNotifier<bool> onWatchlist = useState(false);
    final ValueNotifier<bool> markedAsPlayed = useState(false);
    final StreamController<List<BaseItemDto>> episodeStreamController =
        useStreamController();
    final playButtonHovered = useState(false);

    final scrollController = useScrollController();
    final appBarColorTransaparent = useState(true);
    final ios = isCupertino(context);

    final layout = JfxLayout.scalingLayout(context);
    final featuredPosterHeight = layout.tileHeight * 1.3;

    // iOS: room for the nav bar above the poster, plus a little air, so
    // the poster sits fully below the bar. The artwork and its gradient
    // still run up behind the bar to the top of the screen.
    final barBottom =
        MediaQuery.of(context).padding.top + kMinInteractiveDimensionCupertino;
    final headerTop = ios ? barBottom + 12 : MediaQuery.of(context).padding.top;
    final headerHeight = featuredPosterHeight + headerTop;

    // iOS: how far the bar has turned solid, 0 to 1. It fades in over the
    // last stretch of the header, when what's under the bar is almost all
    // page colour, instead of switching at once over the artwork.
    final barFadeEnd = headerHeight - barBottom;
    final barFadeStart = barFadeEnd - 56;
    final barProgress = useValueNotifier(0.0);

    // Load once per item. Building the future inline refetched the item
    // (and its episodes) on every rebuild, including each time the bar
    // changed while scrolling.
    final details = useMemoized(() => _loadDetails(ref), [itemId]);
    final loaded = useFuture(details).data;
    final title = loaded?.name;
    final backdropHash =
        loaded?.imageBlurHashes?.backdrop?.values.firstOrNull ??
            loaded?.imageBlurHashes?.primary?.values.firstOrNull;
    final edgeColor = useFuture(
      useMemoized(() => _topEdgeColor(backdropHash), [backdropHash]),
    ).data;

    useEffect(() {
      listener() {
        final pixels = scrollController.position.pixels;
        if (ios) {
          barProgress.value =
              ((pixels - barFadeStart) / (barFadeEnd - barFadeStart))
                  .clamp(0.0, 1.0);
        } else {
          appBarColorTransaparent.value = pixels <= 0;
        }
      }

      scrollController.addListener(listener);
      return () {
        return scrollController.removeListener(listener);
      };
    }, [scrollController, barFadeStart, barFadeEnd]);

    useEffect(() {
      ref.read(apiProvider).getWatchlist().then((value) {
        onWatchlist.value =
            value.where((element) => element.id == itemId).isNotEmpty;
      }).ignore();
      return null;
    }, [itemId]);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ios
          ? PreferredSize(
              preferredSize:
                  const Size.fromHeight(kMinInteractiveDimensionCupertino),
              // Rebuilds only the bar on scroll, not the page.
              child: ValueListenableBuilder<double>(
                valueListenable: barProgress,
                builder: (context, progress, _) => _iosBar(context,
                    progress: progress, title: title, edgeColor: edgeColor),
              ),
            )
          : appBarColorTransaparent.value
              ? AppBar(
                  backgroundColor: Colors.transparent,
                )
              : PreferredSize(
                  preferredSize: const Size(
                    double.infinity,
                    56.0,
                  ),
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: AppBar(
                        elevation: 0.0,
                        backgroundColor: Colors.black.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
      body: FutureBuilder(
          future: details,
          builder: (context, AsyncSnapshot<BaseItemDto> snapshot) {
            BaseItemDto data = SkeletonItem.baseItemDto;
            if (snapshot.hasError) {
              return Center(
                child: Text(
                    AppLocalizations.of(context)!.quickConnectErrorUnknown),
              );
            } else if (snapshot.hasData) {
              data = snapshot.data!;
              if (data.type == BaseItemKind.series) {
                ref.read(apiProvider).getEpisodes(itemId).then((value) {
                  episodeStreamController.add(value);
                }).catchError((e) async {
                  // offline without cached metadata: list downloaded episodes
                  final library =
                      await ref.read(downloadLibraryProvider.future);
                  final episodes = library.show(itemId)?.episodes ?? [];
                  if (!episodeStreamController.isClosed) {
                    episodeStreamController
                        .add(episodes.map(baseItemFromDownload).toList());
                  }
                });
              }
              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  controller: scrollController,
                  // Clear of the floating tab bar at the end.
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: headerHeight,
                        child: Stack(
                          // iOS: the artwork stretches above the header on
                          // a pull-down.
                          clipBehavior: Clip.none,
                          children: [
                            if (ios)
                              Positioned.fill(
                                child: _StretchyBackdrop(
                                  scrollController: scrollController,
                                  barBottom: barBottom,
                                  edgeColor: edgeColor ??
                                      Theme.of(context).colorScheme.surface,
                                  image: JellyfinImage(
                                      borderRadius: BorderRadius.zero,
                                      id: data.type == BaseItemKind.episode
                                          ? data.seriesId!
                                          : itemId,
                                      type: ImageType.backdrop,
                                      blurHash: data
                                          .imageBlurHashes?.backdrop?[itemId]),
                                ),
                              )
                            else
                              Positioned.fill(
                                child: Stack(
                                  children: [
                                    JellyfinImage(
                                        borderRadius: BorderRadius.zero,
                                        id: data.type == BaseItemKind.episode
                                            ? data.seriesId!
                                            : itemId,
                                        type: ImageType.backdrop,
                                        blurHash: data.imageBlurHashes
                                            ?.backdrop?[itemId]),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color.fromARGB(100, 0, 0, 0),
                                            Theme.of(context)
                                                .colorScheme
                                                .surface
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: headerTop),
                                      SizedBox(
                                          height: featuredPosterHeight,
                                          child: JfxTile(
                                            id: itemId,
                                            blurHash: data.imageBlurHashes
                                                ?.primary?[itemId],
                                            onTap: () => {},
                                          )),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  // iOS: a soft page-coloured halo behind
                                  // the title and details, so they read
                                  // on any artwork.
                                  child: DefaultTextStyle.merge(
                                    style: ios
                                        ? TextStyle(shadows: [
                                            for (final r in const [4.0, 12.0])
                                              Shadow(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surface,
                                                blurRadius: r,
                                              ),
                                          ])
                                        : null,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment
                                          .end, // Align text to the bottom
                                      children: [
                                        Text(
                                          data.name ?? "",
                                          style: layout.text.headlineSmall!
                                              .copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8.0),
                                        Row(
                                          children: [
                                            Text(
                                                data.premiereDate?.year == null
                                                    ? AppLocalizations.of(
                                                            context)!
                                                        .na
                                                    : data.premiereDate!.year
                                                        .toString(),
                                                style: layout.text.bodyLarge),
                                            const SizedBox(width: 16.0),
                                            Container(
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10.0),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                    width: 0.7,
                                                  )),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(3.0),
                                                child: Text(
                                                  data.officialRating ??
                                                      AppLocalizations.of(
                                                              context)!
                                                          .na,
                                                  style: layout.text.bodySmall,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4.0),
                                        Row(
                                          children: [
                                            data.communityRating == null
                                                ? const SizedBox()
                                                : Row(
                                                    children: [
                                                      const Text(
                                                        "⭐",
                                                        style: TextStyle(
                                                            fontSize: 20),
                                                      ),
                                                      const SizedBox(
                                                          width: 4.0),
                                                      Text(
                                                        (data.communityRating ==
                                                                null)
                                                            ? AppLocalizations
                                                                    .of(
                                                                        context)!
                                                                .na
                                                            : data
                                                                .communityRating!
                                                                .roundToDouble()
                                                                .toString(),
                                                        style: layout
                                                            .text.bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                            const SizedBox(width: 16.0),
                                            data.criticRating == null
                                                ? const SizedBox()
                                                : Row(
                                                    children: [
                                                      const Text(
                                                        "🍅",
                                                        style: TextStyle(
                                                            fontSize: 20),
                                                      ),
                                                      const SizedBox(
                                                          width: 4.0),
                                                      Text(
                                                        data.criticRating!
                                                            .round()
                                                            .toString(),
                                                        style: layout
                                                            .text.bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                            left: 10.0, right: 10, top: 25.0),
                        child: JfxButtonRow(
                          context: context,
                          ref: ref,
                          data: data,
                          itemId: itemId,
                          addtlVersionsHovered: playButtonHovered,
                          playButtonHovered: playButtonHovered,
                          onWatchlist: onWatchlist,
                          markedAsPlayed: markedAsPlayed,
                          streamController: episodeStreamController,
                          goToPlayerScreen: goToPlayerScreen,
                          goToOfflinePlayer: goToOfflinePlayer,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 15.0),
                        child: DescriptionText(
                          text:
                              data.overview ?? AppLocalizations.of(context)!.na,
                        ),
                      ),

                      data.isFolder ?? false
                          ? EpisodeList(
                              parentPath: parentPath,
                              episodeStreamController: episodeStreamController,
                              data: data,
                              markedAsPlayed: markedAsPlayed,
                              itemId: itemId)
                          : const SizedBox(),
                      data.people != null && data.people!.isNotEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15.0),
                              child: ItemCarousel(
                                title: AppLocalizations.of(context)!.cast,
                                titleList:
                                    data.people!.map((e) => e.name!).toList(),
                                imageList:
                                    data.people!.map((e) => e.id!).toList(),
                                subtitleList: data.people!
                                    .map((e) =>
                                        e.role ??
                                        AppLocalizations.of(context)!.na)
                                    .toList(),
                                onTap: (index) {
                                  context.pushNamed(
                                      parentPath + ScreenPaths.detail,
                                      queryParameters: {
                                        "id": data.people![index].id!,
                                      });
                                },
                              ),
                            )
                          : const SizedBox(),
                      FutureItemCarousel(
                        future: ref.read(apiProvider).similarItems(itemId),
                        title: AppLocalizations.of(context)!.similar,
                        titleMapping: (e) => e.name!,
                        imageMapping: (e) => e.id!,
                        subtitleMapping: (e) => e.productionYear.toString(),
                        blurHashMapping: (e) =>
                            e.imageBlurHashes?.primary?[e.id!],
                        onTap: (index, id) {
                          context.pushNamed(parentPath + ScreenPaths.detail,
                              queryParameters: {
                                "id": id,
                              });
                        },
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 10),
                        child: Text(AppLocalizations.of(context)!.details,
                            style: layout.text.headlineSmall),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: ItemInformationDetails(item: data),
                      ),
                      // urls for review sites
                      if (data.externalUrls != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: SizedBox(
                            height: layout.text.bodyLarge!.height! * 20,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: data.externalUrls!.length,
                              itemBuilder: (context, index) {
                                return InkWell(
                                  onTap: () async {
                                    await launchUrl(Uri.parse(
                                        data.externalUrls![index].url!));
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 5.0),
                                    child: Text(
                                      data.externalUrls![index].name!,
                                      style: layout.text.bodyLarge!.copyWith(
                                          decoration: TextDecoration.underline),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      const SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return const Center(
                child: AdaptiveProgressIndicator(),
              );
            }
          }),
    );
  }

  /// iOS bar, faded by [progress]. At 0, over the artwork: no
  /// background, and a round dimmed back button that reads on any picture.
  /// At 1: the system bar material and hairline, the item's name, and a
  /// plain tinted chevron. In between, everything crossfades.
  Widget _iosBar(BuildContext context,
      {required double progress, String? title, Color? edgeColor}) {
    final chrome = CupertinoDynamicColor.resolve(iosChromeColor, context);
    final tint = CupertinoTheme.of(context).primaryColor;
    return CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      // Status bar text that reads on the artwork's colour, then on the
      // bar once it's solid.
      brightness: progress < 0.5 && edgeColor != null
          ? (edgeColor.computeLuminance() > 0.5
              ? Brightness.light
              : Brightness.dark)
          : null,
      automaticBackgroundVisibility: false,
      backgroundColor: chrome.withValues(alpha: chrome.a * progress),
      border: Border(
          bottom: BorderSide(
              color: const Color(0x4D000000).withValues(alpha: 0.3 * progress),
              width: 0.0)),
      // Not wrapped in an Align: that stretched the leading slot across
      // the bar and squeezed the title to nothing.
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(32, 32),
        onPressed: () => Navigator.maybePop(context),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                const Color(0xFF000000).withValues(alpha: 0.4 * (1 - progress)),
            shape: BoxShape.circle,
          ),
          child: Icon(CupertinoIcons.chevron_left,
              color: Color.lerp(const Color(0xFFFFFFFF), tint, progress),
              size: 18 + 4 * progress),
        ),
      ),
      middle: Opacity(
        opacity: title == null ? 0 : progress,
        child: Text(title ?? '', overflow: TextOverflow.ellipsis),
      ),
    );
  }

  /// The average colour along the top edge of an image, from its blur
  /// hash, to extend the artwork up behind the nav bar.
  static Future<Color?> _topEdgeColor(String? blurHash) async {
    if (blurHash == null) return null;
    try {
      const w = 16;
      final pixels =
          await blurHashDecode(blurHash: blurHash, width: w, height: 8);
      var r = 0, g = 0, b = 0;
      for (var x = 0; x < w; x++) {
        r += pixels[x * 4];
        g += pixels[x * 4 + 1];
        b += pixels[x * 4 + 2];
      }
      return Color.fromARGB(255, r ~/ w, g ~/ w, b ~/ w);
    } catch (_) {
      return null;
    }
  }

  /// Item details, falling back to what's known from downloads when the
  /// server is unreachable and the item isn't in the offline cache.
  Future<BaseItemDto> _loadDetails(WidgetRef ref) async {
    try {
      return await ref.read(apiProvider).getItemDetails(itemId);
    } catch (e) {
      final library = await ref.read(downloadLibraryProvider.future);
      final show = library.show(itemId);
      if (show != null) {
        return BaseItemDto((b) => b
          ..id = itemId
          ..name = show.seriesName
          ..type = BaseItemKind.series
          ..isFolder = true
          ..userData.played = false
          ..userData.playbackPositionTicks = 0);
      }
      final download = [
        ...library.movies,
        for (var s in library.shows) ...s.episodes
      ].where((m) => m.id == itemId).firstOrNull;
      if (download != null) return baseItemFromDownload(download);
      rethrow;
    }
  }

  Future<void> goToOfflinePlayer(
      WidgetRef ref, String itemId, BuildContext context, String title) async {
    var playerHelper =
        await ref.read(offlinePlayerHelperProvider(itemId).future);
    if (context.mounted) {
      context.pushNamed(parentPath + ScreenPaths.player,
          queryParameters: {"startTimeTicks": "0", "title": title},
          extra: playerHelper);
    }
  }

  Future<void> goToPlayerScreen(WidgetRef ref, String itemId,
      int playbackStartTicks, BuildContext context, String title) async {
    var playerHelper =
        await ref.read(streamPlayerHelperProvider(itemId).future);
    if (context.mounted) {
      context.pushNamed(parentPath + ScreenPaths.player,
          queryParameters: {
            "startTimeTicks": playbackStartTicks.toString(),
            "title": title
          },
          extra: playerHelper);
    }
  }
}

/// iOS detail header artwork, the Apple TV way: the image runs up behind
/// the nav bar, fading at the very top into its own edge colour, and on a
/// pull-down it stays pinned to the top of the screen and grows, with that
/// colour continuing above it, so no blank page shows through. Its bottom
/// fades into the page.
class _StretchyBackdrop extends StatelessWidget {
  final ScrollController scrollController;
  final double barBottom;
  final Color edgeColor;
  final Widget image;

  const _StretchyBackdrop({
    required this.scrollController,
    required this.barBottom,
    required this.edgeColor,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      return AnimatedBuilder(
        animation: scrollController,
        builder: (context, _) {
          final offset =
              scrollController.hasClients ? scrollController.offset : 0.0;
          final stretch = offset < 0 ? -offset : 0.0;
          final total = height + stretch;
          // The fade at the top covers the status and nav bar area.
          final topFade =
              ((barBottom * 0.85 + stretch) / total).clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Edge colour well above the header, for big pulls.
              Positioned(
                top: -stretch - 2000,
                left: 0,
                right: 0,
                height: 2000.5,
                child: ColoredBox(color: edgeColor),
              ),
              Positioned(
                top: -stretch,
                left: 0,
                right: 0,
                height: total,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, topFade],
                          colors: [edgeColor, edgeColor.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.5, 1.0],
                          colors: [surface.withValues(alpha: 0), surface],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    });
  }
}
