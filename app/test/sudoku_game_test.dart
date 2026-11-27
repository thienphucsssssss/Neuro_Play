import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/auth/auth_models.dart';
import 'package:game_tri_tue/sudoku/sudoku_api.dart';
import 'package:game_tri_tue/sudoku/sudoku_game.dart';
import 'package:game_tri_tue/sudoku/sudoku_puzzle.dart';

import 'support/sudoku_fixture.dart';

void main() {
  late FakeSudokuApi api;
  late SudokuGame game;
  late DateTime now;

  setUp(() {
    api = FakeSudokuApi();
    now = DateTime.utc(2026, 11, 27);
    game = SudokuGame(api: api, authorize: authorizeSudoku, now: () => now);
  });

  tearDown(() => game.dispose());

  test(
    'the display counts time asleep without waiting for a new move',
    () async {
      await game.start(SudokuDifficulty.easy);
      expect(game.elapsedSec, 3);
      now = now.add(const Duration(minutes: 3));
      expect(game.elapsedSec, 183);
    },
  );

  test(
    'reuses the pending move after a lost response and counts a mistake once',
    () async {
      await game.start(SudokuDifficulty.medium);
      expect(game.phase, SudokuPhase.playing);
      expect(game.difficulty, SudokuDifficulty.medium);

      final blank = fixtureSudoku(SudokuDifficulty.medium).puzzle.indexOf(0);
      final wrong = solvedSudoku[blank] % 9 + 1;
      final pending = Completer<SudokuMoveReceipt>();
      final sent = <SudokuMove>[];
      api.confirm = (move) async {
        sent.add(move);
        if (sent.length == 1) return pending.future;
        return SudokuMoveReceipt(
          moveNo: move.moveNo,
          mistakes: 1,
          correct: false,
          elapsedSec: 8,
          solved: false,
        );
      };
      game.select(blank);
      final request = game.enter(wrong);
      expect(game.board?.valueAt(blank), 0);
      await game.enter(solvedSudoku[blank]);
      expect(sent, hasLength(1));
      pending.completeError(const AuthRequestException('Mất kết nối'));
      await request;
      expect(game.hasPendingMove, isTrue);
      expect(game.board?.valueAt(blank), 0);
      expect(game.mistakes, 0);
      await game.retryMove();

      expect(sent[1].toJson(), sent[0].toJson());
      expect(game.board?.valueAt(blank), wrong);
      expect(game.board?.isWrong(blank), isTrue);
      expect(game.mistakes, 1);
      expect(game.hasPendingMove, isFalse);
    },
  );

  test(
    'locks the solved board, freezes time and retries the identical submission',
    () async {
      await game.start(SudokuDifficulty.easy);
      final givens = fixtureSudoku(SudokuDifficulty.easy).puzzle;
      final blanks = Iterable<int>.generate(81)
          .where((i) => givens[i] == 0)
          .toList();
      final submissions = <List<int>>[];
      api.confirm = (move) async => SudokuMoveReceipt(
        moveNo: move.moveNo,
        mistakes: 0,
        correct: true,
        elapsedSec: 23,
        solved: move.moveNo == blanks.length,
      );
      api.submit = (id, board) async {
        expect(id, '1');
        submissions.add(board);
        if (submissions.length == 1) {
          throw const AuthRequestException('Mất kết nối');
        }
        return const SudokuResult(
          sessionId: '1',
          difficulty: SudokuDifficulty.easy,
          score: 954,
          durationSec: 23,
          mistakes: 0,
        );
      };
      for (final index in blanks) {
        game.select(index);
        await game.enter(solvedSudoku[index]);
      }
      expect(game.phase, SudokuPhase.submitFailed);
      expect(game.elapsedSec, 23);
      expect(game.canInteract, isFalse);
      expect(game.requiresExitConfirmation, isTrue);
      await game.retrySubmit();

      expect(submissions, [solvedSudoku, solvedSudoku]);
      expect(game.phase, SudokuPhase.completed);
      expect(game.result?.score, 954);
      expect(game.requiresExitConfirmation, isFalse);
    },
  );
}
