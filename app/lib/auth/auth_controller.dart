import 'package:flutter/foundation.dart';

import 'auth_models.dart';

enum AuthPhase { loading, signedOut, signedIn, retry }

final class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.tokenStore});

  final AuthApi api;
  final RefreshTokenStore tokenStore;

  AuthPhase _phase = AuthPhase.loading;
  AuthUser? _user;
  String? _message;
  String? _accessToken;
  String? _refreshToken;
  AuthTokens? _tokensAwaitingWrite;
  Future<AuthTokens>? _refreshInFlight;
  bool _busy = false;
  bool _profileRetry = false;

  AuthPhase get phase => _phase;
  AuthUser? get user => _user;
  String? get message => _message;
  bool get busy => _busy;
  bool get profileRetry => _profileRetry;

  Future<void> restore() => _run(() async {
    _phase = AuthPhase.loading;
    notifyListeners();
    await _restoreProfile();
  });

  Future<void> login(String identifier, String password) => _run(() async {
    _tokensAwaitingWrite = await api.login(identifier, password);
    await _restoreProfile();
  });

  Future<void> reloadProfile() => _run(() async {
    if (_phase != AuthPhase.signedIn) return;
    try {
      await _loadProfile();
    } on Exception catch (error) {
      _message = authErrorMessage(error);
      _profileRetry = true;
    }
  });

  Future<void> logout() => _run(() async {
    final token = _tokensAwaitingWrite?.refreshToken ?? _refreshToken;
    if (token == null) return;
    try {
      try {
        await api.logout(token);
      } on AuthRequestException catch (error) {
        if (error.statusCode != 401) rethrow;
      }
      await _clearSession();
    } on Exception catch (error) {
      _message = authErrorMessage(error);
    }
  });

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    _busy = true;
    _message = null;
    _profileRetry = false;
    notifyListeners();
    try {
      await operation();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _restoreProfile() async {
    try {
      if (_tokensAwaitingWrite == null) {
        _refreshToken ??= await tokenStore.read();
      }
      if (_refreshToken == null && _tokensAwaitingWrite == null) {
        _phase = AuthPhase.signedOut;
        return;
      }
      await _loadProfile();
    } on Exception catch (error) {
      _phase = AuthPhase.retry;
      _message = authErrorMessage(error);
    }
  }

  Future<void> _loadProfile() async {
    try {
      await _persistTokens();
      _user = await _authorizedProfile();
      _phase = AuthPhase.signedIn;
    } on AuthRequestException catch (error) {
      if (error.statusCode != 401) rethrow;
      await _clearSession(message: 'Phiên đã hết hạn. Vui lòng đăng nhập lại.');
    }
  }

  Future<AuthUser> _authorizedProfile() async {
    final accessToken = _accessToken ?? (await _refresh()).accessToken;
    try {
      return await api.me(accessToken);
    } on AuthRequestException catch (error) {
      if (error.statusCode != 401) rethrow;
      final updated = _accessToken;
      if (updated != null && updated != accessToken) return api.me(updated);
      return api.me((await _refresh()).accessToken);
    }
  }

  Future<AuthTokens> _refresh() =>
      _refreshInFlight ??= _rotate().whenComplete(() {
        _refreshInFlight = null;
      });

  Future<AuthTokens> _rotate() async {
    final token = _refreshToken;
    if (token == null) {
      throw const AuthRequestException('Phiên đã hết hạn.', statusCode: 401);
    }
    final tokens = await api.refresh(token);
    _tokensAwaitingWrite = tokens;
    await _persistTokens();
    return tokens;
  }

  Future<void> _persistTokens() async {
    final tokens = _tokensAwaitingWrite;
    if (tokens == null) return;
    await tokenStore.write(tokens.refreshToken);
    _refreshToken = tokens.refreshToken;
    _accessToken = tokens.accessToken;
    _tokensAwaitingWrite = null;
  }

  Future<void> _clearSession({String? message}) async {
    await tokenStore.clear();
    _accessToken = null;
    _refreshToken = null;
    _tokensAwaitingWrite = null;
    _user = null;
    _message = message;
    _phase = AuthPhase.signedOut;
  }
}

String authErrorMessage(Exception error) => error is AuthRequestException
    ? error.message
    : 'Không thể lưu hoặc đọc phiên. Vui lòng thử lại.';
