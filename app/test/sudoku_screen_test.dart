import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/auth/auth_models.dart';
import 'package:game_tri_tue/sudoku/sudoku_puzzle.dart';
import 'package:game_tri_tue/sudoku/sudoku_screen.dart';
import 'package:material_ui/material_ui.dart';

SudokuPuzzle _puzzle() => SudokuPuzzle.fromJson({
  'sessionId': '1',
  'difficulty': 'easy',
  'puzzle': [
    for (var index = 0; index < 81; index++)
      if (index.isEven || index == 1)
        (index ~/ 9 * 3 + index ~/ 27 + index % 9) % 9 + 1
      else
        0,
  ],
});

void main() {
  testWidgets('loads, retries, and confirms before discarding notes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SudokuScreen(
                    loadPuzzle: () async {
                      if (++attempts == 1) {
                        throw const AuthRequestException('Mất kết nối');
                      }
                      return _puzzle();
                    },
                  ),
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
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    final given = find.byKey(const ValueKey('sudoku-cell-0'));
    final editable = find.byKey(const ValueKey('sudoku-cell-3'));
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
}
