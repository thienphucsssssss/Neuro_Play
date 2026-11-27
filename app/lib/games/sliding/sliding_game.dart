import 'dart:math';

import 'package:flutter/foundation.dart';

import '../round_clock.dart';
import 'sliding_board.dart';
import 'sliding_hint.dart';

Future<int?> _isolatedHint(SlidingBoard board) =>
    compute(findSlidingHint, board);

final class SlidingGame extends ChangeNotifier {
  SlidingGame({
    Random? random,
    RoundClock? clock,
    SlidingBoard Function(int, Random)? newBoard,
    Future<int?> Function(SlidingBoard)? hintRunner,
  }) : _random = random ?? Random(),
       _clock = clock ?? RoundClock(),
       _newBoard = newBoard ?? SlidingBoard.shuffled,
       _hintRunner = hintRunner ?? _isolatedHint;

  final Random _random;
  final RoundClock _clock;
  final SlidingBoard Function(int, Random) _newBoard;
  final Future<int?> Function(SlidingBoard) _hintRunner;
  SlidingBoard? _board;
  int _moves = 0;
  int _revision = 0;
  int? _hint;
  bool _searching = false;
  bool _hintUnavailable = false;
  bool _disposed = false;

  SlidingBoard? get board => _board;
  int get moves => _moves;
  Duration get elapsed => _clock.elapsed;
  bool get completed => _board?.isSolved ?? false;
  int? get hint => _hint;
  bool get searching => _searching;
  bool get hintUnavailable => _hintUnavailable;

  void start(int size) {
    _board = _newBoard(size, _random);
    _moves = 0;
    _revision++;
    _clearHint();
    _clock.start();
    notifyListeners();
  }

  void slide(int index) {
    final current = _board;
    if (current == null || current.isSolved) return;
    final next = current.slide(index);
    if (next == null) return;
    _board = next;
    _moves++;
    _revision++;
    _clearHint();
    if (next.isSolved) _clock.stop();
    notifyListeners();
  }

  Future<void> requestHint() async {
    final current = _board;
    if (current == null || current.isSolved || _searching) return;
    final revision = _revision;
    _searching = true;
    _clearHint();
    notifyListeners();

    int? index;
    try {
      index = await _hintRunner(current);
    } catch (error) {
      debugPrint('Sliding hint could not run: $error');
    }
    if (_disposed) return;
    _searching = false;
    if (revision == _revision) {
      _hint = current.legalMoves.contains(index) ? index : null;
      _hintUnavailable = _hint == null;
    }
    notifyListeners();
  }

  void _clearHint() {
    _hint = null;
    _hintUnavailable = false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
