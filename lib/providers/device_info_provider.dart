import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:jellyflix/services/device_info_service.dart';

final appVersionProvider = FutureProvider<String?>((ref) async {
  return DeviceInfoService().getVersion();
});

/// "1.99.21 (42)": the app version and build number.
final appBuildProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});
