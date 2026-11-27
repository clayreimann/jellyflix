/// Where a downloaded item was last stopped, saved on the device so resume
/// works offline. [synced] is false until the server has been told.
class PlaybackPosition {
  final int ticks;
  final DateTime updatedAt;
  final bool played;
  final bool synced;

  PlaybackPosition({
    required this.ticks,
    required this.updatedAt,
    this.played = false,
    this.synced = false,
  });

  PlaybackPosition copyWith({bool? synced}) => PlaybackPosition(
      ticks: ticks,
      updatedAt: updatedAt,
      played: played,
      synced: synced ?? this.synced);

  Map<String, dynamic> toJson() => {
        "Ticks": ticks,
        "UpdatedAt": updatedAt.toUtc().toIso8601String(),
        "Played": played,
        "Synced": synced,
      };

  static PlaybackPosition? fromJson(Map<String, dynamic> json) {
    final updatedAt = DateTime.tryParse(json["UpdatedAt"] ?? "");
    if (updatedAt == null || json["Ticks"] is! int) return null;
    return PlaybackPosition(
        ticks: json["Ticks"],
        updatedAt: updatedAt,
        played: json["Played"] == true,
        synced: json["Synced"] == true);
  }

  /// Within this much of the end counts as finished.
  static const _finishedFraction = 0.95;

  /// Where to start playing: the newer of the position saved on the device
  /// and the one the server has (from playing on another device, or online
  /// before the download). Finished items start from the beginning.
  static int resumeTicks({
    PlaybackPosition? local,
    int? serverTicks,
    DateTime? serverLastPlayed,
    bool serverPlayed = false,
    int runTimeTicks = 0,
  }) {
    int ticks;
    bool played;
    final serverIsNewer = local == null ||
        (serverLastPlayed != null && serverLastPlayed.isAfter(local.updatedAt));
    if (serverIsNewer) {
      ticks = serverTicks ?? 0;
      played = serverPlayed && ticks == 0;
    } else {
      ticks = local.ticks;
      played = local.played;
    }
    if (played || ticks <= 0) return 0;
    if (runTimeTicks > 0 && ticks >= runTimeTicks * _finishedFraction) {
      return 0;
    }
    return ticks;
  }

  /// Whether a stop at [ticks] means the item was watched to the end.
  static bool isFinished(int ticks, int runTimeTicks) =>
      runTimeTicks > 0 && ticks >= runTimeTicks * _finishedFraction;
}
