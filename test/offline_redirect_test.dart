import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/navigation/app_router.dart';

void main() {
  String? go(String location, {bool offline = true, bool hasProfile = true}) =>
      offlineRedirect(
          location: location, offline: offline, hasProfile: hasProfile);

  test('offline launch with a saved profile skips login and loading', () {
    expect(go(ScreenPaths.login), ScreenPaths.downloads);
    // picking a profile on the profile screen pushes the loading screen
    expect(go(ScreenPaths.loading), ScreenPaths.downloads);
  });

  test('offline screens stay reachable, the rest go to downloads', () {
    expect(go(ScreenPaths.downloads), isNull);
    expect(go("${ScreenPaths.downloads}/${ScreenPaths.downloadedShow}"),
        isNull);
    expect(go("${ScreenPaths.downloads}/${ScreenPaths.player}"), isNull);
    expect(go("${ScreenPaths.library}/${ScreenPaths.detail}"), isNull);
    expect(go(ScreenPaths.profile), isNull);
    expect(go(ScreenPaths.home), ScreenPaths.downloads);
    expect(go(ScreenPaths.search), ScreenPaths.downloads);
  });

  test('without a saved profile the login screen stays', () {
    expect(go(ScreenPaths.login, hasProfile: false), isNull);
  });

  test('while the first online check is running, login stays', () {
    expect(go(ScreenPaths.login, offline: false), isNull);
  });
}
