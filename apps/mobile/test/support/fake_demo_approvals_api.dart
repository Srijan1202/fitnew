import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/exercise/data/demo_approvals_api.dart';
import 'package:fitos/features/exercise/domain/demo/exercise_demos.dart';

/// Beta 5.2: every demo approved unless a test says otherwise.
class FakeDemoApprovalsApi implements DemoApprovalsApi {
  FakeDemoApprovalsApi([Set<String>? approved])
      : approved_ = approved ?? exerciseDemos.keys.toSet();

  Set<String> approved_;
  int calls = 0;

  @override
  Future<Result<Set<String>>> approved() async {
    calls++;
    return Ok({...approved_});
  }
}
