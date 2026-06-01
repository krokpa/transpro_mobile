import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class FavoritesCache {
  static const _boxName = 'favorites';
  static const _companiesKey = 'companies';
  static const _stationsKey = 'stations';

  static Box<String> get _box => Hive.box<String>(_boxName);

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  // ── Companies ─────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> getCompanies() {
    final raw = _box.get(_companiesKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> toggleCompany(Map<String, dynamic> company) async {
    final id = company['id'] as String? ?? '';
    final list = getCompanies();
    final idx = list.indexWhere((c) => c['id'] == id);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add({
        'id': company['id'],
        'name': company['name'],
        'logo': company['logo'],
        'slug': company['slug'],
        'city': company['city'],
      });
    }
    await _box.put(_companiesKey, jsonEncode(list));
  }

  static bool isCompanyFavorite(String id) =>
      getCompanies().any((c) => c['id'] == id);

  // ── Stations ──────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> getStations() {
    final raw = _box.get(_stationsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> toggleStation(Map<String, dynamic> station) async {
    final id = station['id'] as String? ?? '';
    final list = getStations();
    final idx = list.indexWhere((s) => s['id'] == id);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add({
        'id': station['id'],
        'name': station['name'],
        'address': station['address'],
        'city': station['city'],
      });
    }
    await _box.put(_stationsKey, jsonEncode(list));
  }

  static bool isStationFavorite(String id) =>
      getStations().any((s) => s['id'] == id);
}
