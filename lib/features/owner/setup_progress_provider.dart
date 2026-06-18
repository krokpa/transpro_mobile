import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/setup_progress.dart';

final setupProgressProvider = FutureProvider.autoDispose<SetupProgress>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/tenants/me/setup-progress');
  return SetupProgress.fromJson(extractData(res.data) as Map<String, dynamic>);
});
