import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_screens.dart';
import 'core/neuro_theme.dart';
import 'game_home.dart';
import 'sudoku/sudoku_api.dart';

class GameApp extends StatelessWidget {
  const GameApp({required this.checkApi, required this.sudokuApi, super.key});

  final Future<void> Function() checkApi;
  final SudokuApi sudokuApi;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Neuro Play',
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: NeuroTheme.light(),
    debugShowCheckedModeBanner: false,
    home: _AuthGate(checkApi: checkApi, sudokuApi: sudokuApi),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.checkApi, required this.sudokuApi});

  final Future<void> Function() checkApi;
  final SudokuApi sudokuApi;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return switch (auth.phase) {
      AuthPhase.signedOut => const SignInScreen(),
      AuthPhase.signedIn => _SignedInNavigator(
        key: ValueKey(auth.user!.id),
        checkApi: checkApi,
        sudokuApi: sudokuApi,
      ),
      AuthPhase.loading || AuthPhase.retry => Scaffold(
        appBar: AppBar(title: const Text('Neuro Play')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: auth.phase == AuthPhase.loading
                ? const CircularProgressIndicator(
                    semanticsLabel: 'Đang khôi phục phiên',
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(auth.message ?? 'Không thể khôi phục phiên.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: auth.restore,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    };
  }
}

class _SignedInNavigator extends StatefulWidget {
  const _SignedInNavigator({
    required this.checkApi,
    required this.sudokuApi,
    super.key,
  });

  final Future<void> Function() checkApi;
  final SudokuApi sudokuApi;

  @override
  State<_SignedInNavigator> createState() => _SignedInNavigatorState();
}

class _SignedInNavigatorState extends State<_SignedInNavigator> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) {
      final navigator = _navigator.currentState;
      if (navigator != null) unawaited(navigator.maybePop(result));
    },
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => GameHome(
          sudokuApi: widget.sudokuApi,
          health: HealthStatus(checkApi: widget.checkApi),
        ),
      ),
    ),
  );
}

class HealthStatus extends StatefulWidget {
  const HealthStatus({required this.checkApi, super.key});

  final Future<void> Function() checkApi;

  @override
  State<HealthStatus> createState() => _HealthStatusState();
}

class _HealthStatusState extends State<HealthStatus> {
  late Future<void> _status;

  @override
  void initState() {
    super.initState();
    _status = widget.checkApi();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _status,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: CircularProgressIndicator(
            semanticsLabel: 'Đang kết nối máy chủ',
          ),
        );
      }
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Không kết nối được máy chủ'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _status = widget.checkApi();
              }),
              child: const Text('Thử lại'),
            ),
          ],
        );
      }
      return const Text('Đã kết nối máy chủ');
    },
  );
}
