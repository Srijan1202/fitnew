/// Wire shapes of `@fitos/contracts` notifications.ts (Phase 15, ADR-021).
/// Hand-written (ADR-004); the conformance test keeps them in step.
///
/// The server plans (timing, the 4-a-day cap, the words); the phone
/// schedules what it is given and cancels an item the moment its point is
/// gone. Nothing here decides what to send.
library;

enum NotifyKind {
  workoutReminder(
    'workout-reminder',
    'Workout reminder',
    'About an hour before you usually train, on training days.',
  ),
  missedSession(
    'missed-session',
    'Missed session',
    "The morning after a planned session that didn't happen.",
  ),
  proteinGap(
    'protein-gap',
    'Protein nudge',
    'Before dinner, only while protein is under three quarters of your target.',
  ),
  streakAtRisk(
    'streak-at-risk',
    'Streak saver',
    'In the evening, only if nothing is logged that day.',
  ),
  weighIn(
    'weigh-in',
    'Weigh-in reminder',
    'Mornings, after two or more days without a reading.',
  ),
  recoveryCheckin(
    'recovery-checkin',
    'Recovery check-in',
    "Mornings, until you've checked in.",
  ),
  weeklyRecap('weekly-recap', 'Weekly recap', 'Sunday evening, your week.'),
  comeback(
    'comeback',
    'Come back',
    "Only if FITOS isn't opened for a few days. Stops after a week.",
  ),
  // Beta 3.5 (owner): at the person's own meal times, learned from their logs.
  mealBreakfast(
    'meal-breakfast',
    'Breakfast reminder',
    "About half an hour after you usually log breakfast, if it isn't logged yet. Not if you rarely log it.",
  ),
  mealLunch(
    'meal-lunch',
    'Lunch reminder',
    "About half an hour after you usually log lunch, if it isn't logged yet. Not if you rarely log it.",
  ),
  mealDinner(
    'meal-dinner',
    'Dinner reminder',
    "About half an hour after you usually log dinner, if it isn't logged yet. Not if you rarely log it.",
  );

  const NotifyKind(this.wire, this.label, this.description);
  final String wire;
  final String label;
  final String description;

  static NotifyKind? of(Object? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

enum NotifyTone {
  cheeky('cheeky', 'Cheeky', 'Teasing, a little guilt. Never about your body.'),
  gentle('gentle', 'Gentle', 'Kind and plain.');

  const NotifyTone(this.wire, this.label, this.description);
  final String wire;
  final String label;
  final String description;

  static NotifyTone of(Object? wire) =>
      wire == 'gentle' ? NotifyTone.gentle : NotifyTone.cheeky;
}

class NotifySettings {
  const NotifySettings({
    required this.enabled,
    required this.tone,
    required this.kinds,
    required this.quietStart,
    required this.quietEnd,
  });

  factory NotifySettings.fromJson(Map<String, dynamic> json) {
    final kinds = json['kinds'] as Map<String, dynamic>;
    return NotifySettings(
      enabled: json['enabled'] as bool,
      tone: NotifyTone.of(json['tone']),
      kinds: {
        for (final k in NotifyKind.values) k: kinds[k.wire] as bool? ?? false,
      },
      quietStart: json['quietStart'] as String,
      quietEnd: json['quietEnd'] as String,
    );
  }

  final bool enabled;
  final NotifyTone tone;
  final Map<NotifyKind, bool> kinds;

  /// "HH:MM", local.
  final String quietStart;
  final String quietEnd;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'tone': tone.wire,
        'kinds': {for (final e in kinds.entries) e.key.wire: e.value},
        'quietStart': quietStart,
        'quietEnd': quietEnd,
      };
}

/// What, done on the phone, cancels a scheduled item.
class CancelRule {
  const CancelRule({
    required this.event,
    required this.localDate,
    this.grams,
    this.slot,
  });

  factory CancelRule.fromJson(Map<String, dynamic> json) => CancelRule(
        event: json['event'] as String,
        localDate: json['localDate'] as String,
        grams: (json['grams'] as num?)?.toDouble(),
        slot: json['slot'] as String?,
      );

  /// A contracts `CANCEL_EVENTS` value.
  final String event;
  final String localDate;

  /// protein-reached only.
  final double? grams;

  /// food-logged only (beta 3.5): just this meal; null = any meal.
  final String? slot;

  Map<String, dynamic> toJson() => {
        'event': event,
        'localDate': localDate,
        'grams': grams,
        if (slot != null) 'slot': slot,
      };
}

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.localDate,
    required this.at,
    required this.title,
    required this.body,
    required this.variant,
    required this.tone,
    required this.screen,
    required this.slot,
    required this.actions,
    required this.cancelOn,
    required this.why,
  });

  factory PlannedNotification.fromJson(Map<String, dynamic> json) =>
      PlannedNotification(
        id: json['id'] as String,
        kind: json['kind'] as String,
        localDate: json['localDate'] as String,
        at: DateTime.parse(json['at'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        variant: json['variant'] as String,
        tone: json['tone'] as String,
        screen: json['screen'] as String,
        slot: json['slot'] as String?,
        actions: [
          for (final a in json['actions'] as List<dynamic>) a as String,
        ],
        cancelOn: [
          for (final c in json['cancelOn'] as List<dynamic>)
            CancelRule.fromJson(c as Map<String, dynamic>),
        ],
        why: json['why'] as String,
      );

  final String id;

  /// A contracts kind (kept as wire text so an unknown future kind still schedules).
  final String kind;
  final String localDate;
  final DateTime at;
  final String title;
  final String body;
  final String variant;
  final String tone;

  /// 'today' | 'plan' | 'food-log' | 'progress'.
  final String screen;
  final String? slot;
  final List<String> actions;
  final List<CancelRule> cancelOn;
  final String why;

  NotifyKind? get notifyKind => NotifyKind.of(kind);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'localDate': localDate,
        'at': at.toUtc().toIso8601String(),
        'title': title,
        'body': body,
        'variant': variant,
        'tone': tone,
        'screen': screen,
        'slot': slot,
        'actions': actions,
        'cancelOn': [for (final c in cancelOn) c.toJson()],
        'why': why,
      };
}

class NotifyPlan {
  const NotifyPlan({
    required this.generatedAt,
    required this.timeZone,
    required this.settings,
    required this.items,
  });

  factory NotifyPlan.fromJson(Map<String, dynamic> json) => NotifyPlan(
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        timeZone: json['timeZone'] as String,
        settings:
            NotifySettings.fromJson(json['settings'] as Map<String, dynamic>),
        items: [
          for (final i in json['items'] as List<dynamic>)
            PlannedNotification.fromJson(i as Map<String, dynamic>),
        ],
      );

  final DateTime generatedAt;
  final String timeZone;
  final NotifySettings settings;
  final List<PlannedNotification> items;

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'timeZone': timeZone,
        'settings': settings.toJson(),
        'items': [for (final i in items) i.toJson()],
      };
}

/// What happened to a scheduled item, reported with the next plan request.
class NotifyEvent {
  const NotifyEvent({required this.id, required this.event, required this.at});

  factory NotifyEvent.fromJson(Map<String, dynamic> json) => NotifyEvent(
        id: json['id'] as String,
        event: json['event'] as String,
        at: DateTime.parse(json['at'] as String),
      );

  final String id;

  /// 'delivered' | 'opened' | 'cancelled'.
  final String event;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'id': id, 'event': event, 'at': at.toUtc().toIso8601String()};
}
