import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_screens.dart';

class GameApp extends StatelessWidget {
  const GameApp({required this.checkApi, super.key});

  final Future<void> Function() checkApi;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Neuro Play',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF175E52)),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    debugShowCheckedModeBanner: false,
    home: _AuthGate(checkApi: checkApi),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.checkApi});

  final Future<void> Function() checkApi;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return switch (auth.phase) {
      AuthPhase.signedOut => const SignInScreen(),
      AuthPhase.signedIn => _HomeScreen(auth: auth, checkApi: checkApi),
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

class _HomeScreen extends StatefulWidget {
  const _HomeScreen({required this.auth, required this.checkApi});

  final AuthController auth;
  final Future<void> Function() checkApi;

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(widget.auth.reloadProfile()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.auth;
    final user = controller.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Neuro Play')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Xin chào, ${user.displayName}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('@${user.username}'),
                  const SizedBox(height: 24),
                  HealthStatus(checkApi: widget.checkApi),
                  if (controller.message case final message?) ...[
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(message)),
                  ],
                  if (controller.profileRetry)
                    TextButton(
                      onPressed: controller.busy
                          ? null
                          : controller.reloadProfile,
                      child: const Text('Tải lại hồ sơ'),
                    ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: controller.busy ? null : controller.logout,
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
