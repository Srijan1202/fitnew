/// Beta 3.4 (ADR-027 amendment, owner 2026-10-24): what a streak earns —
/// the same for free and premium users, kept forever once earned. The ids
/// and days are the server's (contracts `STREAK_REWARDS`, checked by a test).
enum StreakReward {
  spark('spark', 7, 'Spark picture'),
  emberTheme('ember-theme', 14, 'Ember theme'),
  blazeIcon('blaze-icon', 30, 'Blaze app icon'),
  emberRim('ember-rim', 60, 'Ember rim'),
  century('century', 100, 'Century picture and badge');

  const StreakReward(this.id, this.days, this.label);

  final String id;
  final int days;
  final String label;

  static StreakReward? byId(String? id) {
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// "Reach a 14-day streak to unlock the Ember theme."
  String get howToEarn => 'Reach a $days-day streak to unlock the $label.';
}
