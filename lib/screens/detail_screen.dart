import 'package:cupertino_ui/cupertino_ui.dart';
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
    // iOS: the bar turns solid and shows the title only once the header
    // (poster and name) has scrolled up under it, like the TV and Music
    // apps, rather than at the first pixel.
    final barThreshold = ios ? featuredPosterHeight * 0.75 : 0.0;

    // Load once per item. Building the future inline refetched the item
    // (and its episodes) on every rebuild, including each time the bar
    // changed while scrolling.
    final details = useMemoized(() => _loadDetails(ref), [itemId]);
    final title = useFuture(details).data?.name;

    useEffect(() {
      listener() {
        appBarColorTransaparent.value =
            scrollController.position.pixels <= barThreshold;
      }

      scrollController.addListener(listener);
      return () {
        return scrollController.removeListener(listener);
      };
    }, [scrollController]);

    useEffect(() {
      ref.read(apiProvider).getWatchlist().then((value) {
        onWatchlist.value =
            value.where((element) => element.id == itemId).isNotEmpty;
      }).ignore();
      return null;
    }, [itemId]);

    // iOS: room for the nav bar above the poster, so the back button
    // doesn't sit on top of it.
    final headerTop = MediaQuery.of(context).padding.top +
        (ios ? kMinInteractiveDimensionCupertino : 0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ios
          ? _iosBar(context,
              transparent: appBarColorTransaparent.value, title: title)
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
                        height: featuredPosterHeight + headerTop,
                        child: Stack(
                          children: [
                            Stack(
                              children: [
                                JellyfinImage(
                                    borderRadius: BorderRadius.zero,
                                    id: data.type == BaseItemKind.episode
                                        ? data.seriesId!
                                        : itemId,
                                    type: ImageType.backdrop,
                                    blurHash: data
                                        .imageBlurHashes?.backdrop?[itemId]),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        const Color.fromARGB(100, 0, 0, 0),
                                        Theme.of(context).colorScheme.surface
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment
                                        .end, // Align text to the bottom
                                    children: [
                                      Text(
                                        data.name ?? "",
                                        style:
                                            layout.text.headlineSmall!.copyWith(
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
                                                    BorderRadius.circular(10.0),
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
                                                    const SizedBox(width: 4.0),
                                                    Text(
                                                      (data.communityRating ==
                                                              null)
                                                          ? AppLocalizations.of(
                                                                  context)!
                                                              .na
                                                          : data
                                                              .communityRating!
                                                              .roundToDouble()
                                                              .toString(),
                                                      style:
                                                          layout.text.bodySmall,
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
                                                    const SizedBox(width: 4.0),
                                                    Text(
                                                      data.criticRating!
                                                          .round()
                                                          .toString(),
                                                      style:
                                                          layout.text.bodySmall,
                                                    ),
                                                  ],
                                                ),
                                        ],
                                      ),
                                    ],
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

  /// iOS bar. Over the artwork: no background, and a round dimmed back
  /// button that reads on any picture. Scrolled: the system bar material
  /// with the item's name, and the standard tinted back chevron.
  PreferredSizeWidget _iosBar(BuildContext context,
      {required bool transparent, String? title}) {
    return CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      automaticBackgroundVisibility: false,
      backgroundColor: transparent ? const Color(0x00000000) : null,
      border: transparent
          ? null
          : const Border(
              bottom: BorderSide(color: Color(0x4D000000), width: 0.0)),
      leading: transparent
          ? Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                onPressed: () => Navigator.maybePop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.chevron_left,
                      color: Color(0xFFFFFFFF), size: 18),
                ),
              ),
            )
          : null,
      middle: AnimatedOpacity(
        opacity: transparent || title == null ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        child: Text(title ?? '', overflow: TextOverflow.ellipsis),
      ),
    );
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
