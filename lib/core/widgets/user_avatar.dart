import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a user's avatar photo if available, or initials fallback.
/// Pass [onTap] to make it tappable (e.g. for upload).
class UserAvatarWidget extends StatelessWidget {
  final String? avatar;   // base64 data URL or null
  final String firstName;
  final String lastName;
  final double size;
  final VoidCallback? onTap;
  final bool showEditOverlay;

  const UserAvatarWidget({
    super.key,
    required this.firstName,
    required this.lastName,
    this.avatar,
    this.size = 64,
    this.onTap,
    this.showEditOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
    final radius = size / 2;

    Widget circle;
    if (avatar != null && avatar!.isNotEmpty) {
      try {
        final bytes = base64Decode(avatar!.contains(',') ? avatar!.split(',').last : avatar!);
        circle = CircleAvatar(
          key: ValueKey(avatar),   // force le rechargement quand la photo change
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        circle = _InitialsAvatar(initials: initials, radius: radius);
      }
    } else {
      circle = _InitialsAvatar(initials: initials, radius: radius);
    }

    if (onTap == null && !showEditOverlay) return circle;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          circle,
          if (showEditOverlay)
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: size * 0.35,
                height: size * 0.35,
                decoration: BoxDecoration(
                  color: brandOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: size * 0.18,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  const _InitialsAvatar({required this.initials, required this.radius});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: brandOrange.withValues(alpha: 0.15),
    child: Text(
      initials.isEmpty ? '?' : initials,
      style: TextStyle(
        color: brandOrange,
        fontWeight: FontWeight.w800,
        fontSize: radius * 0.55,
      ),
    ),
  );
}
