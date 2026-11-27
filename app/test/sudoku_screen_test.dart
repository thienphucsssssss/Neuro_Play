import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/auth/auth_models.dart';
import 'package:game_tri_tue/core/neuro_theme.dart';
import 'package:game_tri_tue/core/practice_progress.dart';
import 'package:game_tri_tue/sudoku/sudoku_api.dart';
import 'package:game_tri_tue/sudoku/sudoku_puzzle.dart';
import 'package:game_tri_tue/sudoku/sudoku_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'support/sudoku_fixture.dart';

void main() {
  testWidgets('loads, retries, and confirms before discarding notes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    final api = FakeSudokuApi()
      ..load = (difficulty) async {
        if (++attempts == 1) {
          throw const AuthRequestException('Mất kết nối');
        }
        return fixtureSudoku(difficulty);
      };
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SudokuScreen(api: api, authorize: authorizeSudoku),
                ),
              ),
              child: const Text('Mở Sudoku'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở Sudoku'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn độ khó'), findsOneWidget);
    expect(find.text('Vừa'), findsOneWidget);
    expect(find.text('Khó'), findsOneWidget);
    await tester.tap(find.text('Dễ'));
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    final given = find.byKey(const ValueKey('sudoku-cell-0'));
    final blank = fixtureSudoku(SudokuDifficulty.easy).puzzle.indexOf(0);
    final editable = find.byKey(ValueKey('sudoku-cell-$blank'));
    final digit = find.byKey(const ValueKey('sudoku-digit-1'));
    await tester.tap(given);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(digit).onPressed, isNull);

    await tester.tap(editable);
    await tester.tap(find.text('Ghi chú'));
    await tester.pumpAndSettle();
    await tester.tap(digit);
    await tester.pumpAndSettle();
    final note = find.descendant(of: editable, matching: find.text('1'));
    expect(note, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Rời ván Sudoku?'), findsOneWidget);
    await tester.tap(find.text('Chơi tiếp'));
    await tester.pumpAndSettle();
    expect(note, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rời ván'));
    await tester.pumpAndSettle();
    expect(find.text('Mở Sudoku'), findsOneWidget);
  });

  testWidgets(
    'daily Sudoku opens the real game and shows progress after save',
    (tester) async {
      tester.view.physicalSize = const Size(320, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final puzzle = fixtureSudoku(SudokuDifficulty.medium);
      final blank = puzzle.puzzle.indexOf(0);
      final api = FakeSudokuApi()
        ..load = (difficulty) async {
          expect(difficulty, SudokuDifficulty.medium);
          return puzzle;
        }
        ..confirm = (move) async {
          return SudokuMoveReceipt(
            moveNo: move.moveNo,
            mistakes: 0,
            correct: true,
            elapsedSec: 20,
            solved: true,
          );
        }
        ..submit = (sessionId, board) async => SudokuResult(
          sessionId: sessionId,
          difficulty: SudokuDifficulty.medium,
          score: 1460,
          durationSec: 20,
          mistakes: 0,
        );
      final recorded = <SudokuResult>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: NeuroTheme.light(),
          home: SudokuScreen(
            api: api,
            authorize: authorizeSudoku,
            initialDifficulty: SudokuDifficulty.medium,
            recordPractice: (result, day) {
              recorded.add(result);
              return const PracticeProgress.empty().record(
                result.sessionId,
                day,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chọn độ khó'), findsNothing);
      final cell = find.byKey(ValueKey('sudoku-cell-$blank'));
      await tester.tap(cell);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gợi ý'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hàng 1, cột ${blank + 1} còn'), findsWidgets);

      await tester.ensureVisible(find.text('Phóng to'));
      await tester.tap(find.text('Phóng to'));
      await tester.pumpAndSettle();
      final enlarged = find.byKey(ValueKey('enlarged-cell-$blank'));
      expect(tester.getSize(enlarged).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();

      final digit = find.byKey(ValueKey('sudoku-digit-${solvedSudoku[blank]}'));
      await tester.ensureVisible(digit);
      await tester.tap(digit);
      await tester.pumpAndSettle();
      expect(recorded, hasLength(1));
      expect(find.text('Hoàn thành Sudoku!'), findsOneWidget);
      expect(find.text('Suy luận logic'), findsOneWidget);
      expect(find.text('1 / 5 ván'), findsOneWidget);
      expect(find.text('30 / 100 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
