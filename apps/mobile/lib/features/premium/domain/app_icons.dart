/// Beta 3.2 (ADR-027 amendment): the launcher icons FITOS offers. Standard
/// and White for everyone; Gold, Glow and Lime for premium. Each name is an
/// activity-alias `.Icon<Name>` in AndroidManifest.xml and a preview in
/// assets/brand/app_icons/ (both made by tool/app_icons.py).
enum AppIcon {
  standard('Standard', premium: false),
  white('White', premium: false),
  gold('Gold'),
  glow('Glow'),
  lime('Lime');

  const AppIcon(this.label, {this.premium = true});

  final String label;
  final bool premium;

  String get preview => 'assets/brand/app_icons/$name.png';

  static AppIcon? byName(String? name) {
    for (final icon in values) {
      if (icon.name == name) return icon;
    }
    return null;
  }
}
