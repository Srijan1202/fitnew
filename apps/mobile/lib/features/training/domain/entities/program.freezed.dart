// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'program.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannedSet {
  int get setIndex;
  int get repsMin;
  int get repsMax;
  double? get weightKg;
  int get rir;

  /// Create a copy of PlannedSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PlannedSetCopyWith<PlannedSet> get copyWith =>
      _$PlannedSetCopyWithImpl<PlannedSet>(this as PlannedSet, _$identity);

  /// Serializes this PlannedSet to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PlannedSet &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.repsMin, repsMin) || other.repsMin == repsMin) &&
            (identical(other.repsMax, repsMax) || other.repsMax == repsMax) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.rir, rir) || other.rir == rir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, setIndex, repsMin, repsMax, weightKg, rir);

  @override
  String toString() {
    return 'PlannedSet(setIndex: $setIndex, repsMin: $repsMin, repsMax: $repsMax, weightKg: $weightKg, rir: $rir)';
  }
}

/// @nodoc
abstract mixin class $PlannedSetCopyWith<$Res> {
  factory $PlannedSetCopyWith(
          PlannedSet value, $Res Function(PlannedSet) _then) =
      _$PlannedSetCopyWithImpl;
  @useResult
  $Res call(
      {int setIndex, int repsMin, int repsMax, double? weightKg, int rir});
}

/// @nodoc
class _$PlannedSetCopyWithImpl<$Res> implements $PlannedSetCopyWith<$Res> {
  _$PlannedSetCopyWithImpl(this._self, this._then);

  final PlannedSet _self;
  final $Res Function(PlannedSet) _then;

  /// Create a copy of PlannedSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setIndex = null,
    Object? repsMin = null,
    Object? repsMax = null,
    Object? weightKg = freezed,
    Object? rir = null,
  }) {
    return _then(_self.copyWith(
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      repsMin: null == repsMin
          ? _self.repsMin
          : repsMin // ignore: cast_nullable_to_non_nullable
              as int,
      repsMax: null == repsMax
          ? _self.repsMax
          : repsMax // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      rir: null == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [PlannedSet].
extension PlannedSetPatterns on PlannedSet {
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
    TResult Function(_PlannedSet value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlannedSet() when $default != null:
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
    TResult Function(_PlannedSet value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedSet():
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
    TResult? Function(_PlannedSet value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedSet() when $default != null:
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
            int setIndex, int repsMin, int repsMax, double? weightKg, int rir)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlannedSet() when $default != null:
        return $default(_that.setIndex, _that.repsMin, _that.repsMax,
            _that.weightKg, _that.rir);
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
            int setIndex, int repsMin, int repsMax, double? weightKg, int rir)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedSet():
        return $default(_that.setIndex, _that.repsMin, _that.repsMax,
            _that.weightKg, _that.rir);
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
            int setIndex, int repsMin, int repsMax, double? weightKg, int rir)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedSet() when $default != null:
        return $default(_that.setIndex, _that.repsMin, _that.repsMax,
            _that.weightKg, _that.rir);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PlannedSet extends PlannedSet {
  const _PlannedSet(
      {required this.setIndex,
      required this.repsMin,
      required this.repsMax,
      required this.weightKg,
      required this.rir})
      : super._();
  factory _PlannedSet.fromJson(Map<String, dynamic> json) =>
      _$PlannedSetFromJson(json);

  @override
  final int setIndex;
  @override
  final int repsMin;
  @override
  final int repsMax;
  @override
  final double? weightKg;
  @override
  final int rir;

  /// Create a copy of PlannedSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PlannedSetCopyWith<_PlannedSet> get copyWith =>
      __$PlannedSetCopyWithImpl<_PlannedSet>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PlannedSetToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PlannedSet &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.repsMin, repsMin) || other.repsMin == repsMin) &&
            (identical(other.repsMax, repsMax) || other.repsMax == repsMax) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.rir, rir) || other.rir == rir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, setIndex, repsMin, repsMax, weightKg, rir);

  @override
  String toString() {
    return 'PlannedSet(setIndex: $setIndex, repsMin: $repsMin, repsMax: $repsMax, weightKg: $weightKg, rir: $rir)';
  }
}

/// @nodoc
abstract mixin class _$PlannedSetCopyWith<$Res>
    implements $PlannedSetCopyWith<$Res> {
  factory _$PlannedSetCopyWith(
          _PlannedSet value, $Res Function(_PlannedSet) _then) =
      __$PlannedSetCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int setIndex, int repsMin, int repsMax, double? weightKg, int rir});
}

/// @nodoc
class __$PlannedSetCopyWithImpl<$Res> implements _$PlannedSetCopyWith<$Res> {
  __$PlannedSetCopyWithImpl(this._self, this._then);

  final _PlannedSet _self;
  final $Res Function(_PlannedSet) _then;

  /// Create a copy of PlannedSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? setIndex = null,
    Object? repsMin = null,
    Object? repsMax = null,
    Object? weightKg = freezed,
    Object? rir = null,
  }) {
    return _then(_PlannedSet(
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      repsMin: null == repsMin
          ? _self.repsMin
          : repsMin // ignore: cast_nullable_to_non_nullable
              as int,
      repsMax: null == repsMax
          ? _self.repsMax
          : repsMax // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      rir: null == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$PlannedExercise {
  String get id;
  String get exerciseId;
  String get slug;
  String get name;
  MovementPattern get movementPattern;
  List<Equipment> get equipment;
  Difficulty get difficulty;
  bool get isUnilateral;
  List<MuscleGroup> get primaryMuscles;
  int get orderIndex;
  int get setCount;
  int get repMin;
  int get repMax;
  int get targetRir;
  double get incrementKg;
  String? get reason;
  List<PlannedSet> get sets;

  /// Create a copy of PlannedExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PlannedExerciseCopyWith<PlannedExercise> get copyWith =>
      _$PlannedExerciseCopyWithImpl<PlannedExercise>(
          this as PlannedExercise, _$identity);

  /// Serializes this PlannedExercise to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PlannedExercise &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
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
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.setCount, setCount) ||
                other.setCount == setCount) &&
            (identical(other.repMin, repMin) || other.repMin == repMin) &&
            (identical(other.repMax, repMax) || other.repMax == repMax) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            const DeepCollectionEquality().equals(other.sets, sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      exerciseId,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(equipment),
      difficulty,
      isUnilateral,
      const DeepCollectionEquality().hash(primaryMuscles),
      orderIndex,
      setCount,
      repMin,
      repMax,
      targetRir,
      incrementKg,
      reason,
      const DeepCollectionEquality().hash(sets));

  @override
  String toString() {
    return 'PlannedExercise(id: $id, exerciseId: $exerciseId, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, isUnilateral: $isUnilateral, primaryMuscles: $primaryMuscles, orderIndex: $orderIndex, setCount: $setCount, repMin: $repMin, repMax: $repMax, targetRir: $targetRir, incrementKg: $incrementKg, reason: $reason, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class $PlannedExerciseCopyWith<$Res> {
  factory $PlannedExerciseCopyWith(
          PlannedExercise value, $Res Function(PlannedExercise) _then) =
      _$PlannedExerciseCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String exerciseId,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      bool isUnilateral,
      List<MuscleGroup> primaryMuscles,
      int orderIndex,
      int setCount,
      int repMin,
      int repMax,
      int targetRir,
      double incrementKg,
      String? reason,
      List<PlannedSet> sets});
}

/// @nodoc
class _$PlannedExerciseCopyWithImpl<$Res>
    implements $PlannedExerciseCopyWith<$Res> {
  _$PlannedExerciseCopyWithImpl(this._self, this._then);

  final PlannedExercise _self;
  final $Res Function(PlannedExercise) _then;

  /// Create a copy of PlannedExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? isUnilateral = null,
    Object? primaryMuscles = null,
    Object? orderIndex = null,
    Object? setCount = null,
    Object? repMin = null,
    Object? repMax = null,
    Object? targetRir = null,
    Object? incrementKg = null,
    Object? reason = freezed,
    Object? sets = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
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
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      setCount: null == setCount
          ? _self.setCount
          : setCount // ignore: cast_nullable_to_non_nullable
              as int,
      repMin: null == repMin
          ? _self.repMin
          : repMin // ignore: cast_nullable_to_non_nullable
              as int,
      repMax: null == repMax
          ? _self.repMax
          : repMax // ignore: cast_nullable_to_non_nullable
              as int,
      targetRir: null == targetRir
          ? _self.targetRir
          : targetRir // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      sets: null == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PlannedExercise].
extension PlannedExercisePatterns on PlannedExercise {
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
    TResult Function(_PlannedExercise value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlannedExercise() when $default != null:
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
    TResult Function(_PlannedExercise value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedExercise():
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
    TResult? Function(_PlannedExercise value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedExercise() when $default != null:
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
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            int orderIndex,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double incrementKg,
            String? reason,
            List<PlannedSet> sets)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlannedExercise() when $default != null:
        return $default(
            _that.id,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.orderIndex,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.reason,
            _that.sets);
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
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            int orderIndex,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double incrementKg,
            String? reason,
            List<PlannedSet> sets)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedExercise():
        return $default(
            _that.id,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.orderIndex,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.reason,
            _that.sets);
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
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            int orderIndex,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double incrementKg,
            String? reason,
            List<PlannedSet> sets)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedExercise() when $default != null:
        return $default(
            _that.id,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.orderIndex,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.reason,
            _that.sets);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PlannedExercise extends PlannedExercise {
  const _PlannedExercise(
      {required this.id,
      required this.exerciseId,
      required this.slug,
      required this.name,
      required this.movementPattern,
      required final List<Equipment> equipment,
      required this.difficulty,
      required this.isUnilateral,
      required final List<MuscleGroup> primaryMuscles,
      required this.orderIndex,
      required this.setCount,
      required this.repMin,
      required this.repMax,
      required this.targetRir,
      required this.incrementKg,
      required this.reason,
      required final List<PlannedSet> sets})
      : _equipment = equipment,
        _primaryMuscles = primaryMuscles,
        _sets = sets,
        super._();
  factory _PlannedExercise.fromJson(Map<String, dynamic> json) =>
      _$PlannedExerciseFromJson(json);

  @override
  final String id;
  @override
  final String exerciseId;
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
  final int orderIndex;
  @override
  final int setCount;
  @override
  final int repMin;
  @override
  final int repMax;
  @override
  final int targetRir;
  @override
  final double incrementKg;
  @override
  final String? reason;
  final List<PlannedSet> _sets;
  @override
  List<PlannedSet> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  /// Create a copy of PlannedExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PlannedExerciseCopyWith<_PlannedExercise> get copyWith =>
      __$PlannedExerciseCopyWithImpl<_PlannedExercise>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PlannedExerciseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PlannedExercise &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
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
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.setCount, setCount) ||
                other.setCount == setCount) &&
            (identical(other.repMin, repMin) || other.repMin == repMin) &&
            (identical(other.repMax, repMax) || other.repMax == repMax) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            const DeepCollectionEquality().equals(other._sets, _sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      exerciseId,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(_equipment),
      difficulty,
      isUnilateral,
      const DeepCollectionEquality().hash(_primaryMuscles),
      orderIndex,
      setCount,
      repMin,
      repMax,
      targetRir,
      incrementKg,
      reason,
      const DeepCollectionEquality().hash(_sets));

  @override
  String toString() {
    return 'PlannedExercise(id: $id, exerciseId: $exerciseId, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, isUnilateral: $isUnilateral, primaryMuscles: $primaryMuscles, orderIndex: $orderIndex, setCount: $setCount, repMin: $repMin, repMax: $repMax, targetRir: $targetRir, incrementKg: $incrementKg, reason: $reason, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class _$PlannedExerciseCopyWith<$Res>
    implements $PlannedExerciseCopyWith<$Res> {
  factory _$PlannedExerciseCopyWith(
          _PlannedExercise value, $Res Function(_PlannedExercise) _then) =
      __$PlannedExerciseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String exerciseId,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      bool isUnilateral,
      List<MuscleGroup> primaryMuscles,
      int orderIndex,
      int setCount,
      int repMin,
      int repMax,
      int targetRir,
      double incrementKg,
      String? reason,
      List<PlannedSet> sets});
}

/// @nodoc
class __$PlannedExerciseCopyWithImpl<$Res>
    implements _$PlannedExerciseCopyWith<$Res> {
  __$PlannedExerciseCopyWithImpl(this._self, this._then);

  final _PlannedExercise _self;
  final $Res Function(_PlannedExercise) _then;

  /// Create a copy of PlannedExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? isUnilateral = null,
    Object? primaryMuscles = null,
    Object? orderIndex = null,
    Object? setCount = null,
    Object? repMin = null,
    Object? repMax = null,
    Object? targetRir = null,
    Object? incrementKg = null,
    Object? reason = freezed,
    Object? sets = null,
  }) {
    return _then(_PlannedExercise(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
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
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      setCount: null == setCount
          ? _self.setCount
          : setCount // ignore: cast_nullable_to_non_nullable
              as int,
      repMin: null == repMin
          ? _self.repMin
          : repMin // ignore: cast_nullable_to_non_nullable
              as int,
      repMax: null == repMax
          ? _self.repMax
          : repMax // ignore: cast_nullable_to_non_nullable
              as int,
      targetRir: null == targetRir
          ? _self.targetRir
          : targetRir // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      sets: null == sets
          ? _self._sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>,
    ));
  }
}

/// @nodoc
mixin _$ProgramDay {
  String get id;
  int get dayOfWeek;
  String get sessionName;
  List<MuscleGroup> get focus;
  bool get isRest;
  int get estimatedMinutes;
  List<PlannedExercise> get exercises;

  /// Create a copy of ProgramDay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgramDayCopyWith<ProgramDay> get copyWith =>
      _$ProgramDayCopyWithImpl<ProgramDay>(this as ProgramDay, _$identity);

  /// Serializes this ProgramDay to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProgramDay &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other.focus, focus) &&
            (identical(other.isRest, isRest) || other.isRest == isRest) &&
            (identical(other.estimatedMinutes, estimatedMinutes) ||
                other.estimatedMinutes == estimatedMinutes) &&
            const DeepCollectionEquality().equals(other.exercises, exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      dayOfWeek,
      sessionName,
      const DeepCollectionEquality().hash(focus),
      isRest,
      estimatedMinutes,
      const DeepCollectionEquality().hash(exercises));

  @override
  String toString() {
    return 'ProgramDay(id: $id, dayOfWeek: $dayOfWeek, sessionName: $sessionName, focus: $focus, isRest: $isRest, estimatedMinutes: $estimatedMinutes, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class $ProgramDayCopyWith<$Res> {
  factory $ProgramDayCopyWith(
          ProgramDay value, $Res Function(ProgramDay) _then) =
      _$ProgramDayCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      int dayOfWeek,
      String sessionName,
      List<MuscleGroup> focus,
      bool isRest,
      int estimatedMinutes,
      List<PlannedExercise> exercises});
}

/// @nodoc
class _$ProgramDayCopyWithImpl<$Res> implements $ProgramDayCopyWith<$Res> {
  _$ProgramDayCopyWithImpl(this._self, this._then);

  final ProgramDay _self;
  final $Res Function(ProgramDay) _then;

  /// Create a copy of ProgramDay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? dayOfWeek = null,
    Object? sessionName = null,
    Object? focus = null,
    Object? isRest = null,
    Object? estimatedMinutes = null,
    Object? exercises = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      sessionName: null == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String,
      focus: null == focus
          ? _self.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      isRest: null == isRest
          ? _self.isRest
          : isRest // ignore: cast_nullable_to_non_nullable
              as bool,
      estimatedMinutes: null == estimatedMinutes
          ? _self.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      exercises: null == exercises
          ? _self.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<PlannedExercise>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProgramDay].
extension ProgramDayPatterns on ProgramDay {
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
    TResult Function(_ProgramDay value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgramDay() when $default != null:
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
    TResult Function(_ProgramDay value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgramDay():
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
    TResult? Function(_ProgramDay value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgramDay() when $default != null:
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
            int dayOfWeek,
            String sessionName,
            List<MuscleGroup> focus,
            bool isRest,
            int estimatedMinutes,
            List<PlannedExercise> exercises)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgramDay() when $default != null:
        return $default(_that.id, _that.dayOfWeek, _that.sessionName,
            _that.focus, _that.isRest, _that.estimatedMinutes, _that.exercises);
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
            int dayOfWeek,
            String sessionName,
            List<MuscleGroup> focus,
            bool isRest,
            int estimatedMinutes,
            List<PlannedExercise> exercises)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgramDay():
        return $default(_that.id, _that.dayOfWeek, _that.sessionName,
            _that.focus, _that.isRest, _that.estimatedMinutes, _that.exercises);
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
            int dayOfWeek,
            String sessionName,
            List<MuscleGroup> focus,
            bool isRest,
            int estimatedMinutes,
            List<PlannedExercise> exercises)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgramDay() when $default != null:
        return $default(_that.id, _that.dayOfWeek, _that.sessionName,
            _that.focus, _that.isRest, _that.estimatedMinutes, _that.exercises);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProgramDay implements ProgramDay {
  const _ProgramDay(
      {required this.id,
      required this.dayOfWeek,
      required this.sessionName,
      required final List<MuscleGroup> focus,
      required this.isRest,
      required this.estimatedMinutes,
      required final List<PlannedExercise> exercises})
      : _focus = focus,
        _exercises = exercises;
  factory _ProgramDay.fromJson(Map<String, dynamic> json) =>
      _$ProgramDayFromJson(json);

  @override
  final String id;
  @override
  final int dayOfWeek;
  @override
  final String sessionName;
  final List<MuscleGroup> _focus;
  @override
  List<MuscleGroup> get focus {
    if (_focus is EqualUnmodifiableListView) return _focus;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_focus);
  }

  @override
  final bool isRest;
  @override
  final int estimatedMinutes;
  final List<PlannedExercise> _exercises;
  @override
  List<PlannedExercise> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  /// Create a copy of ProgramDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgramDayCopyWith<_ProgramDay> get copyWith =>
      __$ProgramDayCopyWithImpl<_ProgramDay>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgramDayToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProgramDay &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other._focus, _focus) &&
            (identical(other.isRest, isRest) || other.isRest == isRest) &&
            (identical(other.estimatedMinutes, estimatedMinutes) ||
                other.estimatedMinutes == estimatedMinutes) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      dayOfWeek,
      sessionName,
      const DeepCollectionEquality().hash(_focus),
      isRest,
      estimatedMinutes,
      const DeepCollectionEquality().hash(_exercises));

  @override
  String toString() {
    return 'ProgramDay(id: $id, dayOfWeek: $dayOfWeek, sessionName: $sessionName, focus: $focus, isRest: $isRest, estimatedMinutes: $estimatedMinutes, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class _$ProgramDayCopyWith<$Res>
    implements $ProgramDayCopyWith<$Res> {
  factory _$ProgramDayCopyWith(
          _ProgramDay value, $Res Function(_ProgramDay) _then) =
      __$ProgramDayCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      int dayOfWeek,
      String sessionName,
      List<MuscleGroup> focus,
      bool isRest,
      int estimatedMinutes,
      List<PlannedExercise> exercises});
}

/// @nodoc
class __$ProgramDayCopyWithImpl<$Res> implements _$ProgramDayCopyWith<$Res> {
  __$ProgramDayCopyWithImpl(this._self, this._then);

  final _ProgramDay _self;
  final $Res Function(_ProgramDay) _then;

  /// Create a copy of ProgramDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? dayOfWeek = null,
    Object? sessionName = null,
    Object? focus = null,
    Object? isRest = null,
    Object? estimatedMinutes = null,
    Object? exercises = null,
  }) {
    return _then(_ProgramDay(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      sessionName: null == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String,
      focus: null == focus
          ? _self._focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      isRest: null == isRest
          ? _self.isRest
          : isRest // ignore: cast_nullable_to_non_nullable
              as bool,
      estimatedMinutes: null == estimatedMinutes
          ? _self.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      exercises: null == exercises
          ? _self._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<PlannedExercise>,
    ));
  }
}

/// @nodoc
mixin _$VolumeShortfall {
  MuscleGroup get muscle;
  double get targetSets;
  double get plannedSets;
  ShortfallReason get reason;
  String get detail;

  /// Create a copy of VolumeShortfall
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VolumeShortfallCopyWith<VolumeShortfall> get copyWith =>
      _$VolumeShortfallCopyWithImpl<VolumeShortfall>(
          this as VolumeShortfall, _$identity);

  /// Serializes this VolumeShortfall to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VolumeShortfall &&
            (identical(other.muscle, muscle) || other.muscle == muscle) &&
            (identical(other.targetSets, targetSets) ||
                other.targetSets == targetSets) &&
            (identical(other.plannedSets, plannedSets) ||
                other.plannedSets == plannedSets) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.detail, detail) || other.detail == detail));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, muscle, targetSets, plannedSets, reason, detail);

  @override
  String toString() {
    return 'VolumeShortfall(muscle: $muscle, targetSets: $targetSets, plannedSets: $plannedSets, reason: $reason, detail: $detail)';
  }
}

/// @nodoc
abstract mixin class $VolumeShortfallCopyWith<$Res> {
  factory $VolumeShortfallCopyWith(
          VolumeShortfall value, $Res Function(VolumeShortfall) _then) =
      _$VolumeShortfallCopyWithImpl;
  @useResult
  $Res call(
      {MuscleGroup muscle,
      double targetSets,
      double plannedSets,
      ShortfallReason reason,
      String detail});
}

/// @nodoc
class _$VolumeShortfallCopyWithImpl<$Res>
    implements $VolumeShortfallCopyWith<$Res> {
  _$VolumeShortfallCopyWithImpl(this._self, this._then);

  final VolumeShortfall _self;
  final $Res Function(VolumeShortfall) _then;

  /// Create a copy of VolumeShortfall
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? muscle = null,
    Object? targetSets = null,
    Object? plannedSets = null,
    Object? reason = null,
    Object? detail = null,
  }) {
    return _then(_self.copyWith(
      muscle: null == muscle
          ? _self.muscle
          : muscle // ignore: cast_nullable_to_non_nullable
              as MuscleGroup,
      targetSets: null == targetSets
          ? _self.targetSets
          : targetSets // ignore: cast_nullable_to_non_nullable
              as double,
      plannedSets: null == plannedSets
          ? _self.plannedSets
          : plannedSets // ignore: cast_nullable_to_non_nullable
              as double,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as ShortfallReason,
      detail: null == detail
          ? _self.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [VolumeShortfall].
extension VolumeShortfallPatterns on VolumeShortfall {
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
    TResult Function(_VolumeShortfall value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VolumeShortfall() when $default != null:
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
    TResult Function(_VolumeShortfall value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeShortfall():
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
    TResult? Function(_VolumeShortfall value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeShortfall() when $default != null:
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
    TResult Function(MuscleGroup muscle, double targetSets, double plannedSets,
            ShortfallReason reason, String detail)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VolumeShortfall() when $default != null:
        return $default(_that.muscle, _that.targetSets, _that.plannedSets,
            _that.reason, _that.detail);
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
    TResult Function(MuscleGroup muscle, double targetSets, double plannedSets,
            ShortfallReason reason, String detail)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeShortfall():
        return $default(_that.muscle, _that.targetSets, _that.plannedSets,
            _that.reason, _that.detail);
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
    TResult? Function(MuscleGroup muscle, double targetSets, double plannedSets,
            ShortfallReason reason, String detail)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeShortfall() when $default != null:
        return $default(_that.muscle, _that.targetSets, _that.plannedSets,
            _that.reason, _that.detail);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _VolumeShortfall implements VolumeShortfall {
  const _VolumeShortfall(
      {required this.muscle,
      required this.targetSets,
      required this.plannedSets,
      required this.reason,
      required this.detail});
  factory _VolumeShortfall.fromJson(Map<String, dynamic> json) =>
      _$VolumeShortfallFromJson(json);

  @override
  final MuscleGroup muscle;
  @override
  final double targetSets;
  @override
  final double plannedSets;
  @override
  final ShortfallReason reason;
  @override
  final String detail;

  /// Create a copy of VolumeShortfall
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VolumeShortfallCopyWith<_VolumeShortfall> get copyWith =>
      __$VolumeShortfallCopyWithImpl<_VolumeShortfall>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VolumeShortfallToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VolumeShortfall &&
            (identical(other.muscle, muscle) || other.muscle == muscle) &&
            (identical(other.targetSets, targetSets) ||
                other.targetSets == targetSets) &&
            (identical(other.plannedSets, plannedSets) ||
                other.plannedSets == plannedSets) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.detail, detail) || other.detail == detail));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, muscle, targetSets, plannedSets, reason, detail);

  @override
  String toString() {
    return 'VolumeShortfall(muscle: $muscle, targetSets: $targetSets, plannedSets: $plannedSets, reason: $reason, detail: $detail)';
  }
}

/// @nodoc
abstract mixin class _$VolumeShortfallCopyWith<$Res>
    implements $VolumeShortfallCopyWith<$Res> {
  factory _$VolumeShortfallCopyWith(
          _VolumeShortfall value, $Res Function(_VolumeShortfall) _then) =
      __$VolumeShortfallCopyWithImpl;
  @override
  @useResult
  $Res call(
      {MuscleGroup muscle,
      double targetSets,
      double plannedSets,
      ShortfallReason reason,
      String detail});
}

/// @nodoc
class __$VolumeShortfallCopyWithImpl<$Res>
    implements _$VolumeShortfallCopyWith<$Res> {
  __$VolumeShortfallCopyWithImpl(this._self, this._then);

  final _VolumeShortfall _self;
  final $Res Function(_VolumeShortfall) _then;

  /// Create a copy of VolumeShortfall
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? muscle = null,
    Object? targetSets = null,
    Object? plannedSets = null,
    Object? reason = null,
    Object? detail = null,
  }) {
    return _then(_VolumeShortfall(
      muscle: null == muscle
          ? _self.muscle
          : muscle // ignore: cast_nullable_to_non_nullable
              as MuscleGroup,
      targetSets: null == targetSets
          ? _self.targetSets
          : targetSets // ignore: cast_nullable_to_non_nullable
              as double,
      plannedSets: null == plannedSets
          ? _self.plannedSets
          : plannedSets // ignore: cast_nullable_to_non_nullable
              as double,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as ShortfallReason,
      detail: null == detail
          ? _self.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$Program {
  String get id;
  String get name;
  SplitType get splitType;
  int get daysPerWeek;
  ProgramSource get source;
  String? get templateSlug;
  int get mesocycleWeek;
  bool get active;
  String get createdAt;
  List<ProgramDay> get days;
  Map<String, double> get weeklyVolume;
  List<String> get rationale;
  List<VolumeShortfall> get shortfalls;

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgramCopyWith<Program> get copyWith =>
      _$ProgramCopyWithImpl<Program>(this as Program, _$identity);

  /// Serializes this Program to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Program &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.splitType, splitType) ||
                other.splitType == splitType) &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.templateSlug, templateSlug) ||
                other.templateSlug == templateSlug) &&
            (identical(other.mesocycleWeek, mesocycleWeek) ||
                other.mesocycleWeek == mesocycleWeek) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(other.days, days) &&
            const DeepCollectionEquality()
                .equals(other.weeklyVolume, weeklyVolume) &&
            const DeepCollectionEquality().equals(other.rationale, rationale) &&
            const DeepCollectionEquality()
                .equals(other.shortfalls, shortfalls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      splitType,
      daysPerWeek,
      source,
      templateSlug,
      mesocycleWeek,
      active,
      createdAt,
      const DeepCollectionEquality().hash(days),
      const DeepCollectionEquality().hash(weeklyVolume),
      const DeepCollectionEquality().hash(rationale),
      const DeepCollectionEquality().hash(shortfalls));

  @override
  String toString() {
    return 'Program(id: $id, name: $name, splitType: $splitType, daysPerWeek: $daysPerWeek, source: $source, templateSlug: $templateSlug, mesocycleWeek: $mesocycleWeek, active: $active, createdAt: $createdAt, days: $days, weeklyVolume: $weeklyVolume, rationale: $rationale, shortfalls: $shortfalls)';
  }
}

/// @nodoc
abstract mixin class $ProgramCopyWith<$Res> {
  factory $ProgramCopyWith(Program value, $Res Function(Program) _then) =
      _$ProgramCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      SplitType splitType,
      int daysPerWeek,
      ProgramSource source,
      String? templateSlug,
      int mesocycleWeek,
      bool active,
      String createdAt,
      List<ProgramDay> days,
      Map<String, double> weeklyVolume,
      List<String> rationale,
      List<VolumeShortfall> shortfalls});
}

/// @nodoc
class _$ProgramCopyWithImpl<$Res> implements $ProgramCopyWith<$Res> {
  _$ProgramCopyWithImpl(this._self, this._then);

  final Program _self;
  final $Res Function(Program) _then;

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? splitType = null,
    Object? daysPerWeek = null,
    Object? source = null,
    Object? templateSlug = freezed,
    Object? mesocycleWeek = null,
    Object? active = null,
    Object? createdAt = null,
    Object? days = null,
    Object? weeklyVolume = null,
    Object? rationale = null,
    Object? shortfalls = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      splitType: null == splitType
          ? _self.splitType
          : splitType // ignore: cast_nullable_to_non_nullable
              as SplitType,
      daysPerWeek: null == daysPerWeek
          ? _self.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as ProgramSource,
      templateSlug: freezed == templateSlug
          ? _self.templateSlug
          : templateSlug // ignore: cast_nullable_to_non_nullable
              as String?,
      mesocycleWeek: null == mesocycleWeek
          ? _self.mesocycleWeek
          : mesocycleWeek // ignore: cast_nullable_to_non_nullable
              as int,
      active: null == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      days: null == days
          ? _self.days
          : days // ignore: cast_nullable_to_non_nullable
              as List<ProgramDay>,
      weeklyVolume: null == weeklyVolume
          ? _self.weeklyVolume
          : weeklyVolume // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      rationale: null == rationale
          ? _self.rationale
          : rationale // ignore: cast_nullable_to_non_nullable
              as List<String>,
      shortfalls: null == shortfalls
          ? _self.shortfalls
          : shortfalls // ignore: cast_nullable_to_non_nullable
              as List<VolumeShortfall>,
    ));
  }
}

/// Adds pattern-matching-related methods to [Program].
extension ProgramPatterns on Program {
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
    TResult Function(_Program value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Program() when $default != null:
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
    TResult Function(_Program value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Program():
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
    TResult? Function(_Program value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Program() when $default != null:
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
            String name,
            SplitType splitType,
            int daysPerWeek,
            ProgramSource source,
            String? templateSlug,
            int mesocycleWeek,
            bool active,
            String createdAt,
            List<ProgramDay> days,
            Map<String, double> weeklyVolume,
            List<String> rationale,
            List<VolumeShortfall> shortfalls)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Program() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.splitType,
            _that.daysPerWeek,
            _that.source,
            _that.templateSlug,
            _that.mesocycleWeek,
            _that.active,
            _that.createdAt,
            _that.days,
            _that.weeklyVolume,
            _that.rationale,
            _that.shortfalls);
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
            String name,
            SplitType splitType,
            int daysPerWeek,
            ProgramSource source,
            String? templateSlug,
            int mesocycleWeek,
            bool active,
            String createdAt,
            List<ProgramDay> days,
            Map<String, double> weeklyVolume,
            List<String> rationale,
            List<VolumeShortfall> shortfalls)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Program():
        return $default(
            _that.id,
            _that.name,
            _that.splitType,
            _that.daysPerWeek,
            _that.source,
            _that.templateSlug,
            _that.mesocycleWeek,
            _that.active,
            _that.createdAt,
            _that.days,
            _that.weeklyVolume,
            _that.rationale,
            _that.shortfalls);
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
            String name,
            SplitType splitType,
            int daysPerWeek,
            ProgramSource source,
            String? templateSlug,
            int mesocycleWeek,
            bool active,
            String createdAt,
            List<ProgramDay> days,
            Map<String, double> weeklyVolume,
            List<String> rationale,
            List<VolumeShortfall> shortfalls)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Program() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.splitType,
            _that.daysPerWeek,
            _that.source,
            _that.templateSlug,
            _that.mesocycleWeek,
            _that.active,
            _that.createdAt,
            _that.days,
            _that.weeklyVolume,
            _that.rationale,
            _that.shortfalls);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Program implements Program {
  const _Program(
      {required this.id,
      required this.name,
      required this.splitType,
      required this.daysPerWeek,
      required this.source,
      required this.templateSlug,
      required this.mesocycleWeek,
      required this.active,
      required this.createdAt,
      required final List<ProgramDay> days,
      required final Map<String, double> weeklyVolume,
      required final List<String> rationale,
      required final List<VolumeShortfall> shortfalls})
      : _days = days,
        _weeklyVolume = weeklyVolume,
        _rationale = rationale,
        _shortfalls = shortfalls;
  factory _Program.fromJson(Map<String, dynamic> json) =>
      _$ProgramFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final SplitType splitType;
  @override
  final int daysPerWeek;
  @override
  final ProgramSource source;
  @override
  final String? templateSlug;
  @override
  final int mesocycleWeek;
  @override
  final bool active;
  @override
  final String createdAt;
  final List<ProgramDay> _days;
  @override
  List<ProgramDay> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  final Map<String, double> _weeklyVolume;
  @override
  Map<String, double> get weeklyVolume {
    if (_weeklyVolume is EqualUnmodifiableMapView) return _weeklyVolume;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_weeklyVolume);
  }

  final List<String> _rationale;
  @override
  List<String> get rationale {
    if (_rationale is EqualUnmodifiableListView) return _rationale;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rationale);
  }

  final List<VolumeShortfall> _shortfalls;
  @override
  List<VolumeShortfall> get shortfalls {
    if (_shortfalls is EqualUnmodifiableListView) return _shortfalls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shortfalls);
  }

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgramCopyWith<_Program> get copyWith =>
      __$ProgramCopyWithImpl<_Program>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgramToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Program &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.splitType, splitType) ||
                other.splitType == splitType) &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.templateSlug, templateSlug) ||
                other.templateSlug == templateSlug) &&
            (identical(other.mesocycleWeek, mesocycleWeek) ||
                other.mesocycleWeek == mesocycleWeek) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(other._days, _days) &&
            const DeepCollectionEquality()
                .equals(other._weeklyVolume, _weeklyVolume) &&
            const DeepCollectionEquality()
                .equals(other._rationale, _rationale) &&
            const DeepCollectionEquality()
                .equals(other._shortfalls, _shortfalls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      splitType,
      daysPerWeek,
      source,
      templateSlug,
      mesocycleWeek,
      active,
      createdAt,
      const DeepCollectionEquality().hash(_days),
      const DeepCollectionEquality().hash(_weeklyVolume),
      const DeepCollectionEquality().hash(_rationale),
      const DeepCollectionEquality().hash(_shortfalls));

  @override
  String toString() {
    return 'Program(id: $id, name: $name, splitType: $splitType, daysPerWeek: $daysPerWeek, source: $source, templateSlug: $templateSlug, mesocycleWeek: $mesocycleWeek, active: $active, createdAt: $createdAt, days: $days, weeklyVolume: $weeklyVolume, rationale: $rationale, shortfalls: $shortfalls)';
  }
}

/// @nodoc
abstract mixin class _$ProgramCopyWith<$Res> implements $ProgramCopyWith<$Res> {
  factory _$ProgramCopyWith(_Program value, $Res Function(_Program) _then) =
      __$ProgramCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      SplitType splitType,
      int daysPerWeek,
      ProgramSource source,
      String? templateSlug,
      int mesocycleWeek,
      bool active,
      String createdAt,
      List<ProgramDay> days,
      Map<String, double> weeklyVolume,
      List<String> rationale,
      List<VolumeShortfall> shortfalls});
}

/// @nodoc
class __$ProgramCopyWithImpl<$Res> implements _$ProgramCopyWith<$Res> {
  __$ProgramCopyWithImpl(this._self, this._then);

  final _Program _self;
  final $Res Function(_Program) _then;

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? splitType = null,
    Object? daysPerWeek = null,
    Object? source = null,
    Object? templateSlug = freezed,
    Object? mesocycleWeek = null,
    Object? active = null,
    Object? createdAt = null,
    Object? days = null,
    Object? weeklyVolume = null,
    Object? rationale = null,
    Object? shortfalls = null,
  }) {
    return _then(_Program(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      splitType: null == splitType
          ? _self.splitType
          : splitType // ignore: cast_nullable_to_non_nullable
              as SplitType,
      daysPerWeek: null == daysPerWeek
          ? _self.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as ProgramSource,
      templateSlug: freezed == templateSlug
          ? _self.templateSlug
          : templateSlug // ignore: cast_nullable_to_non_nullable
              as String?,
      mesocycleWeek: null == mesocycleWeek
          ? _self.mesocycleWeek
          : mesocycleWeek // ignore: cast_nullable_to_non_nullable
              as int,
      active: null == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      days: null == days
          ? _self._days
          : days // ignore: cast_nullable_to_non_nullable
              as List<ProgramDay>,
      weeklyVolume: null == weeklyVolume
          ? _self._weeklyVolume
          : weeklyVolume // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      rationale: null == rationale
          ? _self._rationale
          : rationale // ignore: cast_nullable_to_non_nullable
              as List<String>,
      shortfalls: null == shortfalls
          ? _self._shortfalls
          : shortfalls // ignore: cast_nullable_to_non_nullable
              as List<VolumeShortfall>,
    ));
  }
}

/// @nodoc
mixin _$GenerateProgramRequest {
  int? get daysPerWeek;
  int? get preferredSessionMinutes;

  /// Create a copy of GenerateProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GenerateProgramRequestCopyWith<GenerateProgramRequest> get copyWith =>
      _$GenerateProgramRequestCopyWithImpl<GenerateProgramRequest>(
          this as GenerateProgramRequest, _$identity);

  /// Serializes this GenerateProgramRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GenerateProgramRequest &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            (identical(
                    other.preferredSessionMinutes, preferredSessionMinutes) ||
                other.preferredSessionMinutes == preferredSessionMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, daysPerWeek, preferredSessionMinutes);

  @override
  String toString() {
    return 'GenerateProgramRequest(daysPerWeek: $daysPerWeek, preferredSessionMinutes: $preferredSessionMinutes)';
  }
}

/// @nodoc
abstract mixin class $GenerateProgramRequestCopyWith<$Res> {
  factory $GenerateProgramRequestCopyWith(GenerateProgramRequest value,
          $Res Function(GenerateProgramRequest) _then) =
      _$GenerateProgramRequestCopyWithImpl;
  @useResult
  $Res call({int? daysPerWeek, int? preferredSessionMinutes});
}

/// @nodoc
class _$GenerateProgramRequestCopyWithImpl<$Res>
    implements $GenerateProgramRequestCopyWith<$Res> {
  _$GenerateProgramRequestCopyWithImpl(this._self, this._then);

  final GenerateProgramRequest _self;
  final $Res Function(GenerateProgramRequest) _then;

  /// Create a copy of GenerateProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? daysPerWeek = freezed,
    Object? preferredSessionMinutes = freezed,
  }) {
    return _then(_self.copyWith(
      daysPerWeek: freezed == daysPerWeek
          ? _self.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      preferredSessionMinutes: freezed == preferredSessionMinutes
          ? _self.preferredSessionMinutes
          : preferredSessionMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [GenerateProgramRequest].
extension GenerateProgramRequestPatterns on GenerateProgramRequest {
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
    TResult Function(_GenerateProgramRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GenerateProgramRequest() when $default != null:
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
    TResult Function(_GenerateProgramRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GenerateProgramRequest():
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
    TResult? Function(_GenerateProgramRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GenerateProgramRequest() when $default != null:
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
    TResult Function(int? daysPerWeek, int? preferredSessionMinutes)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GenerateProgramRequest() when $default != null:
        return $default(_that.daysPerWeek, _that.preferredSessionMinutes);
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
    TResult Function(int? daysPerWeek, int? preferredSessionMinutes) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GenerateProgramRequest():
        return $default(_that.daysPerWeek, _that.preferredSessionMinutes);
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
    TResult? Function(int? daysPerWeek, int? preferredSessionMinutes)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GenerateProgramRequest() when $default != null:
        return $default(_that.daysPerWeek, _that.preferredSessionMinutes);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _GenerateProgramRequest implements GenerateProgramRequest {
  const _GenerateProgramRequest(
      {this.daysPerWeek, this.preferredSessionMinutes});
  factory _GenerateProgramRequest.fromJson(Map<String, dynamic> json) =>
      _$GenerateProgramRequestFromJson(json);

  @override
  final int? daysPerWeek;
  @override
  final int? preferredSessionMinutes;

  /// Create a copy of GenerateProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GenerateProgramRequestCopyWith<_GenerateProgramRequest> get copyWith =>
      __$GenerateProgramRequestCopyWithImpl<_GenerateProgramRequest>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GenerateProgramRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GenerateProgramRequest &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            (identical(
                    other.preferredSessionMinutes, preferredSessionMinutes) ||
                other.preferredSessionMinutes == preferredSessionMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, daysPerWeek, preferredSessionMinutes);

  @override
  String toString() {
    return 'GenerateProgramRequest(daysPerWeek: $daysPerWeek, preferredSessionMinutes: $preferredSessionMinutes)';
  }
}

/// @nodoc
abstract mixin class _$GenerateProgramRequestCopyWith<$Res>
    implements $GenerateProgramRequestCopyWith<$Res> {
  factory _$GenerateProgramRequestCopyWith(_GenerateProgramRequest value,
          $Res Function(_GenerateProgramRequest) _then) =
      __$GenerateProgramRequestCopyWithImpl;
  @override
  @useResult
  $Res call({int? daysPerWeek, int? preferredSessionMinutes});
}

/// @nodoc
class __$GenerateProgramRequestCopyWithImpl<$Res>
    implements _$GenerateProgramRequestCopyWith<$Res> {
  __$GenerateProgramRequestCopyWithImpl(this._self, this._then);

  final _GenerateProgramRequest _self;
  final $Res Function(_GenerateProgramRequest) _then;

  /// Create a copy of GenerateProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? daysPerWeek = freezed,
    Object? preferredSessionMinutes = freezed,
  }) {
    return _then(_GenerateProgramRequest(
      daysPerWeek: freezed == daysPerWeek
          ? _self.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      preferredSessionMinutes: freezed == preferredSessionMinutes
          ? _self.preferredSessionMinutes
          : preferredSessionMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
mixin _$CustomSet {
  int get repsMin;
  int get repsMax;
  double? get weightKg;
  int get rir;

  /// Create a copy of CustomSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CustomSetCopyWith<CustomSet> get copyWith =>
      _$CustomSetCopyWithImpl<CustomSet>(this as CustomSet, _$identity);

  /// Serializes this CustomSet to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CustomSet &&
            (identical(other.repsMin, repsMin) || other.repsMin == repsMin) &&
            (identical(other.repsMax, repsMax) || other.repsMax == repsMax) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.rir, rir) || other.rir == rir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, repsMin, repsMax, weightKg, rir);

  @override
  String toString() {
    return 'CustomSet(repsMin: $repsMin, repsMax: $repsMax, weightKg: $weightKg, rir: $rir)';
  }
}

/// @nodoc
abstract mixin class $CustomSetCopyWith<$Res> {
  factory $CustomSetCopyWith(CustomSet value, $Res Function(CustomSet) _then) =
      _$CustomSetCopyWithImpl;
  @useResult
  $Res call({int repsMin, int repsMax, double? weightKg, int rir});
}

/// @nodoc
class _$CustomSetCopyWithImpl<$Res> implements $CustomSetCopyWith<$Res> {
  _$CustomSetCopyWithImpl(this._self, this._then);

  final CustomSet _self;
  final $Res Function(CustomSet) _then;

  /// Create a copy of CustomSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? repsMin = null,
    Object? repsMax = null,
    Object? weightKg = freezed,
    Object? rir = null,
  }) {
    return _then(_self.copyWith(
      repsMin: null == repsMin
          ? _self.repsMin
          : repsMin // ignore: cast_nullable_to_non_nullable
              as int,
      repsMax: null == repsMax
          ? _self.repsMax
          : repsMax // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      rir: null == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [CustomSet].
extension CustomSetPatterns on CustomSet {
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
    TResult Function(_CustomSet value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomSet() when $default != null:
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
    TResult Function(_CustomSet value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomSet():
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
    TResult? Function(_CustomSet value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomSet() when $default != null:
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
    TResult Function(int repsMin, int repsMax, double? weightKg, int rir)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomSet() when $default != null:
        return $default(
            _that.repsMin, _that.repsMax, _that.weightKg, _that.rir);
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
    TResult Function(int repsMin, int repsMax, double? weightKg, int rir)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomSet():
        return $default(
            _that.repsMin, _that.repsMax, _that.weightKg, _that.rir);
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
    TResult? Function(int repsMin, int repsMax, double? weightKg, int rir)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomSet() when $default != null:
        return $default(
            _that.repsMin, _that.repsMax, _that.weightKg, _that.rir);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CustomSet implements CustomSet {
  const _CustomSet(
      {required this.repsMin,
      required this.repsMax,
      required this.weightKg,
      required this.rir});
  factory _CustomSet.fromJson(Map<String, dynamic> json) =>
      _$CustomSetFromJson(json);

  @override
  final int repsMin;
  @override
  final int repsMax;
  @override
  final double? weightKg;
  @override
  final int rir;

  /// Create a copy of CustomSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CustomSetCopyWith<_CustomSet> get copyWith =>
      __$CustomSetCopyWithImpl<_CustomSet>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CustomSetToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CustomSet &&
            (identical(other.repsMin, repsMin) || other.repsMin == repsMin) &&
            (identical(other.repsMax, repsMax) || other.repsMax == repsMax) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.rir, rir) || other.rir == rir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, repsMin, repsMax, weightKg, rir);

  @override
  String toString() {
    return 'CustomSet(repsMin: $repsMin, repsMax: $repsMax, weightKg: $weightKg, rir: $rir)';
  }
}

/// @nodoc
abstract mixin class _$CustomSetCopyWith<$Res>
    implements $CustomSetCopyWith<$Res> {
  factory _$CustomSetCopyWith(
          _CustomSet value, $Res Function(_CustomSet) _then) =
      __$CustomSetCopyWithImpl;
  @override
  @useResult
  $Res call({int repsMin, int repsMax, double? weightKg, int rir});
}

/// @nodoc
class __$CustomSetCopyWithImpl<$Res> implements _$CustomSetCopyWith<$Res> {
  __$CustomSetCopyWithImpl(this._self, this._then);

  final _CustomSet _self;
  final $Res Function(_CustomSet) _then;

  /// Create a copy of CustomSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? repsMin = null,
    Object? repsMax = null,
    Object? weightKg = freezed,
    Object? rir = null,
  }) {
    return _then(_CustomSet(
      repsMin: null == repsMin
          ? _self.repsMin
          : repsMin // ignore: cast_nullable_to_non_nullable
              as int,
      repsMax: null == repsMax
          ? _self.repsMax
          : repsMax // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      rir: null == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$CustomExercise {
  String get exerciseId;
  int get setCount;
  int get repMin;
  int get repMax;
  int get targetRir;
  double? get incrementKg;
  double? get startingWeightKg;
  List<CustomSet>? get sets;

  /// Create a copy of CustomExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CustomExerciseCopyWith<CustomExercise> get copyWith =>
      _$CustomExerciseCopyWithImpl<CustomExercise>(
          this as CustomExercise, _$identity);

  /// Serializes this CustomExercise to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CustomExercise &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.setCount, setCount) ||
                other.setCount == setCount) &&
            (identical(other.repMin, repMin) || other.repMin == repMin) &&
            (identical(other.repMax, repMax) || other.repMax == repMax) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            (identical(other.startingWeightKg, startingWeightKg) ||
                other.startingWeightKg == startingWeightKg) &&
            const DeepCollectionEquality().equals(other.sets, sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      exerciseId,
      setCount,
      repMin,
      repMax,
      targetRir,
      incrementKg,
      startingWeightKg,
      const DeepCollectionEquality().hash(sets));

  @override
  String toString() {
    return 'CustomExercise(exerciseId: $exerciseId, setCount: $setCount, repMin: $repMin, repMax: $repMax, targetRir: $targetRir, incrementKg: $incrementKg, startingWeightKg: $startingWeightKg, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class $CustomExerciseCopyWith<$Res> {
  factory $CustomExerciseCopyWith(
          CustomExercise value, $Res Function(CustomExercise) _then) =
      _$CustomExerciseCopyWithImpl;
  @useResult
  $Res call(
      {String exerciseId,
      int setCount,
      int repMin,
      int repMax,
      int targetRir,
      double? incrementKg,
      double? startingWeightKg,
      List<CustomSet>? sets});
}

/// @nodoc
class _$CustomExerciseCopyWithImpl<$Res>
    implements $CustomExerciseCopyWith<$Res> {
  _$CustomExerciseCopyWithImpl(this._self, this._then);

  final CustomExercise _self;
  final $Res Function(CustomExercise) _then;

  /// Create a copy of CustomExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exerciseId = null,
    Object? setCount = null,
    Object? repMin = null,
    Object? repMax = null,
    Object? targetRir = null,
    Object? incrementKg = freezed,
    Object? startingWeightKg = freezed,
    Object? sets = freezed,
  }) {
    return _then(_self.copyWith(
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      setCount: null == setCount
          ? _self.setCount
          : setCount // ignore: cast_nullable_to_non_nullable
              as int,
      repMin: null == repMin
          ? _self.repMin
          : repMin // ignore: cast_nullable_to_non_nullable
              as int,
      repMax: null == repMax
          ? _self.repMax
          : repMax // ignore: cast_nullable_to_non_nullable
              as int,
      targetRir: null == targetRir
          ? _self.targetRir
          : targetRir // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: freezed == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double?,
      startingWeightKg: freezed == startingWeightKg
          ? _self.startingWeightKg
          : startingWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      sets: freezed == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<CustomSet>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CustomExercise].
extension CustomExercisePatterns on CustomExercise {
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
    TResult Function(_CustomExercise value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomExercise() when $default != null:
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
    TResult Function(_CustomExercise value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomExercise():
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
    TResult? Function(_CustomExercise value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomExercise() when $default != null:
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
            String exerciseId,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double? incrementKg,
            double? startingWeightKg,
            List<CustomSet>? sets)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomExercise() when $default != null:
        return $default(
            _that.exerciseId,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.startingWeightKg,
            _that.sets);
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
            String exerciseId,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double? incrementKg,
            double? startingWeightKg,
            List<CustomSet>? sets)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomExercise():
        return $default(
            _that.exerciseId,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.startingWeightKg,
            _that.sets);
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
            String exerciseId,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double? incrementKg,
            double? startingWeightKg,
            List<CustomSet>? sets)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomExercise() when $default != null:
        return $default(
            _that.exerciseId,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.startingWeightKg,
            _that.sets);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CustomExercise implements CustomExercise {
  const _CustomExercise(
      {required this.exerciseId,
      required this.setCount,
      required this.repMin,
      required this.repMax,
      required this.targetRir,
      this.incrementKg,
      this.startingWeightKg,
      final List<CustomSet>? sets})
      : _sets = sets;
  factory _CustomExercise.fromJson(Map<String, dynamic> json) =>
      _$CustomExerciseFromJson(json);

  @override
  final String exerciseId;
  @override
  final int setCount;
  @override
  final int repMin;
  @override
  final int repMax;
  @override
  final int targetRir;
  @override
  final double? incrementKg;
  @override
  final double? startingWeightKg;
  final List<CustomSet>? _sets;
  @override
  List<CustomSet>? get sets {
    final value = _sets;
    if (value == null) return null;
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of CustomExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CustomExerciseCopyWith<_CustomExercise> get copyWith =>
      __$CustomExerciseCopyWithImpl<_CustomExercise>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CustomExerciseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CustomExercise &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.setCount, setCount) ||
                other.setCount == setCount) &&
            (identical(other.repMin, repMin) || other.repMin == repMin) &&
            (identical(other.repMax, repMax) || other.repMax == repMax) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            (identical(other.startingWeightKg, startingWeightKg) ||
                other.startingWeightKg == startingWeightKg) &&
            const DeepCollectionEquality().equals(other._sets, _sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      exerciseId,
      setCount,
      repMin,
      repMax,
      targetRir,
      incrementKg,
      startingWeightKg,
      const DeepCollectionEquality().hash(_sets));

  @override
  String toString() {
    return 'CustomExercise(exerciseId: $exerciseId, setCount: $setCount, repMin: $repMin, repMax: $repMax, targetRir: $targetRir, incrementKg: $incrementKg, startingWeightKg: $startingWeightKg, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class _$CustomExerciseCopyWith<$Res>
    implements $CustomExerciseCopyWith<$Res> {
  factory _$CustomExerciseCopyWith(
          _CustomExercise value, $Res Function(_CustomExercise) _then) =
      __$CustomExerciseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String exerciseId,
      int setCount,
      int repMin,
      int repMax,
      int targetRir,
      double? incrementKg,
      double? startingWeightKg,
      List<CustomSet>? sets});
}

/// @nodoc
class __$CustomExerciseCopyWithImpl<$Res>
    implements _$CustomExerciseCopyWith<$Res> {
  __$CustomExerciseCopyWithImpl(this._self, this._then);

  final _CustomExercise _self;
  final $Res Function(_CustomExercise) _then;

  /// Create a copy of CustomExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? exerciseId = null,
    Object? setCount = null,
    Object? repMin = null,
    Object? repMax = null,
    Object? targetRir = null,
    Object? incrementKg = freezed,
    Object? startingWeightKg = freezed,
    Object? sets = freezed,
  }) {
    return _then(_CustomExercise(
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      setCount: null == setCount
          ? _self.setCount
          : setCount // ignore: cast_nullable_to_non_nullable
              as int,
      repMin: null == repMin
          ? _self.repMin
          : repMin // ignore: cast_nullable_to_non_nullable
              as int,
      repMax: null == repMax
          ? _self.repMax
          : repMax // ignore: cast_nullable_to_non_nullable
              as int,
      targetRir: null == targetRir
          ? _self.targetRir
          : targetRir // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: freezed == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double?,
      startingWeightKg: freezed == startingWeightKg
          ? _self.startingWeightKg
          : startingWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      sets: freezed == sets
          ? _self._sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<CustomSet>?,
    ));
  }
}

/// @nodoc
mixin _$CustomDay {
  int get dayOfWeek;
  String get sessionName;
  List<MuscleGroup>? get focus;
  List<CustomExercise> get exercises;

  /// Create a copy of CustomDay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CustomDayCopyWith<CustomDay> get copyWith =>
      _$CustomDayCopyWithImpl<CustomDay>(this as CustomDay, _$identity);

  /// Serializes this CustomDay to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CustomDay &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other.focus, focus) &&
            const DeepCollectionEquality().equals(other.exercises, exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dayOfWeek,
      sessionName,
      const DeepCollectionEquality().hash(focus),
      const DeepCollectionEquality().hash(exercises));

  @override
  String toString() {
    return 'CustomDay(dayOfWeek: $dayOfWeek, sessionName: $sessionName, focus: $focus, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class $CustomDayCopyWith<$Res> {
  factory $CustomDayCopyWith(CustomDay value, $Res Function(CustomDay) _then) =
      _$CustomDayCopyWithImpl;
  @useResult
  $Res call(
      {int dayOfWeek,
      String sessionName,
      List<MuscleGroup>? focus,
      List<CustomExercise> exercises});
}

/// @nodoc
class _$CustomDayCopyWithImpl<$Res> implements $CustomDayCopyWith<$Res> {
  _$CustomDayCopyWithImpl(this._self, this._then);

  final CustomDay _self;
  final $Res Function(CustomDay) _then;

  /// Create a copy of CustomDay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dayOfWeek = null,
    Object? sessionName = null,
    Object? focus = freezed,
    Object? exercises = null,
  }) {
    return _then(_self.copyWith(
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      sessionName: null == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String,
      focus: freezed == focus
          ? _self.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>?,
      exercises: null == exercises
          ? _self.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<CustomExercise>,
    ));
  }
}

/// Adds pattern-matching-related methods to [CustomDay].
extension CustomDayPatterns on CustomDay {
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
    TResult Function(_CustomDay value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomDay() when $default != null:
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
    TResult Function(_CustomDay value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomDay():
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
    TResult? Function(_CustomDay value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomDay() when $default != null:
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
    TResult Function(int dayOfWeek, String sessionName,
            List<MuscleGroup>? focus, List<CustomExercise> exercises)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomDay() when $default != null:
        return $default(
            _that.dayOfWeek, _that.sessionName, _that.focus, _that.exercises);
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
    TResult Function(int dayOfWeek, String sessionName,
            List<MuscleGroup>? focus, List<CustomExercise> exercises)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomDay():
        return $default(
            _that.dayOfWeek, _that.sessionName, _that.focus, _that.exercises);
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
    TResult? Function(int dayOfWeek, String sessionName,
            List<MuscleGroup>? focus, List<CustomExercise> exercises)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomDay() when $default != null:
        return $default(
            _that.dayOfWeek, _that.sessionName, _that.focus, _that.exercises);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CustomDay implements CustomDay {
  const _CustomDay(
      {required this.dayOfWeek,
      required this.sessionName,
      final List<MuscleGroup>? focus,
      required final List<CustomExercise> exercises})
      : _focus = focus,
        _exercises = exercises;
  factory _CustomDay.fromJson(Map<String, dynamic> json) =>
      _$CustomDayFromJson(json);

  @override
  final int dayOfWeek;
  @override
  final String sessionName;
  final List<MuscleGroup>? _focus;
  @override
  List<MuscleGroup>? get focus {
    final value = _focus;
    if (value == null) return null;
    if (_focus is EqualUnmodifiableListView) return _focus;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<CustomExercise> _exercises;
  @override
  List<CustomExercise> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  /// Create a copy of CustomDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CustomDayCopyWith<_CustomDay> get copyWith =>
      __$CustomDayCopyWithImpl<_CustomDay>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CustomDayToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CustomDay &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other._focus, _focus) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dayOfWeek,
      sessionName,
      const DeepCollectionEquality().hash(_focus),
      const DeepCollectionEquality().hash(_exercises));

  @override
  String toString() {
    return 'CustomDay(dayOfWeek: $dayOfWeek, sessionName: $sessionName, focus: $focus, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class _$CustomDayCopyWith<$Res>
    implements $CustomDayCopyWith<$Res> {
  factory _$CustomDayCopyWith(
          _CustomDay value, $Res Function(_CustomDay) _then) =
      __$CustomDayCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int dayOfWeek,
      String sessionName,
      List<MuscleGroup>? focus,
      List<CustomExercise> exercises});
}

/// @nodoc
class __$CustomDayCopyWithImpl<$Res> implements _$CustomDayCopyWith<$Res> {
  __$CustomDayCopyWithImpl(this._self, this._then);

  final _CustomDay _self;
  final $Res Function(_CustomDay) _then;

  /// Create a copy of CustomDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dayOfWeek = null,
    Object? sessionName = null,
    Object? focus = freezed,
    Object? exercises = null,
  }) {
    return _then(_CustomDay(
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      sessionName: null == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String,
      focus: freezed == focus
          ? _self._focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>?,
      exercises: null == exercises
          ? _self._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<CustomExercise>,
    ));
  }
}

/// @nodoc
mixin _$PutProgramRequest {
  String get name;
  List<CustomDay> get days;

  /// Create a copy of PutProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PutProgramRequestCopyWith<PutProgramRequest> get copyWith =>
      _$PutProgramRequestCopyWithImpl<PutProgramRequest>(
          this as PutProgramRequest, _$identity);

  /// Serializes this PutProgramRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PutProgramRequest &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other.days, days));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, const DeepCollectionEquality().hash(days));

  @override
  String toString() {
    return 'PutProgramRequest(name: $name, days: $days)';
  }
}

/// @nodoc
abstract mixin class $PutProgramRequestCopyWith<$Res> {
  factory $PutProgramRequestCopyWith(
          PutProgramRequest value, $Res Function(PutProgramRequest) _then) =
      _$PutProgramRequestCopyWithImpl;
  @useResult
  $Res call({String name, List<CustomDay> days});
}

/// @nodoc
class _$PutProgramRequestCopyWithImpl<$Res>
    implements $PutProgramRequestCopyWith<$Res> {
  _$PutProgramRequestCopyWithImpl(this._self, this._then);

  final PutProgramRequest _self;
  final $Res Function(PutProgramRequest) _then;

  /// Create a copy of PutProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? days = null,
  }) {
    return _then(_self.copyWith(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      days: null == days
          ? _self.days
          : days // ignore: cast_nullable_to_non_nullable
              as List<CustomDay>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PutProgramRequest].
extension PutProgramRequestPatterns on PutProgramRequest {
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
    TResult Function(_PutProgramRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PutProgramRequest() when $default != null:
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
    TResult Function(_PutProgramRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PutProgramRequest():
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
    TResult? Function(_PutProgramRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PutProgramRequest() when $default != null:
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
    TResult Function(String name, List<CustomDay> days)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PutProgramRequest() when $default != null:
        return $default(_that.name, _that.days);
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
    TResult Function(String name, List<CustomDay> days) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PutProgramRequest():
        return $default(_that.name, _that.days);
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
    TResult? Function(String name, List<CustomDay> days)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PutProgramRequest() when $default != null:
        return $default(_that.name, _that.days);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PutProgramRequest implements PutProgramRequest {
  const _PutProgramRequest(
      {required this.name, required final List<CustomDay> days})
      : _days = days;
  factory _PutProgramRequest.fromJson(Map<String, dynamic> json) =>
      _$PutProgramRequestFromJson(json);

  @override
  final String name;
  final List<CustomDay> _days;
  @override
  List<CustomDay> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  /// Create a copy of PutProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PutProgramRequestCopyWith<_PutProgramRequest> get copyWith =>
      __$PutProgramRequestCopyWithImpl<_PutProgramRequest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PutProgramRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PutProgramRequest &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._days, _days));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, name, const DeepCollectionEquality().hash(_days));

  @override
  String toString() {
    return 'PutProgramRequest(name: $name, days: $days)';
  }
}

/// @nodoc
abstract mixin class _$PutProgramRequestCopyWith<$Res>
    implements $PutProgramRequestCopyWith<$Res> {
  factory _$PutProgramRequestCopyWith(
          _PutProgramRequest value, $Res Function(_PutProgramRequest) _then) =
      __$PutProgramRequestCopyWithImpl;
  @override
  @useResult
  $Res call({String name, List<CustomDay> days});
}

/// @nodoc
class __$PutProgramRequestCopyWithImpl<$Res>
    implements _$PutProgramRequestCopyWith<$Res> {
  __$PutProgramRequestCopyWithImpl(this._self, this._then);

  final _PutProgramRequest _self;
  final $Res Function(_PutProgramRequest) _then;

  /// Create a copy of PutProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? name = null,
    Object? days = null,
  }) {
    return _then(_PutProgramRequest(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      days: null == days
          ? _self._days
          : days // ignore: cast_nullable_to_non_nullable
              as List<CustomDay>,
    ));
  }
}

/// @nodoc
mixin _$PatchProgramDayRequest {
  String? get sessionName;
  List<MuscleGroup>? get focus;
  List<CustomExercise>? get exercises;

  /// Create a copy of PatchProgramDayRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PatchProgramDayRequestCopyWith<PatchProgramDayRequest> get copyWith =>
      _$PatchProgramDayRequestCopyWithImpl<PatchProgramDayRequest>(
          this as PatchProgramDayRequest, _$identity);

  /// Serializes this PatchProgramDayRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PatchProgramDayRequest &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other.focus, focus) &&
            const DeepCollectionEquality().equals(other.exercises, exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      sessionName,
      const DeepCollectionEquality().hash(focus),
      const DeepCollectionEquality().hash(exercises));

  @override
  String toString() {
    return 'PatchProgramDayRequest(sessionName: $sessionName, focus: $focus, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class $PatchProgramDayRequestCopyWith<$Res> {
  factory $PatchProgramDayRequestCopyWith(PatchProgramDayRequest value,
          $Res Function(PatchProgramDayRequest) _then) =
      _$PatchProgramDayRequestCopyWithImpl;
  @useResult
  $Res call(
      {String? sessionName,
      List<MuscleGroup>? focus,
      List<CustomExercise>? exercises});
}

/// @nodoc
class _$PatchProgramDayRequestCopyWithImpl<$Res>
    implements $PatchProgramDayRequestCopyWith<$Res> {
  _$PatchProgramDayRequestCopyWithImpl(this._self, this._then);

  final PatchProgramDayRequest _self;
  final $Res Function(PatchProgramDayRequest) _then;

  /// Create a copy of PatchProgramDayRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionName = freezed,
    Object? focus = freezed,
    Object? exercises = freezed,
  }) {
    return _then(_self.copyWith(
      sessionName: freezed == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String?,
      focus: freezed == focus
          ? _self.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>?,
      exercises: freezed == exercises
          ? _self.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<CustomExercise>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PatchProgramDayRequest].
extension PatchProgramDayRequestPatterns on PatchProgramDayRequest {
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
    TResult Function(_PatchProgramDayRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PatchProgramDayRequest() when $default != null:
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
    TResult Function(_PatchProgramDayRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchProgramDayRequest():
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
    TResult? Function(_PatchProgramDayRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchProgramDayRequest() when $default != null:
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
    TResult Function(String? sessionName, List<MuscleGroup>? focus,
            List<CustomExercise>? exercises)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PatchProgramDayRequest() when $default != null:
        return $default(_that.sessionName, _that.focus, _that.exercises);
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
    TResult Function(String? sessionName, List<MuscleGroup>? focus,
            List<CustomExercise>? exercises)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchProgramDayRequest():
        return $default(_that.sessionName, _that.focus, _that.exercises);
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
    TResult? Function(String? sessionName, List<MuscleGroup>? focus,
            List<CustomExercise>? exercises)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchProgramDayRequest() when $default != null:
        return $default(_that.sessionName, _that.focus, _that.exercises);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PatchProgramDayRequest implements PatchProgramDayRequest {
  const _PatchProgramDayRequest(
      {this.sessionName,
      final List<MuscleGroup>? focus,
      final List<CustomExercise>? exercises})
      : _focus = focus,
        _exercises = exercises;
  factory _PatchProgramDayRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchProgramDayRequestFromJson(json);

  @override
  final String? sessionName;
  final List<MuscleGroup>? _focus;
  @override
  List<MuscleGroup>? get focus {
    final value = _focus;
    if (value == null) return null;
    if (_focus is EqualUnmodifiableListView) return _focus;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<CustomExercise>? _exercises;
  @override
  List<CustomExercise>? get exercises {
    final value = _exercises;
    if (value == null) return null;
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of PatchProgramDayRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PatchProgramDayRequestCopyWith<_PatchProgramDayRequest> get copyWith =>
      __$PatchProgramDayRequestCopyWithImpl<_PatchProgramDayRequest>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PatchProgramDayRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PatchProgramDayRequest &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other._focus, _focus) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      sessionName,
      const DeepCollectionEquality().hash(_focus),
      const DeepCollectionEquality().hash(_exercises));

  @override
  String toString() {
    return 'PatchProgramDayRequest(sessionName: $sessionName, focus: $focus, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class _$PatchProgramDayRequestCopyWith<$Res>
    implements $PatchProgramDayRequestCopyWith<$Res> {
  factory _$PatchProgramDayRequestCopyWith(_PatchProgramDayRequest value,
          $Res Function(_PatchProgramDayRequest) _then) =
      __$PatchProgramDayRequestCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? sessionName,
      List<MuscleGroup>? focus,
      List<CustomExercise>? exercises});
}

/// @nodoc
class __$PatchProgramDayRequestCopyWithImpl<$Res>
    implements _$PatchProgramDayRequestCopyWith<$Res> {
  __$PatchProgramDayRequestCopyWithImpl(this._self, this._then);

  final _PatchProgramDayRequest _self;
  final $Res Function(_PatchProgramDayRequest) _then;

  /// Create a copy of PatchProgramDayRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sessionName = freezed,
    Object? focus = freezed,
    Object? exercises = freezed,
  }) {
    return _then(_PatchProgramDayRequest(
      sessionName: freezed == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String?,
      focus: freezed == focus
          ? _self._focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>?,
      exercises: freezed == exercises
          ? _self._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<CustomExercise>?,
    ));
  }
}

/// @nodoc
mixin _$TemplateDay {
  int get dayOfWeek;
  String get sessionName;
  List<MuscleGroup> get muscles;

  /// Create a copy of TemplateDay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TemplateDayCopyWith<TemplateDay> get copyWith =>
      _$TemplateDayCopyWithImpl<TemplateDay>(this as TemplateDay, _$identity);

  /// Serializes this TemplateDay to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TemplateDay &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other.muscles, muscles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, dayOfWeek, sessionName,
      const DeepCollectionEquality().hash(muscles));

  @override
  String toString() {
    return 'TemplateDay(dayOfWeek: $dayOfWeek, sessionName: $sessionName, muscles: $muscles)';
  }
}

/// @nodoc
abstract mixin class $TemplateDayCopyWith<$Res> {
  factory $TemplateDayCopyWith(
          TemplateDay value, $Res Function(TemplateDay) _then) =
      _$TemplateDayCopyWithImpl;
  @useResult
  $Res call({int dayOfWeek, String sessionName, List<MuscleGroup> muscles});
}

/// @nodoc
class _$TemplateDayCopyWithImpl<$Res> implements $TemplateDayCopyWith<$Res> {
  _$TemplateDayCopyWithImpl(this._self, this._then);

  final TemplateDay _self;
  final $Res Function(TemplateDay) _then;

  /// Create a copy of TemplateDay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dayOfWeek = null,
    Object? sessionName = null,
    Object? muscles = null,
  }) {
    return _then(_self.copyWith(
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      sessionName: null == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String,
      muscles: null == muscles
          ? _self.muscles
          : muscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
    ));
  }
}

/// Adds pattern-matching-related methods to [TemplateDay].
extension TemplateDayPatterns on TemplateDay {
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
    TResult Function(_TemplateDay value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TemplateDay() when $default != null:
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
    TResult Function(_TemplateDay value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplateDay():
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
    TResult? Function(_TemplateDay value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplateDay() when $default != null:
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
            int dayOfWeek, String sessionName, List<MuscleGroup> muscles)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TemplateDay() when $default != null:
        return $default(_that.dayOfWeek, _that.sessionName, _that.muscles);
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
            int dayOfWeek, String sessionName, List<MuscleGroup> muscles)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplateDay():
        return $default(_that.dayOfWeek, _that.sessionName, _that.muscles);
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
            int dayOfWeek, String sessionName, List<MuscleGroup> muscles)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplateDay() when $default != null:
        return $default(_that.dayOfWeek, _that.sessionName, _that.muscles);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TemplateDay implements TemplateDay {
  const _TemplateDay(
      {required this.dayOfWeek,
      required this.sessionName,
      required final List<MuscleGroup> muscles})
      : _muscles = muscles;
  factory _TemplateDay.fromJson(Map<String, dynamic> json) =>
      _$TemplateDayFromJson(json);

  @override
  final int dayOfWeek;
  @override
  final String sessionName;
  final List<MuscleGroup> _muscles;
  @override
  List<MuscleGroup> get muscles {
    if (_muscles is EqualUnmodifiableListView) return _muscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_muscles);
  }

  /// Create a copy of TemplateDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TemplateDayCopyWith<_TemplateDay> get copyWith =>
      __$TemplateDayCopyWithImpl<_TemplateDay>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TemplateDayToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TemplateDay &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other._muscles, _muscles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, dayOfWeek, sessionName,
      const DeepCollectionEquality().hash(_muscles));

  @override
  String toString() {
    return 'TemplateDay(dayOfWeek: $dayOfWeek, sessionName: $sessionName, muscles: $muscles)';
  }
}

/// @nodoc
abstract mixin class _$TemplateDayCopyWith<$Res>
    implements $TemplateDayCopyWith<$Res> {
  factory _$TemplateDayCopyWith(
          _TemplateDay value, $Res Function(_TemplateDay) _then) =
      __$TemplateDayCopyWithImpl;
  @override
  @useResult
  $Res call({int dayOfWeek, String sessionName, List<MuscleGroup> muscles});
}

/// @nodoc
class __$TemplateDayCopyWithImpl<$Res> implements _$TemplateDayCopyWith<$Res> {
  __$TemplateDayCopyWithImpl(this._self, this._then);

  final _TemplateDay _self;
  final $Res Function(_TemplateDay) _then;

  /// Create a copy of TemplateDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dayOfWeek = null,
    Object? sessionName = null,
    Object? muscles = null,
  }) {
    return _then(_TemplateDay(
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      sessionName: null == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String,
      muscles: null == muscles
          ? _self._muscles
          : muscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
    ));
  }
}

/// @nodoc
mixin _$ProgramTemplate {
  String get slug;
  String get name;
  int get daysPerWeek;
  TemplateLevel get level;
  int get approxMinutes;
  String get summary;
  List<TemplateDay> get days;

  /// Create a copy of ProgramTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgramTemplateCopyWith<ProgramTemplate> get copyWith =>
      _$ProgramTemplateCopyWithImpl<ProgramTemplate>(
          this as ProgramTemplate, _$identity);

  /// Serializes this ProgramTemplate to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProgramTemplate &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.approxMinutes, approxMinutes) ||
                other.approxMinutes == approxMinutes) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality().equals(other.days, days));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, slug, name, daysPerWeek, level,
      approxMinutes, summary, const DeepCollectionEquality().hash(days));

  @override
  String toString() {
    return 'ProgramTemplate(slug: $slug, name: $name, daysPerWeek: $daysPerWeek, level: $level, approxMinutes: $approxMinutes, summary: $summary, days: $days)';
  }
}

/// @nodoc
abstract mixin class $ProgramTemplateCopyWith<$Res> {
  factory $ProgramTemplateCopyWith(
          ProgramTemplate value, $Res Function(ProgramTemplate) _then) =
      _$ProgramTemplateCopyWithImpl;
  @useResult
  $Res call(
      {String slug,
      String name,
      int daysPerWeek,
      TemplateLevel level,
      int approxMinutes,
      String summary,
      List<TemplateDay> days});
}

/// @nodoc
class _$ProgramTemplateCopyWithImpl<$Res>
    implements $ProgramTemplateCopyWith<$Res> {
  _$ProgramTemplateCopyWithImpl(this._self, this._then);

  final ProgramTemplate _self;
  final $Res Function(ProgramTemplate) _then;

  /// Create a copy of ProgramTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slug = null,
    Object? name = null,
    Object? daysPerWeek = null,
    Object? level = null,
    Object? approxMinutes = null,
    Object? summary = null,
    Object? days = null,
  }) {
    return _then(_self.copyWith(
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      daysPerWeek: null == daysPerWeek
          ? _self.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int,
      level: null == level
          ? _self.level
          : level // ignore: cast_nullable_to_non_nullable
              as TemplateLevel,
      approxMinutes: null == approxMinutes
          ? _self.approxMinutes
          : approxMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      days: null == days
          ? _self.days
          : days // ignore: cast_nullable_to_non_nullable
              as List<TemplateDay>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProgramTemplate].
extension ProgramTemplatePatterns on ProgramTemplate {
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
    TResult Function(_ProgramTemplate value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgramTemplate() when $default != null:
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
    TResult Function(_ProgramTemplate value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgramTemplate():
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
    TResult? Function(_ProgramTemplate value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgramTemplate() when $default != null:
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
            String slug,
            String name,
            int daysPerWeek,
            TemplateLevel level,
            int approxMinutes,
            String summary,
            List<TemplateDay> days)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgramTemplate() when $default != null:
        return $default(_that.slug, _that.name, _that.daysPerWeek, _that.level,
            _that.approxMinutes, _that.summary, _that.days);
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
            String slug,
            String name,
            int daysPerWeek,
            TemplateLevel level,
            int approxMinutes,
            String summary,
            List<TemplateDay> days)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgramTemplate():
        return $default(_that.slug, _that.name, _that.daysPerWeek, _that.level,
            _that.approxMinutes, _that.summary, _that.days);
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
            String slug,
            String name,
            int daysPerWeek,
            TemplateLevel level,
            int approxMinutes,
            String summary,
            List<TemplateDay> days)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgramTemplate() when $default != null:
        return $default(_that.slug, _that.name, _that.daysPerWeek, _that.level,
            _that.approxMinutes, _that.summary, _that.days);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProgramTemplate implements ProgramTemplate {
  const _ProgramTemplate(
      {required this.slug,
      required this.name,
      required this.daysPerWeek,
      required this.level,
      required this.approxMinutes,
      required this.summary,
      required final List<TemplateDay> days})
      : _days = days;
  factory _ProgramTemplate.fromJson(Map<String, dynamic> json) =>
      _$ProgramTemplateFromJson(json);

  @override
  final String slug;
  @override
  final String name;
  @override
  final int daysPerWeek;
  @override
  final TemplateLevel level;
  @override
  final int approxMinutes;
  @override
  final String summary;
  final List<TemplateDay> _days;
  @override
  List<TemplateDay> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  /// Create a copy of ProgramTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgramTemplateCopyWith<_ProgramTemplate> get copyWith =>
      __$ProgramTemplateCopyWithImpl<_ProgramTemplate>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgramTemplateToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProgramTemplate &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.approxMinutes, approxMinutes) ||
                other.approxMinutes == approxMinutes) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality().equals(other._days, _days));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, slug, name, daysPerWeek, level,
      approxMinutes, summary, const DeepCollectionEquality().hash(_days));

  @override
  String toString() {
    return 'ProgramTemplate(slug: $slug, name: $name, daysPerWeek: $daysPerWeek, level: $level, approxMinutes: $approxMinutes, summary: $summary, days: $days)';
  }
}

/// @nodoc
abstract mixin class _$ProgramTemplateCopyWith<$Res>
    implements $ProgramTemplateCopyWith<$Res> {
  factory _$ProgramTemplateCopyWith(
          _ProgramTemplate value, $Res Function(_ProgramTemplate) _then) =
      __$ProgramTemplateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String slug,
      String name,
      int daysPerWeek,
      TemplateLevel level,
      int approxMinutes,
      String summary,
      List<TemplateDay> days});
}

/// @nodoc
class __$ProgramTemplateCopyWithImpl<$Res>
    implements _$ProgramTemplateCopyWith<$Res> {
  __$ProgramTemplateCopyWithImpl(this._self, this._then);

  final _ProgramTemplate _self;
  final $Res Function(_ProgramTemplate) _then;

  /// Create a copy of ProgramTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? slug = null,
    Object? name = null,
    Object? daysPerWeek = null,
    Object? level = null,
    Object? approxMinutes = null,
    Object? summary = null,
    Object? days = null,
  }) {
    return _then(_ProgramTemplate(
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      daysPerWeek: null == daysPerWeek
          ? _self.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int,
      level: null == level
          ? _self.level
          : level // ignore: cast_nullable_to_non_nullable
              as TemplateLevel,
      approxMinutes: null == approxMinutes
          ? _self.approxMinutes
          : approxMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      days: null == days
          ? _self._days
          : days // ignore: cast_nullable_to_non_nullable
              as List<TemplateDay>,
    ));
  }
}

/// @nodoc
mixin _$PreviewExercise {
  String get exerciseId;
  String get slug;
  String get name;
  MovementPattern get movementPattern;
  List<Equipment> get equipment;
  Difficulty get difficulty;
  bool get isUnilateral;
  List<MuscleGroup> get primaryMuscles;
  int get orderIndex;
  int get setCount;
  int get repMin;
  int get repMax;
  int get targetRir;
  double get incrementKg;
  String? get reason;
  List<PlannedSet> get sets;

  /// Create a copy of PreviewExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PreviewExerciseCopyWith<PreviewExercise> get copyWith =>
      _$PreviewExerciseCopyWithImpl<PreviewExercise>(
          this as PreviewExercise, _$identity);

  /// Serializes this PreviewExercise to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PreviewExercise &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
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
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.setCount, setCount) ||
                other.setCount == setCount) &&
            (identical(other.repMin, repMin) || other.repMin == repMin) &&
            (identical(other.repMax, repMax) || other.repMax == repMax) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            const DeepCollectionEquality().equals(other.sets, sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      exerciseId,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(equipment),
      difficulty,
      isUnilateral,
      const DeepCollectionEquality().hash(primaryMuscles),
      orderIndex,
      setCount,
      repMin,
      repMax,
      targetRir,
      incrementKg,
      reason,
      const DeepCollectionEquality().hash(sets));

  @override
  String toString() {
    return 'PreviewExercise(exerciseId: $exerciseId, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, isUnilateral: $isUnilateral, primaryMuscles: $primaryMuscles, orderIndex: $orderIndex, setCount: $setCount, repMin: $repMin, repMax: $repMax, targetRir: $targetRir, incrementKg: $incrementKg, reason: $reason, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class $PreviewExerciseCopyWith<$Res> {
  factory $PreviewExerciseCopyWith(
          PreviewExercise value, $Res Function(PreviewExercise) _then) =
      _$PreviewExerciseCopyWithImpl;
  @useResult
  $Res call(
      {String exerciseId,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      bool isUnilateral,
      List<MuscleGroup> primaryMuscles,
      int orderIndex,
      int setCount,
      int repMin,
      int repMax,
      int targetRir,
      double incrementKg,
      String? reason,
      List<PlannedSet> sets});
}

/// @nodoc
class _$PreviewExerciseCopyWithImpl<$Res>
    implements $PreviewExerciseCopyWith<$Res> {
  _$PreviewExerciseCopyWithImpl(this._self, this._then);

  final PreviewExercise _self;
  final $Res Function(PreviewExercise) _then;

  /// Create a copy of PreviewExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? isUnilateral = null,
    Object? primaryMuscles = null,
    Object? orderIndex = null,
    Object? setCount = null,
    Object? repMin = null,
    Object? repMax = null,
    Object? targetRir = null,
    Object? incrementKg = null,
    Object? reason = freezed,
    Object? sets = null,
  }) {
    return _then(_self.copyWith(
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
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
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      setCount: null == setCount
          ? _self.setCount
          : setCount // ignore: cast_nullable_to_non_nullable
              as int,
      repMin: null == repMin
          ? _self.repMin
          : repMin // ignore: cast_nullable_to_non_nullable
              as int,
      repMax: null == repMax
          ? _self.repMax
          : repMax // ignore: cast_nullable_to_non_nullable
              as int,
      targetRir: null == targetRir
          ? _self.targetRir
          : targetRir // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      sets: null == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PreviewExercise].
extension PreviewExercisePatterns on PreviewExercise {
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
    TResult Function(_PreviewExercise value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PreviewExercise() when $default != null:
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
    TResult Function(_PreviewExercise value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PreviewExercise():
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
    TResult? Function(_PreviewExercise value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PreviewExercise() when $default != null:
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
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            int orderIndex,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double incrementKg,
            String? reason,
            List<PlannedSet> sets)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PreviewExercise() when $default != null:
        return $default(
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.orderIndex,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.reason,
            _that.sets);
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
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            int orderIndex,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double incrementKg,
            String? reason,
            List<PlannedSet> sets)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PreviewExercise():
        return $default(
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.orderIndex,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.reason,
            _that.sets);
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
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            bool isUnilateral,
            List<MuscleGroup> primaryMuscles,
            int orderIndex,
            int setCount,
            int repMin,
            int repMax,
            int targetRir,
            double incrementKg,
            String? reason,
            List<PlannedSet> sets)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PreviewExercise() when $default != null:
        return $default(
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.isUnilateral,
            _that.primaryMuscles,
            _that.orderIndex,
            _that.setCount,
            _that.repMin,
            _that.repMax,
            _that.targetRir,
            _that.incrementKg,
            _that.reason,
            _that.sets);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PreviewExercise implements PreviewExercise {
  const _PreviewExercise(
      {required this.exerciseId,
      required this.slug,
      required this.name,
      required this.movementPattern,
      required final List<Equipment> equipment,
      required this.difficulty,
      required this.isUnilateral,
      required final List<MuscleGroup> primaryMuscles,
      required this.orderIndex,
      required this.setCount,
      required this.repMin,
      required this.repMax,
      required this.targetRir,
      required this.incrementKg,
      required this.reason,
      required final List<PlannedSet> sets})
      : _equipment = equipment,
        _primaryMuscles = primaryMuscles,
        _sets = sets;
  factory _PreviewExercise.fromJson(Map<String, dynamic> json) =>
      _$PreviewExerciseFromJson(json);

  @override
  final String exerciseId;
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
  final int orderIndex;
  @override
  final int setCount;
  @override
  final int repMin;
  @override
  final int repMax;
  @override
  final int targetRir;
  @override
  final double incrementKg;
  @override
  final String? reason;
  final List<PlannedSet> _sets;
  @override
  List<PlannedSet> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  /// Create a copy of PreviewExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PreviewExerciseCopyWith<_PreviewExercise> get copyWith =>
      __$PreviewExerciseCopyWithImpl<_PreviewExercise>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PreviewExerciseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PreviewExercise &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
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
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.setCount, setCount) ||
                other.setCount == setCount) &&
            (identical(other.repMin, repMin) || other.repMin == repMin) &&
            (identical(other.repMax, repMax) || other.repMax == repMax) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            const DeepCollectionEquality().equals(other._sets, _sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      exerciseId,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(_equipment),
      difficulty,
      isUnilateral,
      const DeepCollectionEquality().hash(_primaryMuscles),
      orderIndex,
      setCount,
      repMin,
      repMax,
      targetRir,
      incrementKg,
      reason,
      const DeepCollectionEquality().hash(_sets));

  @override
  String toString() {
    return 'PreviewExercise(exerciseId: $exerciseId, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, isUnilateral: $isUnilateral, primaryMuscles: $primaryMuscles, orderIndex: $orderIndex, setCount: $setCount, repMin: $repMin, repMax: $repMax, targetRir: $targetRir, incrementKg: $incrementKg, reason: $reason, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class _$PreviewExerciseCopyWith<$Res>
    implements $PreviewExerciseCopyWith<$Res> {
  factory _$PreviewExerciseCopyWith(
          _PreviewExercise value, $Res Function(_PreviewExercise) _then) =
      __$PreviewExerciseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String exerciseId,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      bool isUnilateral,
      List<MuscleGroup> primaryMuscles,
      int orderIndex,
      int setCount,
      int repMin,
      int repMax,
      int targetRir,
      double incrementKg,
      String? reason,
      List<PlannedSet> sets});
}

/// @nodoc
class __$PreviewExerciseCopyWithImpl<$Res>
    implements _$PreviewExerciseCopyWith<$Res> {
  __$PreviewExerciseCopyWithImpl(this._self, this._then);

  final _PreviewExercise _self;
  final $Res Function(_PreviewExercise) _then;

  /// Create a copy of PreviewExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? isUnilateral = null,
    Object? primaryMuscles = null,
    Object? orderIndex = null,
    Object? setCount = null,
    Object? repMin = null,
    Object? repMax = null,
    Object? targetRir = null,
    Object? incrementKg = null,
    Object? reason = freezed,
    Object? sets = null,
  }) {
    return _then(_PreviewExercise(
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
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
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      setCount: null == setCount
          ? _self.setCount
          : setCount // ignore: cast_nullable_to_non_nullable
              as int,
      repMin: null == repMin
          ? _self.repMin
          : repMin // ignore: cast_nullable_to_non_nullable
              as int,
      repMax: null == repMax
          ? _self.repMax
          : repMax // ignore: cast_nullable_to_non_nullable
              as int,
      targetRir: null == targetRir
          ? _self.targetRir
          : targetRir // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      sets: null == sets
          ? _self._sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>,
    ));
  }
}

/// @nodoc
mixin _$PreviewDay {
  int get dayOfWeek;
  String get sessionName;
  List<MuscleGroup> get focus;
  bool get isRest;
  int get estimatedMinutes;
  List<PreviewExercise> get exercises;

  /// Create a copy of PreviewDay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PreviewDayCopyWith<PreviewDay> get copyWith =>
      _$PreviewDayCopyWithImpl<PreviewDay>(this as PreviewDay, _$identity);

  /// Serializes this PreviewDay to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PreviewDay &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other.focus, focus) &&
            (identical(other.isRest, isRest) || other.isRest == isRest) &&
            (identical(other.estimatedMinutes, estimatedMinutes) ||
                other.estimatedMinutes == estimatedMinutes) &&
            const DeepCollectionEquality().equals(other.exercises, exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dayOfWeek,
      sessionName,
      const DeepCollectionEquality().hash(focus),
      isRest,
      estimatedMinutes,
      const DeepCollectionEquality().hash(exercises));

  @override
  String toString() {
    return 'PreviewDay(dayOfWeek: $dayOfWeek, sessionName: $sessionName, focus: $focus, isRest: $isRest, estimatedMinutes: $estimatedMinutes, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class $PreviewDayCopyWith<$Res> {
  factory $PreviewDayCopyWith(
          PreviewDay value, $Res Function(PreviewDay) _then) =
      _$PreviewDayCopyWithImpl;
  @useResult
  $Res call(
      {int dayOfWeek,
      String sessionName,
      List<MuscleGroup> focus,
      bool isRest,
      int estimatedMinutes,
      List<PreviewExercise> exercises});
}

/// @nodoc
class _$PreviewDayCopyWithImpl<$Res> implements $PreviewDayCopyWith<$Res> {
  _$PreviewDayCopyWithImpl(this._self, this._then);

  final PreviewDay _self;
  final $Res Function(PreviewDay) _then;

  /// Create a copy of PreviewDay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dayOfWeek = null,
    Object? sessionName = null,
    Object? focus = null,
    Object? isRest = null,
    Object? estimatedMinutes = null,
    Object? exercises = null,
  }) {
    return _then(_self.copyWith(
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      sessionName: null == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String,
      focus: null == focus
          ? _self.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      isRest: null == isRest
          ? _self.isRest
          : isRest // ignore: cast_nullable_to_non_nullable
              as bool,
      estimatedMinutes: null == estimatedMinutes
          ? _self.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      exercises: null == exercises
          ? _self.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<PreviewExercise>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PreviewDay].
extension PreviewDayPatterns on PreviewDay {
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
    TResult Function(_PreviewDay value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PreviewDay() when $default != null:
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
    TResult Function(_PreviewDay value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PreviewDay():
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
    TResult? Function(_PreviewDay value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PreviewDay() when $default != null:
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
    TResult Function(int dayOfWeek, String sessionName, List<MuscleGroup> focus,
            bool isRest, int estimatedMinutes, List<PreviewExercise> exercises)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PreviewDay() when $default != null:
        return $default(_that.dayOfWeek, _that.sessionName, _that.focus,
            _that.isRest, _that.estimatedMinutes, _that.exercises);
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
    TResult Function(int dayOfWeek, String sessionName, List<MuscleGroup> focus,
            bool isRest, int estimatedMinutes, List<PreviewExercise> exercises)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PreviewDay():
        return $default(_that.dayOfWeek, _that.sessionName, _that.focus,
            _that.isRest, _that.estimatedMinutes, _that.exercises);
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
            int dayOfWeek,
            String sessionName,
            List<MuscleGroup> focus,
            bool isRest,
            int estimatedMinutes,
            List<PreviewExercise> exercises)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PreviewDay() when $default != null:
        return $default(_that.dayOfWeek, _that.sessionName, _that.focus,
            _that.isRest, _that.estimatedMinutes, _that.exercises);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PreviewDay implements PreviewDay {
  const _PreviewDay(
      {required this.dayOfWeek,
      required this.sessionName,
      required final List<MuscleGroup> focus,
      required this.isRest,
      required this.estimatedMinutes,
      required final List<PreviewExercise> exercises})
      : _focus = focus,
        _exercises = exercises;
  factory _PreviewDay.fromJson(Map<String, dynamic> json) =>
      _$PreviewDayFromJson(json);

  @override
  final int dayOfWeek;
  @override
  final String sessionName;
  final List<MuscleGroup> _focus;
  @override
  List<MuscleGroup> get focus {
    if (_focus is EqualUnmodifiableListView) return _focus;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_focus);
  }

  @override
  final bool isRest;
  @override
  final int estimatedMinutes;
  final List<PreviewExercise> _exercises;
  @override
  List<PreviewExercise> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  /// Create a copy of PreviewDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PreviewDayCopyWith<_PreviewDay> get copyWith =>
      __$PreviewDayCopyWithImpl<_PreviewDay>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PreviewDayToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PreviewDay &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            const DeepCollectionEquality().equals(other._focus, _focus) &&
            (identical(other.isRest, isRest) || other.isRest == isRest) &&
            (identical(other.estimatedMinutes, estimatedMinutes) ||
                other.estimatedMinutes == estimatedMinutes) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dayOfWeek,
      sessionName,
      const DeepCollectionEquality().hash(_focus),
      isRest,
      estimatedMinutes,
      const DeepCollectionEquality().hash(_exercises));

  @override
  String toString() {
    return 'PreviewDay(dayOfWeek: $dayOfWeek, sessionName: $sessionName, focus: $focus, isRest: $isRest, estimatedMinutes: $estimatedMinutes, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class _$PreviewDayCopyWith<$Res>
    implements $PreviewDayCopyWith<$Res> {
  factory _$PreviewDayCopyWith(
          _PreviewDay value, $Res Function(_PreviewDay) _then) =
      __$PreviewDayCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int dayOfWeek,
      String sessionName,
      List<MuscleGroup> focus,
      bool isRest,
      int estimatedMinutes,
      List<PreviewExercise> exercises});
}

/// @nodoc
class __$PreviewDayCopyWithImpl<$Res> implements _$PreviewDayCopyWith<$Res> {
  __$PreviewDayCopyWithImpl(this._self, this._then);

  final _PreviewDay _self;
  final $Res Function(_PreviewDay) _then;

  /// Create a copy of PreviewDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dayOfWeek = null,
    Object? sessionName = null,
    Object? focus = null,
    Object? isRest = null,
    Object? estimatedMinutes = null,
    Object? exercises = null,
  }) {
    return _then(_PreviewDay(
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      sessionName: null == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String,
      focus: null == focus
          ? _self._focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      isRest: null == isRest
          ? _self.isRest
          : isRest // ignore: cast_nullable_to_non_nullable
              as bool,
      estimatedMinutes: null == estimatedMinutes
          ? _self.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      exercises: null == exercises
          ? _self._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<PreviewExercise>,
    ));
  }
}

/// @nodoc
mixin _$TemplatePreview {
  ProgramTemplate get template;
  List<PreviewDay> get days;
  Map<String, double> get weeklyVolume;
  List<String> get rationale;
  List<VolumeShortfall> get shortfalls;

  /// Create a copy of TemplatePreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TemplatePreviewCopyWith<TemplatePreview> get copyWith =>
      _$TemplatePreviewCopyWithImpl<TemplatePreview>(
          this as TemplatePreview, _$identity);

  /// Serializes this TemplatePreview to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TemplatePreview &&
            (identical(other.template, template) ||
                other.template == template) &&
            const DeepCollectionEquality().equals(other.days, days) &&
            const DeepCollectionEquality()
                .equals(other.weeklyVolume, weeklyVolume) &&
            const DeepCollectionEquality().equals(other.rationale, rationale) &&
            const DeepCollectionEquality()
                .equals(other.shortfalls, shortfalls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      template,
      const DeepCollectionEquality().hash(days),
      const DeepCollectionEquality().hash(weeklyVolume),
      const DeepCollectionEquality().hash(rationale),
      const DeepCollectionEquality().hash(shortfalls));

  @override
  String toString() {
    return 'TemplatePreview(template: $template, days: $days, weeklyVolume: $weeklyVolume, rationale: $rationale, shortfalls: $shortfalls)';
  }
}

/// @nodoc
abstract mixin class $TemplatePreviewCopyWith<$Res> {
  factory $TemplatePreviewCopyWith(
          TemplatePreview value, $Res Function(TemplatePreview) _then) =
      _$TemplatePreviewCopyWithImpl;
  @useResult
  $Res call(
      {ProgramTemplate template,
      List<PreviewDay> days,
      Map<String, double> weeklyVolume,
      List<String> rationale,
      List<VolumeShortfall> shortfalls});

  $ProgramTemplateCopyWith<$Res> get template;
}

/// @nodoc
class _$TemplatePreviewCopyWithImpl<$Res>
    implements $TemplatePreviewCopyWith<$Res> {
  _$TemplatePreviewCopyWithImpl(this._self, this._then);

  final TemplatePreview _self;
  final $Res Function(TemplatePreview) _then;

  /// Create a copy of TemplatePreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? template = null,
    Object? days = null,
    Object? weeklyVolume = null,
    Object? rationale = null,
    Object? shortfalls = null,
  }) {
    return _then(_self.copyWith(
      template: null == template
          ? _self.template
          : template // ignore: cast_nullable_to_non_nullable
              as ProgramTemplate,
      days: null == days
          ? _self.days
          : days // ignore: cast_nullable_to_non_nullable
              as List<PreviewDay>,
      weeklyVolume: null == weeklyVolume
          ? _self.weeklyVolume
          : weeklyVolume // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      rationale: null == rationale
          ? _self.rationale
          : rationale // ignore: cast_nullable_to_non_nullable
              as List<String>,
      shortfalls: null == shortfalls
          ? _self.shortfalls
          : shortfalls // ignore: cast_nullable_to_non_nullable
              as List<VolumeShortfall>,
    ));
  }

  /// Create a copy of TemplatePreview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgramTemplateCopyWith<$Res> get template {
    return $ProgramTemplateCopyWith<$Res>(_self.template, (value) {
      return _then(_self.copyWith(template: value));
    });
  }
}

/// Adds pattern-matching-related methods to [TemplatePreview].
extension TemplatePreviewPatterns on TemplatePreview {
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
    TResult Function(_TemplatePreview value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TemplatePreview() when $default != null:
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
    TResult Function(_TemplatePreview value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplatePreview():
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
    TResult? Function(_TemplatePreview value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplatePreview() when $default != null:
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
            ProgramTemplate template,
            List<PreviewDay> days,
            Map<String, double> weeklyVolume,
            List<String> rationale,
            List<VolumeShortfall> shortfalls)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TemplatePreview() when $default != null:
        return $default(_that.template, _that.days, _that.weeklyVolume,
            _that.rationale, _that.shortfalls);
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
            ProgramTemplate template,
            List<PreviewDay> days,
            Map<String, double> weeklyVolume,
            List<String> rationale,
            List<VolumeShortfall> shortfalls)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplatePreview():
        return $default(_that.template, _that.days, _that.weeklyVolume,
            _that.rationale, _that.shortfalls);
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
            ProgramTemplate template,
            List<PreviewDay> days,
            Map<String, double> weeklyVolume,
            List<String> rationale,
            List<VolumeShortfall> shortfalls)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplatePreview() when $default != null:
        return $default(_that.template, _that.days, _that.weeklyVolume,
            _that.rationale, _that.shortfalls);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TemplatePreview implements TemplatePreview {
  const _TemplatePreview(
      {required this.template,
      required final List<PreviewDay> days,
      required final Map<String, double> weeklyVolume,
      required final List<String> rationale,
      required final List<VolumeShortfall> shortfalls})
      : _days = days,
        _weeklyVolume = weeklyVolume,
        _rationale = rationale,
        _shortfalls = shortfalls;
  factory _TemplatePreview.fromJson(Map<String, dynamic> json) =>
      _$TemplatePreviewFromJson(json);

  @override
  final ProgramTemplate template;
  final List<PreviewDay> _days;
  @override
  List<PreviewDay> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  final Map<String, double> _weeklyVolume;
  @override
  Map<String, double> get weeklyVolume {
    if (_weeklyVolume is EqualUnmodifiableMapView) return _weeklyVolume;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_weeklyVolume);
  }

  final List<String> _rationale;
  @override
  List<String> get rationale {
    if (_rationale is EqualUnmodifiableListView) return _rationale;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rationale);
  }

  final List<VolumeShortfall> _shortfalls;
  @override
  List<VolumeShortfall> get shortfalls {
    if (_shortfalls is EqualUnmodifiableListView) return _shortfalls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shortfalls);
  }

  /// Create a copy of TemplatePreview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TemplatePreviewCopyWith<_TemplatePreview> get copyWith =>
      __$TemplatePreviewCopyWithImpl<_TemplatePreview>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TemplatePreviewToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TemplatePreview &&
            (identical(other.template, template) ||
                other.template == template) &&
            const DeepCollectionEquality().equals(other._days, _days) &&
            const DeepCollectionEquality()
                .equals(other._weeklyVolume, _weeklyVolume) &&
            const DeepCollectionEquality()
                .equals(other._rationale, _rationale) &&
            const DeepCollectionEquality()
                .equals(other._shortfalls, _shortfalls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      template,
      const DeepCollectionEquality().hash(_days),
      const DeepCollectionEquality().hash(_weeklyVolume),
      const DeepCollectionEquality().hash(_rationale),
      const DeepCollectionEquality().hash(_shortfalls));

  @override
  String toString() {
    return 'TemplatePreview(template: $template, days: $days, weeklyVolume: $weeklyVolume, rationale: $rationale, shortfalls: $shortfalls)';
  }
}

/// @nodoc
abstract mixin class _$TemplatePreviewCopyWith<$Res>
    implements $TemplatePreviewCopyWith<$Res> {
  factory _$TemplatePreviewCopyWith(
          _TemplatePreview value, $Res Function(_TemplatePreview) _then) =
      __$TemplatePreviewCopyWithImpl;
  @override
  @useResult
  $Res call(
      {ProgramTemplate template,
      List<PreviewDay> days,
      Map<String, double> weeklyVolume,
      List<String> rationale,
      List<VolumeShortfall> shortfalls});

  @override
  $ProgramTemplateCopyWith<$Res> get template;
}

/// @nodoc
class __$TemplatePreviewCopyWithImpl<$Res>
    implements _$TemplatePreviewCopyWith<$Res> {
  __$TemplatePreviewCopyWithImpl(this._self, this._then);

  final _TemplatePreview _self;
  final $Res Function(_TemplatePreview) _then;

  /// Create a copy of TemplatePreview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? template = null,
    Object? days = null,
    Object? weeklyVolume = null,
    Object? rationale = null,
    Object? shortfalls = null,
  }) {
    return _then(_TemplatePreview(
      template: null == template
          ? _self.template
          : template // ignore: cast_nullable_to_non_nullable
              as ProgramTemplate,
      days: null == days
          ? _self._days
          : days // ignore: cast_nullable_to_non_nullable
              as List<PreviewDay>,
      weeklyVolume: null == weeklyVolume
          ? _self._weeklyVolume
          : weeklyVolume // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      rationale: null == rationale
          ? _self._rationale
          : rationale // ignore: cast_nullable_to_non_nullable
              as List<String>,
      shortfalls: null == shortfalls
          ? _self._shortfalls
          : shortfalls // ignore: cast_nullable_to_non_nullable
              as List<VolumeShortfall>,
    ));
  }

  /// Create a copy of TemplatePreview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgramTemplateCopyWith<$Res> get template {
    return $ProgramTemplateCopyWith<$Res>(_self.template, (value) {
      return _then(_self.copyWith(template: value));
    });
  }
}

// dart format on
