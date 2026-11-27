import 'dart:math';

import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import 'sudoku_api.dart';
import 'sudoku_board.dart';
import 'sudoku_puzzle.dart';

enum SudokuPhase {
  choosing,
  loading,
  loadFailed,
  playing,
  submitting,
  submitFailed,
  completed,
}

final class SudokuGame extends ChangeNotifier {
  SudokuGame({
    required this.api,
    required this.authorize,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SudokuApi api;
  final SudokuAuthorize authorize;

  final DateTime Function() _now;
  DateTime? _clockAnchor;
  SudokuPhase _phase = SudokuPhase.choosing;
  SudokuDifficulty? _difficulty;
  SudokuPuzzle? _puzzle;
  SudokuBoard? _board;
  SudokuMove? _pendingMove;
  SudokuResult? _result;
  String? _error;
  int _baseElapsedSec = 0;
  int _mistakes = 0;
  int? _lastCorrectIndex;
  int _nextMoveNo = 1;
  bool _sendingMove = false;
  bool _disposed = false;

  SudokuPhase get phase => _phase;
  SudokuBoard? get board => _board;
  SudokuDifficulty? get difficulty => _difficulty;
  SudokuResult? get result => _result;
  String? get error => _error;
  int get elapsedSec {
    final anchor = _clockAnchor;
    return _baseElapsedSec +
        (anchor == null ? 0 : max(0, _now().difference(anchor).inSeconds));
  }

  int get mistakes => _mistakes;
  int? get lastCorrectIndex => _lastCorrectIndex;
  bool get hasPendingMove => _pendingMove != null;
  bool get sendingMove => _sendingMove;
  bool get canInteract => _phase == SudokuPhase.playing && !hasPendingMove;
  bool get requiresExitConfirmation =>
      _phase != SudokuPhase.completed &&
      (hasPendingMove || _nextMoveNo > 1 || (_board?.hasProgress ?? false));

  Future<void> start(SudokuDifficulty difficulty) async {
    if (_phase != SudokuPhase.choosing && _phase != SudokuPhase.loadFailed) {
      return;
    }
    _difficulty = difficulty;
    _phase = SudokuPhase.loading;
    _error = null;
    _changed();
    try {
      final puzzle = await authorize(
        (token) => api.newSudoku(token, difficulty),
      );
      if (_disposed) return;
      if (puzzle.difficulty != difficulty) {
        throw const FormatException('Unexpected Sudoku difficulty');
      }
      _puzzle = puzzle;
      _board = SudokuBoard(puzzle.puzzle);
      _phase = SudokuPhase.playing;
      _syncClock(puzzle.elapsedSec, run: true);
    } on Exception catch (error) {
      _phase = SudokuPhase.loadFailed;
      _error = _message(error);
    } finally {
      _changed();
    }
  }

  Future<void> retryLoad() async {
    final difficulty = _difficulty;
    if (_phase == SudokuPhase.loadFailed && difficulty != null) {
      await start(difficulty);
    }
  }

  void chooseAgain() {
    if (_phase != SudokuPhase.completed && _phase != SudokuPhase.loadFailed) {
      return;
    }
    _phase = SudokuPhase.choosing;
    _difficulty = null;
    _puzzle = null;
    _board = null;
    _result = null;
    _error = null;
    _mistakes = 0;
    _lastCorrectIndex = null;
    _nextMoveNo = 1;
    _syncClock(0, run: false);
    _changed();
  }

  void select(int index) {
    if (!canInteract) return;
    _board!.selected = index;
    _changed();
  }

  void toggleNotes(bool value) {
    if (!canInteract) return;
    _board!.noteMode = value;
    _changed();
  }

  Future<void> enter(int value) async {
    final board = _board;
    if (!canInteract || board == null || !board.canEdit) return;
    if (board.noteMode) {
      board.enter(value);
      _changed();
      return;
    }
    await _queueMove(board, value);
  }

  Future<void> erase() async {
    final board = _board;
    if (!canInteract || board == null || !board.canEdit) return;
    if (board.valueAt(board.selected!) == 0) {
      board.erase();
      _changed();
      return;
    }
    await _queueMove(board, 0);
  }

  Future<void> _queueMove(SudokuBoard board, int value) async {
    final index = board.selected!;
    if (board.valueAt(index) == value) return;
    _pendingMove = SudokuMove(
      sessionId: _puzzle!.sessionId,
      moveNo: _nextMoveNo,
      cellIndex: index,
      value: value,
    );
    await retryMove();
  }

  Future<void> retryMove() async {
    final move = _pendingMove;
    if (_phase != SudokuPhase.playing || move == null || _sendingMove) return;
    final replay = _error != null;
    _sendingMove = true;
    _error = null;
    _changed();
    try {
      final receipt = await authorize((token) => api.moveSudoku(token, move));
      if (_disposed) return;
      if (receipt.moveNo != move.moveNo ||
          (receipt.correct == null) != (move.value == 0) ||
          receipt.mistakes < _mistakes) {
        throw const FormatException('Unexpected Sudoku move receipt');
      }
      _board!.confirmValue(
        move.cellIndex,
        move.value,
        correct: receipt.correct,
      );
      _mistakes = receipt.mistakes;
      _lastCorrectIndex = receipt.correct == true ? move.cellIndex : null;
      _nextMoveNo = move.moveNo + 1;
      _pendingMove = null;
      _syncClock(
        replay && !receipt.solved
            ? max(elapsedSec, receipt.elapsedSec)
            : receipt.elapsedSec,
        run: !receipt.solved,
      );
      if (receipt.solved) _phase = SudokuPhase.submitting;
    } on Exception catch (error) {
      _error = _message(error);
    } finally {
      _sendingMove = false;
      _changed();
    }
    if (!_disposed && _phase == SudokuPhase.submitting) await _submit();
  }

  Future<void> retrySubmit() async {
    if (_phase != SudokuPhase.submitFailed) return;
    _phase = SudokuPhase.submitting;
    await _submit();
  }

  Future<void> _submit() async {
    _error = null;
    _changed();
    try {
      final puzzle = _puzzle!;
      final snapshot = _board!.snapshot();
      final result = await authorize(
        (token) => api.submitSudoku(token, puzzle.sessionId, snapshot),
      );
      if (_disposed) return;
      if (result.sessionId != puzzle.sessionId ||
          result.difficulty != puzzle.difficulty) {
        throw const FormatException('Unexpected Sudoku result');
      }
      _result = result;
      _phase = SudokuPhase.completed;
    } on Exception catch (error) {
      _phase = SudokuPhase.submitFailed;
      _error = _message(error);
    } finally {
      _changed();
    }
  }

  void _syncClock(int elapsedSec, {required bool run}) {
    _baseElapsedSec = elapsedSec;
    _clockAnchor = run ? _now() : null;
  }

  String _message(Exception error) => error is FormatException
      ? 'Phản hồi từ máy chủ không hợp lệ.'
      : authErrorMessage(error);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
