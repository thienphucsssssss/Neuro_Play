import 'package:dio/dio.dart';

class ApiClient {
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
}
