import 'package:flutter/foundation.dart';

import '../round_clock.dart';
import 'caro_ai.dart';
import 'caro_board.dart';

Future<int?> _isolatedCaro(CaroPosition position) =>
    compute(chooseCaroMove, position);

final class CaroGame extends ChangeNotifier {
  CaroGame({RoundClock? clock, Future<int?> Function(CaroPosition)? computer})
    : _clock = clock ?? RoundClock(),
      _computer = computer ?? _isolatedCaro;

  final RoundClock _clock;
  final Future<int?> Function(CaroPosition) _computer;
  final _moves = <CaroMove>[];
  CaroBoard _board = CaroBoard.empty();
  CaroDifficulty? _difficulty;
  CaroOutcome? _outcome;
  List<int> _winningLine = const [];
  bool _thinking = false;
  bool _failed = false;
  bool _disposed = false;
  int _revision = 0;

  CaroDifficulty? get difficulty => _difficulty;
  CaroBoard get board => _board;
  CaroOutcome? get outcome => _outcome;
  List<int> get winningLine => _winningLine;
  List<CaroMove> get moves => List.unmodifiable(_moves);
  int get moveCount => _moves.length;
  int? get lastMove => _moves.isEmpty ? null : _moves.last.index;
  bool get thinking => _thinking;
  bool get failed => _failed;
  bool get canPlay =>
      _difficulty != null && _outcome == null && _moves.length.isEven;
  bool get canUndo => _outcome == null && _moves.isNotEmpty;
  Duration get elapsed => _clock.elapsed;

  void start(CaroDifficulty difficulty) {
    _revision++;
    _difficulty = difficulty;
    _moves.clear();
    _board = CaroBoard.empty();
    _outcome = null;
    _winningLine = const [];
    _thinking = false;
    _failed = false;
    _clock.start();
    notifyListeners();
  }

  Future<void> play(int index) async {
    if (!canPlay || !_place(index, CaroMark.x)) return;
    if (_outcome == null) {
      await _reply();
    } else {
      notifyListeners();
    }
  }

  Future<void> retryComputer() async {
    if (_failed && _outcome == null) await _reply();
  }

  Future<void> _reply() async {
    final revision = ++_revision;
    _thinking = true;
    _failed = false;
    notifyListeners();

    int? choice;
    try {
      choice = await _computer((board: _board, difficulty: _difficulty!));
    } catch (error) {
      debugPrint('Caro opponent could not run: $error');
    }
    if (_disposed || revision != _revision) return;

    _thinking = false;
    _failed = choice == null || !_place(choice, CaroMark.o);
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _revision++;
    _thinking = false;
    _failed = false;
    if (_moves.removeLast().mark == CaroMark.o) _moves.removeLast();
    _board = CaroBoard.fromMoves(_moves);
    notifyListeners();
  }

  bool _place(int index, CaroMark mark) {
    final next = _board.place(index, mark);
    if (next == null) return false;
    _moves.add((index: index, mark: mark));
    _board = next;
    _winningLine = List.unmodifiable(next.winningLine(index));
    if (_winningLine.isNotEmpty) {
      _outcome = mark == CaroMark.x
          ? CaroOutcome.playerWin
          : CaroOutcome.computerWin;
    } else if (next.full) {
      _outcome = CaroOutcome.draw;
    }
    if (_outcome != null) _clock.stop();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
