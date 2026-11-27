final class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => switch (json) {
    {
      'id': String id,
      'username': String username,
      'email': String email,
      'displayName': String displayName,
      'avatarUrl': String? avatarUrl,
    } =>
      AuthUser(
        id: id,
        username: username,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
      ),
    _ => throw const FormatException('Invalid user profile'),
  };

  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? avatarUrl;
}

final class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => switch (json) {
    {'accessToken': String access, 'refreshToken': String refresh}
        when access.isNotEmpty && refresh.isNotEmpty =>
      AuthTokens(accessToken: access, refreshToken: refresh),
    _ => throw const FormatException('Invalid token response'),
  };

  final String accessToken;
  final String refreshToken;
}

final class Registration {
  const Registration({
    required this.username,
    required this.email,
    required this.password,
    this.displayName,
  });

  Map<String, String> toJson() => {
    'username': username,
    'email': email,
    'password': password,
    'displayName': ?displayName,
  };

  final String username;
  final String email;
  final String password;
  final String? displayName;
}

final class AuthRequestException implements Exception {
  const AuthRequestException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

abstract interface class AuthApi {
  Future<void> register(Registration registration);
  Future<AuthTokens> login(String identifier, String password);
  Future<AuthTokens> refresh(String refreshToken);
  Future<AuthUser> me(String accessToken);
  Future<void> logout(String refreshToken);
}

abstract interface class RefreshTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}
