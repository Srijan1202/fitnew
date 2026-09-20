import 'package:flutter/material.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/tokens.dart';
import '../../../../profile/domain/entities/profile.dart';
import '../../../domain/entities/onboarding.dart';
import '../../widgets/onboarding_step.dart';
import 'goal_step.dart' show SubmitAnswer;

/// The six VIT Vellore messes, mirroring packages/core's
/// `mess/providers/vit/config.ts` — the same ids, hostels and labels.
///
/// Static until Phase 9 ships `GET /mess/providers/{slug}/messes`; at that
/// point this list is replaced by the endpoint and nothing else changes.
/// These are real messes with verified endpoints, not placeholders.
class _Mess {
  const _Mess(this.hostelId, this.hostelLabel, this.messId, this.messLabel);
  final String hostelId;
  final String hostelLabel;
  final String messId;
  final String messLabel;
}

const _kProvider = 'vit-vellore';
const _kHostels = <String, String>{
  'mens': "Men's Hostel",
  'womens': "Women's Hostel",
};
const _kMesses = <_Mess>[
  _Mess('mens', "Men's Hostel", 'veg', 'Vegetarian'),
  _Mess('mens', "Men's Hostel", 'nonveg', 'Non-Vegetarian'),
  _Mess('mens', "Men's Hostel", 'special', 'Special'),
  _Mess('womens', "Women's Hostel", 'veg', 'Vegetarian'),
  _Mess('womens', "Women's Hostel", 'nonveg', 'Non-Vegetarian'),
  _Mess('womens', "Women's Hostel", 'special', 'Special'),
];

/// Screen 6 — VIT? (§32). Conditional: a non-student answers "no" and moves
/// on; a student picks hostel then mess.
class VitStep extends StatefulWidget {
  const VitStep({
    required this.state,
    required this.submit,
    required this.onBack,
    required this.onNext,
    super.key,
  });

  final OnboardingState state;
  final SubmitAnswer submit;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  State<VitStep> createState() => _VitStepState();
}

class _VitStepState extends State<VitStep> {
  bool? _isStudent;
  String? _hostel;
  String? _mess;
  bool _busy = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    final m = widget.state.profile.mess;
    if (m != null) {
      _isStudent = true;
      _hostel = m.hostelId;
      _mess = m.messId;
    } else if (widget.state.answered.contains(widget.state.stage) ||
        widget.state.profile.onboardingStage == 'complete') {
      _isStudent = false;
    }
  }

  bool get _ready =>
      _isStudent == false ||
      (_isStudent == true && _hostel != null && _mess != null);

  Future<void> _continue() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.submit(
      OnboardingAnswer.vit(
        isVitStudent: _isStudent!,
        mess: _isStudent!
            ? MessRef(
                providerId: _kProvider,
                hostelId: _hostel!,
                messId: _mess!,
              )
            : null,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
    if (failure == null) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final messesForHostel =
        _kMesses.where((m) => m.hostelId == _hostel).toList();

    return OnboardingStep(
      screenNumber: 6,
      title: 'Do you eat at a VIT mess?',
      lede:
          "If so, FitOS reads tonight's actual menu and tells you what to eat. If not, skip this.",
      busy: _busy,
      failure: _failure,
      canContinue: _ready,
      onBack: widget.onBack,
      onContinue: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChoiceList<bool>(
            options: const [true, false],
            selected: _isStudent,
            enabled: !_busy,
            onSelect: (v) => setState(() {
              _isStudent = v;
              if (!v) {
                _hostel = null;
                _mess = null;
              }
            }),
            label: (v) => v ? 'Yes, I live in a VIT Vellore hostel' : 'No',
          ),
          if (_isStudent == true) ...<Widget>[
            const SizedBox(height: FitSpacing.lg),
            Text('HOSTEL', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            ChoiceList<String>(
              options: _kHostels.keys.toList(),
              selected: _hostel,
              enabled: !_busy,
              onSelect: (h) => setState(() {
                _hostel = h;
                _mess = null;
              }),
              label: (h) => _kHostels[h]!,
            ),
            if (_hostel != null) ...<Widget>[
              const SizedBox(height: FitSpacing.lg),
              Text('MESS', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              ChoiceList<String>(
                options: messesForHostel.map((m) => m.messId).toList(),
                selected: _mess,
                enabled: !_busy,
                onSelect: (m) => setState(() => _mess = m),
                label: (id) =>
                    messesForHostel.firstWhere((m) => m.messId == id).messLabel,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
