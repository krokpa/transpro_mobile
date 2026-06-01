import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

/// Widget permettant de capturer jusqu'à [maxPhotos] photos (caméra ou galerie).
/// Les photos sont encodées en base64 et retournées via [onChanged].
class PhotoCapture extends StatelessWidget {
  final List<String> photos;   // base64 data URLs déjà présentes
  final int maxPhotos;
  final void Function(List<String>) onChanged;
  final bool readOnly;

  const PhotoCapture({
    super.key,
    required this.photos,
    required this.onChanged,
    this.maxPhotos = 2,
    this.readOnly = false,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    onChanged([...photos, b64]);
  }

  void _showPickerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: brandOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: brandOrange, size: 20),
                ),
                title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () { Navigator.pop(context); _pick(context, ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF6366F1), size: 20),
                ),
                title: const Text('Choisir dans la galerie', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () { Navigator.pop(context); _pick(context, ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewPhoto(BuildContext context, String photo, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _PhotoViewDialog(
        photo: photo,
        onDelete: readOnly ? null : () {
          Navigator.pop(context);
          final updated = [...photos]..removeAt(index);
          onChanged(updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = !readOnly && photos.length < maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera_outlined, size: 15, color: context.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Photos (${photos.length}/$maxPhotos)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Miniatures existantes
            ...photos.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _PhotoThumbnail(
                photo: e.value,
                onTap: () => _viewPhoto(context, e.value, e.key),
              ),
            )),
            // Slot d'ajout
            if (canAdd)
              _AddPhotoSlot(onTap: () => _showPickerMenu(context)),
            // Slots vides restants (lecture seule)
            if (readOnly)
              ...List.generate(maxPhotos - photos.length, (_) => const Padding(
                padding: EdgeInsets.only(right: 10),
                child: _EmptySlot(),
              )),
          ],
        ),
      ],
    );
  }
}

// ── Miniature ─────────────────────────────────────────────────────────────────

class _PhotoThumbnail extends StatelessWidget {
  final String photo;
  final VoidCallback onTap;
  const _PhotoThumbnail({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(photo.contains(',') ? photo.split(',').last : photo);
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
      );
    } catch (_) {
      return const SizedBox(width: 72, height: 72);
    }
  }
}

// ── Slot ajout ────────────────────────────────────────────────────────────────

class _AddPhotoSlot extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoSlot({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.divider, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 22, color: context.textMuted),
          const SizedBox(height: 4),
          Text('Ajouter', style: TextStyle(fontSize: 10, color: context.textMuted)),
        ],
      ),
    ),
  );
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();
  @override
  Widget build(BuildContext context) => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(
      color: context.inputFill,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.divider.withValues(alpha: 0.5), width: 1),
    ),
    child: Icon(Icons.image_outlined, size: 22, color: context.divider),
  );
}

// ── Visionneuse plein écran ───────────────────────────────────────────────────

class _PhotoViewDialog extends StatelessWidget {
  final String photo;
  final VoidCallback? onDelete;
  const _PhotoViewDialog({required this.photo, this.onDelete});

  @override
  Widget build(BuildContext context) {
    late final Uint8List bytes;
    bool valid = false;
    try {
      bytes = base64Decode(photo.contains(',') ? photo.split(',').last : photo);
      valid = true;
    } catch (_) {}

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Image centrée
          Center(
            child: valid
                ? InteractiveViewer(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  )
                : const Icon(Icons.broken_image, color: Colors.white54, size: 60),
          ),
          // Bouton fermer
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Bouton supprimer
          if (onDelete != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0, right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
