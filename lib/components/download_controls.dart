import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/download_settings_dialog.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:jellyflix/models/bitrates.dart';
import 'package:jellyflix/providers/connectivity_provider.dart';
import 'package:jellyflix/providers/database_provider.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/services/download_service.dart';
import 'package:tentacle/tentacle.dart';
import 'package:universal_io/io.dart';

/// What tapping a download control does, given the current state. This is
/// the one place that decides between Download / Cancel / Resume / Remove,
/// so every screen shows the same thing.
enum DownloadAction { download, cancel, resume, remove }

DownloadAction downloadActionFor(DownloadState? state) {
  switch (state?.status) {
    case DownloadStatus.complete:
      return DownloadAction.remove;
    case DownloadStatus.downloading:
      return DownloadAction.cancel;
    case DownloadStatus.paused:
    case DownloadStatus.failed:
      return DownloadAction.resume;
    default:
      return DownloadAction.download;
  }
}

String downloadActionLabel(BuildContext context, DownloadAction action) {
  final l10n = AppLocalizations.of(context)!;
  switch (action) {
    case DownloadAction.download:
      return l10n.download;
    case DownloadAction.cancel:
      return l10n.cancelDownload;
    case DownloadAction.resume:
      return l10n.resumeDownload;
    case DownloadAction.remove:
      return l10n.removeDownload;
  }
}

IconData downloadActionIcon(DownloadAction action) {
  switch (action) {
    case DownloadAction.download:
      return Icons.file_download_outlined;
    case DownloadAction.cancel:
      return Icons.cancel_outlined;
    case DownloadAction.resume:
      return Icons.play_arrow_rounded;
    case DownloadAction.remove:
      return Icons.delete_outline_rounded;
  }
}

/// Menu value used by [downloadMenuItem].
const downloadMenuValue = 'download_action';

/// The download entry for an item's ⋮ menu. Handle it in the menu's
/// onSelected by calling [runDownloadAction] when the value is
/// [downloadMenuValue].
PopupMenuItem<String> downloadMenuItem(
    BuildContext context, DownloadState? state) {
  final action = downloadActionFor(state);
  return PopupMenuItem<String>(
    value: downloadMenuValue,
    child: ListTile(
      leading: Icon(downloadActionIcon(action)),
      iconColor: Theme.of(context).colorScheme.primary,
      title: Text(downloadActionLabel(context, action)),
    ),
  );
}

/// Performs whatever the current state calls for (see [downloadActionFor]).
///
/// [shown] is the action the user saw on screen. If the real state has
/// moved on since (say the download finished a moment ago), nothing is done
/// and the control just refreshes, so a tap can never remove a download the
/// user meant to start or resume.
Future<void> runDownloadAction(
    BuildContext context, WidgetRef ref, String itemId,
    {required DownloadAction shown}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(downloadProvider(itemId));
  void snack(String text) => messenger.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)));

  DownloadState? state;
  try {
    state = await service.getState();
  } catch (_) {
    state = null;
  }
  final actual = downloadActionFor(state);
  if (state == null || actual != shown) {
    ref.invalidate(downloadStateProvider(itemId));
    return;
  }
  switch (actual) {
    case DownloadAction.remove:
      await service.removeDownload();
      snack(l10n.removedDownload);
      return;
    case DownloadAction.cancel:
      await service.cancelDownload();
      snack(l10n.canceledDownload);
      return;
    case DownloadAction.resume:
      await service.resumeDownload();
      snack(l10n.resumedDownload);
      return;
    case DownloadAction.download:
      break;
  }

  if ((Platform.isAndroid || Platform.isIOS) &&
      !(ref.read(connectivityProvider).isConnected)) {
    return;
  }
  int downloadBitrate =
      await ref.read(databaseProvider("settings")).get("downloadBitrate") ??
          BitRates.defaultBitrate();

  PlaybackInfoResponse downloadInfo =
      await service.getDownloadInfo(downloadBitrate: downloadBitrate);

  int audioCount = downloadInfo.mediaSources![0].mediaStreams!
      .where((element) =>
          element.type == MediaStreamType.audio &&
          downloadInfo.mediaSources!.first.transcodingUrl != null)
      .length;
  int subtitleCount = downloadInfo.mediaSources![0].mediaStreams!
      .where((element) =>
          element.type == MediaStreamType.subtitle &&
          element.deliveryMethod == SubtitleDeliveryMethod.external_)
      .length;

  if (context.mounted && (audioCount > 1 || subtitleCount > 0)) {
    (int?, int?)? selectedSettings = await showDialog(
      context: context,
      builder: (context) => DownloadSettingsDialog(downloadInfo: downloadInfo),
    );
    if (selectedSettings == null ||
        (selectedSettings.$1 == null && selectedSettings.$2 == null)) {
      return;
    }
    service.downloadItem(
        audioStreamIndex: selectedSettings.$1,
        subtitleStreamIndex: selectedSettings.$2,
        downloadBitrate: downloadBitrate);
  } else {
    service.downloadItem(downloadBitrate: downloadBitrate);
  }
  snack(l10n.startedDownload);
}

/// Round download control: a download icon, a progress ring while
/// downloading, or a check mark once the item is on the device. Tapping it
/// runs [runDownloadAction].
class DownloadStateButton extends ConsumerWidget {
  final String itemId;
  const DownloadStateButton({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadStateProvider(itemId)).value;
    final action = downloadActionFor(state);
    final color = Theme.of(context).colorScheme.primary;
    Widget icon;
    switch (state?.status) {
      case DownloadStatus.complete:
        icon = Icon(Icons.download_done_rounded, color: color);
        break;
      case DownloadStatus.downloading:
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        final progress = state!.progress;
        icon = Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              value: progress == null ? null : progress / 100,
              strokeWidth: 2.5,
              color: state.status == DownloadStatus.failed
                  ? Theme.of(context).colorScheme.error
                  : color,
            ),
          ),
          Icon(
              state.status == DownloadStatus.downloading
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
              size: 16),
        ]);
        break;
      default:
        icon = const Icon(Icons.file_download_outlined);
    }
    return IconButton(
      tooltip: downloadActionLabel(context, action),
      onPressed: () =>
          runDownloadAction(context, ref, itemId, shown: action),
      icon: icon,
    );
  }
}
