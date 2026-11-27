import 'package:material_ui/material_ui.dart';

import 'core/api_client.dart';
import 'game_app.dart';

void main() {
  runApp(GameApp(checkApi: ApiClient().checkHealth));
}
