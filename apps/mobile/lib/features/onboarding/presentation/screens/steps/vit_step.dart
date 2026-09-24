import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/tokens.dart';
import '../../../../mess/domain/mess.dart';
import '../../../../mess/presentation/mess_providers.dart';
import '../../../../profile/domain/entities/profile.dart';
import '../../../domain/entities/onboarding.dart';
import '../../widgets/onboarding_step.dart';
import 'goal_step.dart' show SubmitAnswer;

/// Screen 6 — VIT? (§32). Conditional: a non-student answers "no" and moves
/// on; a student picks hostel then mess, from the server's list (Phase 9,
/// owner D13 — `GET /mess/providers/vit-vellore/messes`; the server refuses
/// any mess it does not list).
class VitStep extends ConsumerStatefulWidget {
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
  ConsumerState<VitStep> createState() => _VitStepState();
}

class _VitStepState extends ConsumerState<VitStep> {
  /// The provider the chosen mess belongs to (from the server's list).
  String _provider = 'vit-vellore';
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
                providerId: _provider,
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
    // Only asked for once the user says they eat at a VIT mess.
    final messes = _isStudent == true ? ref.watch(messesProvider) : null;
    final list = messes?.value ?? const <Mess>[];
    final hostels = <String, String>{
      for (final m in list) m.hostelId: m.hostelLabel,
    };
    final messesForHostel = list.where((m) => m.hostelId == _hostel).toList();

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
          if (_isStudent == true && messes != null && messes.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: FitSpacing.lg),
              child: Text('Loading the messes…'),
            ),
          if (_isStudent == true && messes != null && messes.hasError) ...[
            const SizedBox(height: FitSpacing.lg),
            Text(
              messes.error is Offline
                  ? 'The list of messes needs a connection.'
                  : 'Could not load the messes.',
              key: const ValueKey('vit.messesError'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
            ),
            TextButton(
              onPressed: () => ref.invalidate(messesProvider),
              child: const Text('Try again'),
            ),
          ],
          if (_isStudent == true && hostels.isNotEmpty) ...<Widget>[
            const SizedBox(height: FitSpacing.lg),
            Text('HOSTEL', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            ChoiceList<String>(
              options: hostels.keys.toList(),
              selected: _hostel,
              enabled: !_busy,
              onSelect: (h) => setState(() {
                _hostel = h;
                _mess = null;
              }),
              label: (h) => hostels[h]!,
            ),
            if (_hostel != null) ...<Widget>[
              const SizedBox(height: FitSpacing.lg),
              Text('MESS', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              ChoiceList<String>(
                options: messesForHostel.map((m) => m.messId).toList(),
                selected: _mess,
                enabled: !_busy,
                onSelect: (m) => setState(() {
                  _mess = m;
                  _provider = messesForHostel
                      .firstWhere((x) => x.messId == m)
                      .providerSlug;
                }),
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
