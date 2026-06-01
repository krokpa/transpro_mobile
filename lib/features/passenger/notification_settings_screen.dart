import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/notifications/campaign_config.dart';
import '../../core/notifications/campaign_scheduler.dart';
import '../../core/notifications/notification_prefs_cache.dart';
import '../../core/theme/app_theme.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class _PrefsState {
  final bool morningReminder;
  final bool weekendOffer;
  final bool reEngagement;
  const _PrefsState({
    required this.morningReminder,
    required this.weekendOffer,
    required this.reEngagement,
  });

  static _PrefsState read() => _PrefsState(
        morningReminder: NotifPrefsCache.isCampaignEnabled('morningReminder'),
        weekendOffer: NotifPrefsCache.isCampaignEnabled('weekendOffer'),
        reEngagement: NotifPrefsCache.isCampaignEnabled('reEngagement'),
      );
}

class _PrefsNotifier extends StateNotifier<_PrefsState> {
  _PrefsNotifier() : super(_PrefsState.read());

  Future<void> toggle(String key, bool value, String? tenantId) async {
    await NotifPrefsCache.setCampaignEnabled(key, value);
    final config = NotifPrefsCache.getConfig(tenantId);
    await CampaignScheduler.applyConfig(config: config, tenantId: tenantId);
    state = _PrefsState.read();
  }
}

final _prefsProvider = StateNotifierProvider.autoDispose<_PrefsNotifier, _PrefsState>(
  (_) => _PrefsNotifier(),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs    = ref.watch(_prefsProvider);
    final notifier = ref.read(_prefsProvider.notifier);
    final tenantId = ref.read(authProvider).user?.tenantId;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          _InfoBanner(
            icon: Icons.info_outline_rounded,
            text:
                'Les notifications transactionnelles (réservations, paiements, billets) '
                'sont toujours actives.',
          ),
          const SizedBox(height: 20),

          // Campagnes
          _SectionLabel(label: 'CAMPAGNES & RAPPELS'),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              _CampaignTile(
                icon: Icons.wb_sunny_outlined,
                title: 'Rappel matinal',
                subtitle:
                    'Notification chaque matin pour planifier votre trajet',
                enabled: prefs.morningReminder,
                onChanged: (v) =>
                    notifier.toggle('morningReminder', v, tenantId),
              ),
              const Divider(height: 1, indent: 70),
              _CampaignTile(
                icon: Icons.celebration_outlined,
                title: 'Offre du week-end',
                subtitle:
                    'Rappel chaque vendredi soir avec les offres disponibles',
                enabled: prefs.weekendOffer,
                onChanged: (v) =>
                    notifier.toggle('weekendOffer', v, tenantId),
              ),
              const Divider(height: 1, indent: 70),
              _CampaignTile(
                icon: Icons.directions_bus_outlined,
                title: 'Retour sur l\'appli',
                subtitle:
                    'Rappel si vous n\'avez pas voyagé depuis un moment',
                enabled: prefs.reEngagement,
                onChanged: (v) =>
                    notifier.toggle('reEngagement', v, tenantId),
              ),
            ]),
          ),

          const SizedBox(height: 16),
          _InfoBanner(
            icon: Icons.lock_outline_rounded,
            text:
                'Ces préférences sont locales à votre appareil. '
                'La compagnie de transport peut activer ou désactiver des campagnes de son côté.',
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: brandOrange.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brandOrange.withValues(alpha: 0.18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: brandOrange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12, color: context.textSecondary, height: 1.45),
            ),
          ),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: context.textSecondary,
          ),
        ),
      );
}

class _CampaignTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _CampaignTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled
                ? brandOrange.withValues(alpha: 0.12)
                : context.tagBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: enabled ? brandOrange : context.textMuted, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12, color: context.textMuted, height: 1.35)),
        value: enabled,
        activeThumbColor: brandOrange,
        activeTrackColor: brandOrange.withValues(alpha: 0.25),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onChanged: onChanged,
      );
}
