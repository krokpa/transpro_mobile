import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl    = 'http://192.168.10.101:3001/api'; // Android emulator → localhost
const socketBaseUrl = 'http://192.168.10.101:3001';   // Socket.IO root (no /api)

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) {
      return handler.next(error);
    },
  ));

  return dio;
});

// Helper to extract data from paginated or plain responses
dynamic extractData(dynamic response) {
  if (response is Map && response.containsKey('data')) return response['data'];
  return response;
}
