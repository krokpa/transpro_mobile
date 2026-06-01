import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Stores booking JSON blobs locally so tickets and QR codes remain accessible
/// without an internet connection on travel day.
class TicketCache {
  static const _bookingsBox = 'offline_bookings';
  static const _listKey     = '__list__';

  static Box<String> get _box => Hive.box<String>(_bookingsBox);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_bookingsBox);
  }

  /// Persist a full booking detail (from GET /bookings/my/:id).
  static Future<void> saveBooking(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null) return;
    await _box.put(id, jsonEncode(data));
    await _updateList(id);
  }

  /// Persist the list returned by GET /bookings/my (lightweight — no tickets).
  static Future<void> saveBookingList(List<dynamic> items) async {
    final ids = <String>[];
    for (final raw in items) {
      final b = raw as Map<String, dynamic>;
      final id = b['id'] as String?;
      if (id == null) continue;
      // Only overwrite with list data if we don't already have full detail
      if (!_box.containsKey(id)) {
        await _box.put(id, jsonEncode(b));
      }
      ids.add(id);
    }
    await _box.put(_listKey, jsonEncode(ids));
  }

  /// Returns the booking list order (ids) that was last cached.
  static List<Map<String, dynamic>> getBookings() {
    final raw = _box.get(_listKey);
    if (raw == null) return [];
    final ids = (jsonDecode(raw) as List).cast<String>();
    return ids
        .map((id) {
          final json = _box.get(id);
          if (json == null) return null;
          return jsonDecode(json) as Map<String, dynamic>;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Returns a single booking detail by id, or null if not cached.
  static Map<String, dynamic>? getBooking(String id) {
    final json = _box.get(id);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  static bool get hasData => _box.isNotEmpty && _box.containsKey(_listKey);

  static Future<void> clear() async => _box.clear();

  static Future<void> _updateList(String newId) async {
    final raw = _box.get(_listKey);
    final ids = raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
    if (!ids.contains(newId)) {
      ids.insert(0, newId);
      await _box.put(_listKey, jsonEncode(ids));
    }
  }
}
