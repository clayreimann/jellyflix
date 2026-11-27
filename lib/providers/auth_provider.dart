import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/models/auth_state.dart';
import 'package:jellyflix/components/jellyfin_image.dart';
import 'package:tentacle/tentacle.dart';
import 'package:jellyflix/models/user.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/providers/database_provider.dart';
import 'package:jellyflix/providers/download_provider.dart';
import 'package:jellyflix/providers/connectivity_provider.dart';
import 'package:jellyflix/services/download_service.dart';
import 'package:jellyflix/providers/logger_provider.dart';
import 'package:jellyflix/services/auth_service.dart';
import 'package:jellyflix/services/locks.dart';

final authProvider = Provider<AuthService>((ref) {
  final apiService = ref.read(apiProvider);
  final databaseService = ref.read(databaseProvider('auth'));
  final logger = ref.read(loggerProvider);
  return AuthService(
      apiService: apiService, databaseService: databaseService, logger: logger);
});

final StateProvider authStateProvider = StateProvider<AuthState?>((ref) {
  return null;
});

/// The router starts this check on every navigation. Runs that overlapped
/// could each see "not logged in yet" and each run the just-logged-in work
/// (resume downloads, sync the library), so a run in progress is shared.
final _reachabilityCheck = SingleFlight<void>();

final updateServerReachableProvider = FutureProvider.autoDispose<void>(
    (ref) => _reachabilityCheck.run(() => _updateServerReachable(ref)));

Future<void> _updateServerReachable(Ref ref) async {
  var logger = ref.read(loggerProvider);
  final authService = ref.read(authProvider);
  bool? serverReachable = await authService.checkServerReachable();
  logger.verbose("Auth: Server reachable: $serverReachable");
  final api = ref.read(apiProvider);
  if (serverReachable == true) {
    logger.verbose("Auth: Server is reachable");
    api.offline = false;
    bool loggedIn = await ref.read(authProvider).checkAuthentication();
    if (loggedIn &&
        ref.read(authStateProvider.notifier).state != AuthState.loggedIn) {
      ref.read(authStateStreamControllerProvider).add(AuthState.loggedIn);
      ref.read(authStateProvider.notifier).state = AuthState.loggedIn;
      logger.verbose("Auth: User is logged in");
      // Back online: pick up interrupted downloads and refresh the offline
      // copy of the library in the background.
      // (this provider is auto-disposed, so don't use ref in the callbacks)
      final connectivity = ref.read(connectivityProvider);
      final queue = ref.read(downloadQueueProvider);
      DownloadService.resumeStalledDownloads((id) => DownloadService(api,
              itemId: id, connectivityService: connectivity, logger: logger))
          .then((count) => logger.verbose("Downloads: auto-resumed $count"))
          .catchError((e) {
        logger.error("Downloads: auto-resume failed", error: e);
        return 0;
      })
          // then start whatever was still waiting in the queue
          .whenComplete(queue.pump);
      api.syncOfflineLibrary().then((_) async {
        // keep posters for the whole library so it looks right offline
        final cache = api.offlineCache;
        if (cache == null) return;
        final ids = cache
            .queryItems(includeItemTypes: [
              BaseItemKind.movie,
              BaseItemKind.series,
              BaseItemKind.boxSet
            ])
            .map((e) => e.id!)
            .toList();
        await JfxImageCacheManager.prefetch(
            ids.map((id) => api.getImageUrl(id, ImageType.primary)),
            api.headers);
      }).catchError((e) {
        logger.error("OfflineCache: sync failed", error: e);
      });
    } else if (!loggedIn &&
        ref.read(authStateProvider.notifier).state != AuthState.loggedOut) {
      ref.read(authStateStreamControllerProvider).add(AuthState.loggedOut);
      ref.read(authStateProvider.notifier).state = AuthState.loggedOut;
      logger.verbose("Auth: User is logged out");
    }
  } else if (serverReachable == false &&
      ref.read(authStateProvider.notifier).state != AuthState.offline) {
    api.offline = true;
    // Offline cold start: restore the saved profile without the network so
    // the cached library and images know which server/user they belong to.
    if (api.currentUser == null) {
      await authService.restoreOfflineSession();
    }
    ref.read(authStateStreamControllerProvider).add(AuthState.offline);
    ref.read(authStateProvider.notifier).state = AuthState.offline;
    logger.verbose("Auth: Server is not reachable and AuthState is offline");
  } else if (serverReachable == null &&
      ref.read(authStateProvider.notifier).state != AuthState.unknown) {
    ref.read(authStateStreamControllerProvider).add(AuthState.unknown);
    ref.read(authStateProvider.notifier).state = AuthState.unknown;
    logger.verbose(
        "Auth: Server reachability is unknown and AuthState is unknown");
  }
}

final authStateStreamControllerProvider =
    StateProvider<StreamController<AuthState>>(
        (ref) => StreamController<AuthState>.broadcast());

final allProfilesProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  return ref.read(authProvider).getAllProfiles();
});
