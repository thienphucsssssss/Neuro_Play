import 'package:dio/dio.dart';

import '../auth/auth_models.dart';

class ApiClient implements AuthApi {
  final _http = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:3000',
      ),
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  Future<void> checkHealth() async {
    final response = await _http.get<Map<String, dynamic>>('/health');
    if (response.data?['status'] != 'ok') {
      throw StateError('Unexpected response from /health');
    }
  }

  @override
  Future<void> register(Registration registration) => _request(() async {
    await _http.post<void>('/api/auth/register', data: registration.toJson());
  });

  @override
  Future<AuthTokens> login(String identifier, String password) => _tokens(
    '/api/auth/login',
    {'identifier': identifier, 'password': password},
  );

  @override
  Future<AuthTokens> refresh(String refreshToken) =>
      _tokens('/api/auth/refresh', {'refreshToken': refreshToken});

  @override
  Future<AuthUser> me(String accessToken) => _request(() async {
    final response = await _http.get<Map<String, dynamic>>(
      '/api/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final body = response.data;
    if (body?['user'] case final Map<String, dynamic> profile) {
      return AuthUser.fromJson(profile);
    }
    throw const FormatException('Missing user profile');
  });

  @override
  Future<void> logout(String refreshToken) => _request(() async {
    await _http.post<void>(
      '/api/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  });

  Future<AuthTokens> _tokens(String path, Map<String, String> data) => _request(
    () async {
      final response = await _http.post<Map<String, dynamic>>(path, data: data);
      final body = response.data;
      if (body == null) throw const FormatException('Missing tokens');
      return AuthTokens.fromJson(body);
    },
  );

  Future<T> _request<T>(Future<T> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == null) {
        throw const AuthRequestException('Không kết nối được máy chủ.');
      }
      final body = error.response?.data;
      if (body case {'error': final String message} when status < 500) {
        throw AuthRequestException(message, statusCode: status);
      }
      throw AuthRequestException(
        'Máy chủ chưa xử lý được yêu cầu. Vui lòng thử lại.',
        statusCode: status,
      );
    } on FormatException {
      throw const AuthRequestException('Phản hồi từ máy chủ không hợp lệ.');
    }
  }
}
