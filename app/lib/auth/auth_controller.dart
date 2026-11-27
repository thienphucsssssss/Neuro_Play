import 'dart:async';

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
  Future<void>? _workFinished;
  Future<void>? _profileReload;
  int _sessionVersion = 0;
  bool _storageNeedsClear = false;
  bool _profileRetry = false;

  AuthPhase get phase => _phase;
  AuthUser? get user => _user;
  String? get message => _message;
  bool get busy => _workFinished != null;
  bool get profileRetry => _profileRetry;

  Future<T> requestWithSession<T>(Future<T> Function(String) send) =>
      _withCurrentSession(
        () async {
          try {
            await _persistTokens();
            return await _withAccessToken(send);
          } on AuthRequestException catch (error) {
            if (error.statusCode == 401) {
              await _clearSession(
                message: 'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
              );
            }
            rethrow;
          }
        },
        onSessionChanged: () => throw const AuthRequestException(
          'Vui lòng đăng nhập lại.',
          statusCode: 401,
        ),
      );

  Future<void> restore() => _run(() async {
    _phase = AuthPhase.loading;
    notifyListeners();
    await _restoreProfile();
  });

  Future<void> login(String identifier, String password) => _run(() async {
    _tokensAwaitingWrite = await api.login(identifier, password);
    _sessionVersion++;
    await _restoreProfile();
  });

  Future<void> reloadProfile() => _profileReload ??=
      _withCurrentSession<void>(() async {
        _message = null;
        _profileRetry = false;
        try {
          await _loadProfile();
        } on Exception catch (error) {
          _message = authErrorMessage(error);
          _profileRetry = true;
        }
      }, onSessionChanged: () {}).whenComplete(() {
        _profileReload = null;
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
    if (busy) return;
    _message = null;
    _profileRetry = false;
    await _withWork(operation);
  }

  Future<T> _withCurrentSession<T>(
    Future<T> Function() operation, {
    required T Function() onSessionChanged,
  }) async {
    if (_phase != AuthPhase.signedIn) return onSessionChanged();
    final version = _sessionVersion;
    var pending = _workFinished;
    while (pending != null) {
      await pending;
      pending = _workFinished;
    }
    if (_phase != AuthPhase.signedIn || version != _sessionVersion) {
      return onSessionChanged();
    }
    return _withWork(operation);
  }

  Future<T> _withWork<T>(Future<T> Function() operation) async {
    final finished = Completer<void>();
    _workFinished = finished.future;
    notifyListeners();
    try {
      return await operation();
    } finally {
      _workFinished = null;
      finished.complete();
      notifyListeners();
    }
  }

  Future<void> _restoreProfile() async {
    try {
      if (_tokensAwaitingWrite == null) {
        await _clearStoredSession();
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
      _user = await _withAccessToken(api.me);
      _phase = AuthPhase.signedIn;
    } on AuthRequestException catch (error) {
      if (error.statusCode != 401) rethrow;
      await _clearSession(message: 'Phiên đã hết hạn. Vui lòng đăng nhập lại.');
    }
  }

  Future<T> _withAccessToken<T>(Future<T> Function(String) send) async {
    final accessToken = _accessToken ?? (await _rotate()).accessToken;
    try {
      return await send(accessToken);
    } on AuthRequestException catch (error) {
      if (error.statusCode != 401) rethrow;
      return send((await _rotate()).accessToken);
    }
  }

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
    _storageNeedsClear = false;
    _refreshToken = tokens.refreshToken;
    _accessToken = tokens.accessToken;
    _tokensAwaitingWrite = null;
  }

  Future<void> _clearSession({String? message}) async {
    _sessionVersion++;
    _accessToken = null;
    _refreshToken = null;
    _tokensAwaitingWrite = null;
    _user = null;
    _message = message;
    _phase = AuthPhase.signedOut;
    _storageNeedsClear = true;
    notifyListeners();
    try {
      await _clearStoredSession();
    } on Exception {
      _message = 'Phiên đã kết thúc. Không thể xóa dữ liệu phiên cục bộ.';
    }
  }

  Future<void> _clearStoredSession() async {
    if (!_storageNeedsClear) return;
    await tokenStore.clear();
    _storageNeedsClear = false;
  }
}

String authErrorMessage(Exception error) => error is AuthRequestException
    ? error.message
    : 'Không thể lưu hoặc đọc phiên. Vui lòng thử lại.';
