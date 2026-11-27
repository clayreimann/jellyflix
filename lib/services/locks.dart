import 'dart:async';

/// A lock for async code: [run] calls execute one at a time, in the order
/// they were made. Dart runs on one thread, but every `await` lets other
/// code run in between, so a multi-step operation on shared files or tasks
/// needs this to avoid interleaving with another one.
///
/// Not reentrant: calling [run] from inside [run] on the same lock waits
/// forever. Keep the locked bodies free of calls back into locked methods.
class AsyncLock {
  Future<void> _last = Future.value();
  int _pending = 0;

  /// Whether a locked call is running or waiting.
  bool get isLocked => _pending > 0;

  Future<T> run<T>(Future<T> Function() body) {
    _pending++;
    final previous = _last;
    final completer = Completer<void>();
    _last = completer.future;
    return previous.then((_) => body()).whenComplete(() {
      _pending--;
      completer.complete();
    });
  }
}

/// One [AsyncLock] per key, e.g. per downloaded item.
class KeyedLocks {
  final Map<String, AsyncLock> _locks = {};

  bool isLocked(String key) => _locks[key]?.isLocked ?? false;

  Future<T> run<T>(String key, Future<T> Function() body) {
    final lock = _locks.putIfAbsent(key, () => AsyncLock());
    return lock.run(body).whenComplete(() {
      if (!lock.isLocked) _locks.remove(key);
    });
  }
}

/// Runs an operation at most once at a time: calls made while it is
/// running get the running call's result instead of starting another.
class SingleFlight<T> {
  Future<T>? _running;

  bool get isRunning => _running != null;

  Future<T> run(Future<T> Function() body) {
    final running = _running;
    if (running != null) return running;
    final future = Future.sync(body);
    _running = future;
    future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    }).ignore();
    return future;
  }
}
