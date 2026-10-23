import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/home/data/streak_api.dart';

/// Beta 3.3: a scripted `GET /v1/progress/streak`. Null answers as the
/// server being unreachable, and the Home card hides.
class FakeStreakApi implements StreakApi {
  FakeStreakApi([this.next]);

  Streak? next;
  int calls = 0;

  @override
  Future<Result<Streak>> streak() async {
    calls++;
    final s = next;
    return s == null ? const Err(Unknown()) : Ok(s);
  }
}
