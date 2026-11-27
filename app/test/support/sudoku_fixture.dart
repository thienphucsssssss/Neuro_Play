import 'package:game_tri_tue/sudoku/sudoku_api.dart';
import 'package:game_tri_tue/sudoku/sudoku_puzzle.dart';

final solvedSudoku = List.generate(
  81,
  (index) => (index ~/ 9 * 3 + index ~/ 27 + index % 9) % 9 + 1,
);

SudokuPuzzle fixtureSudoku(SudokuDifficulty difficulty) =>
    SudokuPuzzle.fromJson({
      'sessionId': '1',
      'difficulty': difficulty.name,
      'elapsedSec': 3,
      'puzzle': [
        for (var index = 0; index < 81; index++)
          if (index * 17 % 81 < difficulty.clues) solvedSudoku[index] else 0,
      ],
    });

Future<T> authorizeSudoku<T>(Future<T> Function(String) send) => send('token');

final class FakeSudokuApi implements SudokuApi {
  Future<SudokuPuzzle> Function(SudokuDifficulty)? load;
  Future<SudokuMoveReceipt> Function(SudokuMove)? confirm;
  Future<SudokuResult> Function(String, List<int>)? submit;

  @override
  Future<SudokuPuzzle> newSudoku(
    String accessToken,
    SudokuDifficulty difficulty,
  ) async {
    final handler = load;
    return handler == null ? fixtureSudoku(difficulty) : handler(difficulty);
  }

  @override
  Future<SudokuMoveReceipt> moveSudoku(
    String accessToken,
    SudokuMove move,
  ) async {
    final handler = confirm;
    if (handler == null) throw StateError('Unexpected move.');
    return handler(move);
  }

  @override
  Future<SudokuResult> submitSudoku(
    String accessToken,
    String sessionId,
    List<int> board,
  ) async {
    final handler = submit;
    if (handler == null) throw StateError('Unexpected submit.');
    return handler(sessionId, board);
  }
}
