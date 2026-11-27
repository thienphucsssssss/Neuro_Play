import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/auth/auth_controller.dart';
import 'package:game_tri_tue/auth/auth_models.dart';

void main() {
  late FakeAuthApi api;
  late MemoryTokenStore storage;
  late AuthController controller;

  setUp(() {
    api = FakeAuthApi();
    storage = MemoryTokenStore();
    controller = AuthController(api: api, tokenStore: storage);
  });

  tearDown(() => controller.dispose());

  test(
    'restores a saved session and stores the rotated refresh token',
    () async {
      storage.token = 'saved';
      await controller.restore();

      expect(controller.phase, AuthPhase.signedIn);
      expect(controller.user?.displayName, 'Người chơi');
      expect(storage.token, 'refresh-1');
    },
  );

  test(
    'refreshes once on an expired access token and retries the profile',
    () async {
      await controller.login('player', 'test password');
      api.expiresFirstAccess = true;

      await Future.wait([
        controller.reloadProfile(),
        controller.reloadProfile(),
      ]);

      expect(controller.phase, AuthPhase.signedIn);
      expect(storage.token, 'refresh-1');
      expect(api.refreshCount, 1);
      expect(api.lastProfileToken, 'access-1');
    },
  );

  test(
    'keeps a saved session on network failure and retries on demand',
    () async {
      storage.token = 'saved';
      api.refreshFailure = const AuthRequestException('Mất kết nối');
      await controller.restore();

      expect(controller.phase, AuthPhase.retry);
      expect(storage.token, 'saved');

      api.refreshFailure = null;
      await controller.restore();
      expect(controller.phase, AuthPhase.signedIn);
    },
  );

  test('clears a revoked session and returns to sign in', () async {
    storage.token = 'revoked';
    api.refreshFailure = const AuthRequestException(
      'Hết phiên',
      statusCode: 401,
    );
    await controller.restore();

    expect(controller.phase, AuthPhase.signedOut);
    expect(storage.token, isNull);
    expect(controller.message, isNotEmpty);
  });

  test('makes a failed profile reload retryable without signing out', () async {
    await controller.login('player', 'test password');
    api.profileFailure = const AuthRequestException('Mất kết nối');
    await controller.reloadProfile();
    expect(controller.phase, AuthPhase.signedIn);
    expect(controller.profileRetry, isTrue);

    api.profileFailure = null;
    await controller.reloadProfile();
    expect(controller.profileRetry, isFalse);
    expect(controller.message, isNull);
  });

  test(
    'retries a failed storage write without replaying the old token',
    () async {
      storage.token = 'saved';
      storage.failNextWrite = true;
      await controller.restore();
      expect(controller.phase, AuthPhase.retry);
      expect(storage.token, 'saved');

      await controller.restore();
      expect(controller.phase, AuthPhase.signedIn);
      expect(storage.token, 'refresh-1');
      expect(api.refreshCount, 1);
    },
  );

  test(
    'clears the device token after server logout and handles offline logout',
    () async {
      await controller.login('player', 'test password');
      api.logoutFailure = const AuthRequestException('Mất kết nối');
      await controller.logout();
      expect(controller.phase, AuthPhase.signedIn);
      expect(storage.token, 'refresh-0');
      expect(controller.message, 'Mất kết nối');

      api.logoutFailure = null;
      await controller.logout();
      expect(controller.phase, AuthPhase.signedOut);
      expect(storage.token, isNull);
    },
  );
}

final class FakeAuthApi implements AuthApi {
  var refreshCount = 0;
  var expiresFirstAccess = false;
  String? lastProfileToken;
  AuthRequestException? refreshFailure;
  AuthRequestException? logoutFailure;
  AuthRequestException? profileFailure;

  @override
  Future<AuthTokens> login(String identifier, String password) async =>
      const AuthTokens(accessToken: 'access-0', refreshToken: 'refresh-0');

  @override
  Future<AuthUser> me(String accessToken) async {
    lastProfileToken = accessToken;
    if (profileFailure case final failure?) throw failure;
    if (expiresFirstAccess && accessToken == 'access-0') {
      throw const AuthRequestException('Hết hạn', statusCode: 401);
    }
    return const AuthUser(
      id: '1',
      username: 'player',
      email: 'player@example.com',
      displayName: 'Người chơi',
      avatarUrl: null,
    );
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    if (refreshFailure case final failure?) throw failure;
    refreshCount += 1;
    return AuthTokens(
      accessToken: 'access-$refreshCount',
      refreshToken: 'refresh-$refreshCount',
    );
  }

  @override
  Future<void> register(Registration registration) async {}

  @override
  Future<void> logout(String refreshToken) async {
    if (logoutFailure case final failure?) throw failure;
  }
}

final class MemoryTokenStore implements RefreshTokenStore {
  String? token;
  bool failNextWrite = false;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw Exception('Storage unavailable');
    }
    token = value;
  }

  @override
  Future<void> clear() async => token = null;
}
