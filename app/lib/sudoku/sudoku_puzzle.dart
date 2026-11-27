import 'sudoku_board.dart';

final class SudokuPuzzle {
  SudokuPuzzle.fromJson(Map<String, dynamic> json) {
    if (json
        case {
          'sessionId': String id,
          'difficulty': 'easy',
          'puzzle': List<Object?> cells,
        }
        when RegExp(r'^[1-9][0-9]*$').hasMatch(id) &&
            cells.length == 81 &&
            cells.every((cell) => cell is int && cell >= 0 && cell <= 9)) {
      final givens = List<int>.unmodifiable(cells.cast<int>());
      if (givens.where((digit) => digit != 0).length == 42 &&
          SudokuBoard(givens).conflicts.isEmpty) {
        sessionId = id;
        puzzle = givens;
        return;
      }
    }
    throw const FormatException('Invalid Sudoku puzzle');
  }

  late final String sessionId;
  late final List<int> puzzle;
}
