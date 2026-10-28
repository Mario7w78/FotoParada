// utils/debounce.dart
import 'dart:async';

typedef Debounceable<S, T> = Future<S?> Function(T parameter);

Debounceable<S, T> debounce<S, T>(
    Future<S> Function(T) fn, {
      Duration delay = const Duration(milliseconds: 500),
    }) {
  Timer? timer;
  Completer<S?>? pending;
  return (T parameter) {
    timer?.cancel();
    if (pending != null && !pending!.isCompleted) {
      pending!.complete(null);
    }
    final completer = Completer<S?>();
    pending = completer;
    timer = Timer(delay, () async {
      try {
        final result = await fn(parameter);
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });

    return pending!.future;
  };
}