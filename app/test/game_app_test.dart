import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/game_app.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows a successful API connection', (tester) async {
    await tester.pumpWidget(_statusApp(() async {}));
    await tester.pumpAndSettle();

    expect(find.text('Neuro Play'), findsOneWidget);
    expect(find.text('Đã kết nối máy chủ'), findsOneWidget);
  });

  testWidgets('can retry after the API check fails', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _statusApp(() async {
        if (++attempts == 1) {
          throw StateError('API unavailable');
        }
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Đã kết nối máy chủ'), findsOneWidget);
  });
}

Widget _statusApp(Future<void> Function() checkApi) => MaterialApp(
  home: Scaffold(
    appBar: AppBar(title: const Text('Neuro Play')),
    body: HealthStatus(checkApi: checkApi),
  ),
);
