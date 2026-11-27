import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/sudoku/sudoku_board.dart';

void main() {
  const completed = [
    5,
    3,
    4,
    6,
    7,
    8,
    9,
    1,
    2,
    6,
    7,
    2,
    1,
    9,
    5,
    3,
    4,
    8,
    1,
    9,
    8,
    3,
    4,
    2,
    5,
    6,
    7,
    8,
    5,
    9,
    7,
    6,
    1,
    4,
    2,
    3,
    4,
    2,
    6,
    8,
    5,
    3,
    7,
    9,
    1,
    7,
    1,
    3,
    9,
    2,
    4,
    8,
    5,
    6,
    9,
    6,
    1,
    5,
    3,
    7,
    2,
    8,
    4,
    2,
    8,
    7,
    4,
    1,
    9,
    6,
    3,
    5,
    3,
    4,
    5,
    2,
    8,
    6,
    1,
    7,
    9,
  ];

  test('keeps givens immutable and writes or erases an editable cell', () {
    final board = SudokuBoard([...completed]..[0] = 0);
    board.selected = 1;
    board.enter(8);
    board.erase();
    expect(board.valueAt(1), 3);
    expect(board.hasProgress, isFalse);

    board.selected = 0;
    board.enter(2);
    expect(board.valueAt(0), 2);
    expect(board.hasProgress, isTrue);
    board.erase();
    expect(board.valueAt(0), 0);
    expect(board.hasProgress, isFalse);
  });

  test(
    'toggles notes without filling a cell and clears notes on number entry',
    () {
      final board = SudokuBoard([...completed]..[0] = 0)
        ..selected = 0
        ..noteMode = true;
      board.enter(2);
      board.enter(5);
      board.enter(2);
      expect(board.notesAt(0), 1 << 5);
      expect(board.valueAt(0), 0);
      expect(board.hasProgress, isTrue);

      board.noteMode = false;
      board.enter(5);
      expect(board.notesAt(0), 0);
      expect(board.isComplete, isTrue);
      expect(board.canEdit, isFalse);
    },
  );

  test('flags row, column, and block duplicates including givens', () {
    final board = SudokuBoard([...completed]..[0] = 0)..selected = 0;
    board.enter(7);
    expect(board.conflicts, {0, 4, 45, 10});
    expect(board.isComplete, isFalse);
    board.enter(5);
    expect(board.conflicts, isEmpty);
    expect(board.isComplete, isTrue);
  });

  test('highlights the selected row, column, and block', () {
    final board = SudokuBoard([...completed]..[0] = 0)..selected = 0;
    for (final index in [0, 8, 72, 20]) {
      expect(board.isRelated(index), isTrue);
    }
    expect(board.isRelated(30), isFalse);
  });
}
