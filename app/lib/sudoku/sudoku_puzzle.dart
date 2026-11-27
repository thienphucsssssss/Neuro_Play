import 'sudoku_board.dart';

enum SudokuDifficulty {
  easy('Dễ', 42),
  medium('Vừa', 34),
  hard('Khó', 28);

  const SudokuDifficulty(this.label, this.clues);

  final String label;
  final int clues;

  static SudokuDifficulty fromCode(String code) => switch (code) {
    'easy' => easy,
    'medium' => medium,
    'hard' => hard,
    _ => throw const FormatException('Invalid Sudoku difficulty'),
  };
}

final class SudokuPuzzle {
  const SudokuPuzzle._(
    this.sessionId,
    this.difficulty,
    this.puzzle,
    this.elapsedSec,
  );

  factory SudokuPuzzle.fromJson(Map<String, dynamic> json) {
    if (json
        case {
          'sessionId': String id,
          'difficulty': String difficultyCode,
          'puzzle': List<Object?> cells,
          'elapsedSec': int elapsedSec,
        }
        when RegExp(r'^[1-9][0-9]*$').hasMatch(id) &&
            elapsedSec >= 0 &&
            cells.length == 81 &&
            cells.every((cell) => cell is int && cell >= 0 && cell <= 9)) {
      final difficulty = SudokuDifficulty.fromCode(difficultyCode);
      final givens = List<int>.unmodifiable(cells.cast<int>());
      if (givens.where((digit) => digit != 0).length == difficulty.clues &&
          SudokuBoard(givens).conflicts.isEmpty) {
        return SudokuPuzzle._(id, difficulty, givens, elapsedSec);
      }
    }
    throw const FormatException('Invalid Sudoku puzzle');
  }

  final String sessionId;
  final SudokuDifficulty difficulty;
  final List<int> puzzle;
  final int elapsedSec;
}
