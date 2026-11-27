enum CaroMark {
  x,
  o;

  CaroMark get opponent => this == x ? o : x;
  String get label => this == x ? 'X' : 'O';
}

enum CaroOutcome { playerWin, computerWin, draw }

typedef CaroMove = ({int index, CaroMark mark});
typedef CaroRun = ({int row, int column, int before, int after, int openEnds});

final class CaroBoard {
  CaroBoard.empty()
    : cells = List<CaroMark?>.unmodifiable(List.filled(cellCount, null));

  CaroBoard.fromCells(Iterable<CaroMark?> cells)
    : cells = List<CaroMark?>.unmodifiable(cells) {
    if (this.cells.length != cellCount) {
      throw ArgumentError('Caro uses a 15 by 15 board.');
    }
  }

  factory CaroBoard.fromMoves(Iterable<CaroMove> moves) {
    final cells = List<CaroMark?>.filled(cellCount, null);
    for (final move in moves) {
      cells[move.index] = move.mark;
    }
    return CaroBoard.fromCells(cells);
  }

  static const size = 15;
  static const cellCount = size * size;
  static const center = cellCount ~/ 2;
  static const _directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

  final List<CaroMark?> cells;

  bool get full => !cells.contains(null);

  bool isEmpty(int index) =>
      index >= 0 && index < cellCount && cells[index] == null;

  CaroBoard? place(int index, CaroMark mark) {
    if (!isEmpty(index)) return null;
    final next = List.of(cells)..[index] = mark;
    return CaroBoard.fromCells(next);
  }

  List<int> winningLine(int index) {
    final mark = cells[index];
    if (mark == null) return const [];
    for (final run in runsThrough(cells, index, mark)) {
      if (run.before + run.after + 1 >= 5) {
        return [
          for (var step = -run.before; step <= run.after; step++)
            index + step * (run.row * size + run.column),
        ];
      }
    }
    return const [];
  }

  // The center can be empty when evaluating a possible move.
  static Iterable<CaroRun> runsThrough(
    List<CaroMark?> cells,
    int index,
    CaroMark mark,
  ) sync* {
    final row = index ~/ size;
    final column = index % size;
    for (final (dr, dc) in _directions) {
      final (before, openBefore) = _walk(cells, row, column, -dr, -dc, mark);
      final (after, openAfter) = _walk(cells, row, column, dr, dc, mark);
      yield (
        row: dr,
        column: dc,
        before: before,
        after: after,
        openEnds: (openBefore ? 1 : 0) + (openAfter ? 1 : 0),
      );
    }
  }

  static (int, bool) _walk(
    List<CaroMark?> cells,
    int row,
    int column,
    int dr,
    int dc,
    CaroMark mark,
  ) {
    var count = 0;
    row += dr;
    column += dc;
    while (row >= 0 && row < size && column >= 0 && column < size) {
      final cell = cells[row * size + column];
      if (cell != mark) return (count, cell == null);
      count++;
      row += dr;
      column += dc;
    }
    return (count, false);
  }
}
