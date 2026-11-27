import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/services/locks.dart';

void main() {
  group('AsyncLock', () {
    test('bodies never interleave, and run in call order', () async {
      final lock = AsyncLock();
      final log = <String>[];
      Future<void> step(String name) => lock.run(() async {
            log.add("$name start");
            await Future.delayed(const Duration(milliseconds: 5));
            log.add("$name end");
          });
      await Future.wait([step("a"), step("b"), step("c")]);
      expect(log, [
        "a start",
        "a end",
        "b start",
        "b end",
        "c start",
        "c end",
      ]);
      expect(lock.isLocked, isFalse);
    });

    test('an error is passed to the caller and does not jam the lock',
        () async {
      final lock = AsyncLock();
      await expectLater(
          lock.run(() async => throw StateError("boom")), throwsStateError);
      expect(await lock.run(() async => 42), 42);
    });

    test('a read-modify-write under the lock does not lose updates',
        () async {
      final lock = AsyncLock();
      var counter = 0;
      Future<void> increment() => lock.run(() async {
            final read = counter;
            await Future.delayed(Duration.zero);
            counter = read + 1;
          });
      await Future.wait(List.generate(50, (_) => increment()));
      expect(counter, 50);
    });
  });

  group('KeyedLocks', () {
    test('serializes the same key but not different keys', () async {
      final locks = KeyedLocks();
      final log = <String>[];
      Future<void> step(String key, String name) => locks.run(key, () async {
            log.add("$name start");
            await Future.delayed(const Duration(milliseconds: 5));
            log.add("$name end");
          });
      await Future.wait([step("x", "x1"), step("y", "y1"), step("x", "x2")]);
      // x2 waits for x1; y1 runs alongside x1
      expect(log.indexOf("x2 start"), greaterThan(log.indexOf("x1 end")));
      expect(log.indexOf("y1 start"), lessThan(log.indexOf("x1 end")));
      expect(locks.isLocked("x"), isFalse);
    });
  });

  group('SingleFlight', () {
    test('overlapping calls share one run', () async {
      final flight = SingleFlight<int>();
      var runs = 0;
      Future<int> body() async {
        runs++;
        await Future.delayed(const Duration(milliseconds: 5));
        return runs;
      }

      final results = await Future.wait([
        flight.run(body),
        flight.run(body),
        flight.run(body),
      ]);
      expect(runs, 1);
      expect(results, [1, 1, 1]);
      // once finished, the next call runs again
      expect(await flight.run(body), 2);
    });

    test('a failed run can be retried', () async {
      final flight = SingleFlight<void>();
      await expectLater(
          flight.run(() async => throw StateError("offline")), throwsStateError);
      expect(flight.isRunning, isFalse);
      await flight.run(() async {});
    });
  });
}
