final class RoundClock {
  RoundClock({Duration Function()? now}) : _now = now ?? _monotonicClock();

  final Duration Function() _now;
  Duration? _started;
  Duration? _finished;

  bool get running => _started != null && _finished == null;

  Duration get elapsed {
    final start = _started;
    if (start == null) return Duration.zero;
    final value = (_finished ?? _now()) - start;
    return value.isNegative ? Duration.zero : value;
  }

  void start() {
    _started = _now();
    _finished = null;
  }

  void stop() {
    if (running) _finished = _now();
  }

  static Duration Function() _monotonicClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }
}
