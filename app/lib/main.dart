import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'auth/secure_token_store.dart';
import 'core/api_client.dart';
import 'game_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  runApp(
    ChangeNotifierProvider(
      create: (_) =>
          AuthController(api: api, tokenStore: const SecureTokenStore())
            ..restore(),
      child: GameApp(checkApi: api.checkHealth, newSudoku: api.newSudoku),
    ),
  );
}
