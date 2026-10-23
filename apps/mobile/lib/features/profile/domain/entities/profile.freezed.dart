// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessRef {
  String get providerId;
  String get hostelId;
  String get messId;

  /// Create a copy of MessRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessRefCopyWith<MessRef> get copyWith =>
      _$MessRefCopyWithImpl<MessRef>(this as MessRef, _$identity);

  /// Serializes this MessRef to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessRef &&
            (identical(other.providerId, providerId) ||
                other.providerId == providerId) &&
            (identical(other.hostelId, hostelId) ||
                other.hostelId == hostelId) &&
            (identical(other.messId, messId) || other.messId == messId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, providerId, hostelId, messId);

  @override
  String toString() {
    return 'MessRef(providerId: $providerId, hostelId: $hostelId, messId: $messId)';
  }
}

/// @nodoc
abstract mixin class $MessRefCopyWith<$Res> {
  factory $MessRefCopyWith(MessRef value, $Res Function(MessRef) _then) =
      _$MessRefCopyWithImpl;
  @useResult
  $Res call({String providerId, String hostelId, String messId});
}

/// @nodoc
class _$MessRefCopyWithImpl<$Res> implements $MessRefCopyWith<$Res> {
  _$MessRefCopyWithImpl(this._self, this._then);

  final MessRef _self;
  final $Res Function(MessRef) _then;

  /// Create a copy of MessRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? providerId = null,
    Object? hostelId = null,
    Object? messId = null,
  }) {
    return _then(_self.copyWith(
      providerId: null == providerId
          ? _self.providerId
          : providerId // ignore: cast_nullable_to_non_nullable
              as String,
      hostelId: null == hostelId
          ? _self.hostelId
          : hostelId // ignore: cast_nullable_to_non_nullable
              as String,
      messId: null == messId
          ? _self.messId
          : messId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [MessRef].
extension MessRefPatterns on MessRef {
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
    TResult Function(_MessRef value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MessRef() when $default != null:
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
    TResult Function(_MessRef value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MessRef():
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
    TResult? Function(_MessRef value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MessRef() when $default != null:
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
    TResult Function(String providerId, String hostelId, String messId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MessRef() when $default != null:
        return $default(_that.providerId, _that.hostelId, _that.messId);
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
    TResult Function(String providerId, String hostelId, String messId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MessRef():
        return $default(_that.providerId, _that.hostelId, _that.messId);
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
    TResult? Function(String providerId, String hostelId, String messId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MessRef() when $default != null:
        return $default(_that.providerId, _that.hostelId, _that.messId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MessRef implements MessRef {
  const _MessRef(
      {required this.providerId, required this.hostelId, required this.messId});
  factory _MessRef.fromJson(Map<String, dynamic> json) =>
      _$MessRefFromJson(json);

  @override
  final String providerId;
  @override
  final String hostelId;
  @override
  final String messId;

  /// Create a copy of MessRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MessRefCopyWith<_MessRef> get copyWith =>
      __$MessRefCopyWithImpl<_MessRef>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MessRefToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MessRef &&
            (identical(other.providerId, providerId) ||
                other.providerId == providerId) &&
            (identical(other.hostelId, hostelId) ||
                other.hostelId == hostelId) &&
            (identical(other.messId, messId) || other.messId == messId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, providerId, hostelId, messId);

  @override
  String toString() {
    return 'MessRef(providerId: $providerId, hostelId: $hostelId, messId: $messId)';
  }
}

/// @nodoc
abstract mixin class _$MessRefCopyWith<$Res> implements $MessRefCopyWith<$Res> {
  factory _$MessRefCopyWith(_MessRef value, $Res Function(_MessRef) _then) =
      __$MessRefCopyWithImpl;
  @override
  @useResult
  $Res call({String providerId, String hostelId, String messId});
}

/// @nodoc
class __$MessRefCopyWithImpl<$Res> implements _$MessRefCopyWith<$Res> {
  __$MessRefCopyWithImpl(this._self, this._then);

  final _MessRef _self;
  final $Res Function(_MessRef) _then;

  /// Create a copy of MessRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? providerId = null,
    Object? hostelId = null,
    Object? messId = null,
  }) {
    return _then(_MessRef(
      providerId: null == providerId
          ? _self.providerId
          : providerId // ignore: cast_nullable_to_non_nullable
              as String,
      hostelId: null == hostelId
          ? _self.hostelId
          : hostelId // ignore: cast_nullable_to_non_nullable
              as String,
      messId: null == messId
          ? _self.messId
          : messId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$UserProfileDetail {
  /// Phase 6.6: what the app calls the user; null until answered.
  String? get displayName;
  Sex? get sex;
  String? get birthDate;
  double? get heightCm;
  ExperienceLevel? get experienceLevel;
  int? get trainingDaysPerWeek;
  ActivityLevel? get activityLevel;
  int? get preferredSessionMinutes;
  TrainingLocation? get trainingLocation;
  List<Equipment> get equipment;
  double? get latestWeightKg;
  String get timezone;
  String get locale;
  String get onboardingStage;

  /// Screen 6's answer; null before it is answered (Phase 9 on the wire).
  bool? get isVitStudent;
  MessRef? get mess;

  /// Phase 19 (ADR-027): one of the ten drawn pictures; null = initials.
  String? get avatarId;

  /// Create a copy of UserProfileDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserProfileDetailCopyWith<UserProfileDetail> get copyWith =>
      _$UserProfileDetailCopyWithImpl<UserProfileDetail>(
          this as UserProfileDetail, _$identity);

  /// Serializes this UserProfileDetail to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserProfileDetail &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.sex, sex) || other.sex == sex) &&
            (identical(other.birthDate, birthDate) ||
                other.birthDate == birthDate) &&
            (identical(other.heightCm, heightCm) ||
                other.heightCm == heightCm) &&
            (identical(other.experienceLevel, experienceLevel) ||
                other.experienceLevel == experienceLevel) &&
            (identical(other.trainingDaysPerWeek, trainingDaysPerWeek) ||
                other.trainingDaysPerWeek == trainingDaysPerWeek) &&
            (identical(other.activityLevel, activityLevel) ||
                other.activityLevel == activityLevel) &&
            (identical(
                    other.preferredSessionMinutes, preferredSessionMinutes) ||
                other.preferredSessionMinutes == preferredSessionMinutes) &&
            (identical(other.trainingLocation, trainingLocation) ||
                other.trainingLocation == trainingLocation) &&
            const DeepCollectionEquality().equals(other.equipment, equipment) &&
            (identical(other.latestWeightKg, latestWeightKg) ||
                other.latestWeightKg == latestWeightKg) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.onboardingStage, onboardingStage) ||
                other.onboardingStage == onboardingStage) &&
            (identical(other.isVitStudent, isVitStudent) ||
                other.isVitStudent == isVitStudent) &&
            (identical(other.mess, mess) || other.mess == mess) &&
            (identical(other.avatarId, avatarId) ||
                other.avatarId == avatarId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      displayName,
      sex,
      birthDate,
      heightCm,
      experienceLevel,
      trainingDaysPerWeek,
      activityLevel,
      preferredSessionMinutes,
      trainingLocation,
      const DeepCollectionEquality().hash(equipment),
      latestWeightKg,
      timezone,
      locale,
      onboardingStage,
      isVitStudent,
      mess,
      avatarId);

  @override
  String toString() {
    return 'UserProfileDetail(displayName: $displayName, sex: $sex, birthDate: $birthDate, heightCm: $heightCm, experienceLevel: $experienceLevel, trainingDaysPerWeek: $trainingDaysPerWeek, activityLevel: $activityLevel, preferredSessionMinutes: $preferredSessionMinutes, trainingLocation: $trainingLocation, equipment: $equipment, latestWeightKg: $latestWeightKg, timezone: $timezone, locale: $locale, onboardingStage: $onboardingStage, isVitStudent: $isVitStudent, mess: $mess, avatarId: $avatarId)';
  }
}

/// @nodoc
abstract mixin class $UserProfileDetailCopyWith<$Res> {
  factory $UserProfileDetailCopyWith(
          UserProfileDetail value, $Res Function(UserProfileDetail) _then) =
      _$UserProfileDetailCopyWithImpl;
  @useResult
  $Res call(
      {String? displayName,
      Sex? sex,
      String? birthDate,
      double? heightCm,
      ExperienceLevel? experienceLevel,
      int? trainingDaysPerWeek,
      ActivityLevel? activityLevel,
      int? preferredSessionMinutes,
      TrainingLocation? trainingLocation,
      List<Equipment> equipment,
      double? latestWeightKg,
      String timezone,
      String locale,
      String onboardingStage,
      bool? isVitStudent,
      MessRef? mess,
      String? avatarId});

  $MessRefCopyWith<$Res>? get mess;
}

/// @nodoc
class _$UserProfileDetailCopyWithImpl<$Res>
    implements $UserProfileDetailCopyWith<$Res> {
  _$UserProfileDetailCopyWithImpl(this._self, this._then);

  final UserProfileDetail _self;
  final $Res Function(UserProfileDetail) _then;

  /// Create a copy of UserProfileDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? displayName = freezed,
    Object? sex = freezed,
    Object? birthDate = freezed,
    Object? heightCm = freezed,
    Object? experienceLevel = freezed,
    Object? trainingDaysPerWeek = freezed,
    Object? activityLevel = freezed,
    Object? preferredSessionMinutes = freezed,
    Object? trainingLocation = freezed,
    Object? equipment = null,
    Object? latestWeightKg = freezed,
    Object? timezone = null,
    Object? locale = null,
    Object? onboardingStage = null,
    Object? isVitStudent = freezed,
    Object? mess = freezed,
    Object? avatarId = freezed,
  }) {
    return _then(_self.copyWith(
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      sex: freezed == sex
          ? _self.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as Sex?,
      birthDate: freezed == birthDate
          ? _self.birthDate
          : birthDate // ignore: cast_nullable_to_non_nullable
              as String?,
      heightCm: freezed == heightCm
          ? _self.heightCm
          : heightCm // ignore: cast_nullable_to_non_nullable
              as double?,
      experienceLevel: freezed == experienceLevel
          ? _self.experienceLevel
          : experienceLevel // ignore: cast_nullable_to_non_nullable
              as ExperienceLevel?,
      trainingDaysPerWeek: freezed == trainingDaysPerWeek
          ? _self.trainingDaysPerWeek
          : trainingDaysPerWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      activityLevel: freezed == activityLevel
          ? _self.activityLevel
          : activityLevel // ignore: cast_nullable_to_non_nullable
              as ActivityLevel?,
      preferredSessionMinutes: freezed == preferredSessionMinutes
          ? _self.preferredSessionMinutes
          : preferredSessionMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      trainingLocation: freezed == trainingLocation
          ? _self.trainingLocation
          : trainingLocation // ignore: cast_nullable_to_non_nullable
              as TrainingLocation?,
      equipment: null == equipment
          ? _self.equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      latestWeightKg: freezed == latestWeightKg
          ? _self.latestWeightKg
          : latestWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      locale: null == locale
          ? _self.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      onboardingStage: null == onboardingStage
          ? _self.onboardingStage
          : onboardingStage // ignore: cast_nullable_to_non_nullable
              as String,
      isVitStudent: freezed == isVitStudent
          ? _self.isVitStudent
          : isVitStudent // ignore: cast_nullable_to_non_nullable
              as bool?,
      mess: freezed == mess
          ? _self.mess
          : mess // ignore: cast_nullable_to_non_nullable
              as MessRef?,
      avatarId: freezed == avatarId
          ? _self.avatarId
          : avatarId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of UserProfileDetail
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

/// Adds pattern-matching-related methods to [UserProfileDetail].
extension UserProfileDetailPatterns on UserProfileDetail {
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
    TResult Function(_UserProfileDetail value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserProfileDetail() when $default != null:
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
    TResult Function(_UserProfileDetail value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserProfileDetail():
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
    TResult? Function(_UserProfileDetail value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserProfileDetail() when $default != null:
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
            String? displayName,
            Sex? sex,
            String? birthDate,
            double? heightCm,
            ExperienceLevel? experienceLevel,
            int? trainingDaysPerWeek,
            ActivityLevel? activityLevel,
            int? preferredSessionMinutes,
            TrainingLocation? trainingLocation,
            List<Equipment> equipment,
            double? latestWeightKg,
            String timezone,
            String locale,
            String onboardingStage,
            bool? isVitStudent,
            MessRef? mess,
            String? avatarId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserProfileDetail() when $default != null:
        return $default(
            _that.displayName,
            _that.sex,
            _that.birthDate,
            _that.heightCm,
            _that.experienceLevel,
            _that.trainingDaysPerWeek,
            _that.activityLevel,
            _that.preferredSessionMinutes,
            _that.trainingLocation,
            _that.equipment,
            _that.latestWeightKg,
            _that.timezone,
            _that.locale,
            _that.onboardingStage,
            _that.isVitStudent,
            _that.mess,
            _that.avatarId);
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
            String? displayName,
            Sex? sex,
            String? birthDate,
            double? heightCm,
            ExperienceLevel? experienceLevel,
            int? trainingDaysPerWeek,
            ActivityLevel? activityLevel,
            int? preferredSessionMinutes,
            TrainingLocation? trainingLocation,
            List<Equipment> equipment,
            double? latestWeightKg,
            String timezone,
            String locale,
            String onboardingStage,
            bool? isVitStudent,
            MessRef? mess,
            String? avatarId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserProfileDetail():
        return $default(
            _that.displayName,
            _that.sex,
            _that.birthDate,
            _that.heightCm,
            _that.experienceLevel,
            _that.trainingDaysPerWeek,
            _that.activityLevel,
            _that.preferredSessionMinutes,
            _that.trainingLocation,
            _that.equipment,
            _that.latestWeightKg,
            _that.timezone,
            _that.locale,
            _that.onboardingStage,
            _that.isVitStudent,
            _that.mess,
            _that.avatarId);
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
            String? displayName,
            Sex? sex,
            String? birthDate,
            double? heightCm,
            ExperienceLevel? experienceLevel,
            int? trainingDaysPerWeek,
            ActivityLevel? activityLevel,
            int? preferredSessionMinutes,
            TrainingLocation? trainingLocation,
            List<Equipment> equipment,
            double? latestWeightKg,
            String timezone,
            String locale,
            String onboardingStage,
            bool? isVitStudent,
            MessRef? mess,
            String? avatarId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserProfileDetail() when $default != null:
        return $default(
            _that.displayName,
            _that.sex,
            _that.birthDate,
            _that.heightCm,
            _that.experienceLevel,
            _that.trainingDaysPerWeek,
            _that.activityLevel,
            _that.preferredSessionMinutes,
            _that.trainingLocation,
            _that.equipment,
            _that.latestWeightKg,
            _that.timezone,
            _that.locale,
            _that.onboardingStage,
            _that.isVitStudent,
            _that.mess,
            _that.avatarId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _UserProfileDetail implements UserProfileDetail {
  const _UserProfileDetail(
      {this.displayName = null,
      required this.sex,
      required this.birthDate,
      required this.heightCm,
      required this.experienceLevel,
      required this.trainingDaysPerWeek,
      required this.activityLevel,
      required this.preferredSessionMinutes,
      required this.trainingLocation,
      required final List<Equipment> equipment,
      required this.latestWeightKg,
      required this.timezone,
      required this.locale,
      required this.onboardingStage,
      this.isVitStudent = null,
      required this.mess,
      this.avatarId = null})
      : _equipment = equipment;
  factory _UserProfileDetail.fromJson(Map<String, dynamic> json) =>
      _$UserProfileDetailFromJson(json);

  /// Phase 6.6: what the app calls the user; null until answered.
  @override
  @JsonKey()
  final String? displayName;
  @override
  final Sex? sex;
  @override
  final String? birthDate;
  @override
  final double? heightCm;
  @override
  final ExperienceLevel? experienceLevel;
  @override
  final int? trainingDaysPerWeek;
  @override
  final ActivityLevel? activityLevel;
  @override
  final int? preferredSessionMinutes;
  @override
  final TrainingLocation? trainingLocation;
  final List<Equipment> _equipment;
  @override
  List<Equipment> get equipment {
    if (_equipment is EqualUnmodifiableListView) return _equipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_equipment);
  }

  @override
  final double? latestWeightKg;
  @override
  final String timezone;
  @override
  final String locale;
  @override
  final String onboardingStage;

  /// Screen 6's answer; null before it is answered (Phase 9 on the wire).
  @override
  @JsonKey()
  final bool? isVitStudent;
  @override
  final MessRef? mess;

  /// Phase 19 (ADR-027): one of the ten drawn pictures; null = initials.
  @override
  @JsonKey()
  final String? avatarId;

  /// Create a copy of UserProfileDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserProfileDetailCopyWith<_UserProfileDetail> get copyWith =>
      __$UserProfileDetailCopyWithImpl<_UserProfileDetail>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UserProfileDetailToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserProfileDetail &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.sex, sex) || other.sex == sex) &&
            (identical(other.birthDate, birthDate) ||
                other.birthDate == birthDate) &&
            (identical(other.heightCm, heightCm) ||
                other.heightCm == heightCm) &&
            (identical(other.experienceLevel, experienceLevel) ||
                other.experienceLevel == experienceLevel) &&
            (identical(other.trainingDaysPerWeek, trainingDaysPerWeek) ||
                other.trainingDaysPerWeek == trainingDaysPerWeek) &&
            (identical(other.activityLevel, activityLevel) ||
                other.activityLevel == activityLevel) &&
            (identical(
                    other.preferredSessionMinutes, preferredSessionMinutes) ||
                other.preferredSessionMinutes == preferredSessionMinutes) &&
            (identical(other.trainingLocation, trainingLocation) ||
                other.trainingLocation == trainingLocation) &&
            const DeepCollectionEquality()
                .equals(other._equipment, _equipment) &&
            (identical(other.latestWeightKg, latestWeightKg) ||
                other.latestWeightKg == latestWeightKg) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.onboardingStage, onboardingStage) ||
                other.onboardingStage == onboardingStage) &&
            (identical(other.isVitStudent, isVitStudent) ||
                other.isVitStudent == isVitStudent) &&
            (identical(other.mess, mess) || other.mess == mess) &&
            (identical(other.avatarId, avatarId) ||
                other.avatarId == avatarId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      displayName,
      sex,
      birthDate,
      heightCm,
      experienceLevel,
      trainingDaysPerWeek,
      activityLevel,
      preferredSessionMinutes,
      trainingLocation,
      const DeepCollectionEquality().hash(_equipment),
      latestWeightKg,
      timezone,
      locale,
      onboardingStage,
      isVitStudent,
      mess,
      avatarId);

  @override
  String toString() {
    return 'UserProfileDetail(displayName: $displayName, sex: $sex, birthDate: $birthDate, heightCm: $heightCm, experienceLevel: $experienceLevel, trainingDaysPerWeek: $trainingDaysPerWeek, activityLevel: $activityLevel, preferredSessionMinutes: $preferredSessionMinutes, trainingLocation: $trainingLocation, equipment: $equipment, latestWeightKg: $latestWeightKg, timezone: $timezone, locale: $locale, onboardingStage: $onboardingStage, isVitStudent: $isVitStudent, mess: $mess, avatarId: $avatarId)';
  }
}

/// @nodoc
abstract mixin class _$UserProfileDetailCopyWith<$Res>
    implements $UserProfileDetailCopyWith<$Res> {
  factory _$UserProfileDetailCopyWith(
          _UserProfileDetail value, $Res Function(_UserProfileDetail) _then) =
      __$UserProfileDetailCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? displayName,
      Sex? sex,
      String? birthDate,
      double? heightCm,
      ExperienceLevel? experienceLevel,
      int? trainingDaysPerWeek,
      ActivityLevel? activityLevel,
      int? preferredSessionMinutes,
      TrainingLocation? trainingLocation,
      List<Equipment> equipment,
      double? latestWeightKg,
      String timezone,
      String locale,
      String onboardingStage,
      bool? isVitStudent,
      MessRef? mess,
      String? avatarId});

  @override
  $MessRefCopyWith<$Res>? get mess;
}

/// @nodoc
class __$UserProfileDetailCopyWithImpl<$Res>
    implements _$UserProfileDetailCopyWith<$Res> {
  __$UserProfileDetailCopyWithImpl(this._self, this._then);

  final _UserProfileDetail _self;
  final $Res Function(_UserProfileDetail) _then;

  /// Create a copy of UserProfileDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? displayName = freezed,
    Object? sex = freezed,
    Object? birthDate = freezed,
    Object? heightCm = freezed,
    Object? experienceLevel = freezed,
    Object? trainingDaysPerWeek = freezed,
    Object? activityLevel = freezed,
    Object? preferredSessionMinutes = freezed,
    Object? trainingLocation = freezed,
    Object? equipment = null,
    Object? latestWeightKg = freezed,
    Object? timezone = null,
    Object? locale = null,
    Object? onboardingStage = null,
    Object? isVitStudent = freezed,
    Object? mess = freezed,
    Object? avatarId = freezed,
  }) {
    return _then(_UserProfileDetail(
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      sex: freezed == sex
          ? _self.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as Sex?,
      birthDate: freezed == birthDate
          ? _self.birthDate
          : birthDate // ignore: cast_nullable_to_non_nullable
              as String?,
      heightCm: freezed == heightCm
          ? _self.heightCm
          : heightCm // ignore: cast_nullable_to_non_nullable
              as double?,
      experienceLevel: freezed == experienceLevel
          ? _self.experienceLevel
          : experienceLevel // ignore: cast_nullable_to_non_nullable
              as ExperienceLevel?,
      trainingDaysPerWeek: freezed == trainingDaysPerWeek
          ? _self.trainingDaysPerWeek
          : trainingDaysPerWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      activityLevel: freezed == activityLevel
          ? _self.activityLevel
          : activityLevel // ignore: cast_nullable_to_non_nullable
              as ActivityLevel?,
      preferredSessionMinutes: freezed == preferredSessionMinutes
          ? _self.preferredSessionMinutes
          : preferredSessionMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      trainingLocation: freezed == trainingLocation
          ? _self.trainingLocation
          : trainingLocation // ignore: cast_nullable_to_non_nullable
              as TrainingLocation?,
      equipment: null == equipment
          ? _self._equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      latestWeightKg: freezed == latestWeightKg
          ? _self.latestWeightKg
          : latestWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      locale: null == locale
          ? _self.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      onboardingStage: null == onboardingStage
          ? _self.onboardingStage
          : onboardingStage // ignore: cast_nullable_to_non_nullable
              as String,
      isVitStudent: freezed == isVitStudent
          ? _self.isVitStudent
          : isVitStudent // ignore: cast_nullable_to_non_nullable
              as bool?,
      mess: freezed == mess
          ? _self.mess
          : mess // ignore: cast_nullable_to_non_nullable
              as MessRef?,
      avatarId: freezed == avatarId
          ? _self.avatarId
          : avatarId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of UserProfileDetail
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
mixin _$Goal {
  String get id;
  GoalType get goalType;
  double? get targetWeightKg;
  DateTime get startedAt;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GoalCopyWith<Goal> get copyWith =>
      _$GoalCopyWithImpl<Goal>(this as Goal, _$identity);

  /// Serializes this Goal to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Goal &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.goalType, goalType) ||
                other.goalType == goalType) &&
            (identical(other.targetWeightKg, targetWeightKg) ||
                other.targetWeightKg == targetWeightKg) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, goalType, targetWeightKg, startedAt);

  @override
  String toString() {
    return 'Goal(id: $id, goalType: $goalType, targetWeightKg: $targetWeightKg, startedAt: $startedAt)';
  }
}

/// @nodoc
abstract mixin class $GoalCopyWith<$Res> {
  factory $GoalCopyWith(Goal value, $Res Function(Goal) _then) =
      _$GoalCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      GoalType goalType,
      double? targetWeightKg,
      DateTime startedAt});
}

/// @nodoc
class _$GoalCopyWithImpl<$Res> implements $GoalCopyWith<$Res> {
  _$GoalCopyWithImpl(this._self, this._then);

  final Goal _self;
  final $Res Function(Goal) _then;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? goalType = null,
    Object? targetWeightKg = freezed,
    Object? startedAt = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      goalType: null == goalType
          ? _self.goalType
          : goalType // ignore: cast_nullable_to_non_nullable
              as GoalType,
      targetWeightKg: freezed == targetWeightKg
          ? _self.targetWeightKg
          : targetWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      startedAt: null == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [Goal].
extension GoalPatterns on Goal {
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
    TResult Function(_Goal value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Goal() when $default != null:
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
    TResult Function(_Goal value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Goal():
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
    TResult? Function(_Goal value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Goal() when $default != null:
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
    TResult Function(String id, GoalType goalType, double? targetWeightKg,
            DateTime startedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Goal() when $default != null:
        return $default(
            _that.id, _that.goalType, _that.targetWeightKg, _that.startedAt);
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
    TResult Function(String id, GoalType goalType, double? targetWeightKg,
            DateTime startedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Goal():
        return $default(
            _that.id, _that.goalType, _that.targetWeightKg, _that.startedAt);
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
    TResult? Function(String id, GoalType goalType, double? targetWeightKg,
            DateTime startedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Goal() when $default != null:
        return $default(
            _that.id, _that.goalType, _that.targetWeightKg, _that.startedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Goal implements Goal {
  const _Goal(
      {required this.id,
      required this.goalType,
      required this.targetWeightKg,
      required this.startedAt});
  factory _Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  @override
  final String id;
  @override
  final GoalType goalType;
  @override
  final double? targetWeightKg;
  @override
  final DateTime startedAt;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GoalCopyWith<_Goal> get copyWith =>
      __$GoalCopyWithImpl<_Goal>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GoalToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Goal &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.goalType, goalType) ||
                other.goalType == goalType) &&
            (identical(other.targetWeightKg, targetWeightKg) ||
                other.targetWeightKg == targetWeightKg) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, goalType, targetWeightKg, startedAt);

  @override
  String toString() {
    return 'Goal(id: $id, goalType: $goalType, targetWeightKg: $targetWeightKg, startedAt: $startedAt)';
  }
}

/// @nodoc
abstract mixin class _$GoalCopyWith<$Res> implements $GoalCopyWith<$Res> {
  factory _$GoalCopyWith(_Goal value, $Res Function(_Goal) _then) =
      __$GoalCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      GoalType goalType,
      double? targetWeightKg,
      DateTime startedAt});
}

/// @nodoc
class __$GoalCopyWithImpl<$Res> implements _$GoalCopyWith<$Res> {
  __$GoalCopyWithImpl(this._self, this._then);

  final _Goal _self;
  final $Res Function(_Goal) _then;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? goalType = null,
    Object? targetWeightKg = freezed,
    Object? startedAt = null,
  }) {
    return _then(_Goal(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      goalType: null == goalType
          ? _self.goalType
          : goalType // ignore: cast_nullable_to_non_nullable
              as GoalType,
      targetWeightKg: freezed == targetWeightKg
          ? _self.targetWeightKg
          : targetWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      startedAt: null == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
mixin _$Allergy {
  Allergen get allergen;
  AllergySeverity get severity;

  /// Create a copy of Allergy
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AllergyCopyWith<Allergy> get copyWith =>
      _$AllergyCopyWithImpl<Allergy>(this as Allergy, _$identity);

  /// Serializes this Allergy to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Allergy &&
            (identical(other.allergen, allergen) ||
                other.allergen == allergen) &&
            (identical(other.severity, severity) ||
                other.severity == severity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, allergen, severity);

  @override
  String toString() {
    return 'Allergy(allergen: $allergen, severity: $severity)';
  }
}

/// @nodoc
abstract mixin class $AllergyCopyWith<$Res> {
  factory $AllergyCopyWith(Allergy value, $Res Function(Allergy) _then) =
      _$AllergyCopyWithImpl;
  @useResult
  $Res call({Allergen allergen, AllergySeverity severity});
}

/// @nodoc
class _$AllergyCopyWithImpl<$Res> implements $AllergyCopyWith<$Res> {
  _$AllergyCopyWithImpl(this._self, this._then);

  final Allergy _self;
  final $Res Function(Allergy) _then;

  /// Create a copy of Allergy
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allergen = null,
    Object? severity = null,
  }) {
    return _then(_self.copyWith(
      allergen: null == allergen
          ? _self.allergen
          : allergen // ignore: cast_nullable_to_non_nullable
              as Allergen,
      severity: null == severity
          ? _self.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as AllergySeverity,
    ));
  }
}

/// Adds pattern-matching-related methods to [Allergy].
extension AllergyPatterns on Allergy {
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
    TResult Function(_Allergy value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Allergy() when $default != null:
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
    TResult Function(_Allergy value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Allergy():
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
    TResult? Function(_Allergy value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Allergy() when $default != null:
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
    TResult Function(Allergen allergen, AllergySeverity severity)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Allergy() when $default != null:
        return $default(_that.allergen, _that.severity);
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
    TResult Function(Allergen allergen, AllergySeverity severity) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Allergy():
        return $default(_that.allergen, _that.severity);
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
    TResult? Function(Allergen allergen, AllergySeverity severity)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Allergy() when $default != null:
        return $default(_that.allergen, _that.severity);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Allergy implements Allergy {
  const _Allergy({required this.allergen, required this.severity});
  factory _Allergy.fromJson(Map<String, dynamic> json) =>
      _$AllergyFromJson(json);

  @override
  final Allergen allergen;
  @override
  final AllergySeverity severity;

  /// Create a copy of Allergy
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AllergyCopyWith<_Allergy> get copyWith =>
      __$AllergyCopyWithImpl<_Allergy>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AllergyToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Allergy &&
            (identical(other.allergen, allergen) ||
                other.allergen == allergen) &&
            (identical(other.severity, severity) ||
                other.severity == severity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, allergen, severity);

  @override
  String toString() {
    return 'Allergy(allergen: $allergen, severity: $severity)';
  }
}

/// @nodoc
abstract mixin class _$AllergyCopyWith<$Res> implements $AllergyCopyWith<$Res> {
  factory _$AllergyCopyWith(_Allergy value, $Res Function(_Allergy) _then) =
      __$AllergyCopyWithImpl;
  @override
  @useResult
  $Res call({Allergen allergen, AllergySeverity severity});
}

/// @nodoc
class __$AllergyCopyWithImpl<$Res> implements _$AllergyCopyWith<$Res> {
  __$AllergyCopyWithImpl(this._self, this._then);

  final _Allergy _self;
  final $Res Function(_Allergy) _then;

  /// Create a copy of Allergy
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? allergen = null,
    Object? severity = null,
  }) {
    return _then(_Allergy(
      allergen: null == allergen
          ? _self.allergen
          : allergen // ignore: cast_nullable_to_non_nullable
              as Allergen,
      severity: null == severity
          ? _self.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as AllergySeverity,
    ));
  }
}

/// @nodoc
mixin _$DietPreferences {
  DietType get dietType;
  List<Allergy> get allergies;
  List<String> get excludedDishIds;
  BudgetTier? get budgetTier;

  /// Create a copy of DietPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DietPreferencesCopyWith<DietPreferences> get copyWith =>
      _$DietPreferencesCopyWithImpl<DietPreferences>(
          this as DietPreferences, _$identity);

  /// Serializes this DietPreferences to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DietPreferences &&
            (identical(other.dietType, dietType) ||
                other.dietType == dietType) &&
            const DeepCollectionEquality().equals(other.allergies, allergies) &&
            const DeepCollectionEquality()
                .equals(other.excludedDishIds, excludedDishIds) &&
            (identical(other.budgetTier, budgetTier) ||
                other.budgetTier == budgetTier));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dietType,
      const DeepCollectionEquality().hash(allergies),
      const DeepCollectionEquality().hash(excludedDishIds),
      budgetTier);

  @override
  String toString() {
    return 'DietPreferences(dietType: $dietType, allergies: $allergies, excludedDishIds: $excludedDishIds, budgetTier: $budgetTier)';
  }
}

/// @nodoc
abstract mixin class $DietPreferencesCopyWith<$Res> {
  factory $DietPreferencesCopyWith(
          DietPreferences value, $Res Function(DietPreferences) _then) =
      _$DietPreferencesCopyWithImpl;
  @useResult
  $Res call(
      {DietType dietType,
      List<Allergy> allergies,
      List<String> excludedDishIds,
      BudgetTier? budgetTier});
}

/// @nodoc
class _$DietPreferencesCopyWithImpl<$Res>
    implements $DietPreferencesCopyWith<$Res> {
  _$DietPreferencesCopyWithImpl(this._self, this._then);

  final DietPreferences _self;
  final $Res Function(DietPreferences) _then;

  /// Create a copy of DietPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dietType = null,
    Object? allergies = null,
    Object? excludedDishIds = null,
    Object? budgetTier = freezed,
  }) {
    return _then(_self.copyWith(
      dietType: null == dietType
          ? _self.dietType
          : dietType // ignore: cast_nullable_to_non_nullable
              as DietType,
      allergies: null == allergies
          ? _self.allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<Allergy>,
      excludedDishIds: null == excludedDishIds
          ? _self.excludedDishIds
          : excludedDishIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      budgetTier: freezed == budgetTier
          ? _self.budgetTier
          : budgetTier // ignore: cast_nullable_to_non_nullable
              as BudgetTier?,
    ));
  }
}

/// Adds pattern-matching-related methods to [DietPreferences].
extension DietPreferencesPatterns on DietPreferences {
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
    TResult Function(_DietPreferences value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DietPreferences() when $default != null:
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
    TResult Function(_DietPreferences value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DietPreferences():
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
    TResult? Function(_DietPreferences value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DietPreferences() when $default != null:
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
    TResult Function(DietType dietType, List<Allergy> allergies,
            List<String> excludedDishIds, BudgetTier? budgetTier)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DietPreferences() when $default != null:
        return $default(_that.dietType, _that.allergies, _that.excludedDishIds,
            _that.budgetTier);
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
    TResult Function(DietType dietType, List<Allergy> allergies,
            List<String> excludedDishIds, BudgetTier? budgetTier)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DietPreferences():
        return $default(_that.dietType, _that.allergies, _that.excludedDishIds,
            _that.budgetTier);
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
    TResult? Function(DietType dietType, List<Allergy> allergies,
            List<String> excludedDishIds, BudgetTier? budgetTier)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DietPreferences() when $default != null:
        return $default(_that.dietType, _that.allergies, _that.excludedDishIds,
            _that.budgetTier);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DietPreferences implements DietPreferences {
  const _DietPreferences(
      {required this.dietType,
      required final List<Allergy> allergies,
      required final List<String> excludedDishIds,
      required this.budgetTier})
      : _allergies = allergies,
        _excludedDishIds = excludedDishIds;
  factory _DietPreferences.fromJson(Map<String, dynamic> json) =>
      _$DietPreferencesFromJson(json);

  @override
  final DietType dietType;
  final List<Allergy> _allergies;
  @override
  List<Allergy> get allergies {
    if (_allergies is EqualUnmodifiableListView) return _allergies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergies);
  }

  final List<String> _excludedDishIds;
  @override
  List<String> get excludedDishIds {
    if (_excludedDishIds is EqualUnmodifiableListView) return _excludedDishIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_excludedDishIds);
  }

  @override
  final BudgetTier? budgetTier;

  /// Create a copy of DietPreferences
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DietPreferencesCopyWith<_DietPreferences> get copyWith =>
      __$DietPreferencesCopyWithImpl<_DietPreferences>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DietPreferencesToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DietPreferences &&
            (identical(other.dietType, dietType) ||
                other.dietType == dietType) &&
            const DeepCollectionEquality()
                .equals(other._allergies, _allergies) &&
            const DeepCollectionEquality()
                .equals(other._excludedDishIds, _excludedDishIds) &&
            (identical(other.budgetTier, budgetTier) ||
                other.budgetTier == budgetTier));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dietType,
      const DeepCollectionEquality().hash(_allergies),
      const DeepCollectionEquality().hash(_excludedDishIds),
      budgetTier);

  @override
  String toString() {
    return 'DietPreferences(dietType: $dietType, allergies: $allergies, excludedDishIds: $excludedDishIds, budgetTier: $budgetTier)';
  }
}

/// @nodoc
abstract mixin class _$DietPreferencesCopyWith<$Res>
    implements $DietPreferencesCopyWith<$Res> {
  factory _$DietPreferencesCopyWith(
          _DietPreferences value, $Res Function(_DietPreferences) _then) =
      __$DietPreferencesCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DietType dietType,
      List<Allergy> allergies,
      List<String> excludedDishIds,
      BudgetTier? budgetTier});
}

/// @nodoc
class __$DietPreferencesCopyWithImpl<$Res>
    implements _$DietPreferencesCopyWith<$Res> {
  __$DietPreferencesCopyWithImpl(this._self, this._then);

  final _DietPreferences _self;
  final $Res Function(_DietPreferences) _then;

  /// Create a copy of DietPreferences
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dietType = null,
    Object? allergies = null,
    Object? excludedDishIds = null,
    Object? budgetTier = freezed,
  }) {
    return _then(_DietPreferences(
      dietType: null == dietType
          ? _self.dietType
          : dietType // ignore: cast_nullable_to_non_nullable
              as DietType,
      allergies: null == allergies
          ? _self._allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<Allergy>,
      excludedDishIds: null == excludedDishIds
          ? _self._excludedDishIds
          : excludedDishIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      budgetTier: freezed == budgetTier
          ? _self.budgetTier
          : budgetTier // ignore: cast_nullable_to_non_nullable
              as BudgetTier?,
    ));
  }
}

/// @nodoc
mixin _$NutritionTargets {
  String get effectiveFrom;
  int get kcal;
  int get proteinG;
  int get carbG;
  int get fatG;
  int get fiberG;
  int get bmr;
  int get tdeeEstimate;
  List<String> get rationale;
  String get reason;

  /// Beta 3.2 (ADR-031): `custom` when the user set calories and protein.
  String get source;

  /// Create a copy of NutritionTargets
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<NutritionTargets> get copyWith =>
      _$NutritionTargetsCopyWithImpl<NutritionTargets>(
          this as NutritionTargets, _$identity);

  /// Serializes this NutritionTargets to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NutritionTargets &&
            (identical(other.effectiveFrom, effectiveFrom) ||
                other.effectiveFrom == effectiveFrom) &&
            (identical(other.kcal, kcal) || other.kcal == kcal) &&
            (identical(other.proteinG, proteinG) ||
                other.proteinG == proteinG) &&
            (identical(other.carbG, carbG) || other.carbG == carbG) &&
            (identical(other.fatG, fatG) || other.fatG == fatG) &&
            (identical(other.fiberG, fiberG) || other.fiberG == fiberG) &&
            (identical(other.bmr, bmr) || other.bmr == bmr) &&
            (identical(other.tdeeEstimate, tdeeEstimate) ||
                other.tdeeEstimate == tdeeEstimate) &&
            const DeepCollectionEquality().equals(other.rationale, rationale) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      effectiveFrom,
      kcal,
      proteinG,
      carbG,
      fatG,
      fiberG,
      bmr,
      tdeeEstimate,
      const DeepCollectionEquality().hash(rationale),
      reason,
      source);

  @override
  String toString() {
    return 'NutritionTargets(effectiveFrom: $effectiveFrom, kcal: $kcal, proteinG: $proteinG, carbG: $carbG, fatG: $fatG, fiberG: $fiberG, bmr: $bmr, tdeeEstimate: $tdeeEstimate, rationale: $rationale, reason: $reason, source: $source)';
  }
}

/// @nodoc
abstract mixin class $NutritionTargetsCopyWith<$Res> {
  factory $NutritionTargetsCopyWith(
          NutritionTargets value, $Res Function(NutritionTargets) _then) =
      _$NutritionTargetsCopyWithImpl;
  @useResult
  $Res call(
      {String effectiveFrom,
      int kcal,
      int proteinG,
      int carbG,
      int fatG,
      int fiberG,
      int bmr,
      int tdeeEstimate,
      List<String> rationale,
      String reason,
      String source});
}

/// @nodoc
class _$NutritionTargetsCopyWithImpl<$Res>
    implements $NutritionTargetsCopyWith<$Res> {
  _$NutritionTargetsCopyWithImpl(this._self, this._then);

  final NutritionTargets _self;
  final $Res Function(NutritionTargets) _then;

  /// Create a copy of NutritionTargets
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? effectiveFrom = null,
    Object? kcal = null,
    Object? proteinG = null,
    Object? carbG = null,
    Object? fatG = null,
    Object? fiberG = null,
    Object? bmr = null,
    Object? tdeeEstimate = null,
    Object? rationale = null,
    Object? reason = null,
    Object? source = null,
  }) {
    return _then(_self.copyWith(
      effectiveFrom: null == effectiveFrom
          ? _self.effectiveFrom
          : effectiveFrom // ignore: cast_nullable_to_non_nullable
              as String,
      kcal: null == kcal
          ? _self.kcal
          : kcal // ignore: cast_nullable_to_non_nullable
              as int,
      proteinG: null == proteinG
          ? _self.proteinG
          : proteinG // ignore: cast_nullable_to_non_nullable
              as int,
      carbG: null == carbG
          ? _self.carbG
          : carbG // ignore: cast_nullable_to_non_nullable
              as int,
      fatG: null == fatG
          ? _self.fatG
          : fatG // ignore: cast_nullable_to_non_nullable
              as int,
      fiberG: null == fiberG
          ? _self.fiberG
          : fiberG // ignore: cast_nullable_to_non_nullable
              as int,
      bmr: null == bmr
          ? _self.bmr
          : bmr // ignore: cast_nullable_to_non_nullable
              as int,
      tdeeEstimate: null == tdeeEstimate
          ? _self.tdeeEstimate
          : tdeeEstimate // ignore: cast_nullable_to_non_nullable
              as int,
      rationale: null == rationale
          ? _self.rationale
          : rationale // ignore: cast_nullable_to_non_nullable
              as List<String>,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [NutritionTargets].
extension NutritionTargetsPatterns on NutritionTargets {
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
    TResult Function(_NutritionTargets value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NutritionTargets() when $default != null:
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
    TResult Function(_NutritionTargets value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionTargets():
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
    TResult? Function(_NutritionTargets value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionTargets() when $default != null:
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
            String effectiveFrom,
            int kcal,
            int proteinG,
            int carbG,
            int fatG,
            int fiberG,
            int bmr,
            int tdeeEstimate,
            List<String> rationale,
            String reason,
            String source)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NutritionTargets() when $default != null:
        return $default(
            _that.effectiveFrom,
            _that.kcal,
            _that.proteinG,
            _that.carbG,
            _that.fatG,
            _that.fiberG,
            _that.bmr,
            _that.tdeeEstimate,
            _that.rationale,
            _that.reason,
            _that.source);
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
            String effectiveFrom,
            int kcal,
            int proteinG,
            int carbG,
            int fatG,
            int fiberG,
            int bmr,
            int tdeeEstimate,
            List<String> rationale,
            String reason,
            String source)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionTargets():
        return $default(
            _that.effectiveFrom,
            _that.kcal,
            _that.proteinG,
            _that.carbG,
            _that.fatG,
            _that.fiberG,
            _that.bmr,
            _that.tdeeEstimate,
            _that.rationale,
            _that.reason,
            _that.source);
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
            String effectiveFrom,
            int kcal,
            int proteinG,
            int carbG,
            int fatG,
            int fiberG,
            int bmr,
            int tdeeEstimate,
            List<String> rationale,
            String reason,
            String source)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionTargets() when $default != null:
        return $default(
            _that.effectiveFrom,
            _that.kcal,
            _that.proteinG,
            _that.carbG,
            _that.fatG,
            _that.fiberG,
            _that.bmr,
            _that.tdeeEstimate,
            _that.rationale,
            _that.reason,
            _that.source);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _NutritionTargets implements NutritionTargets {
  const _NutritionTargets(
      {required this.effectiveFrom,
      required this.kcal,
      required this.proteinG,
      required this.carbG,
      required this.fatG,
      required this.fiberG,
      required this.bmr,
      required this.tdeeEstimate,
      required final List<String> rationale,
      required this.reason,
      this.source = 'fitos'})
      : _rationale = rationale;
  factory _NutritionTargets.fromJson(Map<String, dynamic> json) =>
      _$NutritionTargetsFromJson(json);

  @override
  final String effectiveFrom;
  @override
  final int kcal;
  @override
  final int proteinG;
  @override
  final int carbG;
  @override
  final int fatG;
  @override
  final int fiberG;
  @override
  final int bmr;
  @override
  final int tdeeEstimate;
  final List<String> _rationale;
  @override
  List<String> get rationale {
    if (_rationale is EqualUnmodifiableListView) return _rationale;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rationale);
  }

  @override
  final String reason;

  /// Beta 3.2 (ADR-031): `custom` when the user set calories and protein.
  @override
  @JsonKey()
  final String source;

  /// Create a copy of NutritionTargets
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NutritionTargetsCopyWith<_NutritionTargets> get copyWith =>
      __$NutritionTargetsCopyWithImpl<_NutritionTargets>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NutritionTargetsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NutritionTargets &&
            (identical(other.effectiveFrom, effectiveFrom) ||
                other.effectiveFrom == effectiveFrom) &&
            (identical(other.kcal, kcal) || other.kcal == kcal) &&
            (identical(other.proteinG, proteinG) ||
                other.proteinG == proteinG) &&
            (identical(other.carbG, carbG) || other.carbG == carbG) &&
            (identical(other.fatG, fatG) || other.fatG == fatG) &&
            (identical(other.fiberG, fiberG) || other.fiberG == fiberG) &&
            (identical(other.bmr, bmr) || other.bmr == bmr) &&
            (identical(other.tdeeEstimate, tdeeEstimate) ||
                other.tdeeEstimate == tdeeEstimate) &&
            const DeepCollectionEquality()
                .equals(other._rationale, _rationale) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      effectiveFrom,
      kcal,
      proteinG,
      carbG,
      fatG,
      fiberG,
      bmr,
      tdeeEstimate,
      const DeepCollectionEquality().hash(_rationale),
      reason,
      source);

  @override
  String toString() {
    return 'NutritionTargets(effectiveFrom: $effectiveFrom, kcal: $kcal, proteinG: $proteinG, carbG: $carbG, fatG: $fatG, fiberG: $fiberG, bmr: $bmr, tdeeEstimate: $tdeeEstimate, rationale: $rationale, reason: $reason, source: $source)';
  }
}

/// @nodoc
abstract mixin class _$NutritionTargetsCopyWith<$Res>
    implements $NutritionTargetsCopyWith<$Res> {
  factory _$NutritionTargetsCopyWith(
          _NutritionTargets value, $Res Function(_NutritionTargets) _then) =
      __$NutritionTargetsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String effectiveFrom,
      int kcal,
      int proteinG,
      int carbG,
      int fatG,
      int fiberG,
      int bmr,
      int tdeeEstimate,
      List<String> rationale,
      String reason,
      String source});
}

/// @nodoc
class __$NutritionTargetsCopyWithImpl<$Res>
    implements _$NutritionTargetsCopyWith<$Res> {
  __$NutritionTargetsCopyWithImpl(this._self, this._then);

  final _NutritionTargets _self;
  final $Res Function(_NutritionTargets) _then;

  /// Create a copy of NutritionTargets
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? effectiveFrom = null,
    Object? kcal = null,
    Object? proteinG = null,
    Object? carbG = null,
    Object? fatG = null,
    Object? fiberG = null,
    Object? bmr = null,
    Object? tdeeEstimate = null,
    Object? rationale = null,
    Object? reason = null,
    Object? source = null,
  }) {
    return _then(_NutritionTargets(
      effectiveFrom: null == effectiveFrom
          ? _self.effectiveFrom
          : effectiveFrom // ignore: cast_nullable_to_non_nullable
              as String,
      kcal: null == kcal
          ? _self.kcal
          : kcal // ignore: cast_nullable_to_non_nullable
              as int,
      proteinG: null == proteinG
          ? _self.proteinG
          : proteinG // ignore: cast_nullable_to_non_nullable
              as int,
      carbG: null == carbG
          ? _self.carbG
          : carbG // ignore: cast_nullable_to_non_nullable
              as int,
      fatG: null == fatG
          ? _self.fatG
          : fatG // ignore: cast_nullable_to_non_nullable
              as int,
      fiberG: null == fiberG
          ? _self.fiberG
          : fiberG // ignore: cast_nullable_to_non_nullable
              as int,
      bmr: null == bmr
          ? _self.bmr
          : bmr // ignore: cast_nullable_to_non_nullable
              as int,
      tdeeEstimate: null == tdeeEstimate
          ? _self.tdeeEstimate
          : tdeeEstimate // ignore: cast_nullable_to_non_nullable
              as int,
      rationale: null == rationale
          ? _self._rationale
          : rationale // ignore: cast_nullable_to_non_nullable
              as List<String>,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$TargetsSuggestion {
  int get kcal;
  int get proteinG;
  int get carbG;
  int get fatG;
  int get fiberG;

  /// Create a copy of TargetsSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TargetsSuggestionCopyWith<TargetsSuggestion> get copyWith =>
      _$TargetsSuggestionCopyWithImpl<TargetsSuggestion>(
          this as TargetsSuggestion, _$identity);

  /// Serializes this TargetsSuggestion to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TargetsSuggestion &&
            (identical(other.kcal, kcal) || other.kcal == kcal) &&
            (identical(other.proteinG, proteinG) ||
                other.proteinG == proteinG) &&
            (identical(other.carbG, carbG) || other.carbG == carbG) &&
            (identical(other.fatG, fatG) || other.fatG == fatG) &&
            (identical(other.fiberG, fiberG) || other.fiberG == fiberG));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, kcal, proteinG, carbG, fatG, fiberG);

  @override
  String toString() {
    return 'TargetsSuggestion(kcal: $kcal, proteinG: $proteinG, carbG: $carbG, fatG: $fatG, fiberG: $fiberG)';
  }
}

/// @nodoc
abstract mixin class $TargetsSuggestionCopyWith<$Res> {
  factory $TargetsSuggestionCopyWith(
          TargetsSuggestion value, $Res Function(TargetsSuggestion) _then) =
      _$TargetsSuggestionCopyWithImpl;
  @useResult
  $Res call({int kcal, int proteinG, int carbG, int fatG, int fiberG});
}

/// @nodoc
class _$TargetsSuggestionCopyWithImpl<$Res>
    implements $TargetsSuggestionCopyWith<$Res> {
  _$TargetsSuggestionCopyWithImpl(this._self, this._then);

  final TargetsSuggestion _self;
  final $Res Function(TargetsSuggestion) _then;

  /// Create a copy of TargetsSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kcal = null,
    Object? proteinG = null,
    Object? carbG = null,
    Object? fatG = null,
    Object? fiberG = null,
  }) {
    return _then(_self.copyWith(
      kcal: null == kcal
          ? _self.kcal
          : kcal // ignore: cast_nullable_to_non_nullable
              as int,
      proteinG: null == proteinG
          ? _self.proteinG
          : proteinG // ignore: cast_nullable_to_non_nullable
              as int,
      carbG: null == carbG
          ? _self.carbG
          : carbG // ignore: cast_nullable_to_non_nullable
              as int,
      fatG: null == fatG
          ? _self.fatG
          : fatG // ignore: cast_nullable_to_non_nullable
              as int,
      fiberG: null == fiberG
          ? _self.fiberG
          : fiberG // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [TargetsSuggestion].
extension TargetsSuggestionPatterns on TargetsSuggestion {
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
    TResult Function(_TargetsSuggestion value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TargetsSuggestion() when $default != null:
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
    TResult Function(_TargetsSuggestion value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetsSuggestion():
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
    TResult? Function(_TargetsSuggestion value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetsSuggestion() when $default != null:
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
    TResult Function(int kcal, int proteinG, int carbG, int fatG, int fiberG)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TargetsSuggestion() when $default != null:
        return $default(
            _that.kcal, _that.proteinG, _that.carbG, _that.fatG, _that.fiberG);
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
    TResult Function(int kcal, int proteinG, int carbG, int fatG, int fiberG)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetsSuggestion():
        return $default(
            _that.kcal, _that.proteinG, _that.carbG, _that.fatG, _that.fiberG);
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
    TResult? Function(int kcal, int proteinG, int carbG, int fatG, int fiberG)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetsSuggestion() when $default != null:
        return $default(
            _that.kcal, _that.proteinG, _that.carbG, _that.fatG, _that.fiberG);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TargetsSuggestion implements TargetsSuggestion {
  const _TargetsSuggestion(
      {required this.kcal,
      required this.proteinG,
      required this.carbG,
      required this.fatG,
      required this.fiberG});
  factory _TargetsSuggestion.fromJson(Map<String, dynamic> json) =>
      _$TargetsSuggestionFromJson(json);

  @override
  final int kcal;
  @override
  final int proteinG;
  @override
  final int carbG;
  @override
  final int fatG;
  @override
  final int fiberG;

  /// Create a copy of TargetsSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TargetsSuggestionCopyWith<_TargetsSuggestion> get copyWith =>
      __$TargetsSuggestionCopyWithImpl<_TargetsSuggestion>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TargetsSuggestionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TargetsSuggestion &&
            (identical(other.kcal, kcal) || other.kcal == kcal) &&
            (identical(other.proteinG, proteinG) ||
                other.proteinG == proteinG) &&
            (identical(other.carbG, carbG) || other.carbG == carbG) &&
            (identical(other.fatG, fatG) || other.fatG == fatG) &&
            (identical(other.fiberG, fiberG) || other.fiberG == fiberG));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, kcal, proteinG, carbG, fatG, fiberG);

  @override
  String toString() {
    return 'TargetsSuggestion(kcal: $kcal, proteinG: $proteinG, carbG: $carbG, fatG: $fatG, fiberG: $fiberG)';
  }
}

/// @nodoc
abstract mixin class _$TargetsSuggestionCopyWith<$Res>
    implements $TargetsSuggestionCopyWith<$Res> {
  factory _$TargetsSuggestionCopyWith(
          _TargetsSuggestion value, $Res Function(_TargetsSuggestion) _then) =
      __$TargetsSuggestionCopyWithImpl;
  @override
  @useResult
  $Res call({int kcal, int proteinG, int carbG, int fatG, int fiberG});
}

/// @nodoc
class __$TargetsSuggestionCopyWithImpl<$Res>
    implements _$TargetsSuggestionCopyWith<$Res> {
  __$TargetsSuggestionCopyWithImpl(this._self, this._then);

  final _TargetsSuggestion _self;
  final $Res Function(_TargetsSuggestion) _then;

  /// Create a copy of TargetsSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? kcal = null,
    Object? proteinG = null,
    Object? carbG = null,
    Object? fatG = null,
    Object? fiberG = null,
  }) {
    return _then(_TargetsSuggestion(
      kcal: null == kcal
          ? _self.kcal
          : kcal // ignore: cast_nullable_to_non_nullable
              as int,
      proteinG: null == proteinG
          ? _self.proteinG
          : proteinG // ignore: cast_nullable_to_non_nullable
              as int,
      carbG: null == carbG
          ? _self.carbG
          : carbG // ignore: cast_nullable_to_non_nullable
              as int,
      fatG: null == fatG
          ? _self.fatG
          : fatG // ignore: cast_nullable_to_non_nullable
              as int,
      fiberG: null == fiberG
          ? _self.fiberG
          : fiberG // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$TargetLimits {
  int get kcalMin;
  int get kcalMax;
  int get proteinMinG;
  int get proteinMaxG;

  /// Create a copy of TargetLimits
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TargetLimitsCopyWith<TargetLimits> get copyWith =>
      _$TargetLimitsCopyWithImpl<TargetLimits>(
          this as TargetLimits, _$identity);

  /// Serializes this TargetLimits to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TargetLimits &&
            (identical(other.kcalMin, kcalMin) || other.kcalMin == kcalMin) &&
            (identical(other.kcalMax, kcalMax) || other.kcalMax == kcalMax) &&
            (identical(other.proteinMinG, proteinMinG) ||
                other.proteinMinG == proteinMinG) &&
            (identical(other.proteinMaxG, proteinMaxG) ||
                other.proteinMaxG == proteinMaxG));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, kcalMin, kcalMax, proteinMinG, proteinMaxG);

  @override
  String toString() {
    return 'TargetLimits(kcalMin: $kcalMin, kcalMax: $kcalMax, proteinMinG: $proteinMinG, proteinMaxG: $proteinMaxG)';
  }
}

/// @nodoc
abstract mixin class $TargetLimitsCopyWith<$Res> {
  factory $TargetLimitsCopyWith(
          TargetLimits value, $Res Function(TargetLimits) _then) =
      _$TargetLimitsCopyWithImpl;
  @useResult
  $Res call({int kcalMin, int kcalMax, int proteinMinG, int proteinMaxG});
}

/// @nodoc
class _$TargetLimitsCopyWithImpl<$Res> implements $TargetLimitsCopyWith<$Res> {
  _$TargetLimitsCopyWithImpl(this._self, this._then);

  final TargetLimits _self;
  final $Res Function(TargetLimits) _then;

  /// Create a copy of TargetLimits
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kcalMin = null,
    Object? kcalMax = null,
    Object? proteinMinG = null,
    Object? proteinMaxG = null,
  }) {
    return _then(_self.copyWith(
      kcalMin: null == kcalMin
          ? _self.kcalMin
          : kcalMin // ignore: cast_nullable_to_non_nullable
              as int,
      kcalMax: null == kcalMax
          ? _self.kcalMax
          : kcalMax // ignore: cast_nullable_to_non_nullable
              as int,
      proteinMinG: null == proteinMinG
          ? _self.proteinMinG
          : proteinMinG // ignore: cast_nullable_to_non_nullable
              as int,
      proteinMaxG: null == proteinMaxG
          ? _self.proteinMaxG
          : proteinMaxG // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [TargetLimits].
extension TargetLimitsPatterns on TargetLimits {
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
    TResult Function(_TargetLimits value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TargetLimits() when $default != null:
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
    TResult Function(_TargetLimits value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetLimits():
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
    TResult? Function(_TargetLimits value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetLimits() when $default != null:
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
            int kcalMin, int kcalMax, int proteinMinG, int proteinMaxG)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TargetLimits() when $default != null:
        return $default(
            _that.kcalMin, _that.kcalMax, _that.proteinMinG, _that.proteinMaxG);
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
    TResult Function(int kcalMin, int kcalMax, int proteinMinG, int proteinMaxG)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetLimits():
        return $default(
            _that.kcalMin, _that.kcalMax, _that.proteinMinG, _that.proteinMaxG);
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
            int kcalMin, int kcalMax, int proteinMinG, int proteinMaxG)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetLimits() when $default != null:
        return $default(
            _that.kcalMin, _that.kcalMax, _that.proteinMinG, _that.proteinMaxG);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TargetLimits implements TargetLimits {
  const _TargetLimits(
      {required this.kcalMin,
      required this.kcalMax,
      required this.proteinMinG,
      required this.proteinMaxG});
  factory _TargetLimits.fromJson(Map<String, dynamic> json) =>
      _$TargetLimitsFromJson(json);

  @override
  final int kcalMin;
  @override
  final int kcalMax;
  @override
  final int proteinMinG;
  @override
  final int proteinMaxG;

  /// Create a copy of TargetLimits
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TargetLimitsCopyWith<_TargetLimits> get copyWith =>
      __$TargetLimitsCopyWithImpl<_TargetLimits>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TargetLimitsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TargetLimits &&
            (identical(other.kcalMin, kcalMin) || other.kcalMin == kcalMin) &&
            (identical(other.kcalMax, kcalMax) || other.kcalMax == kcalMax) &&
            (identical(other.proteinMinG, proteinMinG) ||
                other.proteinMinG == proteinMinG) &&
            (identical(other.proteinMaxG, proteinMaxG) ||
                other.proteinMaxG == proteinMaxG));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, kcalMin, kcalMax, proteinMinG, proteinMaxG);

  @override
  String toString() {
    return 'TargetLimits(kcalMin: $kcalMin, kcalMax: $kcalMax, proteinMinG: $proteinMinG, proteinMaxG: $proteinMaxG)';
  }
}

/// @nodoc
abstract mixin class _$TargetLimitsCopyWith<$Res>
    implements $TargetLimitsCopyWith<$Res> {
  factory _$TargetLimitsCopyWith(
          _TargetLimits value, $Res Function(_TargetLimits) _then) =
      __$TargetLimitsCopyWithImpl;
  @override
  @useResult
  $Res call({int kcalMin, int kcalMax, int proteinMinG, int proteinMaxG});
}

/// @nodoc
class __$TargetLimitsCopyWithImpl<$Res>
    implements _$TargetLimitsCopyWith<$Res> {
  __$TargetLimitsCopyWithImpl(this._self, this._then);

  final _TargetLimits _self;
  final $Res Function(_TargetLimits) _then;

  /// Create a copy of TargetLimits
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? kcalMin = null,
    Object? kcalMax = null,
    Object? proteinMinG = null,
    Object? proteinMaxG = null,
  }) {
    return _then(_TargetLimits(
      kcalMin: null == kcalMin
          ? _self.kcalMin
          : kcalMin // ignore: cast_nullable_to_non_nullable
              as int,
      kcalMax: null == kcalMax
          ? _self.kcalMax
          : kcalMax // ignore: cast_nullable_to_non_nullable
              as int,
      proteinMinG: null == proteinMinG
          ? _self.proteinMinG
          : proteinMinG // ignore: cast_nullable_to_non_nullable
              as int,
      proteinMaxG: null == proteinMaxG
          ? _self.proteinMaxG
          : proteinMaxG // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$TargetsView {
  NutritionTargets? get current;
  TargetsSuggestion? get suggestion;
  TargetLimits get limits;

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TargetsViewCopyWith<TargetsView> get copyWith =>
      _$TargetsViewCopyWithImpl<TargetsView>(this as TargetsView, _$identity);

  /// Serializes this TargetsView to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TargetsView &&
            (identical(other.current, current) || other.current == current) &&
            (identical(other.suggestion, suggestion) ||
                other.suggestion == suggestion) &&
            (identical(other.limits, limits) || other.limits == limits));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, current, suggestion, limits);

  @override
  String toString() {
    return 'TargetsView(current: $current, suggestion: $suggestion, limits: $limits)';
  }
}

/// @nodoc
abstract mixin class $TargetsViewCopyWith<$Res> {
  factory $TargetsViewCopyWith(
          TargetsView value, $Res Function(TargetsView) _then) =
      _$TargetsViewCopyWithImpl;
  @useResult
  $Res call(
      {NutritionTargets? current,
      TargetsSuggestion? suggestion,
      TargetLimits limits});

  $NutritionTargetsCopyWith<$Res>? get current;
  $TargetsSuggestionCopyWith<$Res>? get suggestion;
  $TargetLimitsCopyWith<$Res> get limits;
}

/// @nodoc
class _$TargetsViewCopyWithImpl<$Res> implements $TargetsViewCopyWith<$Res> {
  _$TargetsViewCopyWithImpl(this._self, this._then);

  final TargetsView _self;
  final $Res Function(TargetsView) _then;

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? current = freezed,
    Object? suggestion = freezed,
    Object? limits = null,
  }) {
    return _then(_self.copyWith(
      current: freezed == current
          ? _self.current
          : current // ignore: cast_nullable_to_non_nullable
              as NutritionTargets?,
      suggestion: freezed == suggestion
          ? _self.suggestion
          : suggestion // ignore: cast_nullable_to_non_nullable
              as TargetsSuggestion?,
      limits: null == limits
          ? _self.limits
          : limits // ignore: cast_nullable_to_non_nullable
              as TargetLimits,
    ));
  }

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<$Res>? get current {
    if (_self.current == null) {
      return null;
    }

    return $NutritionTargetsCopyWith<$Res>(_self.current!, (value) {
      return _then(_self.copyWith(current: value));
    });
  }

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TargetsSuggestionCopyWith<$Res>? get suggestion {
    if (_self.suggestion == null) {
      return null;
    }

    return $TargetsSuggestionCopyWith<$Res>(_self.suggestion!, (value) {
      return _then(_self.copyWith(suggestion: value));
    });
  }

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TargetLimitsCopyWith<$Res> get limits {
    return $TargetLimitsCopyWith<$Res>(_self.limits, (value) {
      return _then(_self.copyWith(limits: value));
    });
  }
}

/// Adds pattern-matching-related methods to [TargetsView].
extension TargetsViewPatterns on TargetsView {
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
    TResult Function(_TargetsView value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TargetsView() when $default != null:
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
    TResult Function(_TargetsView value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetsView():
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
    TResult? Function(_TargetsView value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetsView() when $default != null:
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
    TResult Function(NutritionTargets? current, TargetsSuggestion? suggestion,
            TargetLimits limits)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TargetsView() when $default != null:
        return $default(_that.current, _that.suggestion, _that.limits);
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
    TResult Function(NutritionTargets? current, TargetsSuggestion? suggestion,
            TargetLimits limits)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetsView():
        return $default(_that.current, _that.suggestion, _that.limits);
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
    TResult? Function(NutritionTargets? current, TargetsSuggestion? suggestion,
            TargetLimits limits)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TargetsView() when $default != null:
        return $default(_that.current, _that.suggestion, _that.limits);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TargetsView implements TargetsView {
  const _TargetsView(
      {required this.current, required this.suggestion, required this.limits});
  factory _TargetsView.fromJson(Map<String, dynamic> json) =>
      _$TargetsViewFromJson(json);

  @override
  final NutritionTargets? current;
  @override
  final TargetsSuggestion? suggestion;
  @override
  final TargetLimits limits;

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TargetsViewCopyWith<_TargetsView> get copyWith =>
      __$TargetsViewCopyWithImpl<_TargetsView>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TargetsViewToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TargetsView &&
            (identical(other.current, current) || other.current == current) &&
            (identical(other.suggestion, suggestion) ||
                other.suggestion == suggestion) &&
            (identical(other.limits, limits) || other.limits == limits));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, current, suggestion, limits);

  @override
  String toString() {
    return 'TargetsView(current: $current, suggestion: $suggestion, limits: $limits)';
  }
}

/// @nodoc
abstract mixin class _$TargetsViewCopyWith<$Res>
    implements $TargetsViewCopyWith<$Res> {
  factory _$TargetsViewCopyWith(
          _TargetsView value, $Res Function(_TargetsView) _then) =
      __$TargetsViewCopyWithImpl;
  @override
  @useResult
  $Res call(
      {NutritionTargets? current,
      TargetsSuggestion? suggestion,
      TargetLimits limits});

  @override
  $NutritionTargetsCopyWith<$Res>? get current;
  @override
  $TargetsSuggestionCopyWith<$Res>? get suggestion;
  @override
  $TargetLimitsCopyWith<$Res> get limits;
}

/// @nodoc
class __$TargetsViewCopyWithImpl<$Res> implements _$TargetsViewCopyWith<$Res> {
  __$TargetsViewCopyWithImpl(this._self, this._then);

  final _TargetsView _self;
  final $Res Function(_TargetsView) _then;

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? current = freezed,
    Object? suggestion = freezed,
    Object? limits = null,
  }) {
    return _then(_TargetsView(
      current: freezed == current
          ? _self.current
          : current // ignore: cast_nullable_to_non_nullable
              as NutritionTargets?,
      suggestion: freezed == suggestion
          ? _self.suggestion
          : suggestion // ignore: cast_nullable_to_non_nullable
              as TargetsSuggestion?,
      limits: null == limits
          ? _self.limits
          : limits // ignore: cast_nullable_to_non_nullable
              as TargetLimits,
    ));
  }

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<$Res>? get current {
    if (_self.current == null) {
      return null;
    }

    return $NutritionTargetsCopyWith<$Res>(_self.current!, (value) {
      return _then(_self.copyWith(current: value));
    });
  }

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TargetsSuggestionCopyWith<$Res>? get suggestion {
    if (_self.suggestion == null) {
      return null;
    }

    return $TargetsSuggestionCopyWith<$Res>(_self.suggestion!, (value) {
      return _then(_self.copyWith(suggestion: value));
    });
  }

  /// Create a copy of TargetsView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TargetLimitsCopyWith<$Res> get limits {
    return $TargetLimitsCopyWith<$Res>(_self.limits, (value) {
      return _then(_self.copyWith(limits: value));
    });
  }
}

/// @nodoc
mixin _$CustomTargetsResponse {
  NutritionTargets get targets;
  List<String> get warnings;

  /// Create a copy of CustomTargetsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CustomTargetsResponseCopyWith<CustomTargetsResponse> get copyWith =>
      _$CustomTargetsResponseCopyWithImpl<CustomTargetsResponse>(
          this as CustomTargetsResponse, _$identity);

  /// Serializes this CustomTargetsResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CustomTargetsResponse &&
            (identical(other.targets, targets) || other.targets == targets) &&
            const DeepCollectionEquality().equals(other.warnings, warnings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, targets, const DeepCollectionEquality().hash(warnings));

  @override
  String toString() {
    return 'CustomTargetsResponse(targets: $targets, warnings: $warnings)';
  }
}

/// @nodoc
abstract mixin class $CustomTargetsResponseCopyWith<$Res> {
  factory $CustomTargetsResponseCopyWith(CustomTargetsResponse value,
          $Res Function(CustomTargetsResponse) _then) =
      _$CustomTargetsResponseCopyWithImpl;
  @useResult
  $Res call({NutritionTargets targets, List<String> warnings});

  $NutritionTargetsCopyWith<$Res> get targets;
}

/// @nodoc
class _$CustomTargetsResponseCopyWithImpl<$Res>
    implements $CustomTargetsResponseCopyWith<$Res> {
  _$CustomTargetsResponseCopyWithImpl(this._self, this._then);

  final CustomTargetsResponse _self;
  final $Res Function(CustomTargetsResponse) _then;

  /// Create a copy of CustomTargetsResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? targets = null,
    Object? warnings = null,
  }) {
    return _then(_self.copyWith(
      targets: null == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as NutritionTargets,
      warnings: null == warnings
          ? _self.warnings
          : warnings // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }

  /// Create a copy of CustomTargetsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<$Res> get targets {
    return $NutritionTargetsCopyWith<$Res>(_self.targets, (value) {
      return _then(_self.copyWith(targets: value));
    });
  }
}

/// Adds pattern-matching-related methods to [CustomTargetsResponse].
extension CustomTargetsResponsePatterns on CustomTargetsResponse {
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
    TResult Function(_CustomTargetsResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomTargetsResponse() when $default != null:
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
    TResult Function(_CustomTargetsResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomTargetsResponse():
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
    TResult? Function(_CustomTargetsResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomTargetsResponse() when $default != null:
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
    TResult Function(NutritionTargets targets, List<String> warnings)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomTargetsResponse() when $default != null:
        return $default(_that.targets, _that.warnings);
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
    TResult Function(NutritionTargets targets, List<String> warnings) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomTargetsResponse():
        return $default(_that.targets, _that.warnings);
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
    TResult? Function(NutritionTargets targets, List<String> warnings)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomTargetsResponse() when $default != null:
        return $default(_that.targets, _that.warnings);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CustomTargetsResponse implements CustomTargetsResponse {
  const _CustomTargetsResponse(
      {required this.targets, required final List<String> warnings})
      : _warnings = warnings;
  factory _CustomTargetsResponse.fromJson(Map<String, dynamic> json) =>
      _$CustomTargetsResponseFromJson(json);

  @override
  final NutritionTargets targets;
  final List<String> _warnings;
  @override
  List<String> get warnings {
    if (_warnings is EqualUnmodifiableListView) return _warnings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_warnings);
  }

  /// Create a copy of CustomTargetsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CustomTargetsResponseCopyWith<_CustomTargetsResponse> get copyWith =>
      __$CustomTargetsResponseCopyWithImpl<_CustomTargetsResponse>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CustomTargetsResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CustomTargetsResponse &&
            (identical(other.targets, targets) || other.targets == targets) &&
            const DeepCollectionEquality().equals(other._warnings, _warnings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, targets, const DeepCollectionEquality().hash(_warnings));

  @override
  String toString() {
    return 'CustomTargetsResponse(targets: $targets, warnings: $warnings)';
  }
}

/// @nodoc
abstract mixin class _$CustomTargetsResponseCopyWith<$Res>
    implements $CustomTargetsResponseCopyWith<$Res> {
  factory _$CustomTargetsResponseCopyWith(_CustomTargetsResponse value,
          $Res Function(_CustomTargetsResponse) _then) =
      __$CustomTargetsResponseCopyWithImpl;
  @override
  @useResult
  $Res call({NutritionTargets targets, List<String> warnings});

  @override
  $NutritionTargetsCopyWith<$Res> get targets;
}

/// @nodoc
class __$CustomTargetsResponseCopyWithImpl<$Res>
    implements _$CustomTargetsResponseCopyWith<$Res> {
  __$CustomTargetsResponseCopyWithImpl(this._self, this._then);

  final _CustomTargetsResponse _self;
  final $Res Function(_CustomTargetsResponse) _then;

  /// Create a copy of CustomTargetsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? targets = null,
    Object? warnings = null,
  }) {
    return _then(_CustomTargetsResponse(
      targets: null == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as NutritionTargets,
      warnings: null == warnings
          ? _self._warnings
          : warnings // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }

  /// Create a copy of CustomTargetsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<$Res> get targets {
    return $NutritionTargetsCopyWith<$Res>(_self.targets, (value) {
      return _then(_self.copyWith(targets: value));
    });
  }
}

/// @nodoc
mixin _$GoalResponse {
  Goal get goal;
  NutritionTargets? get targets;

  /// Create a copy of GoalResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GoalResponseCopyWith<GoalResponse> get copyWith =>
      _$GoalResponseCopyWithImpl<GoalResponse>(
          this as GoalResponse, _$identity);

  /// Serializes this GoalResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GoalResponse &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.targets, targets) || other.targets == targets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, goal, targets);

  @override
  String toString() {
    return 'GoalResponse(goal: $goal, targets: $targets)';
  }
}

/// @nodoc
abstract mixin class $GoalResponseCopyWith<$Res> {
  factory $GoalResponseCopyWith(
          GoalResponse value, $Res Function(GoalResponse) _then) =
      _$GoalResponseCopyWithImpl;
  @useResult
  $Res call({Goal goal, NutritionTargets? targets});

  $GoalCopyWith<$Res> get goal;
  $NutritionTargetsCopyWith<$Res>? get targets;
}

/// @nodoc
class _$GoalResponseCopyWithImpl<$Res> implements $GoalResponseCopyWith<$Res> {
  _$GoalResponseCopyWithImpl(this._self, this._then);

  final GoalResponse _self;
  final $Res Function(GoalResponse) _then;

  /// Create a copy of GoalResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goal = null,
    Object? targets = freezed,
  }) {
    return _then(_self.copyWith(
      goal: null == goal
          ? _self.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as Goal,
      targets: freezed == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as NutritionTargets?,
    ));
  }

  /// Create a copy of GoalResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GoalCopyWith<$Res> get goal {
    return $GoalCopyWith<$Res>(_self.goal, (value) {
      return _then(_self.copyWith(goal: value));
    });
  }

  /// Create a copy of GoalResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<$Res>? get targets {
    if (_self.targets == null) {
      return null;
    }

    return $NutritionTargetsCopyWith<$Res>(_self.targets!, (value) {
      return _then(_self.copyWith(targets: value));
    });
  }
}

/// Adds pattern-matching-related methods to [GoalResponse].
extension GoalResponsePatterns on GoalResponse {
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
    TResult Function(_GoalResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GoalResponse() when $default != null:
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
    TResult Function(_GoalResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GoalResponse():
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
    TResult? Function(_GoalResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GoalResponse() when $default != null:
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
    TResult Function(Goal goal, NutritionTargets? targets)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GoalResponse() when $default != null:
        return $default(_that.goal, _that.targets);
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
    TResult Function(Goal goal, NutritionTargets? targets) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GoalResponse():
        return $default(_that.goal, _that.targets);
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
    TResult? Function(Goal goal, NutritionTargets? targets)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GoalResponse() when $default != null:
        return $default(_that.goal, _that.targets);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _GoalResponse implements GoalResponse {
  const _GoalResponse({required this.goal, required this.targets});
  factory _GoalResponse.fromJson(Map<String, dynamic> json) =>
      _$GoalResponseFromJson(json);

  @override
  final Goal goal;
  @override
  final NutritionTargets? targets;

  /// Create a copy of GoalResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GoalResponseCopyWith<_GoalResponse> get copyWith =>
      __$GoalResponseCopyWithImpl<_GoalResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GoalResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GoalResponse &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.targets, targets) || other.targets == targets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, goal, targets);

  @override
  String toString() {
    return 'GoalResponse(goal: $goal, targets: $targets)';
  }
}

/// @nodoc
abstract mixin class _$GoalResponseCopyWith<$Res>
    implements $GoalResponseCopyWith<$Res> {
  factory _$GoalResponseCopyWith(
          _GoalResponse value, $Res Function(_GoalResponse) _then) =
      __$GoalResponseCopyWithImpl;
  @override
  @useResult
  $Res call({Goal goal, NutritionTargets? targets});

  @override
  $GoalCopyWith<$Res> get goal;
  @override
  $NutritionTargetsCopyWith<$Res>? get targets;
}

/// @nodoc
class __$GoalResponseCopyWithImpl<$Res>
    implements _$GoalResponseCopyWith<$Res> {
  __$GoalResponseCopyWithImpl(this._self, this._then);

  final _GoalResponse _self;
  final $Res Function(_GoalResponse) _then;

  /// Create a copy of GoalResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? goal = null,
    Object? targets = freezed,
  }) {
    return _then(_GoalResponse(
      goal: null == goal
          ? _self.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as Goal,
      targets: freezed == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as NutritionTargets?,
    ));
  }

  /// Create a copy of GoalResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GoalCopyWith<$Res> get goal {
    return $GoalCopyWith<$Res>(_self.goal, (value) {
      return _then(_self.copyWith(goal: value));
    });
  }

  /// Create a copy of GoalResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTargetsCopyWith<$Res>? get targets {
    if (_self.targets == null) {
      return null;
    }

    return $NutritionTargetsCopyWith<$Res>(_self.targets!, (value) {
      return _then(_self.copyWith(targets: value));
    });
  }
}

/// @nodoc
mixin _$PutGoalRequest {
  GoalType get goalType;
  double? get targetWeightKg;

  /// Create a copy of PutGoalRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PutGoalRequestCopyWith<PutGoalRequest> get copyWith =>
      _$PutGoalRequestCopyWithImpl<PutGoalRequest>(
          this as PutGoalRequest, _$identity);

  /// Serializes this PutGoalRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PutGoalRequest &&
            (identical(other.goalType, goalType) ||
                other.goalType == goalType) &&
            (identical(other.targetWeightKg, targetWeightKg) ||
                other.targetWeightKg == targetWeightKg));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, goalType, targetWeightKg);

  @override
  String toString() {
    return 'PutGoalRequest(goalType: $goalType, targetWeightKg: $targetWeightKg)';
  }
}

/// @nodoc
abstract mixin class $PutGoalRequestCopyWith<$Res> {
  factory $PutGoalRequestCopyWith(
          PutGoalRequest value, $Res Function(PutGoalRequest) _then) =
      _$PutGoalRequestCopyWithImpl;
  @useResult
  $Res call({GoalType goalType, double? targetWeightKg});
}

/// @nodoc
class _$PutGoalRequestCopyWithImpl<$Res>
    implements $PutGoalRequestCopyWith<$Res> {
  _$PutGoalRequestCopyWithImpl(this._self, this._then);

  final PutGoalRequest _self;
  final $Res Function(PutGoalRequest) _then;

  /// Create a copy of PutGoalRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalType = null,
    Object? targetWeightKg = freezed,
  }) {
    return _then(_self.copyWith(
      goalType: null == goalType
          ? _self.goalType
          : goalType // ignore: cast_nullable_to_non_nullable
              as GoalType,
      targetWeightKg: freezed == targetWeightKg
          ? _self.targetWeightKg
          : targetWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PutGoalRequest].
extension PutGoalRequestPatterns on PutGoalRequest {
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
    TResult Function(_PutGoalRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PutGoalRequest() when $default != null:
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
    TResult Function(_PutGoalRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PutGoalRequest():
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
    TResult? Function(_PutGoalRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PutGoalRequest() when $default != null:
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
    TResult Function(GoalType goalType, double? targetWeightKg)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PutGoalRequest() when $default != null:
        return $default(_that.goalType, _that.targetWeightKg);
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
    TResult Function(GoalType goalType, double? targetWeightKg) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PutGoalRequest():
        return $default(_that.goalType, _that.targetWeightKg);
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
    TResult? Function(GoalType goalType, double? targetWeightKg)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PutGoalRequest() when $default != null:
        return $default(_that.goalType, _that.targetWeightKg);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PutGoalRequest implements PutGoalRequest {
  const _PutGoalRequest({required this.goalType, this.targetWeightKg});
  factory _PutGoalRequest.fromJson(Map<String, dynamic> json) =>
      _$PutGoalRequestFromJson(json);

  @override
  final GoalType goalType;
  @override
  final double? targetWeightKg;

  /// Create a copy of PutGoalRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PutGoalRequestCopyWith<_PutGoalRequest> get copyWith =>
      __$PutGoalRequestCopyWithImpl<_PutGoalRequest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PutGoalRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PutGoalRequest &&
            (identical(other.goalType, goalType) ||
                other.goalType == goalType) &&
            (identical(other.targetWeightKg, targetWeightKg) ||
                other.targetWeightKg == targetWeightKg));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, goalType, targetWeightKg);

  @override
  String toString() {
    return 'PutGoalRequest(goalType: $goalType, targetWeightKg: $targetWeightKg)';
  }
}

/// @nodoc
abstract mixin class _$PutGoalRequestCopyWith<$Res>
    implements $PutGoalRequestCopyWith<$Res> {
  factory _$PutGoalRequestCopyWith(
          _PutGoalRequest value, $Res Function(_PutGoalRequest) _then) =
      __$PutGoalRequestCopyWithImpl;
  @override
  @useResult
  $Res call({GoalType goalType, double? targetWeightKg});
}

/// @nodoc
class __$PutGoalRequestCopyWithImpl<$Res>
    implements _$PutGoalRequestCopyWith<$Res> {
  __$PutGoalRequestCopyWithImpl(this._self, this._then);

  final _PutGoalRequest _self;
  final $Res Function(_PutGoalRequest) _then;

  /// Create a copy of PutGoalRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? goalType = null,
    Object? targetWeightKg = freezed,
  }) {
    return _then(_PutGoalRequest(
      goalType: null == goalType
          ? _self.goalType
          : goalType // ignore: cast_nullable_to_non_nullable
              as GoalType,
      targetWeightKg: freezed == targetWeightKg
          ? _self.targetWeightKg
          : targetWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

// dart format on
