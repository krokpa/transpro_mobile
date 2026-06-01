import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/models.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/notifications/my');
  final items = extractData(res.data);
  return (items as List).map((e) => AppNotification.fromJson(e)).toList();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final dio  = ref.read(dioProvider);
  final res  = await dio.get('/notifications/my/count');
  final data = extractData(res.data);
  if (data is Map) return (data['count'] ?? data['unread'] ?? 0) as int;
  return 0;
});
