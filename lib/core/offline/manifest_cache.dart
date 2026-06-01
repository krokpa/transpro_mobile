import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Caches trip manifests (passenger list + QR codes) for offline scan.
/// Also queues offline check-in events for sync when connectivity returns.
class ManifestCache {
  static const _manifestBox  = 'offline_manifests';
  static const _syncQueueBox = 'offline_sync_queue';

  static Box<String> get _manifests  => Hive.box<String>(_manifestBox);
  static Box<String> get _syncQueue  => Hive.box<String>(_syncQueueBox);

  static Future<void> init() async {
    await Hive.openBox<String>(_manifestBox);
    await Hive.openBox<String>(_syncQueueBox);
  }

  // ── Manifest storage ──────────────────────────────────────────────────────

  static Future<void> saveManifest(String tripId, List<dynamic> entries) async {
    await _manifests.put(tripId, jsonEncode(entries));
  }

  static List<Map<String, dynamic>>? getManifest(String tripId) {
    final raw = _manifests.get(tripId);
    if (raw == null) return null;
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  static bool hasManifest(String tripId) => _manifests.containsKey(tripId);

  static Future<void> clearManifest(String tripId) async {
    await _manifests.delete(tripId);
  }

  // ── Offline QR scan — match by qrCodeData ─────────────────────────────────

  /// Finds the booking entry that owns the given QR code data.
  static Map<String, dynamic>? findByQrCode(String tripId, String qrData) {
    final entries = getManifest(tripId);
    if (entries == null) return null;
    for (final entry in entries) {
      final tickets = (entry['tickets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final t in tickets) {
        if (t['qrCodeData'] == qrData) {
          return {'entry': entry, 'ticket': t};
        }
      }
    }
    return null;
  }

  // ── Sync queue — offline check-ins pending server confirmation ────────────

  static Future<void> queueCheckIn(String ticketId, String tripId) async {
    final key = 'checkin_$ticketId';
    if (_syncQueue.containsKey(key)) return;
    await _syncQueue.put(key, jsonEncode({'ticketId': ticketId, 'tripId': tripId, 'queuedAt': DateTime.now().toIso8601String()}));
  }

  static List<Map<String, dynamic>> getPendingSyncs() {
    return _syncQueue.values
        .map((v) => jsonDecode(v) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> removeSynced(String ticketId) async {
    await _syncQueue.delete('checkin_$ticketId');
  }

  static bool get hasPendingSyncs => _syncQueue.isNotEmpty;
}
