import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/games/round_clock.dart';
import 'package:game_tri_tue/games/sliding/sliding_board.dart';
import 'package:game_tri_tue/games/sliding/sliding_game.dart';
import 'package:game_tri_tue/games/sliding/sliding_hint.dart';

void main() {
  test('shuffled boards of both sizes can reverse the legal shuffle', () {
    for (final size in [3, 4]) {
      for (var seed = 0; seed < 50; seed++) {
        final random = _LoggedRandom(seed);
        final actual = SlidingBoard.shuffled(size, random);
        final steps = size == 3 ? 12 : 24;
        expect(random.choices.length >= steps, isTrue);
        expect(random.choices.length % steps, 0);

        final expected = List.of(SlidingBoard.solved(size).tiles);
        final blankPositions = <int>[];
        for (final choice in random.choices.skip(
          random.choices.length - steps,
        )) {
          final blank = expected.indexOf(0);
          final previous = blankPositions.isEmpty ? null : blankPositions.last;
          final options = [
            if (blank >= size) blank - size,
            if (blank % size != 0) blank - 1,
            if (blank % size != size - 1) blank + 1,
            if (blank < size * (size - 1)) blank + size,
          ]..remove(previous);
          final target = options[choice];
          blankPositions.add(blank);
          expected[blank] = expected[target];
          expected[target] = 0;
        }
        expect(actual.tiles, expected, reason: '$size, seed $seed');
        expect(actual.isSolved, isFalse);
        var restored = actual;
        for (final previous in blankPositions.reversed) {
          restored = restored.slide(previous)!;
        }
        expect(restored.isSolved, isTrue);
      }
    }
  });

  test('only legal moves count and the solved clock stops', () {
    var now = const Duration(seconds: 10);
    final game = SlidingGame(
      clock: RoundClock(now: () => now),
      newBoard: (size, _) => SlidingBoard.solved(size).slide(7)!,
    );
    addTearDown(game.dispose);
    game.start(3);
    game.slide(3);
    expect(game.moves, 0);
    expect(game.board!.blank, 7);

    now = const Duration(seconds: 14);
    game.slide(8);
    expect(game.completed, isTrue);
    expect(game.moves, 1);
    game.slide(7);
    now = const Duration(seconds: 20);
    expect(game.elapsed, const Duration(seconds: 4));
    expect(game.moves, 1);
  });

  test(
    'IDA* returns reversible legal next moves or signals its node limit',
    () {
      for (final size in [3, 4]) {
        var board = SlidingBoard.shuffled(size, Random(size));
        expect(findSlidingHint(board, maxNodes: 0), isNull);
        for (var step = 0; step < 24 && !board.isSolved; step++) {
          final suggested = findSlidingHint(board);
          expect(board.legalMoves, contains(suggested));
          board = board.slide(suggested!)!;
        }
        expect(board.isSolved, isTrue);
      }
    },
  );

  test('an asynchronous hint cannot overwrite a newer board', () async {
    final pending = Completer<int?>();
    final game = SlidingGame(
      newBoard: (size, _) => SlidingBoard.solved(size).slide(7)!,
      hintRunner: (_) => pending.future,
    );
    addTearDown(game.dispose);
    game.start(3);
    final request = game.requestHint();
    expect(game.searching, isTrue);
    game.slide(6);
    pending.complete(8);
    await request;
    expect(game.hint, isNull);
    expect(game.searching, isFalse);
  });
}

class _LoggedRandom implements Random {
  _LoggedRandom(int seed) : _random = Random(seed);

  final Random _random;
  final choices = <int>[];

  @override
  int nextInt(int max) {
    final value = _random.nextInt(max);
    choices.add(value);
    return value;
  }

  @override
  bool nextBool() => _random.nextBool();

  @override
  double nextDouble() => _random.nextDouble();
}
