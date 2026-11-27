import 'package:jellyflix/components/ios_sheets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:jellyflix/services/player_helper.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:tentacle/tentacle.dart';

class PlayerSettingsDialog extends StatelessWidget {
  final PlayerHelper playbackHelper;
  final MediaStream audioTrack;
  final MediaStream subtitleTrack;
  final int maxStreamingBitrate;
  final bool isSubtitleEnabled;
  final Function(MediaStream?) onSubtitleSelected;
  final Function(MediaStream?) onAudioSelected;
  final Function(int?) onBitrateSelected;
  final bool showBitrate;

  const PlayerSettingsDialog({
    super.key,
    required this.playbackHelper,
    required this.audioTrack,
    required this.subtitleTrack,
    required this.maxStreamingBitrate,
    required this.onSubtitleSelected,
    required this.onAudioSelected,
    required this.onBitrateSelected,
    required this.isSubtitleEnabled,
    required this.showBitrate,
  });

  /// iOS: an action sheet listing Quality, Audio and Subtitles with their
  /// current values; picking one opens a second sheet of its options, the
  /// current one in bold.
  Future<void> showOnIos(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = playbackHelper.subtitles
        .firstWhere((e) => e.index == subtitleTrack.index);
    final audio = playbackHelper.audioStreams
        .firstWhere((e) => e.index == audioTrack.index);
    final bitrates = playbackHelper.getBitrateMap();

    final section = await showIosActionSheet<String>(
      context: context,
      title: l10n.settings,
      actions: [
        if (showBitrate)
          IosSheetAction(
              value: 'quality',
              label: '${l10n.quality}: ${bitrates[maxStreamingBitrate] ?? ''}'),
        if (playbackHelper.audioStreams.length > 1)
          IosSheetAction(
              value: 'audio',
              label: '${l10n.audio}: ${audio.displayTitle ?? l10n.none}'),
        if (playbackHelper.subtitles.length > 1)
          IosSheetAction(
              value: 'subtitles',
              label:
                  '${l10n.subtitles}: ${isSubtitleEnabled ? subtitle.displayTitle ?? l10n.none : l10n.none}'),
      ],
    );
    if (section == null || !context.mounted) return;

    switch (section) {
      case 'quality':
        final picked = await showIosActionSheet<int>(
          context: context,
          title: l10n.quality,
          actions: [
            for (final e in bitrates.entries)
              IosSheetAction(
                  value: e.key,
                  label: e.value,
                  isDefault: e.key == maxStreamingBitrate),
          ],
        );
        if (picked != null) onBitrateSelected(picked);
      case 'audio':
        final picked = await showIosActionSheet<MediaStream>(
          context: context,
          title: l10n.audio,
          actions: [
            for (final e in playbackHelper.audioStreams)
              IosSheetAction(
                  value: e,
                  label: e.displayTitle ?? l10n.none,
                  isDefault: e.index == audio.index),
          ],
        );
        if (picked != null) onAudioSelected(picked);
      case 'subtitles':
        final picked = await showIosActionSheet<MediaStream>(
          context: context,
          title: l10n.subtitles,
          actions: [
            for (final e in playbackHelper.subtitles)
              IosSheetAction(
                  value: e,
                  label: e.displayTitle ?? l10n.none,
                  isDefault: isSubtitleEnabled
                      ? e.index == subtitle.index
                      : e.index == -1),
          ],
        );
        if (picked != null) onSubtitleSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    var subtitle = playbackHelper.subtitles
        .firstWhere((e) => e.index == subtitleTrack.index);
    var audio = playbackHelper.audioStreams
        .firstWhere((e) => e.index == audioTrack.index);
    return SafeArea(
        child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 25.0, vertical: 50.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(10.0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 250,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppLocalizations.of(context)!.settings,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (showBitrate)
                            Material(
                              child: DropdownMenu(
                                  width: 250,
                                  requestFocusOnTap: false,
                                  label: Text(
                                      AppLocalizations.of(context)!.quality),
                                  leadingIcon:
                                      const Icon(Icons.videocam_outlined),
                                  initialSelection: maxStreamingBitrate,
                                  dropdownMenuEntries: playbackHelper
                                      .getBitrateMap()
                                      .entries
                                      .toList()
                                      .map((e) {
                                    return DropdownMenuEntry(
                                        value: e.key, label: e.value);
                                  }).toList(),
                                  onSelected: onBitrateSelected),
                            ),
                          if (showBitrate) const SizedBox(height: 10),
                          if (playbackHelper.audioStreams.length > 1)
                            Material(
                              child: DropdownMenu(
                                width: 250,
                                requestFocusOnTap: false,
                                label:
                                    Text(AppLocalizations.of(context)!.audio),
                                leadingIcon:
                                    const Icon(Icons.volume_up_rounded),
                                initialSelection: audio,
                                dropdownMenuEntries: playbackHelper.audioStreams
                                    .map((e) => DropdownMenuEntry(
                                        value: e,
                                        label: e.displayTitle ?? "Unknown"))
                                    .toList(),
                                onSelected: onAudioSelected,
                              ),
                            ),
                          const SizedBox(height: 10),
                          if (playbackHelper.subtitles.length > 1)
                            Material(
                              child: DropdownMenu<MediaStream>(
                                  width: 250,
                                  label: Text(
                                      AppLocalizations.of(context)!.subtitles),
                                  requestFocusOnTap: false,
                                  leadingIcon:
                                      const Icon(Icons.videocam_outlined),
                                  initialSelection: subtitle,
                                  dropdownMenuEntries: playbackHelper.subtitles
                                      .map((e) => DropdownMenuEntry(
                                          value: e,
                                          label: e.displayTitle ?? "Unknown"))
                                      .toList(),
                                  onSelected: onSubtitleSelected),
                            ),
                        ]),
                  ),
                ),
              ),
            )));
  }
}
