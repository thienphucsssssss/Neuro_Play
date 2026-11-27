import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'auth/secure_token_store.dart';
import 'core/api_client.dart';
import 'game_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/OFL-SourceSans3.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Source Sans 3'], license);
  });
  final api = ApiClient();
  runApp(
    ChangeNotifierProvider(
      create: (_) =>
          AuthController(api: api, tokenStore: const SecureTokenStore())
            ..restore(),
      child: GameApp(checkApi: api.checkHealth, sudokuApi: api),
    ),
  );
}
