// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConsentGrant {
  String get policyVersion;
  List<ConsentType> get types;

  /// Create a copy of ConsentGrant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ConsentGrantCopyWith<ConsentGrant> get copyWith =>
      _$ConsentGrantCopyWithImpl<ConsentGrant>(
          this as ConsentGrant, _$identity);

  /// Serializes this ConsentGrant to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ConsentGrant &&
            (identical(other.policyVersion, policyVersion) ||
                other.policyVersion == policyVersion) &&
            const DeepCollectionEquality().equals(other.types, types));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, policyVersion, const DeepCollectionEquality().hash(types));

  @override
  String toString() {
    return 'ConsentGrant(policyVersion: $policyVersion, types: $types)';
  }
}

/// @nodoc
abstract mixin class $ConsentGrantCopyWith<$Res> {
  factory $ConsentGrantCopyWith(
          ConsentGrant value, $Res Function(ConsentGrant) _then) =
      _$ConsentGrantCopyWithImpl;
  @useResult
  $Res call({String policyVersion, List<ConsentType> types});
}

/// @nodoc
class _$ConsentGrantCopyWithImpl<$Res> implements $ConsentGrantCopyWith<$Res> {
  _$ConsentGrantCopyWithImpl(this._self, this._then);

  final ConsentGrant _self;
  final $Res Function(ConsentGrant) _then;

  /// Create a copy of ConsentGrant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? policyVersion = null,
    Object? types = null,
  }) {
    return _then(_self.copyWith(
      policyVersion: null == policyVersion
          ? _self.policyVersion
          : policyVersion // ignore: cast_nullable_to_non_nullable
              as String,
      types: null == types
          ? _self.types
          : types // ignore: cast_nullable_to_non_nullable
              as List<ConsentType>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ConsentGrant].
extension ConsentGrantPatterns on ConsentGrant {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ConsentGrant value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConsentGrant() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_ConsentGrant value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsentGrant():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ConsentGrant value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsentGrant() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String policyVersion, List<ConsentType> types)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConsentGrant() when $default != null:
        return $default(_that.policyVersion, _that.types);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String policyVersion, List<ConsentType> types) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsentGrant():
        return $default(_that.policyVersion, _that.types);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String policyVersion, List<ConsentType> types)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConsentGrant() when $default != null:
        return $default(_that.policyVersion, _that.types);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ConsentGrant implements ConsentGrant {
  const _ConsentGrant(
      {required this.policyVersion, required final List<ConsentType> types})
      : _types = types;
  factory _ConsentGrant.fromJson(Map<String, dynamic> json) =>
      _$ConsentGrantFromJson(json);

  @override
  final String policyVersion;
  final List<ConsentType> _types;
  @override
  List<ConsentType> get types {
    if (_types is EqualUnmodifiableListView) return _types;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_types);
  }

  /// Create a copy of ConsentGrant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ConsentGrantCopyWith<_ConsentGrant> get copyWith =>
      __$ConsentGrantCopyWithImpl<_ConsentGrant>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ConsentGrantToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ConsentGrant &&
            (identical(other.policyVersion, policyVersion) ||
                other.policyVersion == policyVersion) &&
            const DeepCollectionEquality().equals(other._types, _types));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, policyVersion, const DeepCollectionEquality().hash(_types));

  @override
  String toString() {
    return 'ConsentGrant(policyVersion: $policyVersion, types: $types)';
  }
}

/// @nodoc
abstract mixin class _$ConsentGrantCopyWith<$Res>
    implements $ConsentGrantCopyWith<$Res> {
  factory _$ConsentGrantCopyWith(
          _ConsentGrant value, $Res Function(_ConsentGrant) _then) =
      __$ConsentGrantCopyWithImpl;
  @override
  @useResult
  $Res call({String policyVersion, List<ConsentType> types});
}

/// @nodoc
class __$ConsentGrantCopyWithImpl<$Res>
    implements _$ConsentGrantCopyWith<$Res> {
  __$ConsentGrantCopyWithImpl(this._self, this._then);

  final _ConsentGrant _self;
  final $Res Function(_ConsentGrant) _then;

  /// Create a copy of ConsentGrant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? policyVersion = null,
    Object? types = null,
  }) {
    return _then(_ConsentGrant(
      policyVersion: null == policyVersion
          ? _self.policyVersion
          : policyVersion // ignore: cast_nullable_to_non_nullable
              as String,
      types: null == types
          ? _self._types
          : types // ignore: cast_nullable_to_non_nullable
              as List<ConsentType>,
    ));
  }
}

OnboardingAnswer _$OnboardingAnswerFromJson(Map<String, dynamic> json) {
  switch (json['step']) {
    case 'goal':
      return GoalAnswer.fromJson(json);
    case 'about':
      return AboutAnswer.fromJson(json);
    case 'experience':
      return ExperienceAnswer.fromJson(json);
    case 'training':
      return TrainingAnswer.fromJson(json);
    case 'food':
      return FoodAnswer.fromJson(json);
    case 'vit':
      return VitAnswer.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'step', 'OnboardingAnswer',
          'Invalid union type "${json['step']}"!');
  }
}

/// @nodoc
mixin _$OnboardingAnswer {
  /// Serializes this OnboardingAnswer to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is OnboardingAnswer);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'OnboardingAnswer()';
  }
}

/// @nodoc
class $OnboardingAnswerCopyWith<$Res> {
  $OnboardingAnswerCopyWith(
      OnboardingAnswer _, $Res Function(OnboardingAnswer) __);
}

/// Adds pattern-matching-related methods to [OnboardingAnswer].
extension OnboardingAnswerPatterns on OnboardingAnswer {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GoalAnswer value)? goal,
    TResult Function(AboutAnswer value)? about,
    TResult Function(ExperienceAnswer value)? experience,
    TResult Function(TrainingAnswer value)? training,
    TResult Function(FoodAnswer value)? food,
    TResult Function(VitAnswer value)? vit,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case GoalAnswer() when goal != null:
        return goal(_that);
      case AboutAnswer() when about != null:
        return about(_that);
      case ExperienceAnswer() when experience != null:
        return experience(_that);
      case TrainingAnswer() when training != null:
        return training(_that);
      case FoodAnswer() when food != null:
        return food(_that);
      case VitAnswer() when vit != null:
        return vit(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GoalAnswer value) goal,
    required TResult Function(AboutAnswer value) about,
    required TResult Function(ExperienceAnswer value) experience,
    required TResult Function(TrainingAnswer value) training,
    required TResult Function(FoodAnswer value) food,
    required TResult Function(VitAnswer value) vit,
  }) {
    final _that = this;
    switch (_that) {
      case GoalAnswer():
        return goal(_that);
      case AboutAnswer():
        return about(_that);
      case ExperienceAnswer():
        return experience(_that);
      case TrainingAnswer():
        return training(_that);
      case FoodAnswer():
        return food(_that);
      case VitAnswer():
        return vit(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GoalAnswer value)? goal,
    TResult? Function(AboutAnswer value)? about,
    TResult? Function(ExperienceAnswer value)? experience,
    TResult? Function(TrainingAnswer value)? training,
    TResult? Function(FoodAnswer value)? food,
    TResult? Function(VitAnswer value)? vit,
  }) {
    final _that = this;
    switch (_that) {
      case GoalAnswer() when goal != null:
        return goal(_that);
      case AboutAnswer() when about != null:
        return about(_that);
      case ExperienceAnswer() when experience != null:
        return experience(_that);
      case TrainingAnswer() when training != null:
        return training(_that);
      case FoodAnswer() when food != null:
        return food(_that);
      case VitAnswer() when vit != null:
        return vit(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(GoalType goalType)? goal,
    TResult Function(Sex sex, String birthDate, double heightCm,
            double weightKg, ConsentGrant consent)?
        about,
    TResult Function(ExperienceLevel experienceLevel, int trainingDaysPerWeek,
            ActivityLevel activityLevel)?
        experience,
    TResult Function(
            TrainingLocation trainingLocation, List<Equipment> equipment)?
        training,
    TResult Function(DietType dietType, List<Allergy> allergies)? food,
    TResult Function(bool isVitStudent, MessRef? mess)? vit,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case GoalAnswer() when goal != null:
        return goal(_that.goalType);
      case AboutAnswer() when about != null:
        return about(_that.sex, _that.birthDate, _that.heightCm, _that.weightKg,
            _that.consent);
      case ExperienceAnswer() when experience != null:
        return experience(_that.experienceLevel, _that.trainingDaysPerWeek,
            _that.activityLevel);
      case TrainingAnswer() when training != null:
        return training(_that.trainingLocation, _that.equipment);
      case FoodAnswer() when food != null:
        return food(_that.dietType, _that.allergies);
      case VitAnswer() when vit != null:
        return vit(_that.isVitStudent, _that.mess);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(GoalType goalType) goal,
    required TResult Function(Sex sex, String birthDate, double heightCm,
            double weightKg, ConsentGrant consent)
        about,
    required TResult Function(ExperienceLevel experienceLevel,
            int trainingDaysPerWeek, ActivityLevel activityLevel)
        experience,
    required TResult Function(
            TrainingLocation trainingLocation, List<Equipment> equipment)
        training,
    required TResult Function(DietType dietType, List<Allergy> allergies) food,
    required TResult Function(bool isVitStudent, MessRef? mess) vit,
  }) {
    final _that = this;
    switch (_that) {
      case GoalAnswer():
        return goal(_that.goalType);
      case AboutAnswer():
        return about(_that.sex, _that.birthDate, _that.heightCm, _that.weightKg,
            _that.consent);
      case ExperienceAnswer():
        return experience(_that.experienceLevel, _that.trainingDaysPerWeek,
            _that.activityLevel);
      case TrainingAnswer():
        return training(_that.trainingLocation, _that.equipment);
      case FoodAnswer():
        return food(_that.dietType, _that.allergies);
      case VitAnswer():
        return vit(_that.isVitStudent, _that.mess);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(GoalType goalType)? goal,
    TResult? Function(Sex sex, String birthDate, double heightCm,
            double weightKg, ConsentGrant consent)?
        about,
    TResult? Function(ExperienceLevel experienceLevel, int trainingDaysPerWeek,
            ActivityLevel activityLevel)?
        experience,
    TResult? Function(
            TrainingLocation trainingLocation, List<Equipment> equipment)?
        training,
    TResult? Function(DietType dietType, List<Allergy> allergies)? food,
    TResult? Function(bool isVitStudent, MessRef? mess)? vit,
  }) {
    final _that = this;
    switch (_that) {
      case GoalAnswer() when goal != null:
        return goal(_that.goalType);
      case AboutAnswer() when about != null:
        return about(_that.sex, _that.birthDate, _that.heightCm, _that.weightKg,
            _that.consent);
      case ExperienceAnswer() when experience != null:
        return experience(_that.experienceLevel, _that.trainingDaysPerWeek,
            _that.activityLevel);
      case TrainingAnswer() when training != null:
        return training(_that.trainingLocation, _that.equipment);
      case FoodAnswer() when food != null:
        return food(_that.dietType, _that.allergies);
      case VitAnswer() when vit != null:
        return vit(_that.isVitStudent, _that.mess);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class GoalAnswer implements OnboardingAnswer {
  const GoalAnswer({required this.goalType, final String? $type})
      : $type = $type ?? 'goal';
  factory GoalAnswer.fromJson(Map<String, dynamic> json) =>
      _$GoalAnswerFromJson(json);

  final GoalType goalType;

  @JsonKey(name: 'step')
  final String $type;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GoalAnswerCopyWith<GoalAnswer> get copyWith =>
      _$GoalAnswerCopyWithImpl<GoalAnswer>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GoalAnswerToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GoalAnswer &&
            (identical(other.goalType, goalType) ||
                other.goalType == goalType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, goalType);

  @override
  String toString() {
    return 'OnboardingAnswer.goal(goalType: $goalType)';
  }
}

/// @nodoc
abstract mixin class $GoalAnswerCopyWith<$Res>
    implements $OnboardingAnswerCopyWith<$Res> {
  factory $GoalAnswerCopyWith(
          GoalAnswer value, $Res Function(GoalAnswer) _then) =
      _$GoalAnswerCopyWithImpl;
  @useResult
  $Res call({GoalType goalType});
}

/// @nodoc
class _$GoalAnswerCopyWithImpl<$Res> implements $GoalAnswerCopyWith<$Res> {
  _$GoalAnswerCopyWithImpl(this._self, this._then);

  final GoalAnswer _self;
  final $Res Function(GoalAnswer) _then;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? goalType = null,
  }) {
    return _then(GoalAnswer(
      goalType: null == goalType
          ? _self.goalType
          : goalType // ignore: cast_nullable_to_non_nullable
              as GoalType,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AboutAnswer implements OnboardingAnswer {
  const AboutAnswer(
      {required this.sex,
      required this.birthDate,
      required this.heightCm,
      required this.weightKg,
      required this.consent,
      final String? $type})
      : $type = $type ?? 'about';
  factory AboutAnswer.fromJson(Map<String, dynamic> json) =>
      _$AboutAnswerFromJson(json);

  final Sex sex;
  final String birthDate;
  final double heightCm;
  final double weightKg;
  final ConsentGrant consent;

  @JsonKey(name: 'step')
  final String $type;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AboutAnswerCopyWith<AboutAnswer> get copyWith =>
      _$AboutAnswerCopyWithImpl<AboutAnswer>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AboutAnswerToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AboutAnswer &&
            (identical(other.sex, sex) || other.sex == sex) &&
            (identical(other.birthDate, birthDate) ||
                other.birthDate == birthDate) &&
            (identical(other.heightCm, heightCm) ||
                other.heightCm == heightCm) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.consent, consent) || other.consent == consent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, sex, birthDate, heightCm, weightKg, consent);

  @override
  String toString() {
    return 'OnboardingAnswer.about(sex: $sex, birthDate: $birthDate, heightCm: $heightCm, weightKg: $weightKg, consent: $consent)';
  }
}

/// @nodoc
abstract mixin class $AboutAnswerCopyWith<$Res>
    implements $OnboardingAnswerCopyWith<$Res> {
  factory $AboutAnswerCopyWith(
          AboutAnswer value, $Res Function(AboutAnswer) _then) =
      _$AboutAnswerCopyWithImpl;
  @useResult
  $Res call(
      {Sex sex,
      String birthDate,
      double heightCm,
      double weightKg,
      ConsentGrant consent});

  $ConsentGrantCopyWith<$Res> get consent;
}

/// @nodoc
class _$AboutAnswerCopyWithImpl<$Res> implements $AboutAnswerCopyWith<$Res> {
  _$AboutAnswerCopyWithImpl(this._self, this._then);

  final AboutAnswer _self;
  final $Res Function(AboutAnswer) _then;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sex = null,
    Object? birthDate = null,
    Object? heightCm = null,
    Object? weightKg = null,
    Object? consent = null,
  }) {
    return _then(AboutAnswer(
      sex: null == sex
          ? _self.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as Sex,
      birthDate: null == birthDate
          ? _self.birthDate
          : birthDate // ignore: cast_nullable_to_non_nullable
              as String,
      heightCm: null == heightCm
          ? _self.heightCm
          : heightCm // ignore: cast_nullable_to_non_nullable
              as double,
      weightKg: null == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double,
      consent: null == consent
          ? _self.consent
          : consent // ignore: cast_nullable_to_non_nullable
              as ConsentGrant,
    ));
  }

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ConsentGrantCopyWith<$Res> get consent {
    return $ConsentGrantCopyWith<$Res>(_self.consent, (value) {
      return _then(_self.copyWith(consent: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class ExperienceAnswer implements OnboardingAnswer {
  const ExperienceAnswer(
      {required this.experienceLevel,
      required this.trainingDaysPerWeek,
      required this.activityLevel,
      final String? $type})
      : $type = $type ?? 'experience';
  factory ExperienceAnswer.fromJson(Map<String, dynamic> json) =>
      _$ExperienceAnswerFromJson(json);

  final ExperienceLevel experienceLevel;
  final int trainingDaysPerWeek;
  final ActivityLevel activityLevel;

  @JsonKey(name: 'step')
  final String $type;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExperienceAnswerCopyWith<ExperienceAnswer> get copyWith =>
      _$ExperienceAnswerCopyWithImpl<ExperienceAnswer>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExperienceAnswerToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExperienceAnswer &&
            (identical(other.experienceLevel, experienceLevel) ||
                other.experienceLevel == experienceLevel) &&
            (identical(other.trainingDaysPerWeek, trainingDaysPerWeek) ||
                other.trainingDaysPerWeek == trainingDaysPerWeek) &&
            (identical(other.activityLevel, activityLevel) ||
                other.activityLevel == activityLevel));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, experienceLevel, trainingDaysPerWeek, activityLevel);

  @override
  String toString() {
    return 'OnboardingAnswer.experience(experienceLevel: $experienceLevel, trainingDaysPerWeek: $trainingDaysPerWeek, activityLevel: $activityLevel)';
  }
}

/// @nodoc
abstract mixin class $ExperienceAnswerCopyWith<$Res>
    implements $OnboardingAnswerCopyWith<$Res> {
  factory $ExperienceAnswerCopyWith(
          ExperienceAnswer value, $Res Function(ExperienceAnswer) _then) =
      _$ExperienceAnswerCopyWithImpl;
  @useResult
  $Res call(
      {ExperienceLevel experienceLevel,
      int trainingDaysPerWeek,
      ActivityLevel activityLevel});
}

/// @nodoc
class _$ExperienceAnswerCopyWithImpl<$Res>
    implements $ExperienceAnswerCopyWith<$Res> {
  _$ExperienceAnswerCopyWithImpl(this._self, this._then);

  final ExperienceAnswer _self;
  final $Res Function(ExperienceAnswer) _then;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? experienceLevel = null,
    Object? trainingDaysPerWeek = null,
    Object? activityLevel = null,
  }) {
    return _then(ExperienceAnswer(
      experienceLevel: null == experienceLevel
          ? _self.experienceLevel
          : experienceLevel // ignore: cast_nullable_to_non_nullable
              as ExperienceLevel,
      trainingDaysPerWeek: null == trainingDaysPerWeek
          ? _self.trainingDaysPerWeek
          : trainingDaysPerWeek // ignore: cast_nullable_to_non_nullable
              as int,
      activityLevel: null == activityLevel
          ? _self.activityLevel
          : activityLevel // ignore: cast_nullable_to_non_nullable
              as ActivityLevel,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class TrainingAnswer implements OnboardingAnswer {
  const TrainingAnswer(
      {required this.trainingLocation,
      required final List<Equipment> equipment,
      final String? $type})
      : _equipment = equipment,
        $type = $type ?? 'training';
  factory TrainingAnswer.fromJson(Map<String, dynamic> json) =>
      _$TrainingAnswerFromJson(json);

  final TrainingLocation trainingLocation;
  final List<Equipment> _equipment;
  List<Equipment> get equipment {
    if (_equipment is EqualUnmodifiableListView) return _equipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_equipment);
  }

  @JsonKey(name: 'step')
  final String $type;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TrainingAnswerCopyWith<TrainingAnswer> get copyWith =>
      _$TrainingAnswerCopyWithImpl<TrainingAnswer>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TrainingAnswerToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TrainingAnswer &&
            (identical(other.trainingLocation, trainingLocation) ||
                other.trainingLocation == trainingLocation) &&
            const DeepCollectionEquality()
                .equals(other._equipment, _equipment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, trainingLocation,
      const DeepCollectionEquality().hash(_equipment));

  @override
  String toString() {
    return 'OnboardingAnswer.training(trainingLocation: $trainingLocation, equipment: $equipment)';
  }
}

/// @nodoc
abstract mixin class $TrainingAnswerCopyWith<$Res>
    implements $OnboardingAnswerCopyWith<$Res> {
  factory $TrainingAnswerCopyWith(
          TrainingAnswer value, $Res Function(TrainingAnswer) _then) =
      _$TrainingAnswerCopyWithImpl;
  @useResult
  $Res call({TrainingLocation trainingLocation, List<Equipment> equipment});
}

/// @nodoc
class _$TrainingAnswerCopyWithImpl<$Res>
    implements $TrainingAnswerCopyWith<$Res> {
  _$TrainingAnswerCopyWithImpl(this._self, this._then);

  final TrainingAnswer _self;
  final $Res Function(TrainingAnswer) _then;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? trainingLocation = null,
    Object? equipment = null,
  }) {
    return _then(TrainingAnswer(
      trainingLocation: null == trainingLocation
          ? _self.trainingLocation
          : trainingLocation // ignore: cast_nullable_to_non_nullable
              as TrainingLocation,
      equipment: null == equipment
          ? _self._equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class FoodAnswer implements OnboardingAnswer {
  const FoodAnswer(
      {required this.dietType,
      required final List<Allergy> allergies,
      final String? $type})
      : _allergies = allergies,
        $type = $type ?? 'food';
  factory FoodAnswer.fromJson(Map<String, dynamic> json) =>
      _$FoodAnswerFromJson(json);

  final DietType dietType;
  final List<Allergy> _allergies;
  List<Allergy> get allergies {
    if (_allergies is EqualUnmodifiableListView) return _allergies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergies);
  }

  @JsonKey(name: 'step')
  final String $type;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FoodAnswerCopyWith<FoodAnswer> get copyWith =>
      _$FoodAnswerCopyWithImpl<FoodAnswer>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FoodAnswerToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FoodAnswer &&
            (identical(other.dietType, dietType) ||
                other.dietType == dietType) &&
            const DeepCollectionEquality()
                .equals(other._allergies, _allergies));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, dietType, const DeepCollectionEquality().hash(_allergies));

  @override
  String toString() {
    return 'OnboardingAnswer.food(dietType: $dietType, allergies: $allergies)';
  }
}

/// @nodoc
abstract mixin class $FoodAnswerCopyWith<$Res>
    implements $OnboardingAnswerCopyWith<$Res> {
  factory $FoodAnswerCopyWith(
          FoodAnswer value, $Res Function(FoodAnswer) _then) =
      _$FoodAnswerCopyWithImpl;
  @useResult
  $Res call({DietType dietType, List<Allergy> allergies});
}

/// @nodoc
class _$FoodAnswerCopyWithImpl<$Res> implements $FoodAnswerCopyWith<$Res> {
  _$FoodAnswerCopyWithImpl(this._self, this._then);

  final FoodAnswer _self;
  final $Res Function(FoodAnswer) _then;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dietType = null,
    Object? allergies = null,
  }) {
    return _then(FoodAnswer(
      dietType: null == dietType
          ? _self.dietType
          : dietType // ignore: cast_nullable_to_non_nullable
              as DietType,
      allergies: null == allergies
          ? _self._allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<Allergy>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class VitAnswer implements OnboardingAnswer {
  const VitAnswer(
      {required this.isVitStudent, required this.mess, final String? $type})
      : $type = $type ?? 'vit';
  factory VitAnswer.fromJson(Map<String, dynamic> json) =>
      _$VitAnswerFromJson(json);

  final bool isVitStudent;
  final MessRef? mess;

  @JsonKey(name: 'step')
  final String $type;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VitAnswerCopyWith<VitAnswer> get copyWith =>
      _$VitAnswerCopyWithImpl<VitAnswer>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VitAnswerToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VitAnswer &&
            (identical(other.isVitStudent, isVitStudent) ||
                other.isVitStudent == isVitStudent) &&
            (identical(other.mess, mess) || other.mess == mess));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, isVitStudent, mess);

  @override
  String toString() {
    return 'OnboardingAnswer.vit(isVitStudent: $isVitStudent, mess: $mess)';
  }
}

/// @nodoc
abstract mixin class $VitAnswerCopyWith<$Res>
    implements $OnboardingAnswerCopyWith<$Res> {
  factory $VitAnswerCopyWith(VitAnswer value, $Res Function(VitAnswer) _then) =
      _$VitAnswerCopyWithImpl;
  @useResult
  $Res call({bool isVitStudent, MessRef? mess});

  $MessRefCopyWith<$Res>? get mess;
}

/// @nodoc
class _$VitAnswerCopyWithImpl<$Res> implements $VitAnswerCopyWith<$Res> {
  _$VitAnswerCopyWithImpl(this._self, this._then);

  final VitAnswer _self;
  final $Res Function(VitAnswer) _then;

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? isVitStudent = null,
    Object? mess = freezed,
  }) {
    return _then(VitAnswer(
      isVitStudent: null == isVitStudent
          ? _self.isVitStudent
          : isVitStudent // ignore: cast_nullable_to_non_nullable
              as bool,
      mess: freezed == mess
          ? _self.mess
          : mess // ignore: cast_nullable_to_non_nullable
              as MessRef?,
    ));
  }

  /// Create a copy of OnboardingAnswer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessRefCopyWith<$Res>? get mess {
    if (_self.mess == null) {
      return null;
    }

    return $MessRefCopyWith<$Res>(_self.mess!, (value) {
      return _then(_self.copyWith(mess: value));
    });
  }
}

/// @nodoc
mixin _$OnboardingState {
  /// Next unanswered step, or `complete` when all are answered (ready for screen 7).
  OnboardingStage get stage;

  /// True only once /onboarding/complete has computed targets.
  bool get completed;
  List<OnboardingStage> get answered;
  List<OnboardingStage> get missing;
  UserProfileDetail get profile;
  GoalType? get goalType;
  DietType? get dietType;
  List<Allergy> get allergies;
  String get policyVersion;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OnboardingStateCopyWith<OnboardingState> get copyWith =>
      _$OnboardingStateCopyWithImpl<OnboardingState>(
          this as OnboardingState, _$identity);

  /// Serializes this OnboardingState to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is OnboardingState &&
            (identical(other.stage, stage) || other.stage == stage) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            const DeepCollectionEquality().equals(other.answered, answered) &&
            const DeepCollectionEquality().equals(other.missing, missing) &&
            (identical(other.profile, profile) || other.profile == profile) &&
            (identical(other.goalType, goalType) ||
                other.goalType == goalType) &&
            (identical(other.dietType, dietType) ||
                other.dietType == dietType) &&
            const DeepCollectionEquality().equals(other.allergies, allergies) &&
            (identical(other.policyVersion, policyVersion) ||
                other.policyVersion == policyVersion));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      stage,
      completed,
      const DeepCollectionEquality().hash(answered),
      const DeepCollectionEquality().hash(missing),
      profile,
      goalType,
      dietType,
      const DeepCollectionEquality().hash(allergies),
      policyVersion);

  @override
  String toString() {
    return 'OnboardingState(stage: $stage, completed: $completed, answered: $answered, missing: $missing, profile: $profile, goalType: $goalType, dietType: $dietType, allergies: $allergies, policyVersion: $policyVersion)';
  }
}

/// @nodoc
abstract mixin class $OnboardingStateCopyWith<$Res> {
  factory $OnboardingStateCopyWith(
          OnboardingState value, $Res Function(OnboardingState) _then) =
      _$OnboardingStateCopyWithImpl;
  @useResult
  $Res call(
      {OnboardingStage stage,
      bool completed,
      List<OnboardingStage> answered,
      List<OnboardingStage> missing,
      UserProfileDetail profile,
      GoalType? goalType,
      DietType? dietType,
      List<Allergy> allergies,
      String policyVersion});

  $UserProfileDetailCopyWith<$Res> get profile;
}

/// @nodoc
class _$OnboardingStateCopyWithImpl<$Res>
    implements $OnboardingStateCopyWith<$Res> {
  _$OnboardingStateCopyWithImpl(this._self, this._then);

  final OnboardingState _self;
  final $Res Function(OnboardingState) _then;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stage = null,
    Object? completed = null,
    Object? answered = null,
    Object? missing = null,
    Object? profile = null,
    Object? goalType = freezed,
    Object? dietType = freezed,
    Object? allergies = null,
    Object? policyVersion = null,
  }) {
    return _then(_self.copyWith(
      stage: null == stage
          ? _self.stage
          : stage // ignore: cast_nullable_to_non_nullable
              as OnboardingStage,
      completed: null == completed
          ? _self.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      answered: null == answered
          ? _self.answered
          : answered // ignore: cast_nullable_to_non_nullable
              as List<OnboardingStage>,
      missing: null == missing
          ? _self.missing
          : missing // ignore: cast_nullable_to_non_nullable
              as List<OnboardingStage>,
      profile: null == profile
          ? _self.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as UserProfileDetail,
      goalType: freezed == goalType
          ? _self.goalType
          : goalType // ignore: cast_nullable_to_non_nullable
              as GoalType?,
      dietType: freezed == dietType
          ? _self.dietType
          : dietType // ignore: cast_nullable_to_non_nullable
              as DietType?,
      allergies: null == allergies
          ? _self.allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<Allergy>,
      policyVersion: null == policyVersion
          ? _self.policyVersion
          : policyVersion // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserProfileDetailCopyWith<$Res> get profile {
    return $UserProfileDetailCopyWith<$Res>(_self.profile, (value) {
      return _then(_self.copyWith(profile: value));
    });
  }
}

/// Adds pattern-matching-related methods to [OnboardingState].
extension OnboardingStatePatterns on OnboardingState {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_OnboardingState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OnboardingState() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_OnboardingState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OnboardingState():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_OnboardingState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OnboardingState() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            OnboardingStage stage,
            bool completed,
            List<OnboardingStage> answered,
            List<OnboardingStage> missing,
            UserProfileDetail profile,
            GoalType? goalType,
            DietType? dietType,
            List<Allergy> allergies,
            String policyVersion)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OnboardingState() when $default != null:
        return $default(
            _that.stage,
            _that.completed,
            _that.answered,
            _that.missing,
            _that.profile,
            _that.goalType,
            _that.dietType,
            _that.allergies,
            _that.policyVersion);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            OnboardingStage stage,
            bool completed,
            List<OnboardingStage> answered,
            List<OnboardingStage> missing,
            UserProfileDetail profile,
            GoalType? goalType,
            DietType? dietType,
            List<Allergy> allergies,
            String policyVersion)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OnboardingState():
        return $default(
            _that.stage,
            _that.completed,
            _that.answered,
            _that.missing,
            _that.profile,
            _that.goalType,
            _that.dietType,
            _that.allergies,
            _that.policyVersion);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            OnboardingStage stage,
            bool completed,
            List<OnboardingStage> answered,
            List<OnboardingStage> missing,
            UserProfileDetail profile,
            GoalType? goalType,
            DietType? dietType,
            List<Allergy> allergies,
            String policyVersion)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OnboardingState() when $default != null:
        return $default(
            _that.stage,
            _that.completed,
            _that.answered,
            _that.missing,
            _that.profile,
            _that.goalType,
            _that.dietType,
            _that.allergies,
            _that.policyVersion);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _OnboardingState implements OnboardingState {
  const _OnboardingState(
      {required this.stage,
      required this.completed,
      required final List<OnboardingStage> answered,
      required final List<OnboardingStage> missing,
      required this.profile,
      required this.goalType,
      required this.dietType,
      required final List<Allergy> allergies,
      required this.policyVersion})
      : _answered = answered,
        _missing = missing,
        _allergies = allergies;
  factory _OnboardingState.fromJson(Map<String, dynamic> json) =>
      _$OnboardingStateFromJson(json);

  /// Next unanswered step, or `complete` when all are answered (ready for screen 7).
  @override
  final OnboardingStage stage;

  /// True only once /onboarding/complete has computed targets.
  @override
  final bool completed;
  final List<OnboardingStage> _answered;
  @override
  List<OnboardingStage> get answered {
    if (_answered is EqualUnmodifiableListView) return _answered;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_answered);
  }

  final List<OnboardingStage> _missing;
  @override
  List<OnboardingStage> get missing {
    if (_missing is EqualUnmodifiableListView) return _missing;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_missing);
  }

  @override
  final UserProfileDetail profile;
  @override
  final GoalType? goalType;
  @override
  final DietType? dietType;
  final List<Allergy> _allergies;
  @override
  List<Allergy> get allergies {
    if (_allergies is EqualUnmodifiableListView) return _allergies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergies);
  }

  @override
  final String policyVersion;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OnboardingStateCopyWith<_OnboardingState> get copyWith =>
      __$OnboardingStateCopyWithImpl<_OnboardingState>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$OnboardingStateToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _OnboardingState &&
            (identical(other.stage, stage) || other.stage == stage) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            const DeepCollectionEquality().equals(other._answered, _answered) &&
            const DeepCollectionEquality().equals(other._missing, _missing) &&
            (identical(other.profile, profile) || other.profile == profile) &&
            (identical(other.goalType, goalType) ||
                other.goalType == goalType) &&
            (identical(other.dietType, dietType) ||
                other.dietType == dietType) &&
            const DeepCollectionEquality()
                .equals(other._allergies, _allergies) &&
            (identical(other.policyVersion, policyVersion) ||
                other.policyVersion == policyVersion));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      stage,
      completed,
      const DeepCollectionEquality().hash(_answered),
      const DeepCollectionEquality().hash(_missing),
      profile,
      goalType,
      dietType,
      const DeepCollectionEquality().hash(_allergies),
      policyVersion);

  @override
  String toString() {
    return 'OnboardingState(stage: $stage, completed: $completed, answered: $answered, missing: $missing, profile: $profile, goalType: $goalType, dietType: $dietType, allergies: $allergies, policyVersion: $policyVersion)';
  }
}

/// @nodoc
abstract mixin class _$OnboardingStateCopyWith<$Res>
    implements $OnboardingStateCopyWith<$Res> {
  factory _$OnboardingStateCopyWith(
          _OnboardingState value, $Res Function(_OnboardingState) _then) =
      __$OnboardingStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {OnboardingStage stage,
      bool completed,
      List<OnboardingStage> answered,
      List<OnboardingStage> missing,
      UserProfileDetail profile,
      GoalType? goalType,
      DietType? dietType,
      List<Allergy> allergies,
      String policyVersion});

  @override
  $UserProfileDetailCopyWith<$Res> get profile;
}

/// @nodoc
class __$OnboardingStateCopyWithImpl<$Res>
    implements _$OnboardingStateCopyWith<$Res> {
  __$OnboardingStateCopyWithImpl(this._self, this._then);

  final _OnboardingState _self;
  final $Res Function(_OnboardingState) _then;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? stage = null,
    Object? completed = null,
    Object? answered = null,
    Object? missing = null,
    Object? profile = null,
    Object? goalType = freezed,
    Object? dietType = freezed,
    Object? allergies = null,
    Object? policyVersion = null,
  }) {
    return _then(_OnboardingState(
      stage: null == stage
          ? _self.stage
          : stage // ignore: cast_nullable_to_non_nullable
              as OnboardingStage,
      completed: null == completed
          ? _self.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      answered: null == answered
          ? _self._answered
          : answered // ignore: cast_nullable_to_non_nullable
              as List<OnboardingStage>,
      missing: null == missing
          ? _self._missing
          : missing // ignore: cast_nullable_to_non_nullable
              as List<OnboardingStage>,
      profile: null == profile
          ? _self.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as UserProfileDetail,
      goalType: freezed == goalType
          ? _self.goalType
          : goalType // ignore: cast_nullable_to_non_nullable
              as GoalType?,
      dietType: freezed == dietType
          ? _self.dietType
          : dietType // ignore: cast_nullable_to_non_nullable
              as DietType?,
      allergies: null == allergies
          ? _self._allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<Allergy>,
      policyVersion: null == policyVersion
          ? _self.policyVersion
          : policyVersion // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserProfileDetailCopyWith<$Res> get profile {
    return $UserProfileDetailCopyWith<$Res>(_self.profile, (value) {
      return _then(_self.copyWith(profile: value));
    });
  }
}

/// @nodoc
mixin _$OnboardingCompleteResponse {
  UserProfileDetail get profile;
  Goal get goal;
  NutritionTargets get targets;

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OnboardingCompleteResponseCopyWith<OnboardingCompleteResponse>
      get copyWith =>
          _$OnboardingCompleteResponseCopyWithImpl<OnboardingCompleteResponse>(
              this as OnboardingCompleteResponse, _$identity);

  /// Serializes this OnboardingCompleteResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is OnboardingCompleteResponse &&
            (identical(other.profile, profile) || other.profile == profile) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.targets, targets) || other.targets == targets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, profile, goal, targets);

  @override
  String toString() {
    return 'OnboardingCompleteResponse(profile: $profile, goal: $goal, targets: $targets)';
  }
}

/// @nodoc
abstract mixin class $OnboardingCompleteResponseCopyWith<$Res> {
  factory $OnboardingCompleteResponseCopyWith(OnboardingCompleteResponse value,
          $Res Function(OnboardingCompleteResponse) _then) =
      _$OnboardingCompleteResponseCopyWithImpl;
  @useResult
  $Res call({UserProfileDetail profile, Goal goal, NutritionTargets targets});

  $UserProfileDetailCopyWith<$Res> get profile;
  $GoalCopyWith<$Res> get goal;
  $NutritionTargetsCopyWith<$Res> get targets;
}

/// @nodoc
class _$OnboardingCompleteResponseCopyWithImpl<$Res>
    implements $OnboardingCompleteResponseCopyWith<$Res> {
  _$OnboardingCompleteResponseCopyWithImpl(this._self, this._then);

  final OnboardingCompleteResponse _self;
  final $Res Function(OnboardingCompleteResponse) _then;

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? profile = null,
    Object? goal = null,
    Object? targets = null,
  }) {
    return _then(_self.copyWith(
      profile: null == profile
          ? _self.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as UserProfileDetail,
      goal: null == goal
          ? _self.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as Goal,
      targets: null == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as NutritionTargets,
    ));
  }

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserProfileDetailCopyWith<$Res> get profile {
    return $UserProfileDetailCopyWith<$Res>(_self.profile, (value) {
      return _then(_self.copyWith(profile: value));
    });
  }

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GoalCopyWith<$Res> get goal {
    return $GoalCopyWith<$Res>(_self.goal, (value) {
      return _then(_self.copyWith(goal: value));
    });
  }

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<$Res> get targets {
    return $NutritionTargetsCopyWith<$Res>(_self.targets, (value) {
      return _then(_self.copyWith(targets: value));
    });
  }
}

/// Adds pattern-matching-related methods to [OnboardingCompleteResponse].
extension OnboardingCompleteResponsePatterns on OnboardingCompleteResponse {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_OnboardingCompleteResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OnboardingCompleteResponse() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_OnboardingCompleteResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OnboardingCompleteResponse():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_OnboardingCompleteResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OnboardingCompleteResponse() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            UserProfileDetail profile, Goal goal, NutritionTargets targets)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OnboardingCompleteResponse() when $default != null:
        return $default(_that.profile, _that.goal, _that.targets);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            UserProfileDetail profile, Goal goal, NutritionTargets targets)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OnboardingCompleteResponse():
        return $default(_that.profile, _that.goal, _that.targets);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            UserProfileDetail profile, Goal goal, NutritionTargets targets)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OnboardingCompleteResponse() when $default != null:
        return $default(_that.profile, _that.goal, _that.targets);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _OnboardingCompleteResponse implements OnboardingCompleteResponse {
  const _OnboardingCompleteResponse(
      {required this.profile, required this.goal, required this.targets});
  factory _OnboardingCompleteResponse.fromJson(Map<String, dynamic> json) =>
      _$OnboardingCompleteResponseFromJson(json);

  @override
  final UserProfileDetail profile;
  @override
  final Goal goal;
  @override
  final NutritionTargets targets;

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OnboardingCompleteResponseCopyWith<_OnboardingCompleteResponse>
      get copyWith => __$OnboardingCompleteResponseCopyWithImpl<
          _OnboardingCompleteResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$OnboardingCompleteResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _OnboardingCompleteResponse &&
            (identical(other.profile, profile) || other.profile == profile) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.targets, targets) || other.targets == targets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, profile, goal, targets);

  @override
  String toString() {
    return 'OnboardingCompleteResponse(profile: $profile, goal: $goal, targets: $targets)';
  }
}

/// @nodoc
abstract mixin class _$OnboardingCompleteResponseCopyWith<$Res>
    implements $OnboardingCompleteResponseCopyWith<$Res> {
  factory _$OnboardingCompleteResponseCopyWith(
          _OnboardingCompleteResponse value,
          $Res Function(_OnboardingCompleteResponse) _then) =
      __$OnboardingCompleteResponseCopyWithImpl;
  @override
  @useResult
  $Res call({UserProfileDetail profile, Goal goal, NutritionTargets targets});

  @override
  $UserProfileDetailCopyWith<$Res> get profile;
  @override
  $GoalCopyWith<$Res> get goal;
  @override
  $NutritionTargetsCopyWith<$Res> get targets;
}

/// @nodoc
class __$OnboardingCompleteResponseCopyWithImpl<$Res>
    implements _$OnboardingCompleteResponseCopyWith<$Res> {
  __$OnboardingCompleteResponseCopyWithImpl(this._self, this._then);

  final _OnboardingCompleteResponse _self;
  final $Res Function(_OnboardingCompleteResponse) _then;

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? profile = null,
    Object? goal = null,
    Object? targets = null,
  }) {
    return _then(_OnboardingCompleteResponse(
      profile: null == profile
          ? _self.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as UserProfileDetail,
      goal: null == goal
          ? _self.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as Goal,
      targets: null == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as NutritionTargets,
    ));
  }

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserProfileDetailCopyWith<$Res> get profile {
    return $UserProfileDetailCopyWith<$Res>(_self.profile, (value) {
      return _then(_self.copyWith(profile: value));
    });
  }

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GoalCopyWith<$Res> get goal {
    return $GoalCopyWith<$Res>(_self.goal, (value) {
      return _then(_self.copyWith(goal: value));
    });
  }

  /// Create a copy of OnboardingCompleteResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<$Res> get targets {
    return $NutritionTargetsCopyWith<$Res>(_self.targets, (value) {
      return _then(_self.copyWith(targets: value));
    });
  }
}

// dart format on
