import 'dart:ui';

import 'package:universal_io/io.dart';

class BitRates {
  Map<int, String> map = {
    120000000: "120 Mb/s",
    100000000: "100 Mb/s",
    60000000: "60 Mb/s",
    40000000: "40 Mb/s",
    20000000: "20 Mb/s",
    8000000: "8 Mb/s",
    4000000: "4 Mb/s",
    2000000: "2 Mb/s",
    420000: "420 Kb/s",
  };

  static const phoneBitrate = 4000000;
  static const tabletBitrate = 8000000;
  static const desktopBitrate = 8000000;

  /// The download bitrate used until the user picks one, sized to the
  /// screen: 4 Mb/s on a phone (about 1.8 GB per hour, plenty on a small
  /// screen) and 8 Mb/s on a tablet or computer.
  static int defaultBitrate() {
    if (!(Platform.isIOS || Platform.isAndroid)) return desktopBitrate;
    return isPhone(_shortestSide()) ? phoneBitrate : tabletBitrate;
  }

  /// Material's phone/tablet split: a phone's shorter screen side is under
  /// 600 logical pixels in either orientation.
  static bool isPhone(double? shortestSide) =>
      shortestSide != null && shortestSide < 600;

  static double? _shortestSide() {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return null;
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    return size.shortestSide;
  }
}
