import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_constants.dart';
import '../theme/app_theme.dart';

/// Section « Légal » réutilisable : ouvre les pages juridiques publiques
/// (hébergées sur la landing white-label) dans le navigateur externe.
class LegalLinksSection extends StatelessWidget {
  const LegalLinksSection({super.key});

  static const _links = <({String label, String path})>[
    (label: "Conditions d'utilisation (CGU)", path: 'cgu'),
    (label: 'Conditions de vente (CGV)',       path: 'cgv'),
    (label: 'Politique de confidentialité',    path: 'confidentialite'),
    (label: 'Mentions légales',                path: 'mentions-legales'),
    (label: 'Politique de cookies',            path: 'cookies'),
  ];

  Future<void> _open(String path) async {
    final uri = Uri.parse('$kPublicWebUrl/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'Légal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < _links.length; i++) ...[
                ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: context.inputFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.description_outlined,
                        size: 18, color: context.textSecondary),
                  ),
                  title: Text(_links[i].label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: Icon(Icons.open_in_new_rounded, size: 16, color: context.textMuted),
                  onTap: () => _open(_links[i].path),
                ),
                if (i < _links.length - 1)
                  Divider(height: 1, color: context.divider, indent: 60),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
