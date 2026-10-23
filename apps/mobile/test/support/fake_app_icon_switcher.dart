import 'package:fitos/features/premium/domain/app_icons.dart';
import 'package:fitos/features/premium/presentation/app_icon_controller.dart';

/// Beta 3.2: the launcher icon without Android; [icon] null is a phone where
/// it cannot change.
class FakeAppIconSwitcher implements AppIconSwitcher {
  FakeAppIconSwitcher({this.icon = AppIcon.standard});

  AppIcon? icon;
  bool refuse = false;
  final chosen = <AppIcon>[];

  @override
  Future<AppIcon?> current() async => icon;

  @override
  Future<void> choose(AppIcon next) async {
    if (refuse) throw StateError('refused');
    chosen.add(next);
    icon = next;
  }
}
