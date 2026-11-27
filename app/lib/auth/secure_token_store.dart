import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';

final class SecureTokenStore implements RefreshTokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'neuro_play_refresh_token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
