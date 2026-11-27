import 'dart:math';

import 'sliding_board.dart';

int? findSlidingHint(SlidingBoard board, {int maxNodes = 120000}) =>
    board.isSolved ? null : _HintSearch(board, maxNodes).run(board.blank);

class _HintSearch {
  _HintSearch(SlidingBoard board, this.maxNodes)
    : tiles = List.of(board.tiles),
      neighbors = List.generate(
        board.tiles.length,
        (i) => SlidingBoard.adjacent(board.size, i),
      ),
      distances = List.generate(
        board.tiles.length,
        (tile) => List.generate(
          board.tiles.length,
          (index) =>
              (index ~/ board.size - (tile - 1) ~/ board.size).abs() +
              (index % board.size - (tile - 1) % board.size).abs(),
        ),
      );

  static const _exhausted = 1 << 30;
  static const _found = -1;
  final int maxNodes;
  final List<int> tiles;
  final List<List<int>> neighbors;
  final List<List<int>> distances;
  int _nodes = 0;
  int? _suggestion;

  int? run(int blank) {
    var distance = 0;
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] != 0) distance += distances[tiles[i]][i];
    }
    var bound = distance;
    while (bound != _exhausted) {
      bound = _search(blank, -1, distance, 0, bound, null);
      if (bound == _found) return _suggestion;
      if (_nodes >= maxNodes) return null;
    }
    return null;
  }

  int _search(
    int blank,
    int previousBlank,
    int distance,
    int depth,
    int bound,
    int? firstMove,
  ) {
    if (_nodes >= maxNodes) return _exhausted;
    _nodes++;
    final estimate = distance + depth;
    if (estimate > bound) return estimate;
    if (distance == 0) {
      _suggestion = firstMove;
      return _found;
    }

    var nextBound = _exhausted;
    for (final index in neighbors[blank]) {
      if (index == previousBlank) continue;
      final tile = tiles[index];
      tiles[blank] = tile;
      tiles[index] = 0;
      final result = _search(
        index,
        blank,
        distance + distances[tile][blank] - distances[tile][index],
        depth + 1,
        bound,
        firstMove ?? index,
      );
      tiles[index] = tile;
      tiles[blank] = 0;
      if (result == _found) return result;
      nextBound = min(nextBound, result);
      if (_nodes >= maxNodes) break;
    }
    return nextBound;
  }
}
