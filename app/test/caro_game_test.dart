import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/games/caro/caro_ai.dart';
import 'package:game_tri_tue/games/caro/caro_board.dart';
import 'package:game_tri_tue/games/caro/caro_game.dart';
import 'package:game_tri_tue/games/round_clock.dart';

void main() {
  test('detects both diagonal directions, vertical and horizontal wins', () {
    for (final step in [1, 15, 16, 14]) {
      final line = [for (var i = 0; i < 5; i++) 53 + i * step];
      final board = _board(x: line);
      expect(board.winningLine(line[2]), orderedEquals(line));
    }
    final overline = [for (var i = 0; i < 6; i++) 34 + i];
    final board = _board(o: overline);
    expect(board.winningLine(36), overline);
    expect(board.place(36, CaroMark.x), isNull);
    expect(board.place(-1, CaroMark.x), isNull);
    expect(_board(x: [12, 13, 14, 15, 16]).winningLine(14), isEmpty);
  });

  test('reaches a draw on a full board with no winner', () async {
    final x = <int>[];
    final o = <int>[];
    for (var i = 0; i < CaroBoard.cellCount; i++) {
      final group = (i ~/ CaroBoard.size + 2 * (i % CaroBoard.size)) % 4;
      (group < 2 ? x : o).add(i);
    }
    if (x.length < o.length) {
      final extra = x.toList();
      x
        ..clear()
        ..addAll(o);
      o
        ..clear()
        ..addAll(extra);
    }
    var next = 0;
    final game = CaroGame(computer: (_) async => o[next++]);
    addTearDown(game.dispose);
    game.start(CaroDifficulty.easy);
    for (final index in x) {
      await game.play(index);
    }
    expect(game.board.full, isTrue);
    expect(game.winningLine, isEmpty);
    expect(game.outcome, CaroOutcome.draw);
    expect(game.moveCount, 225);
  });

  test('all AI settings prioritize immediate wins and block a forced loss', () {
    final row = 105;
    final winning = _board(
      x: [row + 4, 70, 71, 72, 73],
      o: [row + 5, row + 6, row + 7, row + 8],
    );
    final blocking = _board(
      x: [row + 5, row + 6, row + 7, row + 8],
      o: [row + 4, 63, 121, 195],
    );
    for (final difficulty in CaroDifficulty.values) {
      expect(chooseCaroMove((board: winning, difficulty: difficulty)), row + 9);
      expect(
        chooseCaroMove((board: blocking, difficulty: difficulty)),
        row + 9,
      );
      final regular = (
        board: _board(x: [112, 128, 127], o: [113, 111]),
        difficulty: difficulty,
      );
      final move = chooseCaroMove(regular);
      expect(regular.board.isEmpty(move!), isTrue);
      expect(chooseCaroMove(regular), move);
      expect(
        regular.board.isEmpty(chooseCaroMove(regular, maxNodes: 0)!),
        isTrue,
      );
    }
  });

  test(
    'undo removes a pair and ignores a pending reply and a prior round',
    () async {
      final replies = [for (var i = 0; i < 3; i++) Completer<int?>()];
      var issued = 0;
      final game = CaroGame(computer: (_) => replies[issued++].future);
      addTearDown(game.dispose);
      game.start(CaroDifficulty.medium);

      final first = game.play(112);
      await game.play(110);
      expect(game.moveCount, 1);
      replies[0].complete(113);
      await first;
      expect(game.moves.map((move) => move.index), [112, 113]);
      game.undo();
      expect(game.moveCount, 0);

      final second = game.play(112);
      expect(game.thinking, isTrue);
      game.undo();
      replies[1].complete(113);
      await second;
      expect(game.canPlay, isTrue);
      expect(game.moveCount, 0);

      final previous = game.play(112);
      game.start(CaroDifficulty.hard);
      replies[2].complete(113);
      await previous;
      expect(game.moveCount, 0);
      expect(game.difficulty, CaroDifficulty.hard);
    },
  );

  test('leaving the game drops an unfinished computer reply', () async {
    final pending = Completer<int?>();
    final game = CaroGame(computer: (_) => pending.future);
    game.start(CaroDifficulty.hard);
    final turn = game.play(112);
    expect(game.thinking, isTrue);
    game.dispose();
    pending.complete(113);
    await turn;
    expect(game.board.cells[113], isNull);
  });

  test('records a winning line and freezes the finished round clock', () async {
    var now = Duration.zero;
    var opponent = 180;
    final game = CaroGame(
      clock: RoundClock(now: () => now),
      computer: (_) async => opponent++,
    );
    addTearDown(game.dispose);
    game.start(CaroDifficulty.easy);
    for (var i = 0; i < 5; i++) {
      now += const Duration(seconds: 1);
      await game.play(60 + i);
    }
    expect(game.outcome, CaroOutcome.playerWin);
    expect(game.moveCount, 9);
    expect(game.winningLine, [60, 61, 62, 63, 64]);
    expect(CaroBoard.fromMoves(game.moves.take(2)).cells[180], CaroMark.o);
    expect(game.canUndo, isFalse);
    now += const Duration(seconds: 10);
    expect(game.elapsed, const Duration(seconds: 5));
  });
}

CaroBoard _board({List<int> x = const [], List<int> o = const []}) =>
    CaroBoard.fromMoves([
      for (final index in x) (index: index, mark: CaroMark.x),
      for (final index in o) (index: index, mark: CaroMark.o),
    ]);
