import 'dart:math';

final class SlidingBoard {
  SlidingBoard(this.size, Iterable<int> tiles)
    : tiles = List<int>.unmodifiable(tiles) {
    if ((size != 3 && size != 4) ||
        this.tiles.length != size * size ||
        this.tiles.toSet().length != this.tiles.length ||
        this.tiles.any((tile) => tile < 0 || tile >= this.tiles.length)) {
      throw ArgumentError(
        'A sliding board needs one of each tile and a blank.',
      );
    }
  }

  const SlidingBoard._(this.size, this.tiles);

  factory SlidingBoard.solved(int size) {
    if (size != 3 && size != 4) throw ArgumentError.value(size, 'size');
    return SlidingBoard._(
      size,
      List<int>.unmodifiable(
        List.generate(size * size, (i) => (i + 1) % (size * size)),
      ),
    );
  }

  factory SlidingBoard.shuffled(int size, Random random) {
    final solved = SlidingBoard.solved(size);
    final steps = size == 3 ? 12 : 24;
    while (true) {
      var board = solved;
      int? previousBlank;
      for (var step = 0; step < steps; step++) {
        final moves = board.legalMoves
            .where((index) => index != previousBlank)
            .toList();
        previousBlank = board.blank;
        board = board.slide(moves[random.nextInt(moves.length)])!;
      }
      if (!board.isSolved) return board;
    }
  }

  final int size;
  final List<int> tiles;

  int get blank => tiles.indexOf(0);
  bool get isSolved {
    for (var i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles.last == 0;
  }

  List<int> get legalMoves => adjacent(size, blank);

  SlidingBoard? slide(int index) {
    final empty = blank;
    if (!adjacent(size, empty).contains(index)) return null;
    final next = List<int>.of(tiles);
    next[empty] = next[index];
    next[index] = 0;
    return SlidingBoard._(size, List<int>.unmodifiable(next));
  }

  static List<int> adjacent(int size, int index) => [
    if (index >= size) index - size,
    if (index % size > 0) index - 1,
    if (index % size < size - 1) index + 1,
    if (index < size * (size - 1)) index + size,
  ];
}
