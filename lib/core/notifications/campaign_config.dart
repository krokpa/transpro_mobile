import 'dart:convert';

class CampaignConfig {
  final bool morningReminderEnabled;
  final int morningReminderHour;
  final int morningReminderMinute;
  final String morningReminderTitle;
  final String morningReminderBody;

  final bool weekendOfferEnabled;
  final int weekendOfferHour;
  final int weekendOfferMinute;
  final String weekendOfferTitle;
  final String weekendOfferBody;

  final bool reEngagementEnabled;
  final int reEngagementAfterDays;
  final String reEngagementTitle;
  final String reEngagementBody;

  const CampaignConfig({
    this.morningReminderEnabled = false,
    this.morningReminderHour = 7,
    this.morningReminderMinute = 30,
    this.morningReminderTitle = 'Bonjour !',
    this.morningReminderBody = 'Planifiez votre prochain voyage dès maintenant.',
    this.weekendOfferEnabled = false,
    this.weekendOfferHour = 18,
    this.weekendOfferMinute = 0,
    this.weekendOfferTitle = 'Bon week-end !',
    this.weekendOfferBody =
        'Voyagez en famille ce week-end. Réservez vos places maintenant.',
    this.reEngagementEnabled = false,
    this.reEngagementAfterDays = 7,
    this.reEngagementTitle = 'On vous attend !',
    this.reEngagementBody =
        'Ça fait un moment ! Où voyagez-vous cette semaine ?',
  });

  static const CampaignConfig defaults = CampaignConfig();

  CampaignConfig copyWith({
    bool? morningReminderEnabled,
    int? morningReminderHour,
    int? morningReminderMinute,
    String? morningReminderTitle,
    String? morningReminderBody,
    bool? weekendOfferEnabled,
    int? weekendOfferHour,
    int? weekendOfferMinute,
    String? weekendOfferTitle,
    String? weekendOfferBody,
    bool? reEngagementEnabled,
    int? reEngagementAfterDays,
    String? reEngagementTitle,
    String? reEngagementBody,
  }) {
    return CampaignConfig(
      morningReminderEnabled:
          morningReminderEnabled ?? this.morningReminderEnabled,
      morningReminderHour: morningReminderHour ?? this.morningReminderHour,
      morningReminderMinute:
          morningReminderMinute ?? this.morningReminderMinute,
      morningReminderTitle: morningReminderTitle ?? this.morningReminderTitle,
      morningReminderBody: morningReminderBody ?? this.morningReminderBody,
      weekendOfferEnabled: weekendOfferEnabled ?? this.weekendOfferEnabled,
      weekendOfferHour: weekendOfferHour ?? this.weekendOfferHour,
      weekendOfferMinute: weekendOfferMinute ?? this.weekendOfferMinute,
      weekendOfferTitle: weekendOfferTitle ?? this.weekendOfferTitle,
      weekendOfferBody: weekendOfferBody ?? this.weekendOfferBody,
      reEngagementEnabled: reEngagementEnabled ?? this.reEngagementEnabled,
      reEngagementAfterDays:
          reEngagementAfterDays ?? this.reEngagementAfterDays,
      reEngagementTitle: reEngagementTitle ?? this.reEngagementTitle,
      reEngagementBody: reEngagementBody ?? this.reEngagementBody,
    );
  }

  Map<String, dynamic> toJson() => {
        'morningReminderEnabled': morningReminderEnabled,
        'morningReminderHour': morningReminderHour,
        'morningReminderMinute': morningReminderMinute,
        'morningReminderTitle': morningReminderTitle,
        'morningReminderBody': morningReminderBody,
        'weekendOfferEnabled': weekendOfferEnabled,
        'weekendOfferHour': weekendOfferHour,
        'weekendOfferMinute': weekendOfferMinute,
        'weekendOfferTitle': weekendOfferTitle,
        'weekendOfferBody': weekendOfferBody,
        'reEngagementEnabled': reEngagementEnabled,
        'reEngagementAfterDays': reEngagementAfterDays,
        'reEngagementTitle': reEngagementTitle,
        'reEngagementBody': reEngagementBody,
      };

  factory CampaignConfig.fromJson(Map<String, dynamic> j) => CampaignConfig(
        morningReminderEnabled:
            j['morningReminderEnabled'] as bool? ?? false,
        morningReminderHour: j['morningReminderHour'] as int? ?? 7,
        morningReminderMinute: j['morningReminderMinute'] as int? ?? 30,
        morningReminderTitle:
            j['morningReminderTitle'] as String? ?? 'Bonjour !',
        morningReminderBody: j['morningReminderBody'] as String? ??
            'Planifiez votre prochain voyage dès maintenant.',
        weekendOfferEnabled: j['weekendOfferEnabled'] as bool? ?? false,
        weekendOfferHour: j['weekendOfferHour'] as int? ?? 18,
        weekendOfferMinute: j['weekendOfferMinute'] as int? ?? 0,
        weekendOfferTitle:
            j['weekendOfferTitle'] as String? ?? 'Bon week-end !',
        weekendOfferBody: j['weekendOfferBody'] as String? ??
            'Voyagez en famille ce week-end. Réservez vos places maintenant.',
        reEngagementEnabled: j['reEngagementEnabled'] as bool? ?? false,
        reEngagementAfterDays: j['reEngagementAfterDays'] as int? ?? 7,
        reEngagementTitle:
            j['reEngagementTitle'] as String? ?? 'On vous attend !',
        reEngagementBody: j['reEngagementBody'] as String? ??
            'Ça fait un moment ! Où voyagez-vous cette semaine ?',
      );

  String toJsonString() => jsonEncode(toJson());

  static CampaignConfig fromJsonString(String s) =>
      CampaignConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
