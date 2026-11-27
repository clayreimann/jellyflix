import 'dart:ui';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:jellyflix/components/adaptive.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/jfx_filter_list_dialog.dart';
import 'package:jellyflix/components/jfx_layout.dart';
import 'package:jellyflix/components/jfx_tile.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/models/skeleton_item.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/components/filter_button.dart';
import 'package:jellyflix/components/offline_dimmed.dart';
import 'package:jellyflix/providers/offline_provider.dart';
import 'package:tentacle/tentacle.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';

class LibraryScreen extends HookConsumerWidget {
  final String? genreFilterParam;
  final String? filterTypeParam;
  final String? sortTypeParam;
  final String? sortOrderParam;
  final String? pageNumberParam;
  final String? libraryParam;
  const LibraryScreen(
      {super.key,
      this.genreFilterParam,
      this.filterTypeParam,
      this.sortTypeParam,
      this.sortOrderParam,
      this.pageNumberParam,
      this.libraryParam});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genreFilter = useState<List<BaseItemDto>?>(genreFilterParam == ""
        ? null
        : genreFilterParam?.split(",").map((e) {
            return BaseItemDto(
              (p0) {
                p0.id = e;
              },
            );
          }).toList());
    final order = useState<String>(
        sortOrderParam ?? AppLocalizations.of(context)!.ascending);
    final filterType = useState<List<ItemFilter>>(
        filterTypeParam == null || filterTypeParam == ""
            ? []
            : filterTypeParam!.split(",").map((e) {
                return ItemFilter.values.firstWhere((element) =>
                    element.toString().split(".").last.toLowerCase() ==
                    e.toLowerCase());
              }).toList());
    final sortType = useState<ItemSortBy>(sortTypeParam == null
        ? ItemSortBy.sortName
        : ItemSortBy.values
            .where((element) =>
                element.toString().split(".").last.toLowerCase() ==
                sortTypeParam?.toLowerCase())
            .first);
    final sortOrder = useState<SortOrder>(sortOrderParam == null
        ? SortOrder.ascending
        : SortOrder.values.firstWhere((element) =>
            element.toString().split(".").last.toLowerCase() ==
            sortOrderParam!.toLowerCase()));
    final allLibraries = useState<List<BaseItemDto>?>(null);
    final selectedLibrary = useState<BaseItemDto?>(null);
    int page = int.parse(pageNumberParam ?? "0");

    final layout = JfxLayout.scalingLayout(context);

    useEffect(() {
      ref.read(apiProvider).getMediaFolders().then((value) {
        if (value.isNotEmpty) {
          allLibraries.value = value;
          if (libraryParam != null) {
            var libraryIds = libraryParam!.split(",").map((e) {
              return e;
            }).toList();
            selectedLibrary.value =
                value.firstWhere((element) => libraryIds.contains(element.id));
          }
        }
      });
      return null;
    }, []);

    final Widget filterRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!((genreFilter.value == null || genreFilter.value!.isEmpty) &&
              filterType.value.isEmpty &&
              sortOrder.value == SortOrder.ascending &&
              sortType.value == ItemSortBy.sortName &&
              selectedLibrary.value == null))
            TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => Theme.of(context).secondaryHeaderColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.filter_list),
                    Icon(Icons.close_outlined),
                  ],
                ),
                onPressed: () {
                  genreFilter.value = null;
                  filterType.value.isEmpty;
                  sortType.value = ItemSortBy.sortName;
                  sortOrder.value = SortOrder.ascending;
                  order.value = AppLocalizations.of(context)!.ascending;
                  selectedLibrary.value = null;
                  filterType.value = [];
                }),
          if (!((genreFilter.value == null || genreFilter.value!.isEmpty) &&
              filterType.value.isEmpty &&
              sortOrder.value == SortOrder.ascending &&
              sortType.value == ItemSortBy.sortName &&
              selectedLibrary.value == null))
            const SizedBox(
              width: 10,
            ),
          FilterButton(
            text:
                "${AppLocalizations.of(context)!.library}: ${selectedLibrary.value == null ? AppLocalizations.of(context)!.all : selectedLibrary.value!.name}",
            length: 1,
            onPressed: () async {
              await JfxFilterListDialog.show<BaseItemDto>(
                context,
                title: AppLocalizations.of(context)!.library,
                enableOnlySingleSelection: true,
                listData: allLibraries.value!,
                selectedListData: selectedLibrary.value == null
                    ? List<BaseItemDto>.empty()
                    : [selectedLibrary.value!],
                onApplyButtonClick: (list) {
                  if (list != null && list.isNotEmpty) {
                    selectedLibrary.value = list.first;
                  } else {
                    selectedLibrary.value = null;
                  }
                  context.pop();
                },
              );
            },
          ),
          const SizedBox(
            width: 10,
          ),
          FilterButton(
            text:
                "${AppLocalizations.of(context)!.genre}: ${genreFilter.value == null || genreFilter.value!.map((e) => e.name).isEmpty ? AppLocalizations.of(context)!.all : genreFilter.value!.length <= 1 ? genreFilter.value!.map((e) => e.name).join() : ""}",
            length: genreFilter.value?.length ?? 0,
            onPressed: () async {
              final listData = await ref.read(apiProvider).getGenres(
                  includeItemTypes: [
                    BaseItemKind.movie,
                    BaseItemKind.series,
                    BaseItemKind.boxSet
                  ]);
              if (!context.mounted) return;
              await JfxFilterListDialog.show<BaseItemDto>(context,
                  title: AppLocalizations.of(context)!.genre,
                  listData: listData,
                  selectedListData: genreFilter.value ?? [],
                  onApplyButtonClick: (list) {
                genreFilter.value = list;
                context.pop(list);
              });
            },
          ),
          const SizedBox(
            width: 10,
          ),
          FilterButton(
            text:
                "${AppLocalizations.of(context)!.filter}: ${filterType.value.map((e) => e.toString().split(".").last).isEmpty ? AppLocalizations.of(context)!.none : filterType.value.map((e) => e.toString().split(".")).length <= 1 ? filterType.value.map((e) => e.toString().split(".").last).join() : ""}",
            length: filterType.value.map((e) => e.toString().split(".")).length,
            onPressed: () async {
              await JfxFilterListDialog.show<ItemFilter>(context,
                  title: AppLocalizations.of(context)!.filter,
                  selectedListData: filterType.value,
                  listData: ItemFilter.values.where((e) {
                    return e != ItemFilter.isFolder &&
                        e != ItemFilter.isNotFolder;
                  }).toList(), onApplyButtonClick: (list) {
                filterType.value = list ?? [];
                context.pop();
              });
            },
          ),
          const SizedBox(
            width: 10,
          ),
          FilterButton(
            text:
                "${AppLocalizations.of(context)!.sort}: ${localizeSortType(context, sortType.value)}",
            length: 1,
            opensList: false,
            onPressed: () {
              if (sortType.value == ItemSortBy.sortName) {
                sortType.value = ItemSortBy.premiereDate;
              } else if (sortType.value == ItemSortBy.premiereDate) {
                sortType.value = ItemSortBy.random;
              } else if (sortType.value == ItemSortBy.random) {
                sortType.value = ItemSortBy.sortName;
              }
            },
          ),
          const SizedBox(
            width: 10,
          ),
          FilterButton(
            text: order.value,
            length: 1,
            opensList: false,
            onPressed: () {
              if (sortOrder.value == SortOrder.ascending) {
                sortOrder.value = SortOrder.descending;
                order.value = AppLocalizations.of(context)!.descending;
              } else {
                sortOrder.value = SortOrder.ascending;
                order.value = AppLocalizations.of(context)!.ascending;
              }
            },
          ),
        ],
      ),
    );

    final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: layout.tileWidth + (layout.tilePadding),
        mainAxisExtent:
            layout.tileHeight + (layout.text.headlineMedium!.fontSize! * 2),
        crossAxisSpacing: layout.tilePadding,
        mainAxisSpacing: layout.tilePadding);

    Widget tileBuilder(BuildContext context, BaseItemDto item) {
      return OfflineDimmed(
        item: item,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            JfxTile(
                id: item.id!,
                onTap: () {
                  context.pushNamed(ScreenPaths.library + ScreenPaths.detail,
                      queryParameters: {
                        "id": item.id!,
                      });
                },
                blurHash: item.imageBlurHashes?.primary?.values.first),
            const SizedBox(height: 5.0),
            Flexible(
              child: Text(
                item.name!,
                style: layout.text.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                item.productionYear?.toString() ?? '',
                style: layout.text.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    void goToPage(int target) {
      context.pushNamed(ScreenPaths.library + ScreenPaths.library,
          queryParameters: {
            "genreFilter": genreFilter.value?.map((e) => e.id).join(","),
            "filterType": filterType.value
                .map((e) => e.toString().split(".").last)
                .join(","),
            "sortType": sortType.value.toString().split(".").last,
            "sortOrder": sortOrder.value.toString().split(".").last,
            "library": selectedLibrary.value,
            "pageNumber": target.toString(),
          });
    }

    final itemsFuture = ref.read(apiProvider).getFilterItems(
        parentId: selectedLibrary.value?.id,
        genreIds: genreFilter.value,
        startIndex: page * 100,
        limit: 100,
        sortOrder: [sortOrder.value],
        sortBy: [sortType.value],
        filters: filterType.value,
        includeItemTypes: [
          BaseItemKind.movie,
          BaseItemKind.series,
          BaseItemKind.boxSet
        ]);

    if (isCupertino(context)) {
      return _iosLibrary(context, ref,
          filterRow: filterRow,
          gridDelegate: gridDelegate,
          tileBuilder: tileBuilder,
          itemsFuture: itemsFuture,
          page: page,
          goToPage: goToPage);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.library),
                if (ref.watch(isOfflineProvider)) ...[
                  const SizedBox(width: 10),
                  Tooltip(
                    message: AppLocalizations.of(context)!.offlineLibraryNotice,
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(Icons.cloud_off_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10.0, left: 15),
            child: Align(
              alignment: Alignment.topLeft,
              child: filterRow,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 0.0),
              child: FutureBuilder(
                future: itemsFuture,
                builder: (context, AsyncSnapshot<List<BaseItemDto>> snapshot) {
                  List<BaseItemDto> itemsList =
                      List.filled(20, SkeletonItem.baseItemDto);
                  if (snapshot.hasData) {
                    itemsList = snapshot.data!;

                    if (itemsList.isEmpty) {
                      return Center(
                        child: Text(AppLocalizations.of(context)!.noItemsFound),
                      );
                    }
                  }
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0, right: 10.0),
                        child: Skeletonizer(
                          enabled: !snapshot.hasData,
                          child: GridView.builder(
                            padding:
                                const EdgeInsets.only(bottom: 70.0, top: 110.0),
                            gridDelegate: gridDelegate,
                            itemCount: itemsList.length,
                            itemBuilder: (context, index) =>
                                tileBuilder(context, itemsList[index]),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(15.0),
                            topRight: Radius.circular(15.0),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Theme.of(context)
                                        .scaffoldBackgroundColor
                                        .withValues(alpha: 0.2),
                                    Theme.of(context).scaffoldBackgroundColor,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (page > 0)
                                    IconButton(
                                      onPressed: () => goToPage(page - 1),
                                      icon: const Icon(Icons.arrow_back_ios),
                                    ),
                                  const SizedBox(
                                    width: 20,
                                  ),
                                  if (itemsList.length == 100)
                                    IconButton(
                                      onPressed: () => goToPage(page + 1),
                                      icon: const Icon(Icons.arrow_forward_ios),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS: a large "Library" title over the filter chips and the poster
  /// grid, all in one scroll view, with the page arrows at the end.
  Widget _iosLibrary(
    BuildContext context,
    WidgetRef ref, {
    required Widget filterRow,
    required SliverGridDelegate gridDelegate,
    required Widget Function(BuildContext, BaseItemDto) tileBuilder,
    required Future<List<BaseItemDto>> itemsFuture,
    required int page,
    required void Function(int) goToPage,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder(
      future: itemsFuture,
      builder: (context, AsyncSnapshot<List<BaseItemDto>> snapshot) {
        final items =
            snapshot.data ?? List.filled(20, SkeletonItem.baseItemDto);
        return IosLargeTitlePage(
          title: l10n.library,
          trailing: ref.watch(isOfflineProvider)
              ? Tooltip(
                  message: l10n.offlineLibraryNotice,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(CupertinoIcons.cloud, size: 22),
                )
              : null,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 15, bottom: 12),
                child: Align(alignment: Alignment.topLeft, child: filterRow),
              ),
            ),
            if (snapshot.hasData && items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(l10n.noItemsFound)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                sliver: Skeletonizer.sliver(
                  enabled: !snapshot.hasData,
                  child: SliverGrid.builder(
                    gridDelegate: gridDelegate,
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        tileBuilder(context, items[index]),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (page > 0)
                      IosNavBarButton(
                        icon: CupertinoIcons.chevron_left,
                        onPressed: () => goToPage(page - 1),
                      ),
                    const SizedBox(width: 20),
                    if (items.length == 100)
                      IosNavBarButton(
                        icon: CupertinoIcons.chevron_right,
                        onPressed: () => goToPage(page + 1),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String localizeSortType(BuildContext context, ItemSortBy sortType) {
    switch (sortType) {
      case ItemSortBy.sortName:
        return AppLocalizations.of(context)!.name;
      case ItemSortBy.premiereDate:
        return AppLocalizations.of(context)!.premiereDate;
      case ItemSortBy.random:
        return AppLocalizations.of(context)!.random;
      default:
        return sortType.toString().split(".").last;
    }
  }
}
