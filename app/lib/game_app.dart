import 'package:material_ui/material_ui.dart';

class GameApp extends StatefulWidget {
  const GameApp({required this.checkApi, super.key});

  final Future<void> Function() checkApi;

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  late Future<void> _apiStatus;

  @override
  void initState() {
    super.initState();
    _apiStatus = widget.checkApi();
  }

  void _retry() {
    setState(() {
      _apiStatus = widget.checkApi();
    });
  }

  @override
  Widget build(BuildContext context) {
    const appName = 'Neuro Play';
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text(appName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<void>(
              future: _apiStatus,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const CircularProgressIndicator(
                    semanticsLabel: 'Đang kết nối máy chủ',
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Không kết nối được máy chủ'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  );
                }
                return const Text('Đã kết nối máy chủ');
              },
            ),
          ),
        ),
      ),
    );
  }
}
