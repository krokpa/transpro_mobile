import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_constants.dart';

const _baseUrl = kApiBaseUrl;
const socketBaseUrl = kSocketUrl;

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // Auth token injection
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) {
          debugPrint('[API] --> ${options.method} ${options.uri}');
          if (options.queryParameters.isNotEmpty) {
            debugPrint('[API]     params: ${options.queryParameters}');
          }
          if (options.data != null) {
            debugPrint('[API]     body:   ${options.data}');
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint(
            '[API] <-- ${response.statusCode} ${response.requestOptions.uri}',
          );
          debugPrint('[API]     body: ${response.data}');
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint(
            '[API] !!! ERROR ${error.response?.statusCode} ${error.requestOptions.uri}',
          );
          debugPrint('[API]     type:     ${error.type}');
          debugPrint('[API]     message:  ${error.message}');
          if (error.response?.data != null) {
            debugPrint('[API]     response: ${error.response?.data}');
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});

// Helper to extract data from paginated or plain responses
dynamic extractData(dynamic response) {
  if (response is Map && response.containsKey('data')) return response['data'];
  return response;
}

// Lookup a registered passenger by phone — returns user map or null
Future<Map<String, dynamic>?> lookupUserByPhone(Dio dio, String phone) async {
  try {
    final res = await dio.get('/users/lookup', queryParameters: {'phone': phone});
    final data = extractData(res.data);
    if (data == null) return null;
    return data as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

String apiErrorMessage(
  Object error, {
  String fallback = 'Une erreur est survenue',
}) {
  if (error is DioException) {
    final data = error.response?.data;
    final message = _messageFromResponse(data);
    if (message != null && message.trim().isNotEmpty) return message;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connexion trop lente. Veuillez réessayer.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
    }
  }

  return fallback;
}

String? _messageFromResponse(dynamic data) {
  if (data is String) return data;
  if (data is Map) {
    final message = data['message'] ?? data['error'] ?? data['detail'];
    if (message is String) return message;
    if (message is List) return message.map((e) => '$e').join('\n');
  }
  return null;
}
