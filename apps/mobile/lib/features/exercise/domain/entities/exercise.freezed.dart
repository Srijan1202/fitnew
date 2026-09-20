// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exercise.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExerciseSummary {
  String get id;
  String get slug;
  String get name;
  MovementPattern get movementPattern;
  List<Equipment> get equipment;
  Difficulty get difficulty;
  bool get isUnilateral;
  List<MuscleGroup> get primaryMuscles;

  /// Create a copy of ExerciseSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExerciseSummaryCopyWith<ExerciseSummary> get copyWith =>
      _$ExerciseSummaryCopyWithImpl<ExerciseSummary>(
          this as ExerciseSummary, _$identity);

  /// Serializes this ExerciseSummary to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExerciseSummary &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.movementPattern, movementPattern) ||
                other.movementPattern == movementPattern) &&
            const DeepCollectionEquality().equals(other.equipment, equipment) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.isUnilateral, isUnilateral) ||
                other.isUnilateral == isUnilateral) &&
            const DeepCollectionEquality()
                .equals(other.primaryMuscles, primaryMuscles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(equipment),
      difficulty,
      isUnilateral,
      const DeepCollectionEquality().hash(primaryMuscles));

  @override
  String toString() {
    return 'ExerciseSummary(id: $id, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, isUnilateral: $isUnilateral, primaryMuscles: $primaryMuscles)';
  }
}

/// @nodoc
abstract mixin class $ExerciseSummaryCopyWith<$Res> {
  factory $ExerciseSummaryCopyWith(
          ExerciseSummary value, $Res Function(ExerciseSummary) _then) =
      _$ExerciseSummaryCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      bool isUnilateral,
      List<MuscleGroup> primaryMuscles});
}

/// @nodoc
class _$ExerciseSummaryCopyWithImpl<$Res>
    implements $ExerciseSummaryCopyWith<$Res> {
  _$ExerciseSummaryCopyWithImpl(this._self, this._then);

  final ExerciseSummary _self;
  final $Res Function(ExerciseSummary) _then;

  /// Create a copy of ExerciseSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? isUnilateral = null,
    Object? primaryMuscles = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      movementPattern: null == movementPattern
          ? _self.movementPattern
          : movementPattern // ignore: cast_nullable_to_non_nullable
              as MovementPattern,
      equipment: null == equipment
          ? _self.equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      difficulty: null == difficulty
          ? _self.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as Difficulty,
      isUnilateral: null == isUnilateral
          ? _self.isUnilateral
          : isUnilateral // ignore: cast_nullable_to_non_nullable
              as bool,
      primaryMuscles: null == primaryMuscles
          ? _self.primaryMuscles
          : primaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ExerciseSummary].
extension ExerciseSummaryPatterns on ExerciseSummary {
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
    TResult Function(_ExerciseSummary value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseSummary() when $default != null:
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
    TResult Function(_ExerciseSummary value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseSummary():
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
    TResult? Function(_ExerciseSummary value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseSummary() when $default != null:
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
            String id,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseSummary() when $default != null:
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles);
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
            String id,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseSummary():
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles);
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
            String id,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseSummary() when $default != null:
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ExerciseSummary implements ExerciseSummary {
  const _ExerciseSummary(
      {required this.id,
      required this.slug,
      required this.name,
      required this.movementPattern,
      required final List<Equipment> equipment,
      required this.difficulty,
      required this.isUnilateral,
      required final List<MuscleGroup> primaryMuscles})
      : _equipment = equipment,
        _primaryMuscles = primaryMuscles;
  factory _ExerciseSummary.fromJson(Map<String, dynamic> json) =>
      _$ExerciseSummaryFromJson(json);

  @override
  final String id;
  @override
  final String slug;
  @override
  final String name;
  @override
  final MovementPattern movementPattern;
  final List<Equipment> _equipment;
  @override
  List<Equipment> get equipment {
    if (_equipment is EqualUnmodifiableListView) return _equipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_equipment);
  }

  @override
  final Difficulty difficulty;
  @override
  final bool isUnilateral;
  final List<MuscleGroup> _primaryMuscles;
  @override
  List<MuscleGroup> get primaryMuscles {
    if (_primaryMuscles is EqualUnmodifiableListView) return _primaryMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_primaryMuscles);
  }

  /// Create a copy of ExerciseSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExerciseSummaryCopyWith<_ExerciseSummary> get copyWith =>
      __$ExerciseSummaryCopyWithImpl<_ExerciseSummary>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExerciseSummaryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExerciseSummary &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.movementPattern, movementPattern) ||
                other.movementPattern == movementPattern) &&
            const DeepCollectionEquality()
                .equals(other._equipment, _equipment) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.isUnilateral, isUnilateral) ||
                other.isUnilateral == isUnilateral) &&
            const DeepCollectionEquality()
                .equals(other._primaryMuscles, _primaryMuscles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(_equipment),
      difficulty,
      isUnilateral,
      const DeepCollectionEquality().hash(_primaryMuscles));

  @override
  String toString() {
    return 'ExerciseSummary(id: $id, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, isUnilateral: $isUnilateral, primaryMuscles: $primaryMuscles)';
  }
}

/// @nodoc
abstract mixin class _$ExerciseSummaryCopyWith<$Res>
    implements $ExerciseSummaryCopyWith<$Res> {
  factory _$ExerciseSummaryCopyWith(
          _ExerciseSummary value, $Res Function(_ExerciseSummary) _then) =
      __$ExerciseSummaryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      bool isUnilateral,
      List<MuscleGroup> primaryMuscles});
}

/// @nodoc
class __$ExerciseSummaryCopyWithImpl<$Res>
    implements _$ExerciseSummaryCopyWith<$Res> {
  __$ExerciseSummaryCopyWithImpl(this._self, this._then);

  final _ExerciseSummary _self;
  final $Res Function(_ExerciseSummary) _then;

  /// Create a copy of ExerciseSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? isUnilateral = null,
    Object? primaryMuscles = null,
  }) {
    return _then(_ExerciseSummary(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      movementPattern: null == movementPattern
          ? _self.movementPattern
          : movementPattern // ignore: cast_nullable_to_non_nullable
              as MovementPattern,
      equipment: null == equipment
          ? _self._equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      difficulty: null == difficulty
          ? _self.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as Difficulty,
      isUnilateral: null == isUnilateral
          ? _self.isUnilateral
          : isUnilateral // ignore: cast_nullable_to_non_nullable
              as bool,
      primaryMuscles: null == primaryMuscles
          ? _self._primaryMuscles
          : primaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
    ));
  }
}

/// @nodoc
mixin _$ExerciseMuscle {
  MuscleGroup get muscleGroup;
  MuscleRole get role;
  double get contribution;

  /// Create a copy of ExerciseMuscle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExerciseMuscleCopyWith<ExerciseMuscle> get copyWith =>
      _$ExerciseMuscleCopyWithImpl<ExerciseMuscle>(
          this as ExerciseMuscle, _$identity);

  /// Serializes this ExerciseMuscle to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExerciseMuscle &&
            (identical(other.muscleGroup, muscleGroup) ||
                other.muscleGroup == muscleGroup) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.contribution, contribution) ||
                other.contribution == contribution));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, muscleGroup, role, contribution);

  @override
  String toString() {
    return 'ExerciseMuscle(muscleGroup: $muscleGroup, role: $role, contribution: $contribution)';
  }
}

/// @nodoc
abstract mixin class $ExerciseMuscleCopyWith<$Res> {
  factory $ExerciseMuscleCopyWith(
          ExerciseMuscle value, $Res Function(ExerciseMuscle) _then) =
      _$ExerciseMuscleCopyWithImpl;
  @useResult
  $Res call({MuscleGroup muscleGroup, MuscleRole role, double contribution});
}

/// @nodoc
class _$ExerciseMuscleCopyWithImpl<$Res>
    implements $ExerciseMuscleCopyWith<$Res> {
  _$ExerciseMuscleCopyWithImpl(this._self, this._then);

  final ExerciseMuscle _self;
  final $Res Function(ExerciseMuscle) _then;

  /// Create a copy of ExerciseMuscle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? muscleGroup = null,
    Object? role = null,
    Object? contribution = null,
  }) {
    return _then(_self.copyWith(
      muscleGroup: null == muscleGroup
          ? _self.muscleGroup
          : muscleGroup // ignore: cast_nullable_to_non_nullable
              as MuscleGroup,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MuscleRole,
      contribution: null == contribution
          ? _self.contribution
          : contribution // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [ExerciseMuscle].
extension ExerciseMusclePatterns on ExerciseMuscle {
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
    TResult Function(_ExerciseMuscle value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseMuscle() when $default != null:
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
    TResult Function(_ExerciseMuscle value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseMuscle():
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
    TResult? Function(_ExerciseMuscle value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseMuscle() when $default != null:
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
            MuscleGroup muscleGroup, MuscleRole role, double contribution)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseMuscle() when $default != null:
        return $default(_that.muscleGroup, _that.role, _that.contribution);
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
            MuscleGroup muscleGroup, MuscleRole role, double contribution)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseMuscle():
        return $default(_that.muscleGroup, _that.role, _that.contribution);
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
            MuscleGroup muscleGroup, MuscleRole role, double contribution)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseMuscle() when $default != null:
        return $default(_that.muscleGroup, _that.role, _that.contribution);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ExerciseMuscle implements ExerciseMuscle {
  const _ExerciseMuscle(
      {required this.muscleGroup,
      required this.role,
      required this.contribution});
  factory _ExerciseMuscle.fromJson(Map<String, dynamic> json) =>
      _$ExerciseMuscleFromJson(json);

  @override
  final MuscleGroup muscleGroup;
  @override
  final MuscleRole role;
  @override
  final double contribution;

  /// Create a copy of ExerciseMuscle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExerciseMuscleCopyWith<_ExerciseMuscle> get copyWith =>
      __$ExerciseMuscleCopyWithImpl<_ExerciseMuscle>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExerciseMuscleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExerciseMuscle &&
            (identical(other.muscleGroup, muscleGroup) ||
                other.muscleGroup == muscleGroup) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.contribution, contribution) ||
                other.contribution == contribution));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, muscleGroup, role, contribution);

  @override
  String toString() {
    return 'ExerciseMuscle(muscleGroup: $muscleGroup, role: $role, contribution: $contribution)';
  }
}

/// @nodoc
abstract mixin class _$ExerciseMuscleCopyWith<$Res>
    implements $ExerciseMuscleCopyWith<$Res> {
  factory _$ExerciseMuscleCopyWith(
          _ExerciseMuscle value, $Res Function(_ExerciseMuscle) _then) =
      __$ExerciseMuscleCopyWithImpl;
  @override
  @useResult
  $Res call({MuscleGroup muscleGroup, MuscleRole role, double contribution});
}

/// @nodoc
class __$ExerciseMuscleCopyWithImpl<$Res>
    implements _$ExerciseMuscleCopyWith<$Res> {
  __$ExerciseMuscleCopyWithImpl(this._self, this._then);

  final _ExerciseMuscle _self;
  final $Res Function(_ExerciseMuscle) _then;

  /// Create a copy of ExerciseMuscle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? muscleGroup = null,
    Object? role = null,
    Object? contribution = null,
  }) {
    return _then(_ExerciseMuscle(
      muscleGroup: null == muscleGroup
          ? _self.muscleGroup
          : muscleGroup // ignore: cast_nullable_to_non_nullable
              as MuscleGroup,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MuscleRole,
      contribution: null == contribution
          ? _self.contribution
          : contribution // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$ExerciseAlternative {
  String get id;
  String get slug;
  String get name;
  AlternativeReason get reason;
  List<Equipment> get equipment;

  /// Create a copy of ExerciseAlternative
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExerciseAlternativeCopyWith<ExerciseAlternative> get copyWith =>
      _$ExerciseAlternativeCopyWithImpl<ExerciseAlternative>(
          this as ExerciseAlternative, _$identity);

  /// Serializes this ExerciseAlternative to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExerciseAlternative &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            const DeepCollectionEquality().equals(other.equipment, equipment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, slug, name, reason,
      const DeepCollectionEquality().hash(equipment));

  @override
  String toString() {
    return 'ExerciseAlternative(id: $id, slug: $slug, name: $name, reason: $reason, equipment: $equipment)';
  }
}

/// @nodoc
abstract mixin class $ExerciseAlternativeCopyWith<$Res> {
  factory $ExerciseAlternativeCopyWith(
          ExerciseAlternative value, $Res Function(ExerciseAlternative) _then) =
      _$ExerciseAlternativeCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String slug,
      String name,
      AlternativeReason reason,
      List<Equipment> equipment});
}

/// @nodoc
class _$ExerciseAlternativeCopyWithImpl<$Res>
    implements $ExerciseAlternativeCopyWith<$Res> {
  _$ExerciseAlternativeCopyWithImpl(this._self, this._then);

  final ExerciseAlternative _self;
  final $Res Function(ExerciseAlternative) _then;

  /// Create a copy of ExerciseAlternative
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? name = null,
    Object? reason = null,
    Object? equipment = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as AlternativeReason,
      equipment: null == equipment
          ? _self.equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ExerciseAlternative].
extension ExerciseAlternativePatterns on ExerciseAlternative {
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
    TResult Function(_ExerciseAlternative value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseAlternative() when $default != null:
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
    TResult Function(_ExerciseAlternative value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseAlternative():
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
    TResult? Function(_ExerciseAlternative value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseAlternative() when $default != null:
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
    TResult Function(String id, String slug, String name,
            AlternativeReason reason, List<Equipment> equipment)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseAlternative() when $default != null:
        return $default(
            _that.id, _that.slug, _that.name, _that.reason, _that.equipment);
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
    TResult Function(String id, String slug, String name,
            AlternativeReason reason, List<Equipment> equipment)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseAlternative():
        return $default(
            _that.id, _that.slug, _that.name, _that.reason, _that.equipment);
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
    TResult? Function(String id, String slug, String name,
            AlternativeReason reason, List<Equipment> equipment)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseAlternative() when $default != null:
        return $default(
            _that.id, _that.slug, _that.name, _that.reason, _that.equipment);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ExerciseAlternative implements ExerciseAlternative {
  const _ExerciseAlternative(
      {required this.id,
      required this.slug,
      required this.name,
      required this.reason,
      required final List<Equipment> equipment})
      : _equipment = equipment;
  factory _ExerciseAlternative.fromJson(Map<String, dynamic> json) =>
      _$ExerciseAlternativeFromJson(json);

  @override
  final String id;
  @override
  final String slug;
  @override
  final String name;
  @override
  final AlternativeReason reason;
  final List<Equipment> _equipment;
  @override
  List<Equipment> get equipment {
    if (_equipment is EqualUnmodifiableListView) return _equipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_equipment);
  }

  /// Create a copy of ExerciseAlternative
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExerciseAlternativeCopyWith<_ExerciseAlternative> get copyWith =>
      __$ExerciseAlternativeCopyWithImpl<_ExerciseAlternative>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExerciseAlternativeToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExerciseAlternative &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            const DeepCollectionEquality()
                .equals(other._equipment, _equipment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, slug, name, reason,
      const DeepCollectionEquality().hash(_equipment));

  @override
  String toString() {
    return 'ExerciseAlternative(id: $id, slug: $slug, name: $name, reason: $reason, equipment: $equipment)';
  }
}

/// @nodoc
abstract mixin class _$ExerciseAlternativeCopyWith<$Res>
    implements $ExerciseAlternativeCopyWith<$Res> {
  factory _$ExerciseAlternativeCopyWith(_ExerciseAlternative value,
          $Res Function(_ExerciseAlternative) _then) =
      __$ExerciseAlternativeCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String slug,
      String name,
      AlternativeReason reason,
      List<Equipment> equipment});
}

/// @nodoc
class __$ExerciseAlternativeCopyWithImpl<$Res>
    implements _$ExerciseAlternativeCopyWith<$Res> {
  __$ExerciseAlternativeCopyWithImpl(this._self, this._then);

  final _ExerciseAlternative _self;
  final $Res Function(_ExerciseAlternative) _then;

  /// Create a copy of ExerciseAlternative
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? name = null,
    Object? reason = null,
    Object? equipment = null,
  }) {
    return _then(_ExerciseAlternative(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as AlternativeReason,
      equipment: null == equipment
          ? _self._equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
    ));
  }
}

/// @nodoc
mixin _$ExerciseDetail {
  String get id;
  String get slug;
  String get name;
  MovementPattern get movementPattern;
  List<Equipment> get equipment;
  Difficulty get difficulty;
  bool get isUnilateral;
  List<MuscleGroup> get primaryMuscles;
  double get defaultIncrementKg;
  List<String> get instructions;
  String? get videoUrl;
  List<ExerciseMuscle> get muscles;
  List<ExerciseAlternative> get alternatives;
  List<BodyPart> get contraindications;

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExerciseDetailCopyWith<ExerciseDetail> get copyWith =>
      _$ExerciseDetailCopyWithImpl<ExerciseDetail>(
          this as ExerciseDetail, _$identity);

  /// Serializes this ExerciseDetail to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExerciseDetail &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.movementPattern, movementPattern) ||
                other.movementPattern == movementPattern) &&
            const DeepCollectionEquality().equals(other.equipment, equipment) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.isUnilateral, isUnilateral) ||
                other.isUnilateral == isUnilateral) &&
            const DeepCollectionEquality()
                .equals(other.primaryMuscles, primaryMuscles) &&
            (identical(other.defaultIncrementKg, defaultIncrementKg) ||
                other.defaultIncrementKg == defaultIncrementKg) &&
            const DeepCollectionEquality()
                .equals(other.instructions, instructions) &&
            (identical(other.videoUrl, videoUrl) ||
                other.videoUrl == videoUrl) &&
            const DeepCollectionEquality().equals(other.muscles, muscles) &&
            const DeepCollectionEquality()
                .equals(other.alternatives, alternatives) &&
            const DeepCollectionEquality()
                .equals(other.contraindications, contraindications));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(equipment),
      difficulty,
      isUnilateral,
      const DeepCollectionEquality().hash(primaryMuscles),
      defaultIncrementKg,
      const DeepCollectionEquality().hash(instructions),
      videoUrl,
      const DeepCollectionEquality().hash(muscles),
      const DeepCollectionEquality().hash(alternatives),
      const DeepCollectionEquality().hash(contraindications));

  @override
  String toString() {
    return 'ExerciseDetail(id: $id, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, isUnilateral: $isUnilateral, primaryMuscles: $primaryMuscles, defaultIncrementKg: $defaultIncrementKg, instructions: $instructions, videoUrl: $videoUrl, muscles: $muscles, alternatives: $alternatives, contraindications: $contraindications)';
  }
}

/// @nodoc
abstract mixin class $ExerciseDetailCopyWith<$Res> {
  factory $ExerciseDetailCopyWith(
          ExerciseDetail value, $Res Function(ExerciseDetail) _then) =
      _$ExerciseDetailCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      bool isUnilateral,
      List<MuscleGroup> primaryMuscles,
      double defaultIncrementKg,
      List<String> instructions,
      String? videoUrl,
      List<ExerciseMuscle> muscles,
      List<ExerciseAlternative> alternatives,
      List<BodyPart> contraindications});
}

/// @nodoc
class _$ExerciseDetailCopyWithImpl<$Res>
    implements $ExerciseDetailCopyWith<$Res> {
  _$ExerciseDetailCopyWithImpl(this._self, this._then);

  final ExerciseDetail _self;
  final $Res Function(ExerciseDetail) _then;

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? isUnilateral = null,
    Object? primaryMuscles = null,
    Object? defaultIncrementKg = null,
    Object? instructions = null,
    Object? videoUrl = freezed,
    Object? muscles = null,
    Object? alternatives = null,
    Object? contraindications = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      movementPattern: null == movementPattern
          ? _self.movementPattern
          : movementPattern // ignore: cast_nullable_to_non_nullable
              as MovementPattern,
      equipment: null == equipment
          ? _self.equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      difficulty: null == difficulty
          ? _self.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as Difficulty,
      isUnilateral: null == isUnilateral
          ? _self.isUnilateral
          : isUnilateral // ignore: cast_nullable_to_non_nullable
              as bool,
      primaryMuscles: null == primaryMuscles
          ? _self.primaryMuscles
          : primaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      defaultIncrementKg: null == defaultIncrementKg
          ? _self.defaultIncrementKg
          : defaultIncrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      instructions: null == instructions
          ? _self.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      videoUrl: freezed == videoUrl
          ? _self.videoUrl
          : videoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      muscles: null == muscles
          ? _self.muscles
          : muscles // ignore: cast_nullable_to_non_nullable
              as List<ExerciseMuscle>,
      alternatives: null == alternatives
          ? _self.alternatives
          : alternatives // ignore: cast_nullable_to_non_nullable
              as List<ExerciseAlternative>,
      contraindications: null == contraindications
          ? _self.contraindications
          : contraindications // ignore: cast_nullable_to_non_nullable
              as List<BodyPart>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ExerciseDetail].
extension ExerciseDetailPatterns on ExerciseDetail {
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
    TResult Function(_ExerciseDetail value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseDetail() when $default != null:
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
    TResult Function(_ExerciseDetail value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseDetail():
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
    TResult? Function(_ExerciseDetail value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseDetail() when $default != null:
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
            String id,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            double defaultIncrementKg,
            List<String> instructions,
            String? videoUrl,
            List<ExerciseMuscle> muscles,
            List<ExerciseAlternative> alternatives,
            List<BodyPart> contraindications)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseDetail() when $default != null:
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.defaultIncrementKg,
            _that.instructions,
            _that.videoUrl,
            _that.muscles,
            _that.alternatives,
            _that.contraindications);
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
            String id,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            double defaultIncrementKg,
            List<String> instructions,
            String? videoUrl,
            List<ExerciseMuscle> muscles,
            List<ExerciseAlternative> alternatives,
            List<BodyPart> contraindications)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseDetail():
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.defaultIncrementKg,
            _that.instructions,
            _that.videoUrl,
            _that.muscles,
            _that.alternatives,
            _that.contraindications);
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
            String id,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            double defaultIncrementKg,
            List<String> instructions,
            String? videoUrl,
            List<ExerciseMuscle> muscles,
            List<ExerciseAlternative> alternatives,
            List<BodyPart> contraindications)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseDetail() when $default != null:
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.defaultIncrementKg,
            _that.instructions,
            _that.videoUrl,
            _that.muscles,
            _that.alternatives,
            _that.contraindications);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ExerciseDetail implements ExerciseDetail {
  const _ExerciseDetail(
      {required this.id,
      required this.slug,
      required this.name,
      required this.movementPattern,
      required final List<Equipment> equipment,
      required this.difficulty,
      required this.isUnilateral,
      required final List<MuscleGroup> primaryMuscles,
      required this.defaultIncrementKg,
      required final List<String> instructions,
      required this.videoUrl,
      required final List<ExerciseMuscle> muscles,
      required final List<ExerciseAlternative> alternatives,
      required final List<BodyPart> contraindications})
      : _equipment = equipment,
        _primaryMuscles = primaryMuscles,
        _instructions = instructions,
        _muscles = muscles,
        _alternatives = alternatives,
        _contraindications = contraindications;
  factory _ExerciseDetail.fromJson(Map<String, dynamic> json) =>
      _$ExerciseDetailFromJson(json);

  @override
  final String id;
  @override
  final String slug;
  @override
  final String name;
  @override
  final MovementPattern movementPattern;
  final List<Equipment> _equipment;
  @override
  List<Equipment> get equipment {
    if (_equipment is EqualUnmodifiableListView) return _equipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_equipment);
  }

  @override
  final Difficulty difficulty;
  @override
  final bool isUnilateral;
  final List<MuscleGroup> _primaryMuscles;
  @override
  List<MuscleGroup> get primaryMuscles {
    if (_primaryMuscles is EqualUnmodifiableListView) return _primaryMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_primaryMuscles);
  }

  @override
  final double defaultIncrementKg;
  final List<String> _instructions;
  @override
  List<String> get instructions {
    if (_instructions is EqualUnmodifiableListView) return _instructions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_instructions);
  }

  @override
  final String? videoUrl;
  final List<ExerciseMuscle> _muscles;
  @override
  List<ExerciseMuscle> get muscles {
    if (_muscles is EqualUnmodifiableListView) return _muscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_muscles);
  }

  final List<ExerciseAlternative> _alternatives;
  @override
  List<ExerciseAlternative> get alternatives {
    if (_alternatives is EqualUnmodifiableListView) return _alternatives;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_alternatives);
  }

  final List<BodyPart> _contraindications;
  @override
  List<BodyPart> get contraindications {
    if (_contraindications is EqualUnmodifiableListView)
      return _contraindications;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_contraindications);
  }

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExerciseDetailCopyWith<_ExerciseDetail> get copyWith =>
      __$ExerciseDetailCopyWithImpl<_ExerciseDetail>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExerciseDetailToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExerciseDetail &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.movementPattern, movementPattern) ||
                other.movementPattern == movementPattern) &&
            const DeepCollectionEquality()
                .equals(other._equipment, _equipment) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.isUnilateral, isUnilateral) ||
                other.isUnilateral == isUnilateral) &&
            const DeepCollectionEquality()
                .equals(other._primaryMuscles, _primaryMuscles) &&
            (identical(other.defaultIncrementKg, defaultIncrementKg) ||
                other.defaultIncrementKg == defaultIncrementKg) &&
            const DeepCollectionEquality()
                .equals(other._instructions, _instructions) &&
            (identical(other.videoUrl, videoUrl) ||
                other.videoUrl == videoUrl) &&
            const DeepCollectionEquality().equals(other._muscles, _muscles) &&
            const DeepCollectionEquality()
                .equals(other._alternatives, _alternatives) &&
            const DeepCollectionEquality()
                .equals(other._contraindications, _contraindications));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(_equipment),
      difficulty,
      isUnilateral,
      const DeepCollectionEquality().hash(_primaryMuscles),
      defaultIncrementKg,
      const DeepCollectionEquality().hash(_instructions),
      videoUrl,
      const DeepCollectionEquality().hash(_muscles),
      const DeepCollectionEquality().hash(_alternatives),
      const DeepCollectionEquality().hash(_contraindications));

  @override
  String toString() {
    return 'ExerciseDetail(id: $id, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, isUnilateral: $isUnilateral, primaryMuscles: $primaryMuscles, defaultIncrementKg: $defaultIncrementKg, instructions: $instructions, videoUrl: $videoUrl, muscles: $muscles, alternatives: $alternatives, contraindications: $contraindications)';
  }
}

/// @nodoc
abstract mixin class _$ExerciseDetailCopyWith<$Res>
    implements $ExerciseDetailCopyWith<$Res> {
  factory _$ExerciseDetailCopyWith(
          _ExerciseDetail value, $Res Function(_ExerciseDetail) _then) =
      __$ExerciseDetailCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      bool isUnilateral,
      List<MuscleGroup> primaryMuscles,
      double defaultIncrementKg,
      List<String> instructions,
      String? videoUrl,
      List<ExerciseMuscle> muscles,
      List<ExerciseAlternative> alternatives,
      List<BodyPart> contraindications});
}

/// @nodoc
class __$ExerciseDetailCopyWithImpl<$Res>
    implements _$ExerciseDetailCopyWith<$Res> {
  __$ExerciseDetailCopyWithImpl(this._self, this._then);

  final _ExerciseDetail _self;
  final $Res Function(_ExerciseDetail) _then;

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? isUnilateral = null,
    Object? primaryMuscles = null,
    Object? defaultIncrementKg = null,
    Object? instructions = null,
    Object? videoUrl = freezed,
    Object? muscles = null,
    Object? alternatives = null,
    Object? contraindications = null,
  }) {
    return _then(_ExerciseDetail(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      movementPattern: null == movementPattern
          ? _self.movementPattern
          : movementPattern // ignore: cast_nullable_to_non_nullable
              as MovementPattern,
      equipment: null == equipment
          ? _self._equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      difficulty: null == difficulty
          ? _self.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as Difficulty,
      isUnilateral: null == isUnilateral
          ? _self.isUnilateral
          : isUnilateral // ignore: cast_nullable_to_non_nullable
              as bool,
      primaryMuscles: null == primaryMuscles
          ? _self._primaryMuscles
          : primaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      defaultIncrementKg: null == defaultIncrementKg
          ? _self.defaultIncrementKg
          : defaultIncrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      instructions: null == instructions
          ? _self._instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      videoUrl: freezed == videoUrl
          ? _self.videoUrl
          : videoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      muscles: null == muscles
          ? _self._muscles
          : muscles // ignore: cast_nullable_to_non_nullable
              as List<ExerciseMuscle>,
      alternatives: null == alternatives
          ? _self._alternatives
          : alternatives // ignore: cast_nullable_to_non_nullable
              as List<ExerciseAlternative>,
      contraindications: null == contraindications
          ? _self._contraindications
          : contraindications // ignore: cast_nullable_to_non_nullable
              as List<BodyPart>,
    ));
  }
}

/// @nodoc
mixin _$ExerciseListResponse {
  List<ExerciseSummary> get items;
  int get total;
  int get limit;
  int get offset;

  /// Create a copy of ExerciseListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExerciseListResponseCopyWith<ExerciseListResponse> get copyWith =>
      _$ExerciseListResponseCopyWithImpl<ExerciseListResponse>(
          this as ExerciseListResponse, _$identity);

  /// Serializes this ExerciseListResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExerciseListResponse &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(items), total, limit, offset);

  @override
  String toString() {
    return 'ExerciseListResponse(items: $items, total: $total, limit: $limit, offset: $offset)';
  }
}

/// @nodoc
abstract mixin class $ExerciseListResponseCopyWith<$Res> {
  factory $ExerciseListResponseCopyWith(ExerciseListResponse value,
          $Res Function(ExerciseListResponse) _then) =
      _$ExerciseListResponseCopyWithImpl;
  @useResult
  $Res call({List<ExerciseSummary> items, int total, int limit, int offset});
}

/// @nodoc
class _$ExerciseListResponseCopyWithImpl<$Res>
    implements $ExerciseListResponseCopyWith<$Res> {
  _$ExerciseListResponseCopyWithImpl(this._self, this._then);

  final ExerciseListResponse _self;
  final $Res Function(ExerciseListResponse) _then;

  /// Create a copy of ExerciseListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? total = null,
    Object? limit = null,
    Object? offset = null,
  }) {
    return _then(_self.copyWith(
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<ExerciseSummary>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      limit: null == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      offset: null == offset
          ? _self.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [ExerciseListResponse].
extension ExerciseListResponsePatterns on ExerciseListResponse {
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
    TResult Function(_ExerciseListResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseListResponse() when $default != null:
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
    TResult Function(_ExerciseListResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseListResponse():
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
    TResult? Function(_ExerciseListResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseListResponse() when $default != null:
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
            List<ExerciseSummary> items, int total, int limit, int offset)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseListResponse() when $default != null:
        return $default(_that.items, _that.total, _that.limit, _that.offset);
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
            List<ExerciseSummary> items, int total, int limit, int offset)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseListResponse():
        return $default(_that.items, _that.total, _that.limit, _that.offset);
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
            List<ExerciseSummary> items, int total, int limit, int offset)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseListResponse() when $default != null:
        return $default(_that.items, _that.total, _that.limit, _that.offset);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ExerciseListResponse implements ExerciseListResponse {
  const _ExerciseListResponse(
      {required final List<ExerciseSummary> items,
      required this.total,
      required this.limit,
      required this.offset})
      : _items = items;
  factory _ExerciseListResponse.fromJson(Map<String, dynamic> json) =>
      _$ExerciseListResponseFromJson(json);

  final List<ExerciseSummary> _items;
  @override
  List<ExerciseSummary> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final int total;
  @override
  final int limit;
  @override
  final int offset;

  /// Create a copy of ExerciseListResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExerciseListResponseCopyWith<_ExerciseListResponse> get copyWith =>
      __$ExerciseListResponseCopyWithImpl<_ExerciseListResponse>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExerciseListResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExerciseListResponse &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_items), total, limit, offset);

  @override
  String toString() {
    return 'ExerciseListResponse(items: $items, total: $total, limit: $limit, offset: $offset)';
  }
}

/// @nodoc
abstract mixin class _$ExerciseListResponseCopyWith<$Res>
    implements $ExerciseListResponseCopyWith<$Res> {
  factory _$ExerciseListResponseCopyWith(_ExerciseListResponse value,
          $Res Function(_ExerciseListResponse) _then) =
      __$ExerciseListResponseCopyWithImpl;
  @override
  @useResult
  $Res call({List<ExerciseSummary> items, int total, int limit, int offset});
}

/// @nodoc
class __$ExerciseListResponseCopyWithImpl<$Res>
    implements _$ExerciseListResponseCopyWith<$Res> {
  __$ExerciseListResponseCopyWithImpl(this._self, this._then);

  final _ExerciseListResponse _self;
  final $Res Function(_ExerciseListResponse) _then;

  /// Create a copy of ExerciseListResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
    Object? total = null,
    Object? limit = null,
    Object? offset = null,
  }) {
    return _then(_ExerciseListResponse(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<ExerciseSummary>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      limit: null == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      offset: null == offset
          ? _self.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$ExerciseQuery {
  String get q;
  Set<Equipment> get equipment;
  MuscleGroup? get muscle;
  MovementPattern? get pattern;
  int get limit;
  int get offset;

  /// Create a copy of ExerciseQuery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExerciseQueryCopyWith<ExerciseQuery> get copyWith =>
      _$ExerciseQueryCopyWithImpl<ExerciseQuery>(
          this as ExerciseQuery, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExerciseQuery &&
            (identical(other.q, q) || other.q == q) &&
            const DeepCollectionEquality().equals(other.equipment, equipment) &&
            (identical(other.muscle, muscle) || other.muscle == muscle) &&
            (identical(other.pattern, pattern) || other.pattern == pattern) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      q,
      const DeepCollectionEquality().hash(equipment),
      muscle,
      pattern,
      limit,
      offset);

  @override
  String toString() {
    return 'ExerciseQuery(q: $q, equipment: $equipment, muscle: $muscle, pattern: $pattern, limit: $limit, offset: $offset)';
  }
}

/// @nodoc
abstract mixin class $ExerciseQueryCopyWith<$Res> {
  factory $ExerciseQueryCopyWith(
          ExerciseQuery value, $Res Function(ExerciseQuery) _then) =
      _$ExerciseQueryCopyWithImpl;
  @useResult
  $Res call(
      {String q,
      Set<Equipment> equipment,
      MuscleGroup? muscle,
      MovementPattern? pattern,
      int limit,
      int offset});
}

/// @nodoc
class _$ExerciseQueryCopyWithImpl<$Res>
    implements $ExerciseQueryCopyWith<$Res> {
  _$ExerciseQueryCopyWithImpl(this._self, this._then);

  final ExerciseQuery _self;
  final $Res Function(ExerciseQuery) _then;

  /// Create a copy of ExerciseQuery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? q = null,
    Object? equipment = null,
    Object? muscle = freezed,
    Object? pattern = freezed,
    Object? limit = null,
    Object? offset = null,
  }) {
    return _then(_self.copyWith(
      q: null == q
          ? _self.q
          : q // ignore: cast_nullable_to_non_nullable
              as String,
      equipment: null == equipment
          ? _self.equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as Set<Equipment>,
      muscle: freezed == muscle
          ? _self.muscle
          : muscle // ignore: cast_nullable_to_non_nullable
              as MuscleGroup?,
      pattern: freezed == pattern
          ? _self.pattern
          : pattern // ignore: cast_nullable_to_non_nullable
              as MovementPattern?,
      limit: null == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      offset: null == offset
          ? _self.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [ExerciseQuery].
extension ExerciseQueryPatterns on ExerciseQuery {
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
    TResult Function(_ExerciseQuery value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseQuery() when $default != null:
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
    TResult Function(_ExerciseQuery value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseQuery():
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
    TResult? Function(_ExerciseQuery value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseQuery() when $default != null:
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
    TResult Function(String q, Set<Equipment> equipment, MuscleGroup? muscle,
            MovementPattern? pattern, int limit, int offset)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExerciseQuery() when $default != null:
        return $default(_that.q, _that.equipment, _that.muscle, _that.pattern,
            _that.limit, _that.offset);
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
    TResult Function(String q, Set<Equipment> equipment, MuscleGroup? muscle,
            MovementPattern? pattern, int limit, int offset)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseQuery():
        return $default(_that.q, _that.equipment, _that.muscle, _that.pattern,
            _that.limit, _that.offset);
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
    TResult? Function(String q, Set<Equipment> equipment, MuscleGroup? muscle,
            MovementPattern? pattern, int limit, int offset)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExerciseQuery() when $default != null:
        return $default(_that.q, _that.equipment, _that.muscle, _that.pattern,
            _that.limit, _that.offset);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ExerciseQuery extends ExerciseQuery {
  const _ExerciseQuery(
      {this.q = '',
      final Set<Equipment> equipment = const <Equipment>{},
      this.muscle,
      this.pattern,
      this.limit = 200,
      this.offset = 0})
      : _equipment = equipment,
        super._();

  @override
  @JsonKey()
  final String q;
  final Set<Equipment> _equipment;
  @override
  @JsonKey()
  Set<Equipment> get equipment {
    if (_equipment is EqualUnmodifiableSetView) return _equipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_equipment);
  }

  @override
  final MuscleGroup? muscle;
  @override
  final MovementPattern? pattern;
  @override
  @JsonKey()
  final int limit;
  @override
  @JsonKey()
  final int offset;

  /// Create a copy of ExerciseQuery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExerciseQueryCopyWith<_ExerciseQuery> get copyWith =>
      __$ExerciseQueryCopyWithImpl<_ExerciseQuery>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExerciseQuery &&
            (identical(other.q, q) || other.q == q) &&
            const DeepCollectionEquality()
                .equals(other._equipment, _equipment) &&
            (identical(other.muscle, muscle) || other.muscle == muscle) &&
            (identical(other.pattern, pattern) || other.pattern == pattern) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      q,
      const DeepCollectionEquality().hash(_equipment),
      muscle,
      pattern,
      limit,
      offset);

  @override
  String toString() {
    return 'ExerciseQuery(q: $q, equipment: $equipment, muscle: $muscle, pattern: $pattern, limit: $limit, offset: $offset)';
  }
}

/// @nodoc
abstract mixin class _$ExerciseQueryCopyWith<$Res>
    implements $ExerciseQueryCopyWith<$Res> {
  factory _$ExerciseQueryCopyWith(
          _ExerciseQuery value, $Res Function(_ExerciseQuery) _then) =
      __$ExerciseQueryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String q,
      Set<Equipment> equipment,
      MuscleGroup? muscle,
      MovementPattern? pattern,
      int limit,
      int offset});
}

/// @nodoc
class __$ExerciseQueryCopyWithImpl<$Res>
    implements _$ExerciseQueryCopyWith<$Res> {
  __$ExerciseQueryCopyWithImpl(this._self, this._then);

  final _ExerciseQuery _self;
  final $Res Function(_ExerciseQuery) _then;

  /// Create a copy of ExerciseQuery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? q = null,
    Object? equipment = null,
    Object? muscle = freezed,
    Object? pattern = freezed,
    Object? limit = null,
    Object? offset = null,
  }) {
    return _then(_ExerciseQuery(
      q: null == q
          ? _self.q
          : q // ignore: cast_nullable_to_non_nullable
              as String,
      equipment: null == equipment
          ? _self._equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as Set<Equipment>,
      muscle: freezed == muscle
          ? _self.muscle
          : muscle // ignore: cast_nullable_to_non_nullable
              as MuscleGroup?,
      pattern: freezed == pattern
          ? _self.pattern
          : pattern // ignore: cast_nullable_to_non_nullable
              as MovementPattern?,
      limit: null == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      offset: null == offset
          ? _self.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
