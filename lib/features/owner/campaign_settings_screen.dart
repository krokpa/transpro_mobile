import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/notifications/campaign_config.dart';
import '../../core/notifications/campaign_scheduler.dart';
import '../../core/notifications/notification_prefs_cache.dart';
import '../../core/theme/app_theme.dart';

class CampaignSettingsScreen extends ConsumerStatefulWidget {
  const CampaignSettingsScreen({super.key});

  @override
  ConsumerState<CampaignSettingsScreen> createState() =>
      _CampaignSettingsScreenState();
}

class _CampaignSettingsScreenState
    extends ConsumerState<CampaignSettingsScreen> {
  late CampaignConfig _config;
  bool _saving = false;
  String? _tenantId;

  @override
  void initState() {
    super.initState();
    _tenantId = ref.read(authProvider).user?.tenantId;
    _config = NotifPrefsCache.getConfig(_tenantId);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await NotifPrefsCache.saveConfig(_tenantId, _config);
      await CampaignScheduler.applyConfig(
          config: _config, tenantId: _tenantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Campagnes enregistrées'),
          backgroundColor: Color(0xFF16A34A),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campagnes de notifications'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Enregistrer',
                      style: TextStyle(
                          color: brandOrange, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Intro
          _InfoBanner(
            text:
                'Configurez les notifications marketing envoyées à vos passagers. '
                'Chaque passager peut les désactiver individuellement.',
          ),
          const SizedBox(height: 20),

          // ── Rappel matinal ──────────────────────────────────────────────────
          _CampaignCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Rappel matinal',
            accentColor: const Color(0xFFF59E0B),
            enabled: _config.morningReminderEnabled,
            onToggle: (v) => setState(
                () => _config = _config.copyWith(morningReminderEnabled: v)),
            children: [
              _TimeRow(
                label: 'Heure d\'envoi',
                hour: _config.morningReminderHour,
                minute: _config.morningReminderMinute,
                onChanged: (h, m) => setState(() => _config = _config.copyWith(
                    morningReminderHour: h, morningReminderMinute: m)),
              ),
              _TextField(
                label: 'Titre',
                value: _config.morningReminderTitle,
                onChanged: (v) => setState(
                    () => _config = _config.copyWith(morningReminderTitle: v)),
              ),
              _TextField(
                label: 'Message',
                value: _config.morningReminderBody,
                maxLines: 2,
                onChanged: (v) => setState(
                    () => _config = _config.copyWith(morningReminderBody: v)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Offre week-end ──────────────────────────────────────────────────
          _CampaignCard(
            icon: Icons.celebration_outlined,
            title: 'Offre du week-end',
            accentColor: const Color(0xFF8B5CF6),
            enabled: _config.weekendOfferEnabled,
            onToggle: (v) => setState(
                () => _config = _config.copyWith(weekendOfferEnabled: v)),
            children: [
              _TimeRow(
                label: 'Heure (vendredi)',
                hour: _config.weekendOfferHour,
                minute: _config.weekendOfferMinute,
                onChanged: (h, m) => setState(() => _config = _config.copyWith(
                    weekendOfferHour: h, weekendOfferMinute: m)),
              ),
              _TextField(
                label: 'Titre',
                value: _config.weekendOfferTitle,
                onChanged: (v) => setState(
                    () => _config = _config.copyWith(weekendOfferTitle: v)),
              ),
              _TextField(
                label: 'Message',
                value: _config.weekendOfferBody,
                maxLines: 2,
                onChanged: (v) => setState(
                    () => _config = _config.copyWith(weekendOfferBody: v)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Ré-engagement ───────────────────────────────────────────────────
          _CampaignCard(
            icon: Icons.people_outline_rounded,
            title: 'Ré-engagement',
            accentColor: const Color(0xFF0EA5E9),
            enabled: _config.reEngagementEnabled,
            onToggle: (v) => setState(
                () => _config = _config.copyWith(reEngagementEnabled: v)),
            children: [
              _SliderRow(
                label: 'Délai d\'inactivité',
                value: _config.reEngagementAfterDays.toDouble(),
                min: 3,
                max: 30,
                format: (v) => '${v.round()} jours',
                onChanged: (v) => setState(() => _config =
                    _config.copyWith(reEngagementAfterDays: v.round())),
              ),
              _TextField(
                label: 'Titre',
                value: _config.reEngagementTitle,
                onChanged: (v) => setState(
                    () => _config = _config.copyWith(reEngagementTitle: v)),
              ),
              _TextField(
                label: 'Message',
                value: _config.reEngagementBody,
                maxLines: 2,
                onChanged: (v) => setState(
                    () => _config = _config.copyWith(reEngagementBody: v)),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: brandOrange.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brandOrange.withValues(alpha: 0.18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.campaign_outlined, color: brandOrange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.45)),
          ),
        ]),
      );
}

class _CampaignCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  const _CampaignCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.enabled,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            secondary: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: enabled
                    ? accentColor.withValues(alpha: 0.12)
                    : context.tagBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: enabled ? accentColor : context.textMuted, size: 20),
            ),
            title: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.textPrimary)),
            value: enabled,
            activeThumbColor: accentColor,
            activeTrackColor: accentColor.withValues(alpha: 0.25),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            onChanged: onToggle,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: enabled
                ? Column(children: [
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: children),
                    ),
                  ])
                : const SizedBox.shrink(),
          ),
        ]),
      );
}

class _TimeRow extends StatelessWidget {
  final String label;
  final int hour, minute;
  final void Function(int, int) onChanged;

  const _TimeRow({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final display =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: hour, minute: minute),
            );
            if (picked != null) onChanged(picked.hour, picked.minute);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: context.tagBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.divider),
            ),
            child: Text(display,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: brandOrange)),
          ),
        ),
      ]),
    );
  }
}

class _TextField extends StatefulWidget {
  final String label, value;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _TextField({
    required this.label,
    required this.value,
    this.maxLines = 1,
    required this.onChanged,
  });

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _ctrl,
          maxLines: widget.maxLines,
          style: TextStyle(fontSize: 13, color: context.textPrimary),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle:
                TextStyle(fontSize: 12, color: context.textSecondary),
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: widget.onChanged,
        ),
      );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(format(value),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: brandOrange)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: brandOrange,
              thumbColor: brandOrange,
              inactiveTrackColor: brandOrange.withValues(alpha: 0.2),
              overlayColor: brandOrange.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: onChanged,
            ),
          ),
        ]),
      );
}
