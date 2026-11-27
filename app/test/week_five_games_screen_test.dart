import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/core/neuro_theme.dart';
import 'package:game_tri_tue/games/caro/caro_board.dart';
import 'package:game_tri_tue/games/caro/caro_game.dart';
import 'package:game_tri_tue/games/caro/caro_screen.dart';
import 'package:game_tri_tue/games/sliding/sliding_board.dart';
import 'package:game_tri_tue/games/sliding/sliding_game.dart';
import 'package:game_tri_tue/games/sliding/sliding_hint.dart';
import 'package:game_tri_tue/games/sliding/sliding_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('slides an indicated tile and displays the completed round', (
    tester,
  ) async {
    _narrowWindow(tester);
    final game = SlidingGame(
      newBoard: (size, _) => SlidingBoard.solved(size).slide(7)!,
      hintRunner: (board) async => findSlidingHint(board),
    );
    await tester.pumpWidget(_app(SlidingScreen(createGame: () => game)));
    await tester.tap(find.text('3 × 3'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Gợi ý'));
    expect(find.textContaining('trượt ô số 8'), findsOneWidget);
    expect(game.moves, 0);
    final suggestion = find.bySemanticsLabel(RegExp(r'^Ô số 8, gợi ý'));
    expect(tester.getSize(suggestion).shortestSide, greaterThanOrEqualTo(48));
    await _tap(tester, suggestion);

    expect(find.text('Hoàn thành Xếp hình!'), findsOneWidget);
    expect(find.text('Không gian và lập kế hoạch'), findsOneWidget);
    expect(find.bySemanticsLabel('Số bước 1'), findsOneWidget);
    await _tap(tester, find.text('Chơi đề mới'));
    expect(game.moves, 0);
    expect(game.completed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('has a 48dp Caro cursor, finished result and replay', (
    tester,
  ) async {
    _narrowWindow(tester);
    var opponent = 180;
    final game = CaroGame(computer: (_) async => opponent++);
    await tester.pumpWidget(_app(CaroScreen(createGame: () => game)));
    await _tap(tester, find.text('Khó'));
    await _tap(tester, find.text('Phóng to'));

    final right = find.byTooltip('Sang phải');
    expect(tester.getSize(right).shortestSide, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSize(find.bySemanticsLabel('Hàng 8, cột 8, ô trống, đang chọn'))
          .shortestSide,
      greaterThanOrEqualTo(48),
    );
    await _tap(tester, right);
    expect(find.text('Hàng 8, cột 9 · Ô trống'), findsOneWidget);
    await _tap(tester, find.text('Đánh vào ô đã chọn'));
    expect(game.board.cells[113], CaroMark.x);
    expect(game.moves.length, 2);
    await _tap(tester, find.byTooltip('Đóng'));
    await _tap(tester, find.text('Hoàn tác'));
    expect(game.moves, isEmpty);

    // The AI fixture replies far from the player's row, so five moves can win.
    for (var index = 60; index <= 64; index++) {
      final cell = find.bySemanticsLabel('Hàng 5, cột ${index - 59}, ô trống');
      await _tap(tester, cell);
    }
    expect(find.text('Bạn thắng!'), findsOneWidget);
    expect(find.text('Chiến thuật và dự đoán'), findsOneWidget);
    await _tap(tester, find.text('Xem lại ván'));
    expect(find.text('Nước 0 / 9'), findsOneWidget);
    await _tap(tester, find.text('Tiến một nước'));
    expect(find.text('Nước 1 / 9 · X · Hàng 5, cột 1'), findsOneWidget);
    await _tap(tester, find.text('Lùi một nước'));
    expect(find.text('Nước 0 / 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget screen) => MaterialApp(
  theme: NeuroTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.3)),
    child: child!,
  ),
  home: screen,
);

void _narrowWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 680);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
