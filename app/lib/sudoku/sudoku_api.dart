import 'sudoku_puzzle.dart';

typedef SudokuAuthorize = Future<T> Function<T>(Future<T> Function(String));

abstract interface class SudokuApi {
  Future<SudokuPuzzle> newSudoku(
    String accessToken,
    SudokuDifficulty difficulty,
  );
  Future<SudokuMoveReceipt> moveSudoku(String accessToken, SudokuMove move);
  Future<SudokuResult> submitSudoku(
    String accessToken,
    String sessionId,
    List<int> board,
  );
}

final class SudokuMove {
  const SudokuMove({
    required this.sessionId,
    required this.moveNo,
    required this.cellIndex,
    required this.value,
  });

  final String sessionId;
  final int moveNo;
  final int cellIndex;
  final int value;

  Map<String, Object> toJson() => {
    'sessionId': sessionId,
    'moveNo': moveNo,
    'cellIndex': cellIndex,
    'value': value,
  };
}

final class SudokuMoveReceipt {
  const SudokuMoveReceipt({
    required this.moveNo,
    required this.mistakes,
    required this.correct,
    required this.elapsedSec,
    required this.solved,
  });

  factory SudokuMoveReceipt.fromJson(Map<String, dynamic> json) =>
      switch (json) {
        {
          'moveNo': int moveNo,
          'mistakes': int mistakes,
          'correct': bool? correct,
          'elapsedSec': int elapsedSec,
          'solved': bool solved,
        }
            when moveNo > 0 && mistakes >= 0 && elapsedSec >= 0 =>
          SudokuMoveReceipt(
            moveNo: moveNo,
            mistakes: mistakes,
            correct: correct,
            elapsedSec: elapsedSec,
            solved: solved,
          ),
        _ => throw const FormatException('Invalid Sudoku move receipt'),
      };

  final int moveNo;
  final int mistakes;
  final bool? correct;
  final int elapsedSec;
  final bool solved;
}

final class SudokuResult {
  const SudokuResult({
    required this.sessionId,
    required this.difficulty,
    required this.score,
    required this.durationSec,
    required this.mistakes,
  });

  factory SudokuResult.fromJson(Map<String, dynamic> json) => switch (json) {
    {
      'sessionId': String sessionId,
      'difficulty': String difficulty,
      'score': int score,
      'durationSec': int durationSec,
      'mistakes': int mistakes,
    }
        when score >= 0 && durationSec >= 0 && mistakes >= 0 =>
      SudokuResult(
        sessionId: sessionId,
        difficulty: SudokuDifficulty.fromCode(difficulty),
        score: score,
        durationSec: durationSec,
        mistakes: mistakes,
      ),
    _ => throw const FormatException('Invalid Sudoku result'),
  };

  final String sessionId;
  final SudokuDifficulty difficulty;
  final int score;
  final int durationSec;
  final int mistakes;
}
