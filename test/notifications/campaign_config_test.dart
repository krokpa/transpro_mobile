import 'package:flutter_test/flutter_test.dart';
import 'package:transpro_mobile/core/notifications/campaign_config.dart';

void main() {
  group('CampaignConfig.defaults', () {
    test('all campaigns are disabled by default', () {
      const cfg = CampaignConfig.defaults;
      expect(cfg.morningReminderEnabled, isFalse);
      expect(cfg.weekendOfferEnabled, isFalse);
      expect(cfg.reEngagementEnabled, isFalse);
    });

    test('default times are sensible', () {
      const cfg = CampaignConfig.defaults;
      expect(cfg.morningReminderHour, 7);
      expect(cfg.morningReminderMinute, 30);
      expect(cfg.weekendOfferHour, 18);
      expect(cfg.weekendOfferMinute, 0);
      expect(cfg.reEngagementAfterDays, 7);
    });
  });

  group('CampaignConfig.fromJson', () {
    test('parses all fields from JSON', () {
      final json = {
        'morningReminderEnabled': true,
        'morningReminderHour': 8,
        'morningReminderMinute': 15,
        'morningReminderTitle': 'Salut !',
        'morningReminderBody': 'Corps personnalisé',
        'weekendOfferEnabled': false,
        'weekendOfferHour': 17,
        'weekendOfferMinute': 30,
        'weekendOfferTitle': 'Week-end',
        'weekendOfferBody': 'Offre',
        'reEngagementEnabled': true,
        'reEngagementAfterDays': 14,
        'reEngagementTitle': 'Retour',
        'reEngagementBody': 'On vous attend',
      };
      final cfg = CampaignConfig.fromJson(json);

      expect(cfg.morningReminderEnabled, isTrue);
      expect(cfg.morningReminderHour, 8);
      expect(cfg.morningReminderMinute, 15);
      expect(cfg.morningReminderTitle, 'Salut !');
      expect(cfg.weekendOfferEnabled, isFalse);
      expect(cfg.reEngagementEnabled, isTrue);
      expect(cfg.reEngagementAfterDays, 14);
    });

    test('falls back to defaults when fields are missing', () {
      final cfg = CampaignConfig.fromJson({});
      expect(cfg.morningReminderEnabled, isFalse);
      expect(cfg.morningReminderHour, 7);
      expect(cfg.morningReminderMinute, 30);
      expect(cfg.weekendOfferHour, 18);
      expect(cfg.reEngagementAfterDays, 7);
    });
  });

  group('CampaignConfig.toJson', () {
    test('round-trips through JSON', () {
      const original = CampaignConfig(
        morningReminderEnabled: true,
        morningReminderHour: 9,
        morningReminderMinute: 0,
        morningReminderTitle: 'Hello',
        morningReminderBody: 'Body',
        weekendOfferEnabled: true,
        weekendOfferHour: 19,
        weekendOfferMinute: 15,
        weekendOfferTitle: 'WE',
        weekendOfferBody: 'WE body',
        reEngagementEnabled: false,
        reEngagementAfterDays: 10,
        reEngagementTitle: 'Title',
        reEngagementBody: 'Body',
      );

      final restored = CampaignConfig.fromJson(original.toJson());

      expect(restored.morningReminderEnabled, original.morningReminderEnabled);
      expect(restored.morningReminderHour, original.morningReminderHour);
      expect(restored.weekendOfferEnabled, original.weekendOfferEnabled);
      expect(restored.weekendOfferHour, original.weekendOfferHour);
      expect(restored.weekendOfferMinute, original.weekendOfferMinute);
      expect(restored.reEngagementAfterDays, original.reEngagementAfterDays);
    });
  });

  group('CampaignConfig.toJsonString / fromJsonString', () {
    test('round-trips through JSON string', () {
      const cfg = CampaignConfig(morningReminderEnabled: true);
      final restored = CampaignConfig.fromJsonString(cfg.toJsonString());
      expect(restored.morningReminderEnabled, isTrue);
    });

    test('throws on invalid JSON string', () {
      expect(
        () => CampaignConfig.fromJsonString('not-json'),
        throwsA(anything),
      );
    });
  });

  group('CampaignConfig.copyWith', () {
    test('overrides only specified fields', () {
      const original = CampaignConfig.defaults;
      final updated = original.copyWith(
        morningReminderEnabled: true,
        morningReminderHour: 9,
      );

      expect(updated.morningReminderEnabled, isTrue);
      expect(updated.morningReminderHour, 9);
      // Unchanged fields preserved
      expect(updated.weekendOfferEnabled, isFalse);
      expect(updated.reEngagementAfterDays, 7);
    });

    test('returns unchanged config when no arguments provided', () {
      const original = CampaignConfig(morningReminderEnabled: true, morningReminderHour: 8);
      final copy = original.copyWith();
      expect(copy.morningReminderEnabled, isTrue);
      expect(copy.morningReminderHour, 8);
    });
  });
}
