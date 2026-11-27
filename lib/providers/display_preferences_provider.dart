import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/providers/auth_provider.dart';

/// Fetches the Jellyfin user setting that controls whether episode thumbnails
/// or series posters are shown in Continue Watching / Next Up carousels.
///
/// Mirrors the `useEpisodeImagesInNextUpAndResume` key stored server-side in
/// DisplayPreferences.customPrefs (client: 'emby', id: 'usersettings').
class UseEpisodeImagesNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // Re-fetch whenever the auth state changes (e.g. profile switch).
    ref.watch(authStateProvider);
    return ref.read(apiProvider).getUseEpisodeImagesInNextUpAndResume();
  }

  /// Flips the switch at once, then saves to the server. If the save
  /// fails (e.g. offline), the switch goes back and the error is rethrown
  /// so the caller can say why.
  Future<void> toggle(bool value) async {
    final previous = state;
    state = AsyncData(value);
    try {
      await ref
          .read(apiProvider)
          .setUseEpisodeImagesInNextUpAndResume(value)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final useEpisodeImagesProvider =
    AsyncNotifierProvider<UseEpisodeImagesNotifier, bool>(
  UseEpisodeImagesNotifier.new,
);
