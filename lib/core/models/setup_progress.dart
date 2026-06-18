enum SetupStepStatus { completed, pending, blocked }

enum SetupMilestone { notStarted, started, advanced, almostReady, operational }

class SetupStep {
  final String id;
  final String title;
  final String description;
  final SetupStepStatus status;
  final int percentage;
  final String icon;
  final String? route;
  final String? action;
  final String? blockedReason;
  final String? blockedAction;
  final String? blockedRoute;

  const SetupStep({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.percentage,
    required this.icon,
    this.route,
    this.action,
    this.blockedReason,
    this.blockedAction,
    this.blockedRoute,
  });

  factory SetupStep.fromJson(Map<String, dynamic> j) => SetupStep(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    status: _parseStatus(j['status'] as String),
    percentage: (j['percentage'] as num).toInt(),
    icon: j['icon'] as String? ?? 'check_circle',
    route: j['route'] as String?,
    action: j['action'] as String?,
    blockedReason: j['blockedReason'] as String?,
    blockedAction: j['blockedAction'] as String?,
    blockedRoute: j['blockedRoute'] as String?,
  );

  static SetupStepStatus _parseStatus(String s) => switch (s) {
    'COMPLETED' => SetupStepStatus.completed,
    'BLOCKED'   => SetupStepStatus.blocked,
    _           => SetupStepStatus.pending,
  };

  bool get isCompleted => status == SetupStepStatus.completed;
  bool get isPending   => status == SetupStepStatus.pending;
  bool get isBlocked   => status == SetupStepStatus.blocked;
}

class SetupProgress {
  final String role;
  final int overall;
  final bool isComplete;
  final SetupMilestone milestoneReached;
  final SetupStep? nextStep;
  final List<SetupStep> steps;

  const SetupProgress({
    required this.role,
    required this.overall,
    required this.isComplete,
    required this.milestoneReached,
    required this.steps,
    this.nextStep,
  });

  factory SetupProgress.fromJson(Map<String, dynamic> j) {
    final stepsJson = (j['steps'] as List).cast<Map<String, dynamic>>();
    final nextJson  = j['nextStep'] as Map<String, dynamic>?;
    return SetupProgress(
      role:            j['role'] as String,
      overall:         (j['overall'] as num).toInt(),
      isComplete:      j['isComplete'] as bool? ?? false,
      milestoneReached: _parseMilestone(j['milestoneReached'] as String? ?? ''),
      steps:           stepsJson.map(SetupStep.fromJson).toList(),
      nextStep:        nextJson != null ? SetupStep.fromJson(nextJson) : null,
    );
  }

  static SetupMilestone _parseMilestone(String s) => switch (s) {
    'OPERATIONAL'   => SetupMilestone.operational,
    'ALMOST_READY'  => SetupMilestone.almostReady,
    'ADVANCED'      => SetupMilestone.advanced,
    'STARTED'       => SetupMilestone.started,
    _               => SetupMilestone.notStarted,
  };

  String get milestoneLabel => switch (milestoneReached) {
    SetupMilestone.operational  => 'Système opérationnel',
    SetupMilestone.almostReady  => 'Presque prêt',
    SetupMilestone.advanced     => 'Configuration avancée',
    SetupMilestone.started      => 'Configuration démarrée',
    SetupMilestone.notStarted   => 'Non démarré',
  };

  String get milestoneEmoji => switch (milestoneReached) {
    SetupMilestone.operational  => '🎉',
    SetupMilestone.almostReady  => '🚀',
    SetupMilestone.advanced     => '⚡',
    SetupMilestone.started      => '✨',
    SetupMilestone.notStarted   => '🌱',
  };

  int get completedCount => steps.where((s) => s.isCompleted).length;
  int get totalCount     => steps.length;
}
