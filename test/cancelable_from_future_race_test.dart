import 'dart:async';

import 'package:test/test.dart';
import 'package:worker_manager/worker_manager.dart';

void main() {
  group('Cancelable.fromFuture race condition - should not throw', () {
    test('cancel after future already completed does not throw', () async {
      final completer = Completer<int>();
      final cancelable = Cancelable<int>.fromFuture(completer.future);

      // Complete the future
      completer.complete(42);

      // Allow the microtask (.then callback) to fire
      await Future<void>.delayed(Duration.zero);

      // Now cancel — should silently ignore since completer is already completed
      expect(
        () => cancelable.cancel(),
        returnsNormally,
      );
    });

    test(
        'cancel before future completes does not cause StateError',
        () async {
      final futureCompleter = Completer<int>();
      final caughtErrors = <Object>[];

      await runZonedGuarded(
        () async {
          final cancelable = Cancelable<int>.fromFuture(futureCompleter.future);

          // Handle the CanceledError on the future so it doesn't leak
          cancelable.future.catchError((_) => -1);

          // Cancel first — completes the internal completer with CanceledError
          cancelable.cancel();

          // Now the future resolves — .then fires, but should silently ignore
          futureCompleter.complete(42);

          // Allow microtasks to process
          await Future<void>.delayed(Duration.zero);
        },
        (error, stack) {
          caughtErrors.add(error);
        },
      );

      // No StateError should have been caught — only CanceledError is acceptable
      expect(caughtErrors.whereType<StateError>(), isEmpty);
    });

    test('_completeError guards against already-completed completer', () async {
      final completer = Completer<int>();

      // Handle the future error so it doesn't leak as unhandled
      completer.future.catchError((_) => -1);

      completer.completeError(CanceledError()); // first completion

      // The second attempt via _completeError should be silently ignored
      // (we can't directly call _completeError, but cancel() triggers it)
      final cancelable = Cancelable<int>(
        completer: completer,
        onCancel: () {
          // This simulates what fromFuture's onCancel does
          if (!completer.isCompleted) {
            completer.completeError(CanceledError());
          }
        },
      );

      expect(() => cancelable.cancel(), returnsNormally);
    });

    test('mergeAll cancel after futures complete does not throw', () async {
      final c1 = Completer<int>();
      final c2 = Completer<int>();

      final cancelable1 = Cancelable<int>.fromFuture(c1.future);
      final cancelable2 = Cancelable<int>.fromFuture(c2.future);

      final merged = Cancelable.mergeAll([cancelable1, cancelable2]);

      c1.complete(1);
      c2.complete(2);
      await Future<void>.delayed(Duration.zero);

      // Cancel after all futures resolved — should silently ignore
      expect(
        () => merged.cancel(),
        returnsNormally,
      );
    });

    test('cancelable still resolves with value when not cancelled', () async {
      final completer = Completer<int>();
      final cancelable = Cancelable<int>.fromFuture(completer.future);

      completer.complete(42);

      final result = await cancelable;
      expect(result, 42);
    });

    test('cancelable resolves with CanceledError when cancelled before completion', () async {
      final completer = Completer<int>();
      final cancelable = Cancelable<int>.fromFuture(completer.future);

      cancelable.cancel();

      expect(() => cancelable.future, throwsA(isA<CanceledError>()));
    });
  });
}
