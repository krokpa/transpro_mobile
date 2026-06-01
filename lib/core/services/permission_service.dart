import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';

// ── PermissionService ─────────────────────────────────────────────────────────

class PermissionService {
  // ── Statuts ────────────────────────────────────────────────────────────────

  static Future<bool> hasNotifications() async =>
      (await Permission.notification.status).isGranted;

  static Future<bool> hasCamera() async =>
      (await Permission.camera.status).isGranted;

  static Future<bool> hasLocation() async =>
      (await Permission.locationWhenInUse.status).isGranted;

  // ── Requêtes ───────────────────────────────────────────────────────────────

  /// Demande la permission de notifications.
  /// Retourne true si accordée. Ne montre pas de dialog de refus permanent
  /// car l'utilisateur peut re-visiter les paramètres depuis le profil.
  static Future<bool> requestNotifications() async {
    if (Platform.isAndroid && !await _isAtLeast(33)) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Demande la caméra avec dialog de rationale si refus permanent.
  static Future<bool> requestCamera(BuildContext context) =>
      _request(
        context,
        Permission.camera,
        icon: Icons.camera_alt_outlined,
        title: 'Caméra requise',
        rationale:
            'TransPro a besoin de la caméra pour scanner les QR codes des billets et colis.',
      );

  /// Demande la localisation avec dialog de rationale si refus permanent.
  static Future<bool> requestLocation(BuildContext context) =>
      _request(
        context,
        Permission.locationWhenInUse,
        icon: Icons.location_on_outlined,
        title: 'Localisation requise',
        rationale:
            'TransPro utilise votre position pour vous guider jusqu\'à la gare '
            'et partager la localisation du véhicule avec les passagers.',
      );

  /// Demande la permission d'alarme exacte (Android 12+, silencieux).
  /// Dégrade gracieusement si refusée — les notifications resteront inexactes.
  static Future<bool> requestExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return true;
    final result = await Permission.scheduleExactAlarm.request();
    return result.isGranted;
  }

  /// Ouvre les paramètres de l'application.
  static Future<void> openSettings() => openAppSettings();

  // ── Implémentation interne ─────────────────────────────────────────────────

  static Future<bool> _request(
    BuildContext context,
    Permission permission, {
    required IconData icon,
    required String title,
    required String rationale,
  }) async {
    var status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) await _showDeniedDialog(context, icon, title, rationale);
      return false;
    }

    status = await permission.request();
    if (status.isPermanentlyDenied && context.mounted) {
      await _showDeniedDialog(context, icon, title, rationale);
    }
    return status.isGranted;
  }

  static Future<void> _showDeniedDialog(
    BuildContext context,
    IconData icon,
    String title,
    String rationale,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PermissionDeniedDialog(
        icon: icon,
        title: title,
        rationale: rationale,
      ),
    );
  }

  static Future<bool> _isAtLeast(int api) async {
    // SDK version check via Platform — returns true conservatively if unknown
    try {
      final ver = Platform.operatingSystemVersion;
      // operatingSystemVersion on Android looks like "Android 13 (API 33)"
      final match = RegExp(r'API (\d+)').firstMatch(ver);
      if (match != null) return int.parse(match.group(1)!) >= api;
    } catch (_) {}
    return true;
  }
}

// ── Dialog refus permanent ────────────────────────────────────────────────────

class _PermissionDeniedDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String rationale;

  const _PermissionDeniedDialog({
    required this.icon,
    required this.title,
    required this.rationale,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: brandOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: brandOrange, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            rationale,
            style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Autorisez l'accès dans les paramètres de l'application.",
            style: TextStyle(fontSize: 12, color: context.textMuted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard',
                style: TextStyle(color: context.textMuted, fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandOrange,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Paramètres', style: TextStyle(fontSize: 13)),
          ),
        ],
      );
}

// ── PermissionGate ─────────────────────────────────────────────────────────────
// Widget inline à afficher à la place du contenu quand une permission est
// refusée (ex : scanner caméra, carte GPS).

class PermissionGate extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;
  final Color? iconColor;

  const PermissionGate({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (iconColor ?? brandOrange).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: iconColor ?? brandOrange, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 13, color: context.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.settings_outlined, size: 17),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
        ),
      );
}
