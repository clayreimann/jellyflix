import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/models/bitrates.dart';

void main() {
  test('phones and tablets are told apart by the shorter screen side', () {
    expect(BitRates.isPhone(390), isTrue); // iPhone 15
    expect(BitRates.isPhone(375), isTrue); // iPhone SE
    expect(BitRates.isPhone(768), isFalse); // iPad Air 2
    expect(BitRates.isPhone(1024), isFalse); // iPad Pro 12.9
    // unknown screen: not a phone, so the higher default
    expect(BitRates.isPhone(null), isFalse);
  });

  test('defaults are values the bitrate picker offers', () {
    final options = BitRates().map.keys;
    expect(options, contains(BitRates.phoneBitrate));
    expect(options, contains(BitRates.tabletBitrate));
    expect(options, contains(BitRates.desktopBitrate));
  });
}
