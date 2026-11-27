import 'dart:async';

import 'package:jellyflix/models/download_metadata.dart';
import 'package:jellyflix/models/playback_position.dart';
import 'package:jellyflix/services/api_service.dart';
import 'package:jellyflix/services/download_service.dart';
import 'package:jellyflix/services/player_helper.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tentacle/tentacle.dart';

class OfflinePlayerHelper extends PlayerHelper {
  late int bitrate;
  late final DownloadMetadata downloadMetadata;

  /// Where to start when the caller doesn't ask for a position (see
  /// [PlaybackPosition.resumeTicks]).
  final int resumeTicks;

  /// Saves the position next to the download.
  final DownloadService? download;

  /// Tells the server the position when it's reachable.
  final ApiService? api;

  OfflinePlayerHelper(
      {required playbackInfo,
      required this.downloadMetadata,
      required logger,
      String? mpvConfig,
      this.resumeTicks = 0,
      this.download,
      this.api})
      : super(
            playbackInfo: playbackInfo, logger: logger, mpvConfig: mpvConfig) {
    audioStream = getDefaultAudio();
    subtitle = getDefaultSubtitle();
    isSubtitleEnabled = subtitle.index != -1;
    showBitrate = false;
  }

  @override
  Future<void> disableSubtitle() async {
    player.setSubtitleTrack(player.state.tracks.subtitle[1]);
    isSubtitleEnabled = false;
  }

  @override
  Future<void> enableSubtitle() async {
    if (subtitle.index == -1) {
      // index 0 is no subtitle
      await setSubtitle(subtitles[1]);
    } else {
      await setSubtitle(subtitle);
    }
  }

  @override
  Future<void> initStream(int startTimeTicks) async {
    String streamUrl = downloadMetadata.path!;
    final start = startTimeTicks > 0 ? startTimeTicks : resumeTicks;
    player.open(Media(streamUrl, start: Duration(microseconds: start ~/ 10)));
    _trackPosition();
    StreamSubscription? trackStream;
    trackStream = player.stream.tracks.listen((event) {
      List<AudioTrack> audioTracks = event.audio;
      List<SubtitleTrack> subtitleTracks = event.subtitle;
      if (audioTracks.length > 2 || subtitleTracks.length > 2) {
        setAudio(audioStream);

        if (getDefaultSubtitle().index != -1) {
          enableSubtitle();
        }

        // only run until initial load
        trackStream?.cancel();
      }
    });
  }

  static const _saveEvery = Duration(seconds: 5);
  StreamSubscription<Duration>? _positionSub;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastTicks = 0;
  bool _finished = false;

  /// Saves the position on the device every few seconds while playing, so
  /// it survives however the player is closed (back button, swipe, app
  /// killed).
  void _trackPosition() {
    _positionSub?.cancel();
    _positionSub = player.stream.position.listen((position) {
      final ticks = position.inMicroseconds * 10;
      if (ticks <= 0) return;
      _lastTicks = ticks;
      final now = DateTime.now();
      if (now.difference(_lastSave) < _saveEvery) return;
      _lastSave = now;
      _save(ticks, played: false);
    }, onDone: () => _positionSub = null);
  }

  Future<void> _save(int ticks, {required bool played}) async {
    await download?.writePosition(PlaybackPosition(
        ticks: played ? 0 : ticks,
        updatedAt: DateTime.now(),
        played: played));
  }

  /// Final save when playback ends; also tells the server if it's
  /// reachable (otherwise that happens on the next sync).
  Future<void> _stop({required bool played}) async {
    if (_finished) return;
    _finished = true;
    await _positionSub?.cancel();
    _positionSub = null;
    final ticks = _lastTicks;
    if (ticks <= 0 && !played) return;
    played = played ||
        PlaybackPosition.isFinished(ticks, downloadMetadata.runTimeTicks);
    final position = PlaybackPosition(
        ticks: played ? 0 : ticks, updatedAt: DateTime.now(), played: played);
    await download?.writePosition(position);
    final api = this.api;
    if (api == null || api.offline || api.currentUser == null) return;
    try {
      await api.saveUserItemData(
          itemId: downloadMetadata.id,
          positionTicks: position.ticks,
          played: played,
          lastPlayed: position.updatedAt);
      await download?.writePosition(position.copyWith(synced: true));
    } catch (_) {
      // left unsynced; sent the next time the server is reachable
    }
  }

  @override
  Future<void> completedPlayback() => _stop(played: true);

  @override
  Future<void> backButtonPressed() => _stop(played: false);

  @override
  Future<void> setAudio(MediaStream mediaStream) async {
    mediaStream = audioStreams
        .firstWhere((element) => element.index == mediaStream.index);
    int index = mappedAudioStreams[mediaStream]!;
    player.setAudioTrack(player.state.tracks.audio[index]);
    audioStream = mediaStream;
  }

  @override
  Future<void> setSubtitle(MediaStream mediaStream) async {
    mediaStream =
        subtitles.firstWhere((element) => element.index == mediaStream.index);
    if (mediaStream.deliveryMethod == SubtitleDeliveryMethod.external_) {
      // load subtitle from file
      SubtitleTrack externalSubtitle =
          SubtitleTrack.uri(mediaStream.deliveryUrl!);
      // external subtitles
      await player.setSubtitleTrack(externalSubtitle);
      isSubtitleEnabled = true;
      subtitle = mediaStream;
    } else {
      if (mediaStream.index == -1) {
        // no subtitles is track with index 1
        player.setSubtitleTrack(player.state.tracks.subtitle[1]);
        isSubtitleEnabled = false;
      } else {
        int index = mappedSubtitles[mediaStream]!;
        player.setSubtitleTrack(player.state.tracks.subtitle[index]);
        isSubtitleEnabled = true;
        subtitle = mediaStream;
      }
    }
  }
}
