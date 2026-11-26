import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/episode_list_tile.dart';
import 'package:jellyflix/components/jfx_text_theme.dart';
import 'package:jellyflix/models/bitrates.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/providers/database_provider.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/providers/offline_provider.dart';
import 'package:tentacle/tentacle.dart';
import 'package:skeletonizer/skeletonizer.dart';

class EpisodeList extends HookConsumerWidget {
  const EpisodeList({
    super.key,
    required this.data,
    required this.markedAsPlayed,
    required this.itemId,
    required this.episodeStreamController,
    required this.parentPath,
  });

  final BaseItemDto data;
  final ValueNotifier<bool?> markedAsPlayed;
  final String itemId;
  final StreamController<List<BaseItemDto>> episodeStreamController;
  final String parentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonSelection = useState(0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
          child: Text(AppLocalizations.of(context)!.episodes,
              style: JfxTextTheme.scalingTheme(context).headlineSmall),
        ),
        StreamBuilder(
          stream: episodeStreamController.stream,
          builder: (context, snapshot) {
            var seasons = [];
            var seasonIds = [];
            var episodes = [];
            if (snapshot.hasData) {
              seasons =
                  snapshot.data!.map((e) => e.seasonName).toSet().toList();

              // get season ids
              seasonIds =
                  snapshot.data!.map((e) => e.seasonId).toSet().toList();
              // get episodes for season
              episodes = snapshot.data!
                  .where((element) =>
                      element.seasonId == seasonIds[seasonSelection.value])
                  .toList();
            }
            return Skeletonizer(
              enabled: !snapshot.hasData,
              child: Column(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 60,
                    child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: seasons.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: ChoiceChip(
                                selected: seasonSelection.value == index,
                                onSelected: (selected) {
                                  seasonSelection.value = index;
                                },
                                label: Text(
                                  seasons[index],
                                  style: JfxTextTheme.scalingTheme(context)
                                      .bodyLarge!
                                      .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                )),
                          );
                        }),
                  ),
                  if (!ref.watch(isOfflineProvider) && episodes.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.download_for_offline_outlined),
                          label: Text(
                              AppLocalizations.of(context)!.downloadSeason),
                          onPressed: () => _downloadSeason(
                              context, ref, List<BaseItemDto>.from(episodes)),
                        ),
                      ),
                    ),
                  ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      BaseItemDto item = episodes[index];
                      return EpisodeListTile(
                        parentPath: parentPath,
                        episode: item,
                        onSelected: (value) async {
                          if (value == 'mark_as_played') {
                            await ref.read(apiProvider).markAsPlayed(
                                itemId: item.id!,
                                played: !item.userData!.played!);
                            if (markedAsPlayed.value == true &&
                                item.userData!.played!) {
                              markedAsPlayed.value = false;
                            } else if (markedAsPlayed.value == false &&
                                episodes
                                        .where((element) =>
                                            element.userData!.played == false)
                                        .length ==
                                    1 &&
                                !item.userData!.played!) {
                              markedAsPlayed.value = true;
                            }

                            episodeStreamController.add(await ref
                                .read(apiProvider)
                                .getEpisodes(itemId));
                          }
                        },
                      );
                    },
                  )
                ],
              ),
            );
            // } else {
            //   return const CircularProgressIndicator();
            // }
          },
        ),
      ],
    );
  }

  /// Queues every episode of the season that isn't already downloaded,
  /// using the default audio/subtitle tracks and download bitrate.
  Future<void> _downloadSeason(
      BuildContext context, WidgetRef ref, List<BaseItemDto> episodes) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    int downloadBitrate =
        await ref.read(databaseProvider("settings")).get("downloadBitrate") ??
            BitRates.defaultBitrate();
    final List<BaseItemDto> toDownload = [];
    for (var e in episodes) {
      final service = ref.read(downloadProvider(e.id!));
      if (!service.isDownloading && await service.calculateProgress() == null) {
        toDownload.add(e);
      }
    }
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.downloadingSeason(toDownload.length)),
      duration: const Duration(seconds: 2),
    ));
    // one at a time, so the server isn't asked to start many transcodes at once
    for (var e in toDownload) {
      await ref
          .read(downloadProvider(e.id!))
          .downloadItem(downloadBitrate: downloadBitrate);
    }
    ref.invalidate(downloadLibraryProvider);
  }
}
