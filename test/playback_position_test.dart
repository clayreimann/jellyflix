import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/models/playback_position.dart';

const minute = 60 * 10000000;
final noon = DateTime.utc(2026, 11, 27, 12);

void main() {
  test('no history starts at the beginning', () {
    expect(PlaybackPosition.resumeTicks(), 0);
  });

  test('uses the device position when it is newer than the server', () {
    final local = PlaybackPosition(ticks: 20 * minute, updatedAt: noon);
    expect(
        PlaybackPosition.resumeTicks(
            local: local,
            serverTicks: 5 * minute,
            serverLastPlayed: noon.subtract(const Duration(days: 1)),
            runTimeTicks: 90 * minute),
        20 * minute);
  });

  test('uses the server position when it is newer (played elsewhere)', () {
    final local = PlaybackPosition(ticks: 20 * minute, updatedAt: noon);
    expect(
        PlaybackPosition.resumeTicks(
            local: local,
            serverTicks: 45 * minute,
            serverLastPlayed: noon.add(const Duration(hours: 2)),
            runTimeTicks: 90 * minute),
        45 * minute);
  });

  test('uses the server position when the device has none', () {
    expect(
        PlaybackPosition.resumeTicks(
            serverTicks: 12 * minute, runTimeTicks: 90 * minute),
        12 * minute);
  });

  test('finished items start over', () {
    final watched =
        PlaybackPosition(ticks: 0, updatedAt: noon, played: true);
    expect(PlaybackPosition.resumeTicks(local: watched), 0);
    final nearEnd = PlaybackPosition(ticks: 88 * minute, updatedAt: noon);
    expect(
        PlaybackPosition.resumeTicks(local: nearEnd, runTimeTicks: 90 * minute),
        0);
    expect(PlaybackPosition.isFinished(88 * minute, 90 * minute), isTrue);
    expect(PlaybackPosition.isFinished(30 * minute, 90 * minute), isFalse);
  });

  test('round-trips through JSON', () {
    final p = PlaybackPosition(
        ticks: 7 * minute, updatedAt: noon, played: false, synced: true);
    final back = PlaybackPosition.fromJson(p.toJson())!;
    expect(back.ticks, p.ticks);
    expect(back.updatedAt, p.updatedAt);
    expect(back.synced, isTrue);
    expect(PlaybackPosition.fromJson({"Ticks": "x"}), isNull);
  });
}
