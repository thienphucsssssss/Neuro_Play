import 'dart:math';

import 'caro_board.dart';

enum CaroDifficulty {
  easy('Dễ', 1),
  medium('Vừa', 2),
  hard('Khó', 4);

  const CaroDifficulty(this.label, this.depth);

  final String label;
  final int depth;
}

typedef CaroPosition = ({CaroBoard board, CaroDifficulty difficulty});

int? chooseCaroMove(CaroPosition position, {int maxNodes = 25000}) {
  if (position.board.full) return null;
  return _CaroSearch(position.board, maxNodes).run(position.difficulty.depth);
}

class _CaroSearch {
  _CaroSearch(CaroBoard board, this.maxNodes)
    : cells = List.of(board.cells),
      occupied = board.cells.whereType<CaroMark>().length;

  static const _win = 100000000;
  static const _limit = 12;
  final List<CaroMark?> cells;
  final int maxNodes;
  final int occupied;
  int _nodes = 0;

  int run(int depth) {
    final candidates = _ordered(CaroMark.o);
    var best = candidates.first;
    // Keep the previous complete iteration when a deeper search runs out of budget.
    for (var limit = 1; limit <= depth; limit++) {
      try {
        var candidate = best;
        var value = -_win - 1;
        for (final index in [best, ...candidates.where((i) => i != best)]) {
          final score = _play(index, CaroMark.o, limit, 1, value, _win + 1);
          if (score > value) {
            value = score;
            candidate = index;
          }
        }
        best = candidate;
        if (value >= _win - limit) break;
      } on _BudgetExhausted {
        break;
      }
    }
    return best;
  }

  int _play(
    int index,
    CaroMark mark,
    int remaining,
    int ply,
    int alpha,
    int beta,
  ) {
    if (_nodes >= maxNodes) throw const _BudgetExhausted();
    _nodes++;
    cells[index] = mark;
    try {
      if (_wins(index, mark)) {
        return mark == CaroMark.o ? _win - ply : -_win + ply;
      }
      if (occupied + ply == CaroBoard.cellCount) return 0;
      if (remaining == 1) return _evaluate();

      final next = mark.opponent;
      final maximizing = next == CaroMark.o;
      var lower = alpha;
      var upper = beta;
      var best = maximizing ? -_win - 1 : _win + 1;
      for (final candidate in _ordered(next)) {
        final score = _play(
          candidate,
          next,
          remaining - 1,
          ply + 1,
          lower,
          upper,
        );
        if (maximizing) {
          best = max(best, score);
          lower = max(lower, best);
        } else {
          best = min(best, score);
          upper = min(upper, best);
        }
        if (lower >= upper) break;
      }
      return best;
    } finally {
      cells[index] = null;
    }
  }

  List<int> _ordered(CaroMark mark) {
    final near = <int>{};
    for (var index = 0; index < cells.length; index++) {
      if (cells[index] == null) continue;
      final row = index ~/ CaroBoard.size;
      final col = index % CaroBoard.size;
      for (
        var r = max(0, row - 2);
        r <= min(CaroBoard.size - 1, row + 2);
        r++
      ) {
        for (
          var c = max(0, col - 2);
          c <= min(CaroBoard.size - 1, col + 2);
          c++
        ) {
          final candidate = r * CaroBoard.size + c;
          if (cells[candidate] == null) near.add(candidate);
        }
      }
    }
    if (near.isEmpty) return [CaroBoard.center];

    final ranked =
        [
          for (final index in near)
            (
              index: index,
              own: _potential(index, mark),
              opponent: _potential(index, mark.opponent),
            ),
        ]..sort((a, b) {
          final tactical = _priority(
            b.own,
            b.opponent,
          ).compareTo(_priority(a.own, a.opponent));
          if (tactical != 0) return tactical;
          final strength = (b.own + b.opponent).compareTo(a.own + a.opponent);
          if (strength != 0) return strength;
          final center = _centerDistance(a.index)
              .compareTo(_centerDistance(b.index));
          return center != 0 ? center : a.index.compareTo(b.index);
        });

    final first = ranked.first;
    if (first.own == _win) return [first.index];
    if (first.opponent == _win) {
      return [
        for (final entry in ranked)
          if (entry.opponent == _win) entry.index,
      ];
    }
    return ranked.take(_limit).map((entry) => entry.index).toList();
  }

  int _priority(int own, int opponent) =>
      own == _win ? 2 : (opponent == _win ? 1 : 0);

  int _centerDistance(int index) {
    const mid = CaroBoard.size ~/ 2;
    return (index ~/ CaroBoard.size - mid).abs() +
        (index % CaroBoard.size - mid).abs();
  }

  bool _wins(int index, CaroMark mark) => CaroBoard.runsThrough(
    cells,
    index,
    mark,
  ).any((run) => run.before + run.after >= 4);

  int _potential(int index, CaroMark mark) {
    var score = 0;
    for (final run in CaroBoard.runsThrough(cells, index, mark)) {
      final length = run.before + run.after + 1;
      if (length >= 5) return _win;
      score += _weight(length, run.openEnds);
    }
    return score;
  }

  int _evaluate() {
    var value = 0;
    for (var index = 0; index < cells.length; index++) {
      final mark = cells[index];
      if (mark == null) continue;
      var score = 0;
      for (final run in CaroBoard.runsThrough(cells, index, mark)) {
        if (run.before == 0) score += _weight(run.after + 1, run.openEnds);
      }
      value += mark == CaroMark.o ? score : -score;
    }
    return value;
  }

  int _weight(int length, int openEnds) {
    if (openEnds == 0) return 0;
    final base = switch (length) {
      4 => 1000,
      3 => 100,
      2 => 10,
      _ => 1,
    };
    return openEnds == 2 ? 10 * base : base;
  }
}

class _BudgetExhausted implements Exception {
  const _BudgetExhausted();
}
