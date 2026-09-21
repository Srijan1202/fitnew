// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetLog {
  String get id;
  String get clientSetId;
  int get setIndex;
  SetType get setType;
  double? get weightKg;
  int get reps;
  int? get rir;
  bool get isPr;
  String get loggedAt;
  String? get plannedSetId;

  /// Create a copy of SetLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SetLogCopyWith<SetLog> get copyWith =>
      _$SetLogCopyWithImpl<SetLog>(this as SetLog, _$identity);

  /// Serializes this SetLog to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SetLog &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientSetId, clientSetId) ||
                other.clientSetId == clientSetId) &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.setType, setType) || other.setType == setType) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir) &&
            (identical(other.isPr, isPr) || other.isPr == isPr) &&
            (identical(other.loggedAt, loggedAt) ||
                other.loggedAt == loggedAt) &&
            (identical(other.plannedSetId, plannedSetId) ||
                other.plannedSetId == plannedSetId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, clientSetId, setIndex,
      setType, weightKg, reps, rir, isPr, loggedAt, plannedSetId);

  @override
  String toString() {
    return 'SetLog(id: $id, clientSetId: $clientSetId, setIndex: $setIndex, setType: $setType, weightKg: $weightKg, reps: $reps, rir: $rir, isPr: $isPr, loggedAt: $loggedAt, plannedSetId: $plannedSetId)';
  }
}

/// @nodoc
abstract mixin class $SetLogCopyWith<$Res> {
  factory $SetLogCopyWith(SetLog value, $Res Function(SetLog) _then) =
      _$SetLogCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String clientSetId,
      int setIndex,
      SetType setType,
      double? weightKg,
      int reps,
      int? rir,
      bool isPr,
      String loggedAt,
      String? plannedSetId});
}

/// @nodoc
class _$SetLogCopyWithImpl<$Res> implements $SetLogCopyWith<$Res> {
  _$SetLogCopyWithImpl(this._self, this._then);

  final SetLog _self;
  final $Res Function(SetLog) _then;

  /// Create a copy of SetLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientSetId = null,
    Object? setIndex = null,
    Object? setType = null,
    Object? weightKg = freezed,
    Object? reps = null,
    Object? rir = freezed,
    Object? isPr = null,
    Object? loggedAt = null,
    Object? plannedSetId = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientSetId: null == clientSetId
          ? _self.clientSetId
          : clientSetId // ignore: cast_nullable_to_non_nullable
              as String,
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      setType: null == setType
          ? _self.setType
          : setType // ignore: cast_nullable_to_non_nullable
              as SetType,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
      isPr: null == isPr
          ? _self.isPr
          : isPr // ignore: cast_nullable_to_non_nullable
              as bool,
      loggedAt: null == loggedAt
          ? _self.loggedAt
          : loggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      plannedSetId: freezed == plannedSetId
          ? _self.plannedSetId
          : plannedSetId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SetLog].
extension SetLogPatterns on SetLog {
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
    TResult Function(_SetLog value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SetLog() when $default != null:
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
    TResult Function(_SetLog value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetLog():
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
    TResult? Function(_SetLog value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetLog() when $default != null:
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
            String clientSetId,
            int setIndex,
            SetType setType,
            double? weightKg,
            int reps,
            int? rir,
            bool isPr,
            String loggedAt,
            String? plannedSetId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SetLog() when $default != null:
        return $default(
            _that.id,
            _that.clientSetId,
            _that.setIndex,
            _that.setType,
            _that.weightKg,
            _that.reps,
            _that.rir,
            _that.isPr,
            _that.loggedAt,
            _that.plannedSetId);
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
            String clientSetId,
            int setIndex,
            SetType setType,
            double? weightKg,
            int reps,
            int? rir,
            bool isPr,
            String loggedAt,
            String? plannedSetId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetLog():
        return $default(
            _that.id,
            _that.clientSetId,
            _that.setIndex,
            _that.setType,
            _that.weightKg,
            _that.reps,
            _that.rir,
            _that.isPr,
            _that.loggedAt,
            _that.plannedSetId);
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
            String clientSetId,
            int setIndex,
            SetType setType,
            double? weightKg,
            int reps,
            int? rir,
            bool isPr,
            String loggedAt,
            String? plannedSetId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetLog() when $default != null:
        return $default(
            _that.id,
            _that.clientSetId,
            _that.setIndex,
            _that.setType,
            _that.weightKg,
            _that.reps,
            _that.rir,
            _that.isPr,
            _that.loggedAt,
            _that.plannedSetId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SetLog extends SetLog {
  const _SetLog(
      {required this.id,
      required this.clientSetId,
      required this.setIndex,
      required this.setType,
      required this.weightKg,
      required this.reps,
      required this.rir,
      required this.isPr,
      required this.loggedAt,
      required this.plannedSetId})
      : super._();
  factory _SetLog.fromJson(Map<String, dynamic> json) => _$SetLogFromJson(json);

  @override
  final String id;
  @override
  final String clientSetId;
  @override
  final int setIndex;
  @override
  final SetType setType;
  @override
  final double? weightKg;
  @override
  final int reps;
  @override
  final int? rir;
  @override
  final bool isPr;
  @override
  final String loggedAt;
  @override
  final String? plannedSetId;

  /// Create a copy of SetLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SetLogCopyWith<_SetLog> get copyWith =>
      __$SetLogCopyWithImpl<_SetLog>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SetLogToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SetLog &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientSetId, clientSetId) ||
                other.clientSetId == clientSetId) &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.setType, setType) || other.setType == setType) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir) &&
            (identical(other.isPr, isPr) || other.isPr == isPr) &&
            (identical(other.loggedAt, loggedAt) ||
                other.loggedAt == loggedAt) &&
            (identical(other.plannedSetId, plannedSetId) ||
                other.plannedSetId == plannedSetId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, clientSetId, setIndex,
      setType, weightKg, reps, rir, isPr, loggedAt, plannedSetId);

  @override
  String toString() {
    return 'SetLog(id: $id, clientSetId: $clientSetId, setIndex: $setIndex, setType: $setType, weightKg: $weightKg, reps: $reps, rir: $rir, isPr: $isPr, loggedAt: $loggedAt, plannedSetId: $plannedSetId)';
  }
}

/// @nodoc
abstract mixin class _$SetLogCopyWith<$Res> implements $SetLogCopyWith<$Res> {
  factory _$SetLogCopyWith(_SetLog value, $Res Function(_SetLog) _then) =
      __$SetLogCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String clientSetId,
      int setIndex,
      SetType setType,
      double? weightKg,
      int reps,
      int? rir,
      bool isPr,
      String loggedAt,
      String? plannedSetId});
}

/// @nodoc
class __$SetLogCopyWithImpl<$Res> implements _$SetLogCopyWith<$Res> {
  __$SetLogCopyWithImpl(this._self, this._then);

  final _SetLog _self;
  final $Res Function(_SetLog) _then;

  /// Create a copy of SetLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? clientSetId = null,
    Object? setIndex = null,
    Object? setType = null,
    Object? weightKg = freezed,
    Object? reps = null,
    Object? rir = freezed,
    Object? isPr = null,
    Object? loggedAt = null,
    Object? plannedSetId = freezed,
  }) {
    return _then(_SetLog(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientSetId: null == clientSetId
          ? _self.clientSetId
          : clientSetId // ignore: cast_nullable_to_non_nullable
              as String,
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      setType: null == setType
          ? _self.setType
          : setType // ignore: cast_nullable_to_non_nullable
              as SetType,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
      isPr: null == isPr
          ? _self.isPr
          : isPr // ignore: cast_nullable_to_non_nullable
              as bool,
      loggedAt: null == loggedAt
          ? _self.loggedAt
          : loggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      plannedSetId: freezed == plannedSetId
          ? _self.plannedSetId
          : plannedSetId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$LastSet {
  int get setIndex;
  double? get weightKg;
  int get reps;
  int? get rir;

  /// Create a copy of LastSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LastSetCopyWith<LastSet> get copyWith =>
      _$LastSetCopyWithImpl<LastSet>(this as LastSet, _$identity);

  /// Serializes this LastSet to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LastSet &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, setIndex, weightKg, reps, rir);

  @override
  String toString() {
    return 'LastSet(setIndex: $setIndex, weightKg: $weightKg, reps: $reps, rir: $rir)';
  }
}

/// @nodoc
abstract mixin class $LastSetCopyWith<$Res> {
  factory $LastSetCopyWith(LastSet value, $Res Function(LastSet) _then) =
      _$LastSetCopyWithImpl;
  @useResult
  $Res call({int setIndex, double? weightKg, int reps, int? rir});
}

/// @nodoc
class _$LastSetCopyWithImpl<$Res> implements $LastSetCopyWith<$Res> {
  _$LastSetCopyWithImpl(this._self, this._then);

  final LastSet _self;
  final $Res Function(LastSet) _then;

  /// Create a copy of LastSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setIndex = null,
    Object? weightKg = freezed,
    Object? reps = null,
    Object? rir = freezed,
  }) {
    return _then(_self.copyWith(
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [LastSet].
extension LastSetPatterns on LastSet {
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
    TResult Function(_LastSet value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LastSet() when $default != null:
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
    TResult Function(_LastSet value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LastSet():
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
    TResult? Function(_LastSet value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LastSet() when $default != null:
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
    TResult Function(int setIndex, double? weightKg, int reps, int? rir)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LastSet() when $default != null:
        return $default(_that.setIndex, _that.weightKg, _that.reps, _that.rir);
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
    TResult Function(int setIndex, double? weightKg, int reps, int? rir)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LastSet():
        return $default(_that.setIndex, _that.weightKg, _that.reps, _that.rir);
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
    TResult? Function(int setIndex, double? weightKg, int reps, int? rir)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LastSet() when $default != null:
        return $default(_that.setIndex, _that.weightKg, _that.reps, _that.rir);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LastSet implements LastSet {
  const _LastSet(
      {required this.setIndex,
      required this.weightKg,
      required this.reps,
      required this.rir});
  factory _LastSet.fromJson(Map<String, dynamic> json) =>
      _$LastSetFromJson(json);

  @override
  final int setIndex;
  @override
  final double? weightKg;
  @override
  final int reps;
  @override
  final int? rir;

  /// Create a copy of LastSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LastSetCopyWith<_LastSet> get copyWith =>
      __$LastSetCopyWithImpl<_LastSet>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LastSetToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LastSet &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, setIndex, weightKg, reps, rir);

  @override
  String toString() {
    return 'LastSet(setIndex: $setIndex, weightKg: $weightKg, reps: $reps, rir: $rir)';
  }
}

/// @nodoc
abstract mixin class _$LastSetCopyWith<$Res> implements $LastSetCopyWith<$Res> {
  factory _$LastSetCopyWith(_LastSet value, $Res Function(_LastSet) _then) =
      __$LastSetCopyWithImpl;
  @override
  @useResult
  $Res call({int setIndex, double? weightKg, int reps, int? rir});
}

/// @nodoc
class __$LastSetCopyWithImpl<$Res> implements _$LastSetCopyWith<$Res> {
  __$LastSetCopyWithImpl(this._self, this._then);

  final _LastSet _self;
  final $Res Function(_LastSet) _then;

  /// Create a copy of LastSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? setIndex = null,
    Object? weightKg = freezed,
    Object? reps = null,
    Object? rir = freezed,
  }) {
    return _then(_LastSet(
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
mixin _$LastPerformance {
  String get sessionId;
  String get completedAt;
  List<LastSet> get sets;

  /// Create a copy of LastPerformance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LastPerformanceCopyWith<LastPerformance> get copyWith =>
      _$LastPerformanceCopyWithImpl<LastPerformance>(
          this as LastPerformance, _$identity);

  /// Serializes this LastPerformance to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LastPerformance &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            const DeepCollectionEquality().equals(other.sets, sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sessionId, completedAt,
      const DeepCollectionEquality().hash(sets));

  @override
  String toString() {
    return 'LastPerformance(sessionId: $sessionId, completedAt: $completedAt, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class $LastPerformanceCopyWith<$Res> {
  factory $LastPerformanceCopyWith(
          LastPerformance value, $Res Function(LastPerformance) _then) =
      _$LastPerformanceCopyWithImpl;
  @useResult
  $Res call({String sessionId, String completedAt, List<LastSet> sets});
}

/// @nodoc
class _$LastPerformanceCopyWithImpl<$Res>
    implements $LastPerformanceCopyWith<$Res> {
  _$LastPerformanceCopyWithImpl(this._self, this._then);

  final LastPerformance _self;
  final $Res Function(LastPerformance) _then;

  /// Create a copy of LastPerformance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? completedAt = null,
    Object? sets = null,
  }) {
    return _then(_self.copyWith(
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      completedAt: null == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as String,
      sets: null == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<LastSet>,
    ));
  }
}

/// Adds pattern-matching-related methods to [LastPerformance].
extension LastPerformancePatterns on LastPerformance {
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
    TResult Function(_LastPerformance value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LastPerformance() when $default != null:
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
    TResult Function(_LastPerformance value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LastPerformance():
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
    TResult? Function(_LastPerformance value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LastPerformance() when $default != null:
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
    TResult Function(String sessionId, String completedAt, List<LastSet> sets)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LastPerformance() when $default != null:
        return $default(_that.sessionId, _that.completedAt, _that.sets);
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
    TResult Function(String sessionId, String completedAt, List<LastSet> sets)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LastPerformance():
        return $default(_that.sessionId, _that.completedAt, _that.sets);
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
    TResult? Function(String sessionId, String completedAt, List<LastSet> sets)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LastPerformance() when $default != null:
        return $default(_that.sessionId, _that.completedAt, _that.sets);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LastPerformance implements LastPerformance {
  const _LastPerformance(
      {required this.sessionId,
      required this.completedAt,
      required final List<LastSet> sets})
      : _sets = sets;
  factory _LastPerformance.fromJson(Map<String, dynamic> json) =>
      _$LastPerformanceFromJson(json);

  @override
  final String sessionId;
  @override
  final String completedAt;
  final List<LastSet> _sets;
  @override
  List<LastSet> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  /// Create a copy of LastPerformance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LastPerformanceCopyWith<_LastPerformance> get copyWith =>
      __$LastPerformanceCopyWithImpl<_LastPerformance>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LastPerformanceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LastPerformance &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            const DeepCollectionEquality().equals(other._sets, _sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sessionId, completedAt,
      const DeepCollectionEquality().hash(_sets));

  @override
  String toString() {
    return 'LastPerformance(sessionId: $sessionId, completedAt: $completedAt, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class _$LastPerformanceCopyWith<$Res>
    implements $LastPerformanceCopyWith<$Res> {
  factory _$LastPerformanceCopyWith(
          _LastPerformance value, $Res Function(_LastPerformance) _then) =
      __$LastPerformanceCopyWithImpl;
  @override
  @useResult
  $Res call({String sessionId, String completedAt, List<LastSet> sets});
}

/// @nodoc
class __$LastPerformanceCopyWithImpl<$Res>
    implements _$LastPerformanceCopyWith<$Res> {
  __$LastPerformanceCopyWithImpl(this._self, this._then);

  final _LastPerformance _self;
  final $Res Function(_LastPerformance) _then;

  /// Create a copy of LastPerformance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sessionId = null,
    Object? completedAt = null,
    Object? sets = null,
  }) {
    return _then(_LastPerformance(
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      completedAt: null == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as String,
      sets: null == sets
          ? _self._sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<LastSet>,
    ));
  }
}

/// @nodoc
mixin _$SetPrefill {
  int get setIndex;
  int get reps;
  double? get weightKg;
  int get rir;
  String get weightSource;

  /// Create a copy of SetPrefill
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SetPrefillCopyWith<SetPrefill> get copyWith =>
      _$SetPrefillCopyWithImpl<SetPrefill>(this as SetPrefill, _$identity);

  /// Serializes this SetPrefill to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SetPrefill &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.rir, rir) || other.rir == rir) &&
            (identical(other.weightSource, weightSource) ||
                other.weightSource == weightSource));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, setIndex, reps, weightKg, rir, weightSource);

  @override
  String toString() {
    return 'SetPrefill(setIndex: $setIndex, reps: $reps, weightKg: $weightKg, rir: $rir, weightSource: $weightSource)';
  }
}

/// @nodoc
abstract mixin class $SetPrefillCopyWith<$Res> {
  factory $SetPrefillCopyWith(
          SetPrefill value, $Res Function(SetPrefill) _then) =
      _$SetPrefillCopyWithImpl;
  @useResult
  $Res call(
      {int setIndex, int reps, double? weightKg, int rir, String weightSource});
}

/// @nodoc
class _$SetPrefillCopyWithImpl<$Res> implements $SetPrefillCopyWith<$Res> {
  _$SetPrefillCopyWithImpl(this._self, this._then);

  final SetPrefill _self;
  final $Res Function(SetPrefill) _then;

  /// Create a copy of SetPrefill
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setIndex = null,
    Object? reps = null,
    Object? weightKg = freezed,
    Object? rir = null,
    Object? weightSource = null,
  }) {
    return _then(_self.copyWith(
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      rir: null == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int,
      weightSource: null == weightSource
          ? _self.weightSource
          : weightSource // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [SetPrefill].
extension SetPrefillPatterns on SetPrefill {
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
    TResult Function(_SetPrefill value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SetPrefill() when $default != null:
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
    TResult Function(_SetPrefill value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetPrefill():
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
    TResult? Function(_SetPrefill value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetPrefill() when $default != null:
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
    TResult Function(int setIndex, int reps, double? weightKg, int rir,
            String weightSource)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SetPrefill() when $default != null:
        return $default(_that.setIndex, _that.reps, _that.weightKg, _that.rir,
            _that.weightSource);
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
    TResult Function(int setIndex, int reps, double? weightKg, int rir,
            String weightSource)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetPrefill():
        return $default(_that.setIndex, _that.reps, _that.weightKg, _that.rir,
            _that.weightSource);
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
    TResult? Function(int setIndex, int reps, double? weightKg, int rir,
            String weightSource)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetPrefill() when $default != null:
        return $default(_that.setIndex, _that.reps, _that.weightKg, _that.rir,
            _that.weightSource);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SetPrefill implements SetPrefill {
  const _SetPrefill(
      {required this.setIndex,
      required this.reps,
      required this.weightKg,
      required this.rir,
      required this.weightSource});
  factory _SetPrefill.fromJson(Map<String, dynamic> json) =>
      _$SetPrefillFromJson(json);

  @override
  final int setIndex;
  @override
  final int reps;
  @override
  final double? weightKg;
  @override
  final int rir;
  @override
  final String weightSource;

  /// Create a copy of SetPrefill
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SetPrefillCopyWith<_SetPrefill> get copyWith =>
      __$SetPrefillCopyWithImpl<_SetPrefill>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SetPrefillToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SetPrefill &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.rir, rir) || other.rir == rir) &&
            (identical(other.weightSource, weightSource) ||
                other.weightSource == weightSource));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, setIndex, reps, weightKg, rir, weightSource);

  @override
  String toString() {
    return 'SetPrefill(setIndex: $setIndex, reps: $reps, weightKg: $weightKg, rir: $rir, weightSource: $weightSource)';
  }
}

/// @nodoc
abstract mixin class _$SetPrefillCopyWith<$Res>
    implements $SetPrefillCopyWith<$Res> {
  factory _$SetPrefillCopyWith(
          _SetPrefill value, $Res Function(_SetPrefill) _then) =
      __$SetPrefillCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int setIndex, int reps, double? weightKg, int rir, String weightSource});
}

/// @nodoc
class __$SetPrefillCopyWithImpl<$Res> implements _$SetPrefillCopyWith<$Res> {
  __$SetPrefillCopyWithImpl(this._self, this._then);

  final _SetPrefill _self;
  final $Res Function(_SetPrefill) _then;

  /// Create a copy of SetPrefill
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? setIndex = null,
    Object? reps = null,
    Object? weightKg = freezed,
    Object? rir = null,
    Object? weightSource = null,
  }) {
    return _then(_SetPrefill(
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      rir: null == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int,
      weightSource: null == weightSource
          ? _self.weightSource
          : weightSource // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$ProgressionRecommendation {
  ProgressionAction get action;
  double? get weightKg;
  String get repTarget;
  int get targetRir;
  String get reason;
  String get basis;
  int get sessionsConsidered;

  /// Create a copy of ProgressionRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgressionRecommendationCopyWith<ProgressionRecommendation> get copyWith =>
      _$ProgressionRecommendationCopyWithImpl<ProgressionRecommendation>(
          this as ProgressionRecommendation, _$identity);

  /// Serializes this ProgressionRecommendation to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProgressionRecommendation &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.repTarget, repTarget) ||
                other.repTarget == repTarget) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.basis, basis) || other.basis == basis) &&
            (identical(other.sessionsConsidered, sessionsConsidered) ||
                other.sessionsConsidered == sessionsConsidered));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, action, weightKg, repTarget,
      targetRir, reason, basis, sessionsConsidered);

  @override
  String toString() {
    return 'ProgressionRecommendation(action: $action, weightKg: $weightKg, repTarget: $repTarget, targetRir: $targetRir, reason: $reason, basis: $basis, sessionsConsidered: $sessionsConsidered)';
  }
}

/// @nodoc
abstract mixin class $ProgressionRecommendationCopyWith<$Res> {
  factory $ProgressionRecommendationCopyWith(ProgressionRecommendation value,
          $Res Function(ProgressionRecommendation) _then) =
      _$ProgressionRecommendationCopyWithImpl;
  @useResult
  $Res call(
      {ProgressionAction action,
      double? weightKg,
      String repTarget,
      int targetRir,
      String reason,
      String basis,
      int sessionsConsidered});
}

/// @nodoc
class _$ProgressionRecommendationCopyWithImpl<$Res>
    implements $ProgressionRecommendationCopyWith<$Res> {
  _$ProgressionRecommendationCopyWithImpl(this._self, this._then);

  final ProgressionRecommendation _self;
  final $Res Function(ProgressionRecommendation) _then;

  /// Create a copy of ProgressionRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? action = null,
    Object? weightKg = freezed,
    Object? repTarget = null,
    Object? targetRir = null,
    Object? reason = null,
    Object? basis = null,
    Object? sessionsConsidered = null,
  }) {
    return _then(_self.copyWith(
      action: null == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
              as ProgressionAction,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      repTarget: null == repTarget
          ? _self.repTarget
          : repTarget // ignore: cast_nullable_to_non_nullable
              as String,
      targetRir: null == targetRir
          ? _self.targetRir
          : targetRir // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      basis: null == basis
          ? _self.basis
          : basis // ignore: cast_nullable_to_non_nullable
              as String,
      sessionsConsidered: null == sessionsConsidered
          ? _self.sessionsConsidered
          : sessionsConsidered // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProgressionRecommendation].
extension ProgressionRecommendationPatterns on ProgressionRecommendation {
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
    TResult Function(_ProgressionRecommendation value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionRecommendation() when $default != null:
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
    TResult Function(_ProgressionRecommendation value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionRecommendation():
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
    TResult? Function(_ProgressionRecommendation value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionRecommendation() when $default != null:
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
            ProgressionAction action,
            double? weightKg,
            String repTarget,
            int targetRir,
            String reason,
            String basis,
            int sessionsConsidered)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionRecommendation() when $default != null:
        return $default(
            _that.action,
            _that.weightKg,
            _that.repTarget,
            _that.targetRir,
            _that.reason,
            _that.basis,
            _that.sessionsConsidered);
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
            ProgressionAction action,
            double? weightKg,
            String repTarget,
            int targetRir,
            String reason,
            String basis,
            int sessionsConsidered)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionRecommendation():
        return $default(
            _that.action,
            _that.weightKg,
            _that.repTarget,
            _that.targetRir,
            _that.reason,
            _that.basis,
            _that.sessionsConsidered);
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
            ProgressionAction action,
            double? weightKg,
            String repTarget,
            int targetRir,
            String reason,
            String basis,
            int sessionsConsidered)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionRecommendation() when $default != null:
        return $default(
            _that.action,
            _that.weightKg,
            _that.repTarget,
            _that.targetRir,
            _that.reason,
            _that.basis,
            _that.sessionsConsidered);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProgressionRecommendation implements ProgressionRecommendation {
  const _ProgressionRecommendation(
      {required this.action,
      required this.weightKg,
      required this.repTarget,
      required this.targetRir,
      required this.reason,
      required this.basis,
      required this.sessionsConsidered});
  factory _ProgressionRecommendation.fromJson(Map<String, dynamic> json) =>
      _$ProgressionRecommendationFromJson(json);

  @override
  final ProgressionAction action;
  @override
  final double? weightKg;
  @override
  final String repTarget;
  @override
  final int targetRir;
  @override
  final String reason;
  @override
  final String basis;
  @override
  final int sessionsConsidered;

  /// Create a copy of ProgressionRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgressionRecommendationCopyWith<_ProgressionRecommendation>
      get copyWith =>
          __$ProgressionRecommendationCopyWithImpl<_ProgressionRecommendation>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgressionRecommendationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProgressionRecommendation &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.repTarget, repTarget) ||
                other.repTarget == repTarget) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.basis, basis) || other.basis == basis) &&
            (identical(other.sessionsConsidered, sessionsConsidered) ||
                other.sessionsConsidered == sessionsConsidered));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, action, weightKg, repTarget,
      targetRir, reason, basis, sessionsConsidered);

  @override
  String toString() {
    return 'ProgressionRecommendation(action: $action, weightKg: $weightKg, repTarget: $repTarget, targetRir: $targetRir, reason: $reason, basis: $basis, sessionsConsidered: $sessionsConsidered)';
  }
}

/// @nodoc
abstract mixin class _$ProgressionRecommendationCopyWith<$Res>
    implements $ProgressionRecommendationCopyWith<$Res> {
  factory _$ProgressionRecommendationCopyWith(_ProgressionRecommendation value,
          $Res Function(_ProgressionRecommendation) _then) =
      __$ProgressionRecommendationCopyWithImpl;
  @override
  @useResult
  $Res call(
      {ProgressionAction action,
      double? weightKg,
      String repTarget,
      int targetRir,
      String reason,
      String basis,
      int sessionsConsidered});
}

/// @nodoc
class __$ProgressionRecommendationCopyWithImpl<$Res>
    implements _$ProgressionRecommendationCopyWith<$Res> {
  __$ProgressionRecommendationCopyWithImpl(this._self, this._then);

  final _ProgressionRecommendation _self;
  final $Res Function(_ProgressionRecommendation) _then;

  /// Create a copy of ProgressionRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? action = null,
    Object? weightKg = freezed,
    Object? repTarget = null,
    Object? targetRir = null,
    Object? reason = null,
    Object? basis = null,
    Object? sessionsConsidered = null,
  }) {
    return _then(_ProgressionRecommendation(
      action: null == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
              as ProgressionAction,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      repTarget: null == repTarget
          ? _self.repTarget
          : repTarget // ignore: cast_nullable_to_non_nullable
              as String,
      targetRir: null == targetRir
          ? _self.targetRir
          : targetRir // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      basis: null == basis
          ? _self.basis
          : basis // ignore: cast_nullable_to_non_nullable
              as String,
      sessionsConsidered: null == sessionsConsidered
          ? _self.sessionsConsidered
          : sessionsConsidered // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$PriorBest {
  double? get weightKg;
  int? get repsAtBestWeight;
  double? get estimated1rm;

  /// Create a copy of PriorBest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PriorBestCopyWith<PriorBest> get copyWith =>
      _$PriorBestCopyWithImpl<PriorBest>(this as PriorBest, _$identity);

  /// Serializes this PriorBest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PriorBest &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.repsAtBestWeight, repsAtBestWeight) ||
                other.repsAtBestWeight == repsAtBestWeight) &&
            (identical(other.estimated1rm, estimated1rm) ||
                other.estimated1rm == estimated1rm));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, weightKg, repsAtBestWeight, estimated1rm);

  @override
  String toString() {
    return 'PriorBest(weightKg: $weightKg, repsAtBestWeight: $repsAtBestWeight, estimated1rm: $estimated1rm)';
  }
}

/// @nodoc
abstract mixin class $PriorBestCopyWith<$Res> {
  factory $PriorBestCopyWith(PriorBest value, $Res Function(PriorBest) _then) =
      _$PriorBestCopyWithImpl;
  @useResult
  $Res call({double? weightKg, int? repsAtBestWeight, double? estimated1rm});
}

/// @nodoc
class _$PriorBestCopyWithImpl<$Res> implements $PriorBestCopyWith<$Res> {
  _$PriorBestCopyWithImpl(this._self, this._then);

  final PriorBest _self;
  final $Res Function(PriorBest) _then;

  /// Create a copy of PriorBest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? weightKg = freezed,
    Object? repsAtBestWeight = freezed,
    Object? estimated1rm = freezed,
  }) {
    return _then(_self.copyWith(
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      repsAtBestWeight: freezed == repsAtBestWeight
          ? _self.repsAtBestWeight
          : repsAtBestWeight // ignore: cast_nullable_to_non_nullable
              as int?,
      estimated1rm: freezed == estimated1rm
          ? _self.estimated1rm
          : estimated1rm // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PriorBest].
extension PriorBestPatterns on PriorBest {
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
    TResult Function(_PriorBest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PriorBest() when $default != null:
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
    TResult Function(_PriorBest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PriorBest():
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
    TResult? Function(_PriorBest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PriorBest() when $default != null:
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
            double? weightKg, int? repsAtBestWeight, double? estimated1rm)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PriorBest() when $default != null:
        return $default(
            _that.weightKg, _that.repsAtBestWeight, _that.estimated1rm);
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
            double? weightKg, int? repsAtBestWeight, double? estimated1rm)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PriorBest():
        return $default(
            _that.weightKg, _that.repsAtBestWeight, _that.estimated1rm);
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
            double? weightKg, int? repsAtBestWeight, double? estimated1rm)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PriorBest() when $default != null:
        return $default(
            _that.weightKg, _that.repsAtBestWeight, _that.estimated1rm);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PriorBest extends PriorBest {
  const _PriorBest(
      {required this.weightKg,
      required this.repsAtBestWeight,
      required this.estimated1rm})
      : super._();
  factory _PriorBest.fromJson(Map<String, dynamic> json) =>
      _$PriorBestFromJson(json);

  @override
  final double? weightKg;
  @override
  final int? repsAtBestWeight;
  @override
  final double? estimated1rm;

  /// Create a copy of PriorBest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PriorBestCopyWith<_PriorBest> get copyWith =>
      __$PriorBestCopyWithImpl<_PriorBest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PriorBestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PriorBest &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.repsAtBestWeight, repsAtBestWeight) ||
                other.repsAtBestWeight == repsAtBestWeight) &&
            (identical(other.estimated1rm, estimated1rm) ||
                other.estimated1rm == estimated1rm));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, weightKg, repsAtBestWeight, estimated1rm);

  @override
  String toString() {
    return 'PriorBest(weightKg: $weightKg, repsAtBestWeight: $repsAtBestWeight, estimated1rm: $estimated1rm)';
  }
}

/// @nodoc
abstract mixin class _$PriorBestCopyWith<$Res>
    implements $PriorBestCopyWith<$Res> {
  factory _$PriorBestCopyWith(
          _PriorBest value, $Res Function(_PriorBest) _then) =
      __$PriorBestCopyWithImpl;
  @override
  @useResult
  $Res call({double? weightKg, int? repsAtBestWeight, double? estimated1rm});
}

/// @nodoc
class __$PriorBestCopyWithImpl<$Res> implements _$PriorBestCopyWith<$Res> {
  __$PriorBestCopyWithImpl(this._self, this._then);

  final _PriorBest _self;
  final $Res Function(_PriorBest) _then;

  /// Create a copy of PriorBest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? weightKg = freezed,
    Object? repsAtBestWeight = freezed,
    Object? estimated1rm = freezed,
  }) {
    return _then(_PriorBest(
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      repsAtBestWeight: freezed == repsAtBestWeight
          ? _self.repsAtBestWeight
          : repsAtBestWeight // ignore: cast_nullable_to_non_nullable
              as int?,
      estimated1rm: freezed == estimated1rm
          ? _self.estimated1rm
          : estimated1rm // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
mixin _$SubstitutionAlternative {
  String get exerciseId;
  String get slug;
  String get name;
  List<Equipment> get equipment;

  /// Create a copy of SubstitutionAlternative
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SubstitutionAlternativeCopyWith<SubstitutionAlternative> get copyWith =>
      _$SubstitutionAlternativeCopyWithImpl<SubstitutionAlternative>(
          this as SubstitutionAlternative, _$identity);

  /// Serializes this SubstitutionAlternative to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SubstitutionAlternative &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other.equipment, equipment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, exerciseId, slug, name,
      const DeepCollectionEquality().hash(equipment));

  @override
  String toString() {
    return 'SubstitutionAlternative(exerciseId: $exerciseId, slug: $slug, name: $name, equipment: $equipment)';
  }
}

/// @nodoc
abstract mixin class $SubstitutionAlternativeCopyWith<$Res> {
  factory $SubstitutionAlternativeCopyWith(SubstitutionAlternative value,
          $Res Function(SubstitutionAlternative) _then) =
      _$SubstitutionAlternativeCopyWithImpl;
  @useResult
  $Res call(
      {String exerciseId, String slug, String name, List<Equipment> equipment});
}

/// @nodoc
class _$SubstitutionAlternativeCopyWithImpl<$Res>
    implements $SubstitutionAlternativeCopyWith<$Res> {
  _$SubstitutionAlternativeCopyWithImpl(this._self, this._then);

  final SubstitutionAlternative _self;
  final $Res Function(SubstitutionAlternative) _then;

  /// Create a copy of SubstitutionAlternative
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? equipment = null,
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
      equipment: null == equipment
          ? _self.equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
    ));
  }
}

/// Adds pattern-matching-related methods to [SubstitutionAlternative].
extension SubstitutionAlternativePatterns on SubstitutionAlternative {
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
    TResult Function(_SubstitutionAlternative value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SubstitutionAlternative() when $default != null:
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
    TResult Function(_SubstitutionAlternative value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubstitutionAlternative():
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
    TResult? Function(_SubstitutionAlternative value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubstitutionAlternative() when $default != null:
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
    TResult Function(String exerciseId, String slug, String name,
            List<Equipment> equipment)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SubstitutionAlternative() when $default != null:
        return $default(
            _that.exerciseId, _that.slug, _that.name, _that.equipment);
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
    TResult Function(String exerciseId, String slug, String name,
            List<Equipment> equipment)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubstitutionAlternative():
        return $default(
            _that.exerciseId, _that.slug, _that.name, _that.equipment);
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
    TResult? Function(String exerciseId, String slug, String name,
            List<Equipment> equipment)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubstitutionAlternative() when $default != null:
        return $default(
            _that.exerciseId, _that.slug, _that.name, _that.equipment);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SubstitutionAlternative implements SubstitutionAlternative {
  const _SubstitutionAlternative(
      {required this.exerciseId,
      required this.slug,
      required this.name,
      required final List<Equipment> equipment})
      : _equipment = equipment;
  factory _SubstitutionAlternative.fromJson(Map<String, dynamic> json) =>
      _$SubstitutionAlternativeFromJson(json);

  @override
  final String exerciseId;
  @override
  final String slug;
  @override
  final String name;
  final List<Equipment> _equipment;
  @override
  List<Equipment> get equipment {
    if (_equipment is EqualUnmodifiableListView) return _equipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_equipment);
  }

  /// Create a copy of SubstitutionAlternative
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SubstitutionAlternativeCopyWith<_SubstitutionAlternative> get copyWith =>
      __$SubstitutionAlternativeCopyWithImpl<_SubstitutionAlternative>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SubstitutionAlternativeToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SubstitutionAlternative &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality()
                .equals(other._equipment, _equipment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, exerciseId, slug, name,
      const DeepCollectionEquality().hash(_equipment));

  @override
  String toString() {
    return 'SubstitutionAlternative(exerciseId: $exerciseId, slug: $slug, name: $name, equipment: $equipment)';
  }
}

/// @nodoc
abstract mixin class _$SubstitutionAlternativeCopyWith<$Res>
    implements $SubstitutionAlternativeCopyWith<$Res> {
  factory _$SubstitutionAlternativeCopyWith(_SubstitutionAlternative value,
          $Res Function(_SubstitutionAlternative) _then) =
      __$SubstitutionAlternativeCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String exerciseId, String slug, String name, List<Equipment> equipment});
}

/// @nodoc
class __$SubstitutionAlternativeCopyWithImpl<$Res>
    implements _$SubstitutionAlternativeCopyWith<$Res> {
  __$SubstitutionAlternativeCopyWithImpl(this._self, this._then);

  final _SubstitutionAlternative _self;
  final $Res Function(_SubstitutionAlternative) _then;

  /// Create a copy of SubstitutionAlternative
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? equipment = null,
  }) {
    return _then(_SubstitutionAlternative(
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
      equipment: null == equipment
          ? _self._equipment
          : equipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
    ));
  }
}

/// @nodoc
mixin _$Substitution {
  SubstitutionTrigger get trigger;
  SubstitutionAlternative? get alternative;
  String get reason;

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SubstitutionCopyWith<Substitution> get copyWith =>
      _$SubstitutionCopyWithImpl<Substitution>(
          this as Substitution, _$identity);

  /// Serializes this Substitution to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Substitution &&
            (identical(other.trigger, trigger) || other.trigger == trigger) &&
            (identical(other.alternative, alternative) ||
                other.alternative == alternative) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, trigger, alternative, reason);

  @override
  String toString() {
    return 'Substitution(trigger: $trigger, alternative: $alternative, reason: $reason)';
  }
}

/// @nodoc
abstract mixin class $SubstitutionCopyWith<$Res> {
  factory $SubstitutionCopyWith(
          Substitution value, $Res Function(Substitution) _then) =
      _$SubstitutionCopyWithImpl;
  @useResult
  $Res call(
      {SubstitutionTrigger trigger,
      SubstitutionAlternative? alternative,
      String reason});

  $SubstitutionAlternativeCopyWith<$Res>? get alternative;
}

/// @nodoc
class _$SubstitutionCopyWithImpl<$Res> implements $SubstitutionCopyWith<$Res> {
  _$SubstitutionCopyWithImpl(this._self, this._then);

  final Substitution _self;
  final $Res Function(Substitution) _then;

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trigger = null,
    Object? alternative = freezed,
    Object? reason = null,
  }) {
    return _then(_self.copyWith(
      trigger: null == trigger
          ? _self.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as SubstitutionTrigger,
      alternative: freezed == alternative
          ? _self.alternative
          : alternative // ignore: cast_nullable_to_non_nullable
              as SubstitutionAlternative?,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SubstitutionAlternativeCopyWith<$Res>? get alternative {
    if (_self.alternative == null) {
      return null;
    }

    return $SubstitutionAlternativeCopyWith<$Res>(_self.alternative!, (value) {
      return _then(_self.copyWith(alternative: value));
    });
  }
}

/// Adds pattern-matching-related methods to [Substitution].
extension SubstitutionPatterns on Substitution {
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
    TResult Function(_Substitution value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Substitution() when $default != null:
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
    TResult Function(_Substitution value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Substitution():
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
    TResult? Function(_Substitution value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Substitution() when $default != null:
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
    TResult Function(SubstitutionTrigger trigger,
            SubstitutionAlternative? alternative, String reason)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Substitution() when $default != null:
        return $default(_that.trigger, _that.alternative, _that.reason);
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
    TResult Function(SubstitutionTrigger trigger,
            SubstitutionAlternative? alternative, String reason)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Substitution():
        return $default(_that.trigger, _that.alternative, _that.reason);
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
    TResult? Function(SubstitutionTrigger trigger,
            SubstitutionAlternative? alternative, String reason)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Substitution() when $default != null:
        return $default(_that.trigger, _that.alternative, _that.reason);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Substitution implements Substitution {
  const _Substitution(
      {required this.trigger, required this.alternative, required this.reason});
  factory _Substitution.fromJson(Map<String, dynamic> json) =>
      _$SubstitutionFromJson(json);

  @override
  final SubstitutionTrigger trigger;
  @override
  final SubstitutionAlternative? alternative;
  @override
  final String reason;

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SubstitutionCopyWith<_Substitution> get copyWith =>
      __$SubstitutionCopyWithImpl<_Substitution>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SubstitutionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Substitution &&
            (identical(other.trigger, trigger) || other.trigger == trigger) &&
            (identical(other.alternative, alternative) ||
                other.alternative == alternative) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, trigger, alternative, reason);

  @override
  String toString() {
    return 'Substitution(trigger: $trigger, alternative: $alternative, reason: $reason)';
  }
}

/// @nodoc
abstract mixin class _$SubstitutionCopyWith<$Res>
    implements $SubstitutionCopyWith<$Res> {
  factory _$SubstitutionCopyWith(
          _Substitution value, $Res Function(_Substitution) _then) =
      __$SubstitutionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {SubstitutionTrigger trigger,
      SubstitutionAlternative? alternative,
      String reason});

  @override
  $SubstitutionAlternativeCopyWith<$Res>? get alternative;
}

/// @nodoc
class __$SubstitutionCopyWithImpl<$Res>
    implements _$SubstitutionCopyWith<$Res> {
  __$SubstitutionCopyWithImpl(this._self, this._then);

  final _Substitution _self;
  final $Res Function(_Substitution) _then;

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? trigger = null,
    Object? alternative = freezed,
    Object? reason = null,
  }) {
    return _then(_Substitution(
      trigger: null == trigger
          ? _self.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as SubstitutionTrigger,
      alternative: freezed == alternative
          ? _self.alternative
          : alternative // ignore: cast_nullable_to_non_nullable
              as SubstitutionAlternative?,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SubstitutionAlternativeCopyWith<$Res>? get alternative {
    if (_self.alternative == null) {
      return null;
    }

    return $SubstitutionAlternativeCopyWith<$Res>(_self.alternative!, (value) {
      return _then(_self.copyWith(alternative: value));
    });
  }
}

/// @nodoc
mixin _$DeloadState {
  DeloadStatus get state;
  DeloadTrigger? get trigger;
  String get reason;
  String? get endsOn;

  /// Create a copy of DeloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DeloadStateCopyWith<DeloadState> get copyWith =>
      _$DeloadStateCopyWithImpl<DeloadState>(this as DeloadState, _$identity);

  /// Serializes this DeloadState to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DeloadState &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.trigger, trigger) || other.trigger == trigger) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.endsOn, endsOn) || other.endsOn == endsOn));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, state, trigger, reason, endsOn);

  @override
  String toString() {
    return 'DeloadState(state: $state, trigger: $trigger, reason: $reason, endsOn: $endsOn)';
  }
}

/// @nodoc
abstract mixin class $DeloadStateCopyWith<$Res> {
  factory $DeloadStateCopyWith(
          DeloadState value, $Res Function(DeloadState) _then) =
      _$DeloadStateCopyWithImpl;
  @useResult
  $Res call(
      {DeloadStatus state,
      DeloadTrigger? trigger,
      String reason,
      String? endsOn});
}

/// @nodoc
class _$DeloadStateCopyWithImpl<$Res> implements $DeloadStateCopyWith<$Res> {
  _$DeloadStateCopyWithImpl(this._self, this._then);

  final DeloadState _self;
  final $Res Function(DeloadState) _then;

  /// Create a copy of DeloadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? trigger = freezed,
    Object? reason = null,
    Object? endsOn = freezed,
  }) {
    return _then(_self.copyWith(
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as DeloadStatus,
      trigger: freezed == trigger
          ? _self.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as DeloadTrigger?,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      endsOn: freezed == endsOn
          ? _self.endsOn
          : endsOn // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [DeloadState].
extension DeloadStatePatterns on DeloadState {
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
    TResult Function(_DeloadState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeloadState() when $default != null:
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
    TResult Function(_DeloadState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeloadState():
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
    TResult? Function(_DeloadState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeloadState() when $default != null:
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
    TResult Function(DeloadStatus state, DeloadTrigger? trigger, String reason,
            String? endsOn)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeloadState() when $default != null:
        return $default(_that.state, _that.trigger, _that.reason, _that.endsOn);
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
    TResult Function(DeloadStatus state, DeloadTrigger? trigger, String reason,
            String? endsOn)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeloadState():
        return $default(_that.state, _that.trigger, _that.reason, _that.endsOn);
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
    TResult? Function(DeloadStatus state, DeloadTrigger? trigger, String reason,
            String? endsOn)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeloadState() when $default != null:
        return $default(_that.state, _that.trigger, _that.reason, _that.endsOn);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DeloadState implements DeloadState {
  const _DeloadState(
      {required this.state,
      required this.trigger,
      required this.reason,
      required this.endsOn});
  factory _DeloadState.fromJson(Map<String, dynamic> json) =>
      _$DeloadStateFromJson(json);

  @override
  final DeloadStatus state;
  @override
  final DeloadTrigger? trigger;
  @override
  final String reason;
  @override
  final String? endsOn;

  /// Create a copy of DeloadState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DeloadStateCopyWith<_DeloadState> get copyWith =>
      __$DeloadStateCopyWithImpl<_DeloadState>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DeloadStateToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DeloadState &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.trigger, trigger) || other.trigger == trigger) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.endsOn, endsOn) || other.endsOn == endsOn));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, state, trigger, reason, endsOn);

  @override
  String toString() {
    return 'DeloadState(state: $state, trigger: $trigger, reason: $reason, endsOn: $endsOn)';
  }
}

/// @nodoc
abstract mixin class _$DeloadStateCopyWith<$Res>
    implements $DeloadStateCopyWith<$Res> {
  factory _$DeloadStateCopyWith(
          _DeloadState value, $Res Function(_DeloadState) _then) =
      __$DeloadStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DeloadStatus state,
      DeloadTrigger? trigger,
      String reason,
      String? endsOn});
}

/// @nodoc
class __$DeloadStateCopyWithImpl<$Res> implements _$DeloadStateCopyWith<$Res> {
  __$DeloadStateCopyWithImpl(this._self, this._then);

  final _DeloadState _self;
  final $Res Function(_DeloadState) _then;

  /// Create a copy of DeloadState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? state = null,
    Object? trigger = freezed,
    Object? reason = null,
    Object? endsOn = freezed,
  }) {
    return _then(_DeloadState(
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as DeloadStatus,
      trigger: freezed == trigger
          ? _self.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as DeloadTrigger?,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      endsOn: freezed == endsOn
          ? _self.endsOn
          : endsOn // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$NeglectedMuscle {
  MuscleGroup get muscle;
  int? get daysSince;

  /// Create a copy of NeglectedMuscle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NeglectedMuscleCopyWith<NeglectedMuscle> get copyWith =>
      _$NeglectedMuscleCopyWithImpl<NeglectedMuscle>(
          this as NeglectedMuscle, _$identity);

  /// Serializes this NeglectedMuscle to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NeglectedMuscle &&
            (identical(other.muscle, muscle) || other.muscle == muscle) &&
            (identical(other.daysSince, daysSince) ||
                other.daysSince == daysSince));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, muscle, daysSince);

  @override
  String toString() {
    return 'NeglectedMuscle(muscle: $muscle, daysSince: $daysSince)';
  }
}

/// @nodoc
abstract mixin class $NeglectedMuscleCopyWith<$Res> {
  factory $NeglectedMuscleCopyWith(
          NeglectedMuscle value, $Res Function(NeglectedMuscle) _then) =
      _$NeglectedMuscleCopyWithImpl;
  @useResult
  $Res call({MuscleGroup muscle, int? daysSince});
}

/// @nodoc
class _$NeglectedMuscleCopyWithImpl<$Res>
    implements $NeglectedMuscleCopyWith<$Res> {
  _$NeglectedMuscleCopyWithImpl(this._self, this._then);

  final NeglectedMuscle _self;
  final $Res Function(NeglectedMuscle) _then;

  /// Create a copy of NeglectedMuscle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? muscle = null,
    Object? daysSince = freezed,
  }) {
    return _then(_self.copyWith(
      muscle: null == muscle
          ? _self.muscle
          : muscle // ignore: cast_nullable_to_non_nullable
              as MuscleGroup,
      daysSince: freezed == daysSince
          ? _self.daysSince
          : daysSince // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [NeglectedMuscle].
extension NeglectedMusclePatterns on NeglectedMuscle {
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
    TResult Function(_NeglectedMuscle value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NeglectedMuscle() when $default != null:
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
    TResult Function(_NeglectedMuscle value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NeglectedMuscle():
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
    TResult? Function(_NeglectedMuscle value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NeglectedMuscle() when $default != null:
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
    TResult Function(MuscleGroup muscle, int? daysSince)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NeglectedMuscle() when $default != null:
        return $default(_that.muscle, _that.daysSince);
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
    TResult Function(MuscleGroup muscle, int? daysSince) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NeglectedMuscle():
        return $default(_that.muscle, _that.daysSince);
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
    TResult? Function(MuscleGroup muscle, int? daysSince)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NeglectedMuscle() when $default != null:
        return $default(_that.muscle, _that.daysSince);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _NeglectedMuscle implements NeglectedMuscle {
  const _NeglectedMuscle({required this.muscle, required this.daysSince});
  factory _NeglectedMuscle.fromJson(Map<String, dynamic> json) =>
      _$NeglectedMuscleFromJson(json);

  @override
  final MuscleGroup muscle;
  @override
  final int? daysSince;

  /// Create a copy of NeglectedMuscle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NeglectedMuscleCopyWith<_NeglectedMuscle> get copyWith =>
      __$NeglectedMuscleCopyWithImpl<_NeglectedMuscle>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NeglectedMuscleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NeglectedMuscle &&
            (identical(other.muscle, muscle) || other.muscle == muscle) &&
            (identical(other.daysSince, daysSince) ||
                other.daysSince == daysSince));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, muscle, daysSince);

  @override
  String toString() {
    return 'NeglectedMuscle(muscle: $muscle, daysSince: $daysSince)';
  }
}

/// @nodoc
abstract mixin class _$NeglectedMuscleCopyWith<$Res>
    implements $NeglectedMuscleCopyWith<$Res> {
  factory _$NeglectedMuscleCopyWith(
          _NeglectedMuscle value, $Res Function(_NeglectedMuscle) _then) =
      __$NeglectedMuscleCopyWithImpl;
  @override
  @useResult
  $Res call({MuscleGroup muscle, int? daysSince});
}

/// @nodoc
class __$NeglectedMuscleCopyWithImpl<$Res>
    implements _$NeglectedMuscleCopyWith<$Res> {
  __$NeglectedMuscleCopyWithImpl(this._self, this._then);

  final _NeglectedMuscle _self;
  final $Res Function(_NeglectedMuscle) _then;

  /// Create a copy of NeglectedMuscle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? muscle = null,
    Object? daysSince = freezed,
  }) {
    return _then(_NeglectedMuscle(
      muscle: null == muscle
          ? _self.muscle
          : muscle // ignore: cast_nullable_to_non_nullable
              as MuscleGroup,
      daysSince: freezed == daysSince
          ? _self.daysSince
          : daysSince // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
mixin _$SessionExercise {
  String get id;
  String get clientExerciseId;
  String get exerciseId;
  String get slug;
  String get name;
  MovementPattern get movementPattern;
  List<Equipment> get equipment;
  Difficulty get difficulty;
  List<MuscleGroup> get primaryMuscles;
  List<MuscleGroup> get secondaryMuscles;
  double get incrementKg;
  int get orderIndex;
  int? get supersetGroup;
  String? get plannedExerciseId;
  List<PlannedSet> get targets;
  List<SetPrefill> get prefill;
  LastPerformance? get lastPerformance;
  ProgressionRecommendation? get recommendation;
  PriorBest get priorBest;
  List<PlannedSet>? get originalTargets;
  List<SetLog> get sets;

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SessionExerciseCopyWith<SessionExercise> get copyWith =>
      _$SessionExerciseCopyWithImpl<SessionExercise>(
          this as SessionExercise, _$identity);

  /// Serializes this SessionExercise to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SessionExercise &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientExerciseId, clientExerciseId) ||
                other.clientExerciseId == clientExerciseId) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.movementPattern, movementPattern) ||
                other.movementPattern == movementPattern) &&
            const DeepCollectionEquality().equals(other.equipment, equipment) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            const DeepCollectionEquality()
                .equals(other.primaryMuscles, primaryMuscles) &&
            const DeepCollectionEquality()
                .equals(other.secondaryMuscles, secondaryMuscles) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.supersetGroup, supersetGroup) ||
                other.supersetGroup == supersetGroup) &&
            (identical(other.plannedExerciseId, plannedExerciseId) ||
                other.plannedExerciseId == plannedExerciseId) &&
            const DeepCollectionEquality().equals(other.targets, targets) &&
            const DeepCollectionEquality().equals(other.prefill, prefill) &&
            (identical(other.lastPerformance, lastPerformance) ||
                other.lastPerformance == lastPerformance) &&
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation) &&
            (identical(other.priorBest, priorBest) ||
                other.priorBest == priorBest) &&
            const DeepCollectionEquality()
                .equals(other.originalTargets, originalTargets) &&
            const DeepCollectionEquality().equals(other.sets, sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        clientExerciseId,
        exerciseId,
        slug,
        name,
        movementPattern,
        const DeepCollectionEquality().hash(equipment),
        difficulty,
        const DeepCollectionEquality().hash(primaryMuscles),
        const DeepCollectionEquality().hash(secondaryMuscles),
        incrementKg,
        orderIndex,
        supersetGroup,
        plannedExerciseId,
        const DeepCollectionEquality().hash(targets),
        const DeepCollectionEquality().hash(prefill),
        lastPerformance,
        recommendation,
        priorBest,
        const DeepCollectionEquality().hash(originalTargets),
        const DeepCollectionEquality().hash(sets)
      ]);

  @override
  String toString() {
    return 'SessionExercise(id: $id, clientExerciseId: $clientExerciseId, exerciseId: $exerciseId, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, primaryMuscles: $primaryMuscles, secondaryMuscles: $secondaryMuscles, incrementKg: $incrementKg, orderIndex: $orderIndex, supersetGroup: $supersetGroup, plannedExerciseId: $plannedExerciseId, targets: $targets, prefill: $prefill, lastPerformance: $lastPerformance, recommendation: $recommendation, priorBest: $priorBest, originalTargets: $originalTargets, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class $SessionExerciseCopyWith<$Res> {
  factory $SessionExerciseCopyWith(
          SessionExercise value, $Res Function(SessionExercise) _then) =
      _$SessionExerciseCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String clientExerciseId,
      String exerciseId,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      List<MuscleGroup> primaryMuscles,
      List<MuscleGroup> secondaryMuscles,
      double incrementKg,
      int orderIndex,
      int? supersetGroup,
      String? plannedExerciseId,
      List<PlannedSet> targets,
      List<SetPrefill> prefill,
      LastPerformance? lastPerformance,
      ProgressionRecommendation? recommendation,
      PriorBest priorBest,
      List<PlannedSet>? originalTargets,
      List<SetLog> sets});

  $LastPerformanceCopyWith<$Res>? get lastPerformance;
  $ProgressionRecommendationCopyWith<$Res>? get recommendation;
  $PriorBestCopyWith<$Res> get priorBest;
}

/// @nodoc
class _$SessionExerciseCopyWithImpl<$Res>
    implements $SessionExerciseCopyWith<$Res> {
  _$SessionExerciseCopyWithImpl(this._self, this._then);

  final SessionExercise _self;
  final $Res Function(SessionExercise) _then;

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientExerciseId = null,
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? primaryMuscles = null,
    Object? secondaryMuscles = null,
    Object? incrementKg = null,
    Object? orderIndex = null,
    Object? supersetGroup = freezed,
    Object? plannedExerciseId = freezed,
    Object? targets = null,
    Object? prefill = null,
    Object? lastPerformance = freezed,
    Object? recommendation = freezed,
    Object? priorBest = null,
    Object? originalTargets = freezed,
    Object? sets = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientExerciseId: null == clientExerciseId
          ? _self.clientExerciseId
          : clientExerciseId // ignore: cast_nullable_to_non_nullable
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
      primaryMuscles: null == primaryMuscles
          ? _self.primaryMuscles
          : primaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      secondaryMuscles: null == secondaryMuscles
          ? _self.secondaryMuscles
          : secondaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      supersetGroup: freezed == supersetGroup
          ? _self.supersetGroup
          : supersetGroup // ignore: cast_nullable_to_non_nullable
              as int?,
      plannedExerciseId: freezed == plannedExerciseId
          ? _self.plannedExerciseId
          : plannedExerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      targets: null == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>,
      prefill: null == prefill
          ? _self.prefill
          : prefill // ignore: cast_nullable_to_non_nullable
              as List<SetPrefill>,
      lastPerformance: freezed == lastPerformance
          ? _self.lastPerformance
          : lastPerformance // ignore: cast_nullable_to_non_nullable
              as LastPerformance?,
      recommendation: freezed == recommendation
          ? _self.recommendation
          : recommendation // ignore: cast_nullable_to_non_nullable
              as ProgressionRecommendation?,
      priorBest: null == priorBest
          ? _self.priorBest
          : priorBest // ignore: cast_nullable_to_non_nullable
              as PriorBest,
      originalTargets: freezed == originalTargets
          ? _self.originalTargets
          : originalTargets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>?,
      sets: null == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<SetLog>,
    ));
  }

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LastPerformanceCopyWith<$Res>? get lastPerformance {
    if (_self.lastPerformance == null) {
      return null;
    }

    return $LastPerformanceCopyWith<$Res>(_self.lastPerformance!, (value) {
      return _then(_self.copyWith(lastPerformance: value));
    });
  }

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressionRecommendationCopyWith<$Res>? get recommendation {
    if (_self.recommendation == null) {
      return null;
    }

    return $ProgressionRecommendationCopyWith<$Res>(_self.recommendation!,
        (value) {
      return _then(_self.copyWith(recommendation: value));
    });
  }

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriorBestCopyWith<$Res> get priorBest {
    return $PriorBestCopyWith<$Res>(_self.priorBest, (value) {
      return _then(_self.copyWith(priorBest: value));
    });
  }
}

/// Adds pattern-matching-related methods to [SessionExercise].
extension SessionExercisePatterns on SessionExercise {
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
    TResult Function(_SessionExercise value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionExercise() when $default != null:
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
    TResult Function(_SessionExercise value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionExercise():
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
    TResult? Function(_SessionExercise value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionExercise() when $default != null:
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
            String clientExerciseId,
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            List<MuscleGroup> primaryMuscles,
            List<MuscleGroup> secondaryMuscles,
            double incrementKg,
            int orderIndex,
            int? supersetGroup,
            String? plannedExerciseId,
            List<PlannedSet> targets,
            List<SetPrefill> prefill,
            LastPerformance? lastPerformance,
            ProgressionRecommendation? recommendation,
            PriorBest priorBest,
            List<PlannedSet>? originalTargets,
            List<SetLog> sets)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionExercise() when $default != null:
        return $default(
            _that.id,
            _that.clientExerciseId,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.primaryMuscles,
            _that.secondaryMuscles,
            _that.incrementKg,
            _that.orderIndex,
            _that.supersetGroup,
            _that.plannedExerciseId,
            _that.targets,
            _that.prefill,
            _that.lastPerformance,
            _that.recommendation,
            _that.priorBest,
            _that.originalTargets,
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
            String clientExerciseId,
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            List<MuscleGroup> primaryMuscles,
            List<MuscleGroup> secondaryMuscles,
            double incrementKg,
            int orderIndex,
            int? supersetGroup,
            String? plannedExerciseId,
            List<PlannedSet> targets,
            List<SetPrefill> prefill,
            LastPerformance? lastPerformance,
            ProgressionRecommendation? recommendation,
            PriorBest priorBest,
            List<PlannedSet>? originalTargets,
            List<SetLog> sets)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionExercise():
        return $default(
            _that.id,
            _that.clientExerciseId,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.primaryMuscles,
            _that.secondaryMuscles,
            _that.incrementKg,
            _that.orderIndex,
            _that.supersetGroup,
            _that.plannedExerciseId,
            _that.targets,
            _that.prefill,
            _that.lastPerformance,
            _that.recommendation,
            _that.priorBest,
            _that.originalTargets,
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
            String clientExerciseId,
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            List<MuscleGroup> primaryMuscles,
            List<MuscleGroup> secondaryMuscles,
            double incrementKg,
            int orderIndex,
            int? supersetGroup,
            String? plannedExerciseId,
            List<PlannedSet> targets,
            List<SetPrefill> prefill,
            LastPerformance? lastPerformance,
            ProgressionRecommendation? recommendation,
            PriorBest priorBest,
            List<PlannedSet>? originalTargets,
            List<SetLog> sets)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionExercise() when $default != null:
        return $default(
            _that.id,
            _that.clientExerciseId,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.primaryMuscles,
            _that.secondaryMuscles,
            _that.incrementKg,
            _that.orderIndex,
            _that.supersetGroup,
            _that.plannedExerciseId,
            _that.targets,
            _that.prefill,
            _that.lastPerformance,
            _that.recommendation,
            _that.priorBest,
            _that.originalTargets,
            _that.sets);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SessionExercise extends SessionExercise {
  const _SessionExercise(
      {required this.id,
      required this.clientExerciseId,
      required this.exerciseId,
      required this.slug,
      required this.name,
      required this.movementPattern,
      required final List<Equipment> equipment,
      required this.difficulty,
      required final List<MuscleGroup> primaryMuscles,
      required final List<MuscleGroup> secondaryMuscles,
      required this.incrementKg,
      required this.orderIndex,
      required this.supersetGroup,
      required this.plannedExerciseId,
      required final List<PlannedSet> targets,
      final List<SetPrefill> prefill = const <SetPrefill>[],
      required this.lastPerformance,
      this.recommendation = null,
      this.priorBest = PriorBest.none,
      final List<PlannedSet>? originalTargets = null,
      required final List<SetLog> sets})
      : _equipment = equipment,
        _primaryMuscles = primaryMuscles,
        _secondaryMuscles = secondaryMuscles,
        _targets = targets,
        _prefill = prefill,
        _originalTargets = originalTargets,
        _sets = sets,
        super._();
  factory _SessionExercise.fromJson(Map<String, dynamic> json) =>
      _$SessionExerciseFromJson(json);

  @override
  final String id;
  @override
  final String clientExerciseId;
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
  final List<MuscleGroup> _primaryMuscles;
  @override
  List<MuscleGroup> get primaryMuscles {
    if (_primaryMuscles is EqualUnmodifiableListView) return _primaryMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_primaryMuscles);
  }

  final List<MuscleGroup> _secondaryMuscles;
  @override
  List<MuscleGroup> get secondaryMuscles {
    if (_secondaryMuscles is EqualUnmodifiableListView)
      return _secondaryMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_secondaryMuscles);
  }

  @override
  final double incrementKg;
  @override
  final int orderIndex;
  @override
  final int? supersetGroup;
  @override
  final String? plannedExerciseId;
  final List<PlannedSet> _targets;
  @override
  List<PlannedSet> get targets {
    if (_targets is EqualUnmodifiableListView) return _targets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targets);
  }

  final List<SetPrefill> _prefill;
  @override
  @JsonKey()
  List<SetPrefill> get prefill {
    if (_prefill is EqualUnmodifiableListView) return _prefill;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_prefill);
  }

  @override
  final LastPerformance? lastPerformance;
  @override
  @JsonKey()
  final ProgressionRecommendation? recommendation;
  @override
  @JsonKey()
  final PriorBest priorBest;
  final List<PlannedSet>? _originalTargets;
  @override
  @JsonKey()
  List<PlannedSet>? get originalTargets {
    final value = _originalTargets;
    if (value == null) return null;
    if (_originalTargets is EqualUnmodifiableListView) return _originalTargets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<SetLog> _sets;
  @override
  List<SetLog> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SessionExerciseCopyWith<_SessionExercise> get copyWith =>
      __$SessionExerciseCopyWithImpl<_SessionExercise>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SessionExerciseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SessionExercise &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientExerciseId, clientExerciseId) ||
                other.clientExerciseId == clientExerciseId) &&
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
            const DeepCollectionEquality()
                .equals(other._primaryMuscles, _primaryMuscles) &&
            const DeepCollectionEquality()
                .equals(other._secondaryMuscles, _secondaryMuscles) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.supersetGroup, supersetGroup) ||
                other.supersetGroup == supersetGroup) &&
            (identical(other.plannedExerciseId, plannedExerciseId) ||
                other.plannedExerciseId == plannedExerciseId) &&
            const DeepCollectionEquality().equals(other._targets, _targets) &&
            const DeepCollectionEquality().equals(other._prefill, _prefill) &&
            (identical(other.lastPerformance, lastPerformance) ||
                other.lastPerformance == lastPerformance) &&
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation) &&
            (identical(other.priorBest, priorBest) ||
                other.priorBest == priorBest) &&
            const DeepCollectionEquality()
                .equals(other._originalTargets, _originalTargets) &&
            const DeepCollectionEquality().equals(other._sets, _sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        clientExerciseId,
        exerciseId,
        slug,
        name,
        movementPattern,
        const DeepCollectionEquality().hash(_equipment),
        difficulty,
        const DeepCollectionEquality().hash(_primaryMuscles),
        const DeepCollectionEquality().hash(_secondaryMuscles),
        incrementKg,
        orderIndex,
        supersetGroup,
        plannedExerciseId,
        const DeepCollectionEquality().hash(_targets),
        const DeepCollectionEquality().hash(_prefill),
        lastPerformance,
        recommendation,
        priorBest,
        const DeepCollectionEquality().hash(_originalTargets),
        const DeepCollectionEquality().hash(_sets)
      ]);

  @override
  String toString() {
    return 'SessionExercise(id: $id, clientExerciseId: $clientExerciseId, exerciseId: $exerciseId, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, primaryMuscles: $primaryMuscles, secondaryMuscles: $secondaryMuscles, incrementKg: $incrementKg, orderIndex: $orderIndex, supersetGroup: $supersetGroup, plannedExerciseId: $plannedExerciseId, targets: $targets, prefill: $prefill, lastPerformance: $lastPerformance, recommendation: $recommendation, priorBest: $priorBest, originalTargets: $originalTargets, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class _$SessionExerciseCopyWith<$Res>
    implements $SessionExerciseCopyWith<$Res> {
  factory _$SessionExerciseCopyWith(
          _SessionExercise value, $Res Function(_SessionExercise) _then) =
      __$SessionExerciseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String clientExerciseId,
      String exerciseId,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      List<MuscleGroup> primaryMuscles,
      List<MuscleGroup> secondaryMuscles,
      double incrementKg,
      int orderIndex,
      int? supersetGroup,
      String? plannedExerciseId,
      List<PlannedSet> targets,
      List<SetPrefill> prefill,
      LastPerformance? lastPerformance,
      ProgressionRecommendation? recommendation,
      PriorBest priorBest,
      List<PlannedSet>? originalTargets,
      List<SetLog> sets});

  @override
  $LastPerformanceCopyWith<$Res>? get lastPerformance;
  @override
  $ProgressionRecommendationCopyWith<$Res>? get recommendation;
  @override
  $PriorBestCopyWith<$Res> get priorBest;
}

/// @nodoc
class __$SessionExerciseCopyWithImpl<$Res>
    implements _$SessionExerciseCopyWith<$Res> {
  __$SessionExerciseCopyWithImpl(this._self, this._then);

  final _SessionExercise _self;
  final $Res Function(_SessionExercise) _then;

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? clientExerciseId = null,
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? primaryMuscles = null,
    Object? secondaryMuscles = null,
    Object? incrementKg = null,
    Object? orderIndex = null,
    Object? supersetGroup = freezed,
    Object? plannedExerciseId = freezed,
    Object? targets = null,
    Object? prefill = null,
    Object? lastPerformance = freezed,
    Object? recommendation = freezed,
    Object? priorBest = null,
    Object? originalTargets = freezed,
    Object? sets = null,
  }) {
    return _then(_SessionExercise(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientExerciseId: null == clientExerciseId
          ? _self.clientExerciseId
          : clientExerciseId // ignore: cast_nullable_to_non_nullable
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
      primaryMuscles: null == primaryMuscles
          ? _self._primaryMuscles
          : primaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      secondaryMuscles: null == secondaryMuscles
          ? _self._secondaryMuscles
          : secondaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      supersetGroup: freezed == supersetGroup
          ? _self.supersetGroup
          : supersetGroup // ignore: cast_nullable_to_non_nullable
              as int?,
      plannedExerciseId: freezed == plannedExerciseId
          ? _self.plannedExerciseId
          : plannedExerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      targets: null == targets
          ? _self._targets
          : targets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>,
      prefill: null == prefill
          ? _self._prefill
          : prefill // ignore: cast_nullable_to_non_nullable
              as List<SetPrefill>,
      lastPerformance: freezed == lastPerformance
          ? _self.lastPerformance
          : lastPerformance // ignore: cast_nullable_to_non_nullable
              as LastPerformance?,
      recommendation: freezed == recommendation
          ? _self.recommendation
          : recommendation // ignore: cast_nullable_to_non_nullable
              as ProgressionRecommendation?,
      priorBest: null == priorBest
          ? _self.priorBest
          : priorBest // ignore: cast_nullable_to_non_nullable
              as PriorBest,
      originalTargets: freezed == originalTargets
          ? _self._originalTargets
          : originalTargets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>?,
      sets: null == sets
          ? _self._sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<SetLog>,
    ));
  }

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LastPerformanceCopyWith<$Res>? get lastPerformance {
    if (_self.lastPerformance == null) {
      return null;
    }

    return $LastPerformanceCopyWith<$Res>(_self.lastPerformance!, (value) {
      return _then(_self.copyWith(lastPerformance: value));
    });
  }

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressionRecommendationCopyWith<$Res>? get recommendation {
    if (_self.recommendation == null) {
      return null;
    }

    return $ProgressionRecommendationCopyWith<$Res>(_self.recommendation!,
        (value) {
      return _then(_self.copyWith(recommendation: value));
    });
  }

  /// Create a copy of SessionExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriorBestCopyWith<$Res> get priorBest {
    return $PriorBestCopyWith<$Res>(_self.priorBest, (value) {
      return _then(_self.copyWith(priorBest: value));
    });
  }
}

/// @nodoc
mixin _$PersonalRecord {
  PrType get prType;
  String get exerciseId;
  String get exerciseName;
  double get value;
  double get previous;
  String get setLogId;
  String get reason;

  /// Create a copy of PersonalRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PersonalRecordCopyWith<PersonalRecord> get copyWith =>
      _$PersonalRecordCopyWithImpl<PersonalRecord>(
          this as PersonalRecord, _$identity);

  /// Serializes this PersonalRecord to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PersonalRecord &&
            (identical(other.prType, prType) || other.prType == prType) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.exerciseName, exerciseName) ||
                other.exerciseName == exerciseName) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.previous, previous) ||
                other.previous == previous) &&
            (identical(other.setLogId, setLogId) ||
                other.setLogId == setLogId) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, prType, exerciseId, exerciseName,
      value, previous, setLogId, reason);

  @override
  String toString() {
    return 'PersonalRecord(prType: $prType, exerciseId: $exerciseId, exerciseName: $exerciseName, value: $value, previous: $previous, setLogId: $setLogId, reason: $reason)';
  }
}

/// @nodoc
abstract mixin class $PersonalRecordCopyWith<$Res> {
  factory $PersonalRecordCopyWith(
          PersonalRecord value, $Res Function(PersonalRecord) _then) =
      _$PersonalRecordCopyWithImpl;
  @useResult
  $Res call(
      {PrType prType,
      String exerciseId,
      String exerciseName,
      double value,
      double previous,
      String setLogId,
      String reason});
}

/// @nodoc
class _$PersonalRecordCopyWithImpl<$Res>
    implements $PersonalRecordCopyWith<$Res> {
  _$PersonalRecordCopyWithImpl(this._self, this._then);

  final PersonalRecord _self;
  final $Res Function(PersonalRecord) _then;

  /// Create a copy of PersonalRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? prType = null,
    Object? exerciseId = null,
    Object? exerciseName = null,
    Object? value = null,
    Object? previous = null,
    Object? setLogId = null,
    Object? reason = null,
  }) {
    return _then(_self.copyWith(
      prType: null == prType
          ? _self.prType
          : prType // ignore: cast_nullable_to_non_nullable
              as PrType,
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseName: null == exerciseName
          ? _self.exerciseName
          : exerciseName // ignore: cast_nullable_to_non_nullable
              as String,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      previous: null == previous
          ? _self.previous
          : previous // ignore: cast_nullable_to_non_nullable
              as double,
      setLogId: null == setLogId
          ? _self.setLogId
          : setLogId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [PersonalRecord].
extension PersonalRecordPatterns on PersonalRecord {
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
    TResult Function(_PersonalRecord value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PersonalRecord() when $default != null:
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
    TResult Function(_PersonalRecord value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PersonalRecord():
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
    TResult? Function(_PersonalRecord value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PersonalRecord() when $default != null:
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
    TResult Function(PrType prType, String exerciseId, String exerciseName,
            double value, double previous, String setLogId, String reason)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PersonalRecord() when $default != null:
        return $default(_that.prType, _that.exerciseId, _that.exerciseName,
            _that.value, _that.previous, _that.setLogId, _that.reason);
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
    TResult Function(PrType prType, String exerciseId, String exerciseName,
            double value, double previous, String setLogId, String reason)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PersonalRecord():
        return $default(_that.prType, _that.exerciseId, _that.exerciseName,
            _that.value, _that.previous, _that.setLogId, _that.reason);
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
    TResult? Function(PrType prType, String exerciseId, String exerciseName,
            double value, double previous, String setLogId, String reason)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PersonalRecord() when $default != null:
        return $default(_that.prType, _that.exerciseId, _that.exerciseName,
            _that.value, _that.previous, _that.setLogId, _that.reason);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PersonalRecord implements PersonalRecord {
  const _PersonalRecord(
      {required this.prType,
      required this.exerciseId,
      required this.exerciseName,
      required this.value,
      required this.previous,
      required this.setLogId,
      required this.reason});
  factory _PersonalRecord.fromJson(Map<String, dynamic> json) =>
      _$PersonalRecordFromJson(json);

  @override
  final PrType prType;
  @override
  final String exerciseId;
  @override
  final String exerciseName;
  @override
  final double value;
  @override
  final double previous;
  @override
  final String setLogId;
  @override
  final String reason;

  /// Create a copy of PersonalRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PersonalRecordCopyWith<_PersonalRecord> get copyWith =>
      __$PersonalRecordCopyWithImpl<_PersonalRecord>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PersonalRecordToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PersonalRecord &&
            (identical(other.prType, prType) || other.prType == prType) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.exerciseName, exerciseName) ||
                other.exerciseName == exerciseName) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.previous, previous) ||
                other.previous == previous) &&
            (identical(other.setLogId, setLogId) ||
                other.setLogId == setLogId) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, prType, exerciseId, exerciseName,
      value, previous, setLogId, reason);

  @override
  String toString() {
    return 'PersonalRecord(prType: $prType, exerciseId: $exerciseId, exerciseName: $exerciseName, value: $value, previous: $previous, setLogId: $setLogId, reason: $reason)';
  }
}

/// @nodoc
abstract mixin class _$PersonalRecordCopyWith<$Res>
    implements $PersonalRecordCopyWith<$Res> {
  factory _$PersonalRecordCopyWith(
          _PersonalRecord value, $Res Function(_PersonalRecord) _then) =
      __$PersonalRecordCopyWithImpl;
  @override
  @useResult
  $Res call(
      {PrType prType,
      String exerciseId,
      String exerciseName,
      double value,
      double previous,
      String setLogId,
      String reason});
}

/// @nodoc
class __$PersonalRecordCopyWithImpl<$Res>
    implements _$PersonalRecordCopyWith<$Res> {
  __$PersonalRecordCopyWithImpl(this._self, this._then);

  final _PersonalRecord _self;
  final $Res Function(_PersonalRecord) _then;

  /// Create a copy of PersonalRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? prType = null,
    Object? exerciseId = null,
    Object? exerciseName = null,
    Object? value = null,
    Object? previous = null,
    Object? setLogId = null,
    Object? reason = null,
  }) {
    return _then(_PersonalRecord(
      prType: null == prType
          ? _self.prType
          : prType // ignore: cast_nullable_to_non_nullable
              as PrType,
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseName: null == exerciseName
          ? _self.exerciseName
          : exerciseName // ignore: cast_nullable_to_non_nullable
              as String,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      previous: null == previous
          ? _self.previous
          : previous // ignore: cast_nullable_to_non_nullable
              as double,
      setLogId: null == setLogId
          ? _self.setLogId
          : setLogId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$SessionSummary {
  int get durationSeconds;
  int get totalSets;
  int get workingSets;
  double get tonnageKg;
  Map<String, double> get hardSetsByMuscle;
  int get exercisesCompleted;
  int get exercisesSkipped;
  List<PersonalRecord> get prs;

  /// Create a copy of SessionSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SessionSummaryCopyWith<SessionSummary> get copyWith =>
      _$SessionSummaryCopyWithImpl<SessionSummary>(
          this as SessionSummary, _$identity);

  /// Serializes this SessionSummary to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SessionSummary &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.totalSets, totalSets) ||
                other.totalSets == totalSets) &&
            (identical(other.workingSets, workingSets) ||
                other.workingSets == workingSets) &&
            (identical(other.tonnageKg, tonnageKg) ||
                other.tonnageKg == tonnageKg) &&
            const DeepCollectionEquality()
                .equals(other.hardSetsByMuscle, hardSetsByMuscle) &&
            (identical(other.exercisesCompleted, exercisesCompleted) ||
                other.exercisesCompleted == exercisesCompleted) &&
            (identical(other.exercisesSkipped, exercisesSkipped) ||
                other.exercisesSkipped == exercisesSkipped) &&
            const DeepCollectionEquality().equals(other.prs, prs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      durationSeconds,
      totalSets,
      workingSets,
      tonnageKg,
      const DeepCollectionEquality().hash(hardSetsByMuscle),
      exercisesCompleted,
      exercisesSkipped,
      const DeepCollectionEquality().hash(prs));

  @override
  String toString() {
    return 'SessionSummary(durationSeconds: $durationSeconds, totalSets: $totalSets, workingSets: $workingSets, tonnageKg: $tonnageKg, hardSetsByMuscle: $hardSetsByMuscle, exercisesCompleted: $exercisesCompleted, exercisesSkipped: $exercisesSkipped, prs: $prs)';
  }
}

/// @nodoc
abstract mixin class $SessionSummaryCopyWith<$Res> {
  factory $SessionSummaryCopyWith(
          SessionSummary value, $Res Function(SessionSummary) _then) =
      _$SessionSummaryCopyWithImpl;
  @useResult
  $Res call(
      {int durationSeconds,
      int totalSets,
      int workingSets,
      double tonnageKg,
      Map<String, double> hardSetsByMuscle,
      int exercisesCompleted,
      int exercisesSkipped,
      List<PersonalRecord> prs});
}

/// @nodoc
class _$SessionSummaryCopyWithImpl<$Res>
    implements $SessionSummaryCopyWith<$Res> {
  _$SessionSummaryCopyWithImpl(this._self, this._then);

  final SessionSummary _self;
  final $Res Function(SessionSummary) _then;

  /// Create a copy of SessionSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? durationSeconds = null,
    Object? totalSets = null,
    Object? workingSets = null,
    Object? tonnageKg = null,
    Object? hardSetsByMuscle = null,
    Object? exercisesCompleted = null,
    Object? exercisesSkipped = null,
    Object? prs = null,
  }) {
    return _then(_self.copyWith(
      durationSeconds: null == durationSeconds
          ? _self.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      totalSets: null == totalSets
          ? _self.totalSets
          : totalSets // ignore: cast_nullable_to_non_nullable
              as int,
      workingSets: null == workingSets
          ? _self.workingSets
          : workingSets // ignore: cast_nullable_to_non_nullable
              as int,
      tonnageKg: null == tonnageKg
          ? _self.tonnageKg
          : tonnageKg // ignore: cast_nullable_to_non_nullable
              as double,
      hardSetsByMuscle: null == hardSetsByMuscle
          ? _self.hardSetsByMuscle
          : hardSetsByMuscle // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      exercisesCompleted: null == exercisesCompleted
          ? _self.exercisesCompleted
          : exercisesCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      exercisesSkipped: null == exercisesSkipped
          ? _self.exercisesSkipped
          : exercisesSkipped // ignore: cast_nullable_to_non_nullable
              as int,
      prs: null == prs
          ? _self.prs
          : prs // ignore: cast_nullable_to_non_nullable
              as List<PersonalRecord>,
    ));
  }
}

/// Adds pattern-matching-related methods to [SessionSummary].
extension SessionSummaryPatterns on SessionSummary {
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
    TResult Function(_SessionSummary value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionSummary() when $default != null:
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
    TResult Function(_SessionSummary value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionSummary():
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
    TResult? Function(_SessionSummary value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionSummary() when $default != null:
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
            int durationSeconds,
            int totalSets,
            int workingSets,
            double tonnageKg,
            Map<String, double> hardSetsByMuscle,
            int exercisesCompleted,
            int exercisesSkipped,
            List<PersonalRecord> prs)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionSummary() when $default != null:
        return $default(
            _that.durationSeconds,
            _that.totalSets,
            _that.workingSets,
            _that.tonnageKg,
            _that.hardSetsByMuscle,
            _that.exercisesCompleted,
            _that.exercisesSkipped,
            _that.prs);
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
            int durationSeconds,
            int totalSets,
            int workingSets,
            double tonnageKg,
            Map<String, double> hardSetsByMuscle,
            int exercisesCompleted,
            int exercisesSkipped,
            List<PersonalRecord> prs)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionSummary():
        return $default(
            _that.durationSeconds,
            _that.totalSets,
            _that.workingSets,
            _that.tonnageKg,
            _that.hardSetsByMuscle,
            _that.exercisesCompleted,
            _that.exercisesSkipped,
            _that.prs);
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
            int durationSeconds,
            int totalSets,
            int workingSets,
            double tonnageKg,
            Map<String, double> hardSetsByMuscle,
            int exercisesCompleted,
            int exercisesSkipped,
            List<PersonalRecord> prs)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionSummary() when $default != null:
        return $default(
            _that.durationSeconds,
            _that.totalSets,
            _that.workingSets,
            _that.tonnageKg,
            _that.hardSetsByMuscle,
            _that.exercisesCompleted,
            _that.exercisesSkipped,
            _that.prs);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SessionSummary implements SessionSummary {
  const _SessionSummary(
      {required this.durationSeconds,
      required this.totalSets,
      required this.workingSets,
      required this.tonnageKg,
      required final Map<String, double> hardSetsByMuscle,
      required this.exercisesCompleted,
      required this.exercisesSkipped,
      required final List<PersonalRecord> prs})
      : _hardSetsByMuscle = hardSetsByMuscle,
        _prs = prs;
  factory _SessionSummary.fromJson(Map<String, dynamic> json) =>
      _$SessionSummaryFromJson(json);

  @override
  final int durationSeconds;
  @override
  final int totalSets;
  @override
  final int workingSets;
  @override
  final double tonnageKg;
  final Map<String, double> _hardSetsByMuscle;
  @override
  Map<String, double> get hardSetsByMuscle {
    if (_hardSetsByMuscle is EqualUnmodifiableMapView) return _hardSetsByMuscle;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_hardSetsByMuscle);
  }

  @override
  final int exercisesCompleted;
  @override
  final int exercisesSkipped;
  final List<PersonalRecord> _prs;
  @override
  List<PersonalRecord> get prs {
    if (_prs is EqualUnmodifiableListView) return _prs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_prs);
  }

  /// Create a copy of SessionSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SessionSummaryCopyWith<_SessionSummary> get copyWith =>
      __$SessionSummaryCopyWithImpl<_SessionSummary>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SessionSummaryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SessionSummary &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.totalSets, totalSets) ||
                other.totalSets == totalSets) &&
            (identical(other.workingSets, workingSets) ||
                other.workingSets == workingSets) &&
            (identical(other.tonnageKg, tonnageKg) ||
                other.tonnageKg == tonnageKg) &&
            const DeepCollectionEquality()
                .equals(other._hardSetsByMuscle, _hardSetsByMuscle) &&
            (identical(other.exercisesCompleted, exercisesCompleted) ||
                other.exercisesCompleted == exercisesCompleted) &&
            (identical(other.exercisesSkipped, exercisesSkipped) ||
                other.exercisesSkipped == exercisesSkipped) &&
            const DeepCollectionEquality().equals(other._prs, _prs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      durationSeconds,
      totalSets,
      workingSets,
      tonnageKg,
      const DeepCollectionEquality().hash(_hardSetsByMuscle),
      exercisesCompleted,
      exercisesSkipped,
      const DeepCollectionEquality().hash(_prs));

  @override
  String toString() {
    return 'SessionSummary(durationSeconds: $durationSeconds, totalSets: $totalSets, workingSets: $workingSets, tonnageKg: $tonnageKg, hardSetsByMuscle: $hardSetsByMuscle, exercisesCompleted: $exercisesCompleted, exercisesSkipped: $exercisesSkipped, prs: $prs)';
  }
}

/// @nodoc
abstract mixin class _$SessionSummaryCopyWith<$Res>
    implements $SessionSummaryCopyWith<$Res> {
  factory _$SessionSummaryCopyWith(
          _SessionSummary value, $Res Function(_SessionSummary) _then) =
      __$SessionSummaryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int durationSeconds,
      int totalSets,
      int workingSets,
      double tonnageKg,
      Map<String, double> hardSetsByMuscle,
      int exercisesCompleted,
      int exercisesSkipped,
      List<PersonalRecord> prs});
}

/// @nodoc
class __$SessionSummaryCopyWithImpl<$Res>
    implements _$SessionSummaryCopyWith<$Res> {
  __$SessionSummaryCopyWithImpl(this._self, this._then);

  final _SessionSummary _self;
  final $Res Function(_SessionSummary) _then;

  /// Create a copy of SessionSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? durationSeconds = null,
    Object? totalSets = null,
    Object? workingSets = null,
    Object? tonnageKg = null,
    Object? hardSetsByMuscle = null,
    Object? exercisesCompleted = null,
    Object? exercisesSkipped = null,
    Object? prs = null,
  }) {
    return _then(_SessionSummary(
      durationSeconds: null == durationSeconds
          ? _self.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      totalSets: null == totalSets
          ? _self.totalSets
          : totalSets // ignore: cast_nullable_to_non_nullable
              as int,
      workingSets: null == workingSets
          ? _self.workingSets
          : workingSets // ignore: cast_nullable_to_non_nullable
              as int,
      tonnageKg: null == tonnageKg
          ? _self.tonnageKg
          : tonnageKg // ignore: cast_nullable_to_non_nullable
              as double,
      hardSetsByMuscle: null == hardSetsByMuscle
          ? _self._hardSetsByMuscle
          : hardSetsByMuscle // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      exercisesCompleted: null == exercisesCompleted
          ? _self.exercisesCompleted
          : exercisesCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      exercisesSkipped: null == exercisesSkipped
          ? _self.exercisesSkipped
          : exercisesSkipped // ignore: cast_nullable_to_non_nullable
              as int,
      prs: null == prs
          ? _self._prs
          : prs // ignore: cast_nullable_to_non_nullable
              as List<PersonalRecord>,
    ));
  }
}

/// @nodoc
mixin _$WorkoutSession {
  String get id;
  String get clientSessionId;
  SessionStatus get status;
  String? get programId;
  String? get programDayId;
  String get name;
  String get startedAt;
  String? get completedAt;
  int? get durationSeconds;
  String? get notes;
  List<SessionExercise> get exercises;
  SessionSummary? get summary;

  /// Create a copy of WorkoutSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WorkoutSessionCopyWith<WorkoutSession> get copyWith =>
      _$WorkoutSessionCopyWithImpl<WorkoutSession>(
          this as WorkoutSession, _$identity);

  /// Serializes this WorkoutSession to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WorkoutSession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientSessionId, clientSessionId) ||
                other.clientSessionId == clientSessionId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.programId, programId) ||
                other.programId == programId) &&
            (identical(other.programDayId, programDayId) ||
                other.programDayId == programDayId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality().equals(other.exercises, exercises) &&
            (identical(other.summary, summary) || other.summary == summary));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      clientSessionId,
      status,
      programId,
      programDayId,
      name,
      startedAt,
      completedAt,
      durationSeconds,
      notes,
      const DeepCollectionEquality().hash(exercises),
      summary);

  @override
  String toString() {
    return 'WorkoutSession(id: $id, clientSessionId: $clientSessionId, status: $status, programId: $programId, programDayId: $programDayId, name: $name, startedAt: $startedAt, completedAt: $completedAt, durationSeconds: $durationSeconds, notes: $notes, exercises: $exercises, summary: $summary)';
  }
}

/// @nodoc
abstract mixin class $WorkoutSessionCopyWith<$Res> {
  factory $WorkoutSessionCopyWith(
          WorkoutSession value, $Res Function(WorkoutSession) _then) =
      _$WorkoutSessionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String clientSessionId,
      SessionStatus status,
      String? programId,
      String? programDayId,
      String name,
      String startedAt,
      String? completedAt,
      int? durationSeconds,
      String? notes,
      List<SessionExercise> exercises,
      SessionSummary? summary});

  $SessionSummaryCopyWith<$Res>? get summary;
}

/// @nodoc
class _$WorkoutSessionCopyWithImpl<$Res>
    implements $WorkoutSessionCopyWith<$Res> {
  _$WorkoutSessionCopyWithImpl(this._self, this._then);

  final WorkoutSession _self;
  final $Res Function(WorkoutSession) _then;

  /// Create a copy of WorkoutSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientSessionId = null,
    Object? status = null,
    Object? programId = freezed,
    Object? programDayId = freezed,
    Object? name = null,
    Object? startedAt = null,
    Object? completedAt = freezed,
    Object? durationSeconds = freezed,
    Object? notes = freezed,
    Object? exercises = null,
    Object? summary = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientSessionId: null == clientSessionId
          ? _self.clientSessionId
          : clientSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SessionStatus,
      programId: freezed == programId
          ? _self.programId
          : programId // ignore: cast_nullable_to_non_nullable
              as String?,
      programDayId: freezed == programDayId
          ? _self.programDayId
          : programDayId // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as String,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      durationSeconds: freezed == durationSeconds
          ? _self.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      exercises: null == exercises
          ? _self.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<SessionExercise>,
      summary: freezed == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as SessionSummary?,
    ));
  }

  /// Create a copy of WorkoutSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
      return null;
    }

    return $SessionSummaryCopyWith<$Res>(_self.summary!, (value) {
      return _then(_self.copyWith(summary: value));
    });
  }
}

/// Adds pattern-matching-related methods to [WorkoutSession].
extension WorkoutSessionPatterns on WorkoutSession {
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
    TResult Function(_WorkoutSession value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WorkoutSession() when $default != null:
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
    TResult Function(_WorkoutSession value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkoutSession():
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
    TResult? Function(_WorkoutSession value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkoutSession() when $default != null:
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
            String clientSessionId,
            SessionStatus status,
            String? programId,
            String? programDayId,
            String name,
            String startedAt,
            String? completedAt,
            int? durationSeconds,
            String? notes,
            List<SessionExercise> exercises,
            SessionSummary? summary)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WorkoutSession() when $default != null:
        return $default(
            _that.id,
            _that.clientSessionId,
            _that.status,
            _that.programId,
            _that.programDayId,
            _that.name,
            _that.startedAt,
            _that.completedAt,
            _that.durationSeconds,
            _that.notes,
            _that.exercises,
            _that.summary);
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
            String clientSessionId,
            SessionStatus status,
            String? programId,
            String? programDayId,
            String name,
            String startedAt,
            String? completedAt,
            int? durationSeconds,
            String? notes,
            List<SessionExercise> exercises,
            SessionSummary? summary)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkoutSession():
        return $default(
            _that.id,
            _that.clientSessionId,
            _that.status,
            _that.programId,
            _that.programDayId,
            _that.name,
            _that.startedAt,
            _that.completedAt,
            _that.durationSeconds,
            _that.notes,
            _that.exercises,
            _that.summary);
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
            String clientSessionId,
            SessionStatus status,
            String? programId,
            String? programDayId,
            String name,
            String startedAt,
            String? completedAt,
            int? durationSeconds,
            String? notes,
            List<SessionExercise> exercises,
            SessionSummary? summary)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkoutSession() when $default != null:
        return $default(
            _that.id,
            _that.clientSessionId,
            _that.status,
            _that.programId,
            _that.programDayId,
            _that.name,
            _that.startedAt,
            _that.completedAt,
            _that.durationSeconds,
            _that.notes,
            _that.exercises,
            _that.summary);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _WorkoutSession extends WorkoutSession {
  const _WorkoutSession(
      {required this.id,
      required this.clientSessionId,
      required this.status,
      required this.programId,
      required this.programDayId,
      required this.name,
      required this.startedAt,
      required this.completedAt,
      required this.durationSeconds,
      required this.notes,
      required final List<SessionExercise> exercises,
      required this.summary})
      : _exercises = exercises,
        super._();
  factory _WorkoutSession.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSessionFromJson(json);

  @override
  final String id;
  @override
  final String clientSessionId;
  @override
  final SessionStatus status;
  @override
  final String? programId;
  @override
  final String? programDayId;
  @override
  final String name;
  @override
  final String startedAt;
  @override
  final String? completedAt;
  @override
  final int? durationSeconds;
  @override
  final String? notes;
  final List<SessionExercise> _exercises;
  @override
  List<SessionExercise> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  @override
  final SessionSummary? summary;

  /// Create a copy of WorkoutSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WorkoutSessionCopyWith<_WorkoutSession> get copyWith =>
      __$WorkoutSessionCopyWithImpl<_WorkoutSession>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WorkoutSessionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WorkoutSession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientSessionId, clientSessionId) ||
                other.clientSessionId == clientSessionId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.programId, programId) ||
                other.programId == programId) &&
            (identical(other.programDayId, programDayId) ||
                other.programDayId == programDayId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises) &&
            (identical(other.summary, summary) || other.summary == summary));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      clientSessionId,
      status,
      programId,
      programDayId,
      name,
      startedAt,
      completedAt,
      durationSeconds,
      notes,
      const DeepCollectionEquality().hash(_exercises),
      summary);

  @override
  String toString() {
    return 'WorkoutSession(id: $id, clientSessionId: $clientSessionId, status: $status, programId: $programId, programDayId: $programDayId, name: $name, startedAt: $startedAt, completedAt: $completedAt, durationSeconds: $durationSeconds, notes: $notes, exercises: $exercises, summary: $summary)';
  }
}

/// @nodoc
abstract mixin class _$WorkoutSessionCopyWith<$Res>
    implements $WorkoutSessionCopyWith<$Res> {
  factory _$WorkoutSessionCopyWith(
          _WorkoutSession value, $Res Function(_WorkoutSession) _then) =
      __$WorkoutSessionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String clientSessionId,
      SessionStatus status,
      String? programId,
      String? programDayId,
      String name,
      String startedAt,
      String? completedAt,
      int? durationSeconds,
      String? notes,
      List<SessionExercise> exercises,
      SessionSummary? summary});

  @override
  $SessionSummaryCopyWith<$Res>? get summary;
}

/// @nodoc
class __$WorkoutSessionCopyWithImpl<$Res>
    implements _$WorkoutSessionCopyWith<$Res> {
  __$WorkoutSessionCopyWithImpl(this._self, this._then);

  final _WorkoutSession _self;
  final $Res Function(_WorkoutSession) _then;

  /// Create a copy of WorkoutSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? clientSessionId = null,
    Object? status = null,
    Object? programId = freezed,
    Object? programDayId = freezed,
    Object? name = null,
    Object? startedAt = null,
    Object? completedAt = freezed,
    Object? durationSeconds = freezed,
    Object? notes = freezed,
    Object? exercises = null,
    Object? summary = freezed,
  }) {
    return _then(_WorkoutSession(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientSessionId: null == clientSessionId
          ? _self.clientSessionId
          : clientSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SessionStatus,
      programId: freezed == programId
          ? _self.programId
          : programId // ignore: cast_nullable_to_non_nullable
              as String?,
      programDayId: freezed == programDayId
          ? _self.programDayId
          : programDayId // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as String,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      durationSeconds: freezed == durationSeconds
          ? _self.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      exercises: null == exercises
          ? _self._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<SessionExercise>,
      summary: freezed == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as SessionSummary?,
    ));
  }

  /// Create a copy of WorkoutSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
      return null;
    }

    return $SessionSummaryCopyWith<$Res>(_self.summary!, (value) {
      return _then(_self.copyWith(summary: value));
    });
  }
}

/// @nodoc
mixin _$SessionListItem {
  String get id;
  SessionStatus get status;
  String get name;
  String get startedAt;
  String? get completedAt;
  int? get durationSeconds;
  int get exerciseCount;
  int get workingSets;
  double get tonnageKg;
  int get prCount;

  /// Create a copy of SessionListItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SessionListItemCopyWith<SessionListItem> get copyWith =>
      _$SessionListItemCopyWithImpl<SessionListItem>(
          this as SessionListItem, _$identity);

  /// Serializes this SessionListItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SessionListItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.exerciseCount, exerciseCount) ||
                other.exerciseCount == exerciseCount) &&
            (identical(other.workingSets, workingSets) ||
                other.workingSets == workingSets) &&
            (identical(other.tonnageKg, tonnageKg) ||
                other.tonnageKg == tonnageKg) &&
            (identical(other.prCount, prCount) || other.prCount == prCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      status,
      name,
      startedAt,
      completedAt,
      durationSeconds,
      exerciseCount,
      workingSets,
      tonnageKg,
      prCount);

  @override
  String toString() {
    return 'SessionListItem(id: $id, status: $status, name: $name, startedAt: $startedAt, completedAt: $completedAt, durationSeconds: $durationSeconds, exerciseCount: $exerciseCount, workingSets: $workingSets, tonnageKg: $tonnageKg, prCount: $prCount)';
  }
}

/// @nodoc
abstract mixin class $SessionListItemCopyWith<$Res> {
  factory $SessionListItemCopyWith(
          SessionListItem value, $Res Function(SessionListItem) _then) =
      _$SessionListItemCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      SessionStatus status,
      String name,
      String startedAt,
      String? completedAt,
      int? durationSeconds,
      int exerciseCount,
      int workingSets,
      double tonnageKg,
      int prCount});
}

/// @nodoc
class _$SessionListItemCopyWithImpl<$Res>
    implements $SessionListItemCopyWith<$Res> {
  _$SessionListItemCopyWithImpl(this._self, this._then);

  final SessionListItem _self;
  final $Res Function(SessionListItem) _then;

  /// Create a copy of SessionListItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? name = null,
    Object? startedAt = null,
    Object? completedAt = freezed,
    Object? durationSeconds = freezed,
    Object? exerciseCount = null,
    Object? workingSets = null,
    Object? tonnageKg = null,
    Object? prCount = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SessionStatus,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as String,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      durationSeconds: freezed == durationSeconds
          ? _self.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      exerciseCount: null == exerciseCount
          ? _self.exerciseCount
          : exerciseCount // ignore: cast_nullable_to_non_nullable
              as int,
      workingSets: null == workingSets
          ? _self.workingSets
          : workingSets // ignore: cast_nullable_to_non_nullable
              as int,
      tonnageKg: null == tonnageKg
          ? _self.tonnageKg
          : tonnageKg // ignore: cast_nullable_to_non_nullable
              as double,
      prCount: null == prCount
          ? _self.prCount
          : prCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [SessionListItem].
extension SessionListItemPatterns on SessionListItem {
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
    TResult Function(_SessionListItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionListItem() when $default != null:
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
    TResult Function(_SessionListItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionListItem():
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
    TResult? Function(_SessionListItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionListItem() when $default != null:
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
            SessionStatus status,
            String name,
            String startedAt,
            String? completedAt,
            int? durationSeconds,
            int exerciseCount,
            int workingSets,
            double tonnageKg,
            int prCount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionListItem() when $default != null:
        return $default(
            _that.id,
            _that.status,
            _that.name,
            _that.startedAt,
            _that.completedAt,
            _that.durationSeconds,
            _that.exerciseCount,
            _that.workingSets,
            _that.tonnageKg,
            _that.prCount);
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
            SessionStatus status,
            String name,
            String startedAt,
            String? completedAt,
            int? durationSeconds,
            int exerciseCount,
            int workingSets,
            double tonnageKg,
            int prCount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionListItem():
        return $default(
            _that.id,
            _that.status,
            _that.name,
            _that.startedAt,
            _that.completedAt,
            _that.durationSeconds,
            _that.exerciseCount,
            _that.workingSets,
            _that.tonnageKg,
            _that.prCount);
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
            SessionStatus status,
            String name,
            String startedAt,
            String? completedAt,
            int? durationSeconds,
            int exerciseCount,
            int workingSets,
            double tonnageKg,
            int prCount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionListItem() when $default != null:
        return $default(
            _that.id,
            _that.status,
            _that.name,
            _that.startedAt,
            _that.completedAt,
            _that.durationSeconds,
            _that.exerciseCount,
            _that.workingSets,
            _that.tonnageKg,
            _that.prCount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SessionListItem implements SessionListItem {
  const _SessionListItem(
      {required this.id,
      required this.status,
      required this.name,
      required this.startedAt,
      required this.completedAt,
      required this.durationSeconds,
      required this.exerciseCount,
      required this.workingSets,
      required this.tonnageKg,
      required this.prCount});
  factory _SessionListItem.fromJson(Map<String, dynamic> json) =>
      _$SessionListItemFromJson(json);

  @override
  final String id;
  @override
  final SessionStatus status;
  @override
  final String name;
  @override
  final String startedAt;
  @override
  final String? completedAt;
  @override
  final int? durationSeconds;
  @override
  final int exerciseCount;
  @override
  final int workingSets;
  @override
  final double tonnageKg;
  @override
  final int prCount;

  /// Create a copy of SessionListItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SessionListItemCopyWith<_SessionListItem> get copyWith =>
      __$SessionListItemCopyWithImpl<_SessionListItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SessionListItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SessionListItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.exerciseCount, exerciseCount) ||
                other.exerciseCount == exerciseCount) &&
            (identical(other.workingSets, workingSets) ||
                other.workingSets == workingSets) &&
            (identical(other.tonnageKg, tonnageKg) ||
                other.tonnageKg == tonnageKg) &&
            (identical(other.prCount, prCount) || other.prCount == prCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      status,
      name,
      startedAt,
      completedAt,
      durationSeconds,
      exerciseCount,
      workingSets,
      tonnageKg,
      prCount);

  @override
  String toString() {
    return 'SessionListItem(id: $id, status: $status, name: $name, startedAt: $startedAt, completedAt: $completedAt, durationSeconds: $durationSeconds, exerciseCount: $exerciseCount, workingSets: $workingSets, tonnageKg: $tonnageKg, prCount: $prCount)';
  }
}

/// @nodoc
abstract mixin class _$SessionListItemCopyWith<$Res>
    implements $SessionListItemCopyWith<$Res> {
  factory _$SessionListItemCopyWith(
          _SessionListItem value, $Res Function(_SessionListItem) _then) =
      __$SessionListItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      SessionStatus status,
      String name,
      String startedAt,
      String? completedAt,
      int? durationSeconds,
      int exerciseCount,
      int workingSets,
      double tonnageKg,
      int prCount});
}

/// @nodoc
class __$SessionListItemCopyWithImpl<$Res>
    implements _$SessionListItemCopyWith<$Res> {
  __$SessionListItemCopyWithImpl(this._self, this._then);

  final _SessionListItem _self;
  final $Res Function(_SessionListItem) _then;

  /// Create a copy of SessionListItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? name = null,
    Object? startedAt = null,
    Object? completedAt = freezed,
    Object? durationSeconds = freezed,
    Object? exerciseCount = null,
    Object? workingSets = null,
    Object? tonnageKg = null,
    Object? prCount = null,
  }) {
    return _then(_SessionListItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SessionStatus,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as String,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      durationSeconds: freezed == durationSeconds
          ? _self.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      exerciseCount: null == exerciseCount
          ? _self.exerciseCount
          : exerciseCount // ignore: cast_nullable_to_non_nullable
              as int,
      workingSets: null == workingSets
          ? _self.workingSets
          : workingSets // ignore: cast_nullable_to_non_nullable
              as int,
      tonnageKg: null == tonnageKg
          ? _self.tonnageKg
          : tonnageKg // ignore: cast_nullable_to_non_nullable
              as double,
      prCount: null == prCount
          ? _self.prCount
          : prCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$SessionListResponse {
  List<SessionListItem> get items;
  String? get nextBefore;

  /// Create a copy of SessionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SessionListResponseCopyWith<SessionListResponse> get copyWith =>
      _$SessionListResponseCopyWithImpl<SessionListResponse>(
          this as SessionListResponse, _$identity);

  /// Serializes this SessionListResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SessionListResponse &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.nextBefore, nextBefore) ||
                other.nextBefore == nextBefore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(items), nextBefore);

  @override
  String toString() {
    return 'SessionListResponse(items: $items, nextBefore: $nextBefore)';
  }
}

/// @nodoc
abstract mixin class $SessionListResponseCopyWith<$Res> {
  factory $SessionListResponseCopyWith(
          SessionListResponse value, $Res Function(SessionListResponse) _then) =
      _$SessionListResponseCopyWithImpl;
  @useResult
  $Res call({List<SessionListItem> items, String? nextBefore});
}

/// @nodoc
class _$SessionListResponseCopyWithImpl<$Res>
    implements $SessionListResponseCopyWith<$Res> {
  _$SessionListResponseCopyWithImpl(this._self, this._then);

  final SessionListResponse _self;
  final $Res Function(SessionListResponse) _then;

  /// Create a copy of SessionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? nextBefore = freezed,
  }) {
    return _then(_self.copyWith(
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<SessionListItem>,
      nextBefore: freezed == nextBefore
          ? _self.nextBefore
          : nextBefore // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SessionListResponse].
extension SessionListResponsePatterns on SessionListResponse {
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
    TResult Function(_SessionListResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionListResponse() when $default != null:
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
    TResult Function(_SessionListResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionListResponse():
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
    TResult? Function(_SessionListResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionListResponse() when $default != null:
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
    TResult Function(List<SessionListItem> items, String? nextBefore)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionListResponse() when $default != null:
        return $default(_that.items, _that.nextBefore);
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
    TResult Function(List<SessionListItem> items, String? nextBefore) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionListResponse():
        return $default(_that.items, _that.nextBefore);
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
    TResult? Function(List<SessionListItem> items, String? nextBefore)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionListResponse() when $default != null:
        return $default(_that.items, _that.nextBefore);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SessionListResponse implements SessionListResponse {
  const _SessionListResponse(
      {required final List<SessionListItem> items, required this.nextBefore})
      : _items = items;
  factory _SessionListResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionListResponseFromJson(json);

  final List<SessionListItem> _items;
  @override
  List<SessionListItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String? nextBefore;

  /// Create a copy of SessionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SessionListResponseCopyWith<_SessionListResponse> get copyWith =>
      __$SessionListResponseCopyWithImpl<_SessionListResponse>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SessionListResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SessionListResponse &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.nextBefore, nextBefore) ||
                other.nextBefore == nextBefore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_items), nextBefore);

  @override
  String toString() {
    return 'SessionListResponse(items: $items, nextBefore: $nextBefore)';
  }
}

/// @nodoc
abstract mixin class _$SessionListResponseCopyWith<$Res>
    implements $SessionListResponseCopyWith<$Res> {
  factory _$SessionListResponseCopyWith(_SessionListResponse value,
          $Res Function(_SessionListResponse) _then) =
      __$SessionListResponseCopyWithImpl;
  @override
  @useResult
  $Res call({List<SessionListItem> items, String? nextBefore});
}

/// @nodoc
class __$SessionListResponseCopyWithImpl<$Res>
    implements _$SessionListResponseCopyWith<$Res> {
  __$SessionListResponseCopyWithImpl(this._self, this._then);

  final _SessionListResponse _self;
  final $Res Function(_SessionListResponse) _then;

  /// Create a copy of SessionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
    Object? nextBefore = freezed,
  }) {
    return _then(_SessionListResponse(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<SessionListItem>,
      nextBefore: freezed == nextBefore
          ? _self.nextBefore
          : nextBefore // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$TodayExercise {
  String get plannedExerciseId;
  String get exerciseId;
  String get slug;
  String get name;
  MovementPattern get movementPattern;
  List<Equipment> get equipment;
  Difficulty get difficulty;
  List<MuscleGroup> get primaryMuscles;
  List<MuscleGroup> get secondaryMuscles;
  int get orderIndex;
  double get incrementKg;
  List<PlannedSet> get targets;
  List<SetPrefill> get prefill;
  LastPerformance? get lastPerformance;
  ProgressionRecommendation? get recommendation;
  PriorBest get priorBest;
  List<PlannedSet>? get originalTargets;
  Substitution? get substitution;

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TodayExerciseCopyWith<TodayExercise> get copyWith =>
      _$TodayExerciseCopyWithImpl<TodayExercise>(
          this as TodayExercise, _$identity);

  /// Serializes this TodayExercise to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TodayExercise &&
            (identical(other.plannedExerciseId, plannedExerciseId) ||
                other.plannedExerciseId == plannedExerciseId) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.movementPattern, movementPattern) ||
                other.movementPattern == movementPattern) &&
            const DeepCollectionEquality().equals(other.equipment, equipment) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            const DeepCollectionEquality()
                .equals(other.primaryMuscles, primaryMuscles) &&
            const DeepCollectionEquality()
                .equals(other.secondaryMuscles, secondaryMuscles) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            const DeepCollectionEquality().equals(other.targets, targets) &&
            const DeepCollectionEquality().equals(other.prefill, prefill) &&
            (identical(other.lastPerformance, lastPerformance) ||
                other.lastPerformance == lastPerformance) &&
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation) &&
            (identical(other.priorBest, priorBest) ||
                other.priorBest == priorBest) &&
            const DeepCollectionEquality()
                .equals(other.originalTargets, originalTargets) &&
            (identical(other.substitution, substitution) ||
                other.substitution == substitution));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      plannedExerciseId,
      exerciseId,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(equipment),
      difficulty,
      const DeepCollectionEquality().hash(primaryMuscles),
      const DeepCollectionEquality().hash(secondaryMuscles),
      orderIndex,
      incrementKg,
      const DeepCollectionEquality().hash(targets),
      const DeepCollectionEquality().hash(prefill),
      lastPerformance,
      recommendation,
      priorBest,
      const DeepCollectionEquality().hash(originalTargets),
      substitution);

  @override
  String toString() {
    return 'TodayExercise(plannedExerciseId: $plannedExerciseId, exerciseId: $exerciseId, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, primaryMuscles: $primaryMuscles, secondaryMuscles: $secondaryMuscles, orderIndex: $orderIndex, incrementKg: $incrementKg, targets: $targets, prefill: $prefill, lastPerformance: $lastPerformance, recommendation: $recommendation, priorBest: $priorBest, originalTargets: $originalTargets, substitution: $substitution)';
  }
}

/// @nodoc
abstract mixin class $TodayExerciseCopyWith<$Res> {
  factory $TodayExerciseCopyWith(
          TodayExercise value, $Res Function(TodayExercise) _then) =
      _$TodayExerciseCopyWithImpl;
  @useResult
  $Res call(
      {String plannedExerciseId,
      String exerciseId,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      List<MuscleGroup> primaryMuscles,
      List<MuscleGroup> secondaryMuscles,
      int orderIndex,
      double incrementKg,
      List<PlannedSet> targets,
      List<SetPrefill> prefill,
      LastPerformance? lastPerformance,
      ProgressionRecommendation? recommendation,
      PriorBest priorBest,
      List<PlannedSet>? originalTargets,
      Substitution? substitution});

  $LastPerformanceCopyWith<$Res>? get lastPerformance;
  $ProgressionRecommendationCopyWith<$Res>? get recommendation;
  $PriorBestCopyWith<$Res> get priorBest;
  $SubstitutionCopyWith<$Res>? get substitution;
}

/// @nodoc
class _$TodayExerciseCopyWithImpl<$Res>
    implements $TodayExerciseCopyWith<$Res> {
  _$TodayExerciseCopyWithImpl(this._self, this._then);

  final TodayExercise _self;
  final $Res Function(TodayExercise) _then;

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plannedExerciseId = null,
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? primaryMuscles = null,
    Object? secondaryMuscles = null,
    Object? orderIndex = null,
    Object? incrementKg = null,
    Object? targets = null,
    Object? prefill = null,
    Object? lastPerformance = freezed,
    Object? recommendation = freezed,
    Object? priorBest = null,
    Object? originalTargets = freezed,
    Object? substitution = freezed,
  }) {
    return _then(_self.copyWith(
      plannedExerciseId: null == plannedExerciseId
          ? _self.plannedExerciseId
          : plannedExerciseId // ignore: cast_nullable_to_non_nullable
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
      primaryMuscles: null == primaryMuscles
          ? _self.primaryMuscles
          : primaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      secondaryMuscles: null == secondaryMuscles
          ? _self.secondaryMuscles
          : secondaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      targets: null == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>,
      prefill: null == prefill
          ? _self.prefill
          : prefill // ignore: cast_nullable_to_non_nullable
              as List<SetPrefill>,
      lastPerformance: freezed == lastPerformance
          ? _self.lastPerformance
          : lastPerformance // ignore: cast_nullable_to_non_nullable
              as LastPerformance?,
      recommendation: freezed == recommendation
          ? _self.recommendation
          : recommendation // ignore: cast_nullable_to_non_nullable
              as ProgressionRecommendation?,
      priorBest: null == priorBest
          ? _self.priorBest
          : priorBest // ignore: cast_nullable_to_non_nullable
              as PriorBest,
      originalTargets: freezed == originalTargets
          ? _self.originalTargets
          : originalTargets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>?,
      substitution: freezed == substitution
          ? _self.substitution
          : substitution // ignore: cast_nullable_to_non_nullable
              as Substitution?,
    ));
  }

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LastPerformanceCopyWith<$Res>? get lastPerformance {
    if (_self.lastPerformance == null) {
      return null;
    }

    return $LastPerformanceCopyWith<$Res>(_self.lastPerformance!, (value) {
      return _then(_self.copyWith(lastPerformance: value));
    });
  }

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressionRecommendationCopyWith<$Res>? get recommendation {
    if (_self.recommendation == null) {
      return null;
    }

    return $ProgressionRecommendationCopyWith<$Res>(_self.recommendation!,
        (value) {
      return _then(_self.copyWith(recommendation: value));
    });
  }

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriorBestCopyWith<$Res> get priorBest {
    return $PriorBestCopyWith<$Res>(_self.priorBest, (value) {
      return _then(_self.copyWith(priorBest: value));
    });
  }

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SubstitutionCopyWith<$Res>? get substitution {
    if (_self.substitution == null) {
      return null;
    }

    return $SubstitutionCopyWith<$Res>(_self.substitution!, (value) {
      return _then(_self.copyWith(substitution: value));
    });
  }
}

/// Adds pattern-matching-related methods to [TodayExercise].
extension TodayExercisePatterns on TodayExercise {
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
    TResult Function(_TodayExercise value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TodayExercise() when $default != null:
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
    TResult Function(_TodayExercise value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TodayExercise():
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
    TResult? Function(_TodayExercise value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TodayExercise() when $default != null:
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
            String plannedExerciseId,
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            List<MuscleGroup> primaryMuscles,
            List<MuscleGroup> secondaryMuscles,
            int orderIndex,
            double incrementKg,
            List<PlannedSet> targets,
            List<SetPrefill> prefill,
            LastPerformance? lastPerformance,
            ProgressionRecommendation? recommendation,
            PriorBest priorBest,
            List<PlannedSet>? originalTargets,
            Substitution? substitution)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TodayExercise() when $default != null:
        return $default(
            _that.plannedExerciseId,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.primaryMuscles,
            _that.secondaryMuscles,
            _that.orderIndex,
            _that.incrementKg,
            _that.targets,
            _that.prefill,
            _that.lastPerformance,
            _that.recommendation,
            _that.priorBest,
            _that.originalTargets,
            _that.substitution);
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
            String plannedExerciseId,
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            List<MuscleGroup> primaryMuscles,
            List<MuscleGroup> secondaryMuscles,
            int orderIndex,
            double incrementKg,
            List<PlannedSet> targets,
            List<SetPrefill> prefill,
            LastPerformance? lastPerformance,
            ProgressionRecommendation? recommendation,
            PriorBest priorBest,
            List<PlannedSet>? originalTargets,
            Substitution? substitution)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TodayExercise():
        return $default(
            _that.plannedExerciseId,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.primaryMuscles,
            _that.secondaryMuscles,
            _that.orderIndex,
            _that.incrementKg,
            _that.targets,
            _that.prefill,
            _that.lastPerformance,
            _that.recommendation,
            _that.priorBest,
            _that.originalTargets,
            _that.substitution);
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
            String plannedExerciseId,
            String exerciseId,
            String slug,
            String name,
            MovementPattern movementPattern,
            List<Equipment> equipment,
            Difficulty difficulty,
            List<MuscleGroup> primaryMuscles,
            List<MuscleGroup> secondaryMuscles,
            int orderIndex,
            double incrementKg,
            List<PlannedSet> targets,
            List<SetPrefill> prefill,
            LastPerformance? lastPerformance,
            ProgressionRecommendation? recommendation,
            PriorBest priorBest,
            List<PlannedSet>? originalTargets,
            Substitution? substitution)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TodayExercise() when $default != null:
        return $default(
            _that.plannedExerciseId,
            _that.exerciseId,
            _that.slug,
            _that.name,
            _that.movementPattern,
            _that.equipment,
            _that.difficulty,
            _that.primaryMuscles,
            _that.secondaryMuscles,
            _that.orderIndex,
            _that.incrementKg,
            _that.targets,
            _that.prefill,
            _that.lastPerformance,
            _that.recommendation,
            _that.priorBest,
            _that.originalTargets,
            _that.substitution);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TodayExercise implements TodayExercise {
  const _TodayExercise(
      {required this.plannedExerciseId,
      required this.exerciseId,
      required this.slug,
      required this.name,
      required this.movementPattern,
      required final List<Equipment> equipment,
      required this.difficulty,
      required final List<MuscleGroup> primaryMuscles,
      required final List<MuscleGroup> secondaryMuscles,
      required this.orderIndex,
      required this.incrementKg,
      required final List<PlannedSet> targets,
      final List<SetPrefill> prefill = const <SetPrefill>[],
      required this.lastPerformance,
      this.recommendation = null,
      this.priorBest = PriorBest.none,
      final List<PlannedSet>? originalTargets = null,
      this.substitution = null})
      : _equipment = equipment,
        _primaryMuscles = primaryMuscles,
        _secondaryMuscles = secondaryMuscles,
        _targets = targets,
        _prefill = prefill,
        _originalTargets = originalTargets;
  factory _TodayExercise.fromJson(Map<String, dynamic> json) =>
      _$TodayExerciseFromJson(json);

  @override
  final String plannedExerciseId;
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
  final List<MuscleGroup> _primaryMuscles;
  @override
  List<MuscleGroup> get primaryMuscles {
    if (_primaryMuscles is EqualUnmodifiableListView) return _primaryMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_primaryMuscles);
  }

  final List<MuscleGroup> _secondaryMuscles;
  @override
  List<MuscleGroup> get secondaryMuscles {
    if (_secondaryMuscles is EqualUnmodifiableListView)
      return _secondaryMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_secondaryMuscles);
  }

  @override
  final int orderIndex;
  @override
  final double incrementKg;
  final List<PlannedSet> _targets;
  @override
  List<PlannedSet> get targets {
    if (_targets is EqualUnmodifiableListView) return _targets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targets);
  }

  final List<SetPrefill> _prefill;
  @override
  @JsonKey()
  List<SetPrefill> get prefill {
    if (_prefill is EqualUnmodifiableListView) return _prefill;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_prefill);
  }

  @override
  final LastPerformance? lastPerformance;
  @override
  @JsonKey()
  final ProgressionRecommendation? recommendation;
  @override
  @JsonKey()
  final PriorBest priorBest;
  final List<PlannedSet>? _originalTargets;
  @override
  @JsonKey()
  List<PlannedSet>? get originalTargets {
    final value = _originalTargets;
    if (value == null) return null;
    if (_originalTargets is EqualUnmodifiableListView) return _originalTargets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final Substitution? substitution;

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TodayExerciseCopyWith<_TodayExercise> get copyWith =>
      __$TodayExerciseCopyWithImpl<_TodayExercise>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TodayExerciseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TodayExercise &&
            (identical(other.plannedExerciseId, plannedExerciseId) ||
                other.plannedExerciseId == plannedExerciseId) &&
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
            const DeepCollectionEquality()
                .equals(other._primaryMuscles, _primaryMuscles) &&
            const DeepCollectionEquality()
                .equals(other._secondaryMuscles, _secondaryMuscles) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg) &&
            const DeepCollectionEquality().equals(other._targets, _targets) &&
            const DeepCollectionEquality().equals(other._prefill, _prefill) &&
            (identical(other.lastPerformance, lastPerformance) ||
                other.lastPerformance == lastPerformance) &&
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation) &&
            (identical(other.priorBest, priorBest) ||
                other.priorBest == priorBest) &&
            const DeepCollectionEquality()
                .equals(other._originalTargets, _originalTargets) &&
            (identical(other.substitution, substitution) ||
                other.substitution == substitution));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      plannedExerciseId,
      exerciseId,
      slug,
      name,
      movementPattern,
      const DeepCollectionEquality().hash(_equipment),
      difficulty,
      const DeepCollectionEquality().hash(_primaryMuscles),
      const DeepCollectionEquality().hash(_secondaryMuscles),
      orderIndex,
      incrementKg,
      const DeepCollectionEquality().hash(_targets),
      const DeepCollectionEquality().hash(_prefill),
      lastPerformance,
      recommendation,
      priorBest,
      const DeepCollectionEquality().hash(_originalTargets),
      substitution);

  @override
  String toString() {
    return 'TodayExercise(plannedExerciseId: $plannedExerciseId, exerciseId: $exerciseId, slug: $slug, name: $name, movementPattern: $movementPattern, equipment: $equipment, difficulty: $difficulty, primaryMuscles: $primaryMuscles, secondaryMuscles: $secondaryMuscles, orderIndex: $orderIndex, incrementKg: $incrementKg, targets: $targets, prefill: $prefill, lastPerformance: $lastPerformance, recommendation: $recommendation, priorBest: $priorBest, originalTargets: $originalTargets, substitution: $substitution)';
  }
}

/// @nodoc
abstract mixin class _$TodayExerciseCopyWith<$Res>
    implements $TodayExerciseCopyWith<$Res> {
  factory _$TodayExerciseCopyWith(
          _TodayExercise value, $Res Function(_TodayExercise) _then) =
      __$TodayExerciseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String plannedExerciseId,
      String exerciseId,
      String slug,
      String name,
      MovementPattern movementPattern,
      List<Equipment> equipment,
      Difficulty difficulty,
      List<MuscleGroup> primaryMuscles,
      List<MuscleGroup> secondaryMuscles,
      int orderIndex,
      double incrementKg,
      List<PlannedSet> targets,
      List<SetPrefill> prefill,
      LastPerformance? lastPerformance,
      ProgressionRecommendation? recommendation,
      PriorBest priorBest,
      List<PlannedSet>? originalTargets,
      Substitution? substitution});

  @override
  $LastPerformanceCopyWith<$Res>? get lastPerformance;
  @override
  $ProgressionRecommendationCopyWith<$Res>? get recommendation;
  @override
  $PriorBestCopyWith<$Res> get priorBest;
  @override
  $SubstitutionCopyWith<$Res>? get substitution;
}

/// @nodoc
class __$TodayExerciseCopyWithImpl<$Res>
    implements _$TodayExerciseCopyWith<$Res> {
  __$TodayExerciseCopyWithImpl(this._self, this._then);

  final _TodayExercise _self;
  final $Res Function(_TodayExercise) _then;

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? plannedExerciseId = null,
    Object? exerciseId = null,
    Object? slug = null,
    Object? name = null,
    Object? movementPattern = null,
    Object? equipment = null,
    Object? difficulty = null,
    Object? primaryMuscles = null,
    Object? secondaryMuscles = null,
    Object? orderIndex = null,
    Object? incrementKg = null,
    Object? targets = null,
    Object? prefill = null,
    Object? lastPerformance = freezed,
    Object? recommendation = freezed,
    Object? priorBest = null,
    Object? originalTargets = freezed,
    Object? substitution = freezed,
  }) {
    return _then(_TodayExercise(
      plannedExerciseId: null == plannedExerciseId
          ? _self.plannedExerciseId
          : plannedExerciseId // ignore: cast_nullable_to_non_nullable
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
      primaryMuscles: null == primaryMuscles
          ? _self._primaryMuscles
          : primaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      secondaryMuscles: null == secondaryMuscles
          ? _self._secondaryMuscles
          : secondaryMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
      targets: null == targets
          ? _self._targets
          : targets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>,
      prefill: null == prefill
          ? _self._prefill
          : prefill // ignore: cast_nullable_to_non_nullable
              as List<SetPrefill>,
      lastPerformance: freezed == lastPerformance
          ? _self.lastPerformance
          : lastPerformance // ignore: cast_nullable_to_non_nullable
              as LastPerformance?,
      recommendation: freezed == recommendation
          ? _self.recommendation
          : recommendation // ignore: cast_nullable_to_non_nullable
              as ProgressionRecommendation?,
      priorBest: null == priorBest
          ? _self.priorBest
          : priorBest // ignore: cast_nullable_to_non_nullable
              as PriorBest,
      originalTargets: freezed == originalTargets
          ? _self._originalTargets
          : originalTargets // ignore: cast_nullable_to_non_nullable
              as List<PlannedSet>?,
      substitution: freezed == substitution
          ? _self.substitution
          : substitution // ignore: cast_nullable_to_non_nullable
              as Substitution?,
    ));
  }

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LastPerformanceCopyWith<$Res>? get lastPerformance {
    if (_self.lastPerformance == null) {
      return null;
    }

    return $LastPerformanceCopyWith<$Res>(_self.lastPerformance!, (value) {
      return _then(_self.copyWith(lastPerformance: value));
    });
  }

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressionRecommendationCopyWith<$Res>? get recommendation {
    if (_self.recommendation == null) {
      return null;
    }

    return $ProgressionRecommendationCopyWith<$Res>(_self.recommendation!,
        (value) {
      return _then(_self.copyWith(recommendation: value));
    });
  }

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriorBestCopyWith<$Res> get priorBest {
    return $PriorBestCopyWith<$Res>(_self.priorBest, (value) {
      return _then(_self.copyWith(priorBest: value));
    });
  }

  /// Create a copy of TodayExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SubstitutionCopyWith<$Res>? get substitution {
    if (_self.substitution == null) {
      return null;
    }

    return $SubstitutionCopyWith<$Res>(_self.substitution!, (value) {
      return _then(_self.copyWith(substitution: value));
    });
  }
}

/// @nodoc
mixin _$TodayResponse {
  String get date;
  int get dayOfWeek;
  String? get programId;
  String? get programDayId;
  String? get sessionName;
  bool get isRest;
  List<MuscleGroup> get focus;
  List<TodayExercise> get exercises;
  WorkoutSession? get activeSession;
  String? get completedSessionId;
  int? get mesocycleWeek;
  DeloadState get deload;
  List<NeglectedMuscle> get neglected;

  /// Create a copy of TodayResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TodayResponseCopyWith<TodayResponse> get copyWith =>
      _$TodayResponseCopyWithImpl<TodayResponse>(
          this as TodayResponse, _$identity);

  /// Serializes this TodayResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TodayResponse &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.programId, programId) ||
                other.programId == programId) &&
            (identical(other.programDayId, programDayId) ||
                other.programDayId == programDayId) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            (identical(other.isRest, isRest) || other.isRest == isRest) &&
            const DeepCollectionEquality().equals(other.focus, focus) &&
            const DeepCollectionEquality().equals(other.exercises, exercises) &&
            (identical(other.activeSession, activeSession) ||
                other.activeSession == activeSession) &&
            (identical(other.completedSessionId, completedSessionId) ||
                other.completedSessionId == completedSessionId) &&
            (identical(other.mesocycleWeek, mesocycleWeek) ||
                other.mesocycleWeek == mesocycleWeek) &&
            (identical(other.deload, deload) || other.deload == deload) &&
            const DeepCollectionEquality().equals(other.neglected, neglected));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      date,
      dayOfWeek,
      programId,
      programDayId,
      sessionName,
      isRest,
      const DeepCollectionEquality().hash(focus),
      const DeepCollectionEquality().hash(exercises),
      activeSession,
      completedSessionId,
      mesocycleWeek,
      deload,
      const DeepCollectionEquality().hash(neglected));

  @override
  String toString() {
    return 'TodayResponse(date: $date, dayOfWeek: $dayOfWeek, programId: $programId, programDayId: $programDayId, sessionName: $sessionName, isRest: $isRest, focus: $focus, exercises: $exercises, activeSession: $activeSession, completedSessionId: $completedSessionId, mesocycleWeek: $mesocycleWeek, deload: $deload, neglected: $neglected)';
  }
}

/// @nodoc
abstract mixin class $TodayResponseCopyWith<$Res> {
  factory $TodayResponseCopyWith(
          TodayResponse value, $Res Function(TodayResponse) _then) =
      _$TodayResponseCopyWithImpl;
  @useResult
  $Res call(
      {String date,
      int dayOfWeek,
      String? programId,
      String? programDayId,
      String? sessionName,
      bool isRest,
      List<MuscleGroup> focus,
      List<TodayExercise> exercises,
      WorkoutSession? activeSession,
      String? completedSessionId,
      int? mesocycleWeek,
      DeloadState deload,
      List<NeglectedMuscle> neglected});

  $WorkoutSessionCopyWith<$Res>? get activeSession;
  $DeloadStateCopyWith<$Res> get deload;
}

/// @nodoc
class _$TodayResponseCopyWithImpl<$Res>
    implements $TodayResponseCopyWith<$Res> {
  _$TodayResponseCopyWithImpl(this._self, this._then);

  final TodayResponse _self;
  final $Res Function(TodayResponse) _then;

  /// Create a copy of TodayResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? dayOfWeek = null,
    Object? programId = freezed,
    Object? programDayId = freezed,
    Object? sessionName = freezed,
    Object? isRest = null,
    Object? focus = null,
    Object? exercises = null,
    Object? activeSession = freezed,
    Object? completedSessionId = freezed,
    Object? mesocycleWeek = freezed,
    Object? deload = null,
    Object? neglected = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      programId: freezed == programId
          ? _self.programId
          : programId // ignore: cast_nullable_to_non_nullable
              as String?,
      programDayId: freezed == programDayId
          ? _self.programDayId
          : programDayId // ignore: cast_nullable_to_non_nullable
              as String?,
      sessionName: freezed == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String?,
      isRest: null == isRest
          ? _self.isRest
          : isRest // ignore: cast_nullable_to_non_nullable
              as bool,
      focus: null == focus
          ? _self.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      exercises: null == exercises
          ? _self.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<TodayExercise>,
      activeSession: freezed == activeSession
          ? _self.activeSession
          : activeSession // ignore: cast_nullable_to_non_nullable
              as WorkoutSession?,
      completedSessionId: freezed == completedSessionId
          ? _self.completedSessionId
          : completedSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      mesocycleWeek: freezed == mesocycleWeek
          ? _self.mesocycleWeek
          : mesocycleWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      deload: null == deload
          ? _self.deload
          : deload // ignore: cast_nullable_to_non_nullable
              as DeloadState,
      neglected: null == neglected
          ? _self.neglected
          : neglected // ignore: cast_nullable_to_non_nullable
              as List<NeglectedMuscle>,
    ));
  }

  /// Create a copy of TodayResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WorkoutSessionCopyWith<$Res>? get activeSession {
    if (_self.activeSession == null) {
      return null;
    }

    return $WorkoutSessionCopyWith<$Res>(_self.activeSession!, (value) {
      return _then(_self.copyWith(activeSession: value));
    });
  }

  /// Create a copy of TodayResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeloadStateCopyWith<$Res> get deload {
    return $DeloadStateCopyWith<$Res>(_self.deload, (value) {
      return _then(_self.copyWith(deload: value));
    });
  }
}

/// Adds pattern-matching-related methods to [TodayResponse].
extension TodayResponsePatterns on TodayResponse {
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
    TResult Function(_TodayResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TodayResponse() when $default != null:
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
    TResult Function(_TodayResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TodayResponse():
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
    TResult? Function(_TodayResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TodayResponse() when $default != null:
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
            String date,
            int dayOfWeek,
            String? programId,
            String? programDayId,
            String? sessionName,
            bool isRest,
            List<MuscleGroup> focus,
            List<TodayExercise> exercises,
            WorkoutSession? activeSession,
            String? completedSessionId,
            int? mesocycleWeek,
            DeloadState deload,
            List<NeglectedMuscle> neglected)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TodayResponse() when $default != null:
        return $default(
            _that.date,
            _that.dayOfWeek,
            _that.programId,
            _that.programDayId,
            _that.sessionName,
            _that.isRest,
            _that.focus,
            _that.exercises,
            _that.activeSession,
            _that.completedSessionId,
            _that.mesocycleWeek,
            _that.deload,
            _that.neglected);
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
            String date,
            int dayOfWeek,
            String? programId,
            String? programDayId,
            String? sessionName,
            bool isRest,
            List<MuscleGroup> focus,
            List<TodayExercise> exercises,
            WorkoutSession? activeSession,
            String? completedSessionId,
            int? mesocycleWeek,
            DeloadState deload,
            List<NeglectedMuscle> neglected)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TodayResponse():
        return $default(
            _that.date,
            _that.dayOfWeek,
            _that.programId,
            _that.programDayId,
            _that.sessionName,
            _that.isRest,
            _that.focus,
            _that.exercises,
            _that.activeSession,
            _that.completedSessionId,
            _that.mesocycleWeek,
            _that.deload,
            _that.neglected);
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
            String date,
            int dayOfWeek,
            String? programId,
            String? programDayId,
            String? sessionName,
            bool isRest,
            List<MuscleGroup> focus,
            List<TodayExercise> exercises,
            WorkoutSession? activeSession,
            String? completedSessionId,
            int? mesocycleWeek,
            DeloadState deload,
            List<NeglectedMuscle> neglected)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TodayResponse() when $default != null:
        return $default(
            _that.date,
            _that.dayOfWeek,
            _that.programId,
            _that.programDayId,
            _that.sessionName,
            _that.isRest,
            _that.focus,
            _that.exercises,
            _that.activeSession,
            _that.completedSessionId,
            _that.mesocycleWeek,
            _that.deload,
            _that.neglected);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TodayResponse implements TodayResponse {
  const _TodayResponse(
      {required this.date,
      required this.dayOfWeek,
      required this.programId,
      required this.programDayId,
      required this.sessionName,
      required this.isRest,
      required final List<MuscleGroup> focus,
      required final List<TodayExercise> exercises,
      required this.activeSession,
      required this.completedSessionId,
      this.mesocycleWeek = null,
      this.deload = DeloadState.none,
      final List<NeglectedMuscle> neglected = const <NeglectedMuscle>[]})
      : _focus = focus,
        _exercises = exercises,
        _neglected = neglected;
  factory _TodayResponse.fromJson(Map<String, dynamic> json) =>
      _$TodayResponseFromJson(json);

  @override
  final String date;
  @override
  final int dayOfWeek;
  @override
  final String? programId;
  @override
  final String? programDayId;
  @override
  final String? sessionName;
  @override
  final bool isRest;
  final List<MuscleGroup> _focus;
  @override
  List<MuscleGroup> get focus {
    if (_focus is EqualUnmodifiableListView) return _focus;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_focus);
  }

  final List<TodayExercise> _exercises;
  @override
  List<TodayExercise> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  @override
  final WorkoutSession? activeSession;
  @override
  final String? completedSessionId;
  @override
  @JsonKey()
  final int? mesocycleWeek;
  @override
  @JsonKey()
  final DeloadState deload;
  final List<NeglectedMuscle> _neglected;
  @override
  @JsonKey()
  List<NeglectedMuscle> get neglected {
    if (_neglected is EqualUnmodifiableListView) return _neglected;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_neglected);
  }

  /// Create a copy of TodayResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TodayResponseCopyWith<_TodayResponse> get copyWith =>
      __$TodayResponseCopyWithImpl<_TodayResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TodayResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TodayResponse &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.programId, programId) ||
                other.programId == programId) &&
            (identical(other.programDayId, programDayId) ||
                other.programDayId == programDayId) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            (identical(other.isRest, isRest) || other.isRest == isRest) &&
            const DeepCollectionEquality().equals(other._focus, _focus) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises) &&
            (identical(other.activeSession, activeSession) ||
                other.activeSession == activeSession) &&
            (identical(other.completedSessionId, completedSessionId) ||
                other.completedSessionId == completedSessionId) &&
            (identical(other.mesocycleWeek, mesocycleWeek) ||
                other.mesocycleWeek == mesocycleWeek) &&
            (identical(other.deload, deload) || other.deload == deload) &&
            const DeepCollectionEquality()
                .equals(other._neglected, _neglected));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      date,
      dayOfWeek,
      programId,
      programDayId,
      sessionName,
      isRest,
      const DeepCollectionEquality().hash(_focus),
      const DeepCollectionEquality().hash(_exercises),
      activeSession,
      completedSessionId,
      mesocycleWeek,
      deload,
      const DeepCollectionEquality().hash(_neglected));

  @override
  String toString() {
    return 'TodayResponse(date: $date, dayOfWeek: $dayOfWeek, programId: $programId, programDayId: $programDayId, sessionName: $sessionName, isRest: $isRest, focus: $focus, exercises: $exercises, activeSession: $activeSession, completedSessionId: $completedSessionId, mesocycleWeek: $mesocycleWeek, deload: $deload, neglected: $neglected)';
  }
}

/// @nodoc
abstract mixin class _$TodayResponseCopyWith<$Res>
    implements $TodayResponseCopyWith<$Res> {
  factory _$TodayResponseCopyWith(
          _TodayResponse value, $Res Function(_TodayResponse) _then) =
      __$TodayResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String date,
      int dayOfWeek,
      String? programId,
      String? programDayId,
      String? sessionName,
      bool isRest,
      List<MuscleGroup> focus,
      List<TodayExercise> exercises,
      WorkoutSession? activeSession,
      String? completedSessionId,
      int? mesocycleWeek,
      DeloadState deload,
      List<NeglectedMuscle> neglected});

  @override
  $WorkoutSessionCopyWith<$Res>? get activeSession;
  @override
  $DeloadStateCopyWith<$Res> get deload;
}

/// @nodoc
class __$TodayResponseCopyWithImpl<$Res>
    implements _$TodayResponseCopyWith<$Res> {
  __$TodayResponseCopyWithImpl(this._self, this._then);

  final _TodayResponse _self;
  final $Res Function(_TodayResponse) _then;

  /// Create a copy of TodayResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? dayOfWeek = null,
    Object? programId = freezed,
    Object? programDayId = freezed,
    Object? sessionName = freezed,
    Object? isRest = null,
    Object? focus = null,
    Object? exercises = null,
    Object? activeSession = freezed,
    Object? completedSessionId = freezed,
    Object? mesocycleWeek = freezed,
    Object? deload = null,
    Object? neglected = null,
  }) {
    return _then(_TodayResponse(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      dayOfWeek: null == dayOfWeek
          ? _self.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as int,
      programId: freezed == programId
          ? _self.programId
          : programId // ignore: cast_nullable_to_non_nullable
              as String?,
      programDayId: freezed == programDayId
          ? _self.programDayId
          : programDayId // ignore: cast_nullable_to_non_nullable
              as String?,
      sessionName: freezed == sessionName
          ? _self.sessionName
          : sessionName // ignore: cast_nullable_to_non_nullable
              as String?,
      isRest: null == isRest
          ? _self.isRest
          : isRest // ignore: cast_nullable_to_non_nullable
              as bool,
      focus: null == focus
          ? _self._focus
          : focus // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      exercises: null == exercises
          ? _self._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<TodayExercise>,
      activeSession: freezed == activeSession
          ? _self.activeSession
          : activeSession // ignore: cast_nullable_to_non_nullable
              as WorkoutSession?,
      completedSessionId: freezed == completedSessionId
          ? _self.completedSessionId
          : completedSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      mesocycleWeek: freezed == mesocycleWeek
          ? _self.mesocycleWeek
          : mesocycleWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      deload: null == deload
          ? _self.deload
          : deload // ignore: cast_nullable_to_non_nullable
              as DeloadState,
      neglected: null == neglected
          ? _self._neglected
          : neglected // ignore: cast_nullable_to_non_nullable
              as List<NeglectedMuscle>,
    ));
  }

  /// Create a copy of TodayResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WorkoutSessionCopyWith<$Res>? get activeSession {
    if (_self.activeSession == null) {
      return null;
    }

    return $WorkoutSessionCopyWith<$Res>(_self.activeSession!, (value) {
      return _then(_self.copyWith(activeSession: value));
    });
  }

  /// Create a copy of TodayResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeloadStateCopyWith<$Res> get deload {
    return $DeloadStateCopyWith<$Res>(_self.deload, (value) {
      return _then(_self.copyWith(deload: value));
    });
  }
}

/// @nodoc
mixin _$VolumeLandmarks {
  double get mv;
  double get mev;
  double get mavLow;
  double get mavHigh;
  double get mrv;

  /// Create a copy of VolumeLandmarks
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VolumeLandmarksCopyWith<VolumeLandmarks> get copyWith =>
      _$VolumeLandmarksCopyWithImpl<VolumeLandmarks>(
          this as VolumeLandmarks, _$identity);

  /// Serializes this VolumeLandmarks to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VolumeLandmarks &&
            (identical(other.mv, mv) || other.mv == mv) &&
            (identical(other.mev, mev) || other.mev == mev) &&
            (identical(other.mavLow, mavLow) || other.mavLow == mavLow) &&
            (identical(other.mavHigh, mavHigh) || other.mavHigh == mavHigh) &&
            (identical(other.mrv, mrv) || other.mrv == mrv));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mv, mev, mavLow, mavHigh, mrv);

  @override
  String toString() {
    return 'VolumeLandmarks(mv: $mv, mev: $mev, mavLow: $mavLow, mavHigh: $mavHigh, mrv: $mrv)';
  }
}

/// @nodoc
abstract mixin class $VolumeLandmarksCopyWith<$Res> {
  factory $VolumeLandmarksCopyWith(
          VolumeLandmarks value, $Res Function(VolumeLandmarks) _then) =
      _$VolumeLandmarksCopyWithImpl;
  @useResult
  $Res call({double mv, double mev, double mavLow, double mavHigh, double mrv});
}

/// @nodoc
class _$VolumeLandmarksCopyWithImpl<$Res>
    implements $VolumeLandmarksCopyWith<$Res> {
  _$VolumeLandmarksCopyWithImpl(this._self, this._then);

  final VolumeLandmarks _self;
  final $Res Function(VolumeLandmarks) _then;

  /// Create a copy of VolumeLandmarks
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mv = null,
    Object? mev = null,
    Object? mavLow = null,
    Object? mavHigh = null,
    Object? mrv = null,
  }) {
    return _then(_self.copyWith(
      mv: null == mv
          ? _self.mv
          : mv // ignore: cast_nullable_to_non_nullable
              as double,
      mev: null == mev
          ? _self.mev
          : mev // ignore: cast_nullable_to_non_nullable
              as double,
      mavLow: null == mavLow
          ? _self.mavLow
          : mavLow // ignore: cast_nullable_to_non_nullable
              as double,
      mavHigh: null == mavHigh
          ? _self.mavHigh
          : mavHigh // ignore: cast_nullable_to_non_nullable
              as double,
      mrv: null == mrv
          ? _self.mrv
          : mrv // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [VolumeLandmarks].
extension VolumeLandmarksPatterns on VolumeLandmarks {
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
    TResult Function(_VolumeLandmarks value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VolumeLandmarks() when $default != null:
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
    TResult Function(_VolumeLandmarks value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeLandmarks():
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
    TResult? Function(_VolumeLandmarks value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeLandmarks() when $default != null:
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
            double mv, double mev, double mavLow, double mavHigh, double mrv)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VolumeLandmarks() when $default != null:
        return $default(
            _that.mv, _that.mev, _that.mavLow, _that.mavHigh, _that.mrv);
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
            double mv, double mev, double mavLow, double mavHigh, double mrv)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeLandmarks():
        return $default(
            _that.mv, _that.mev, _that.mavLow, _that.mavHigh, _that.mrv);
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
            double mv, double mev, double mavLow, double mavHigh, double mrv)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeLandmarks() when $default != null:
        return $default(
            _that.mv, _that.mev, _that.mavLow, _that.mavHigh, _that.mrv);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _VolumeLandmarks implements VolumeLandmarks {
  const _VolumeLandmarks(
      {required this.mv,
      required this.mev,
      required this.mavLow,
      required this.mavHigh,
      required this.mrv});
  factory _VolumeLandmarks.fromJson(Map<String, dynamic> json) =>
      _$VolumeLandmarksFromJson(json);

  @override
  final double mv;
  @override
  final double mev;
  @override
  final double mavLow;
  @override
  final double mavHigh;
  @override
  final double mrv;

  /// Create a copy of VolumeLandmarks
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VolumeLandmarksCopyWith<_VolumeLandmarks> get copyWith =>
      __$VolumeLandmarksCopyWithImpl<_VolumeLandmarks>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VolumeLandmarksToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VolumeLandmarks &&
            (identical(other.mv, mv) || other.mv == mv) &&
            (identical(other.mev, mev) || other.mev == mev) &&
            (identical(other.mavLow, mavLow) || other.mavLow == mavLow) &&
            (identical(other.mavHigh, mavHigh) || other.mavHigh == mavHigh) &&
            (identical(other.mrv, mrv) || other.mrv == mrv));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mv, mev, mavLow, mavHigh, mrv);

  @override
  String toString() {
    return 'VolumeLandmarks(mv: $mv, mev: $mev, mavLow: $mavLow, mavHigh: $mavHigh, mrv: $mrv)';
  }
}

/// @nodoc
abstract mixin class _$VolumeLandmarksCopyWith<$Res>
    implements $VolumeLandmarksCopyWith<$Res> {
  factory _$VolumeLandmarksCopyWith(
          _VolumeLandmarks value, $Res Function(_VolumeLandmarks) _then) =
      __$VolumeLandmarksCopyWithImpl;
  @override
  @useResult
  $Res call({double mv, double mev, double mavLow, double mavHigh, double mrv});
}

/// @nodoc
class __$VolumeLandmarksCopyWithImpl<$Res>
    implements _$VolumeLandmarksCopyWith<$Res> {
  __$VolumeLandmarksCopyWithImpl(this._self, this._then);

  final _VolumeLandmarks _self;
  final $Res Function(_VolumeLandmarks) _then;

  /// Create a copy of VolumeLandmarks
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? mv = null,
    Object? mev = null,
    Object? mavLow = null,
    Object? mavHigh = null,
    Object? mrv = null,
  }) {
    return _then(_VolumeLandmarks(
      mv: null == mv
          ? _self.mv
          : mv // ignore: cast_nullable_to_non_nullable
              as double,
      mev: null == mev
          ? _self.mev
          : mev // ignore: cast_nullable_to_non_nullable
              as double,
      mavLow: null == mavLow
          ? _self.mavLow
          : mavLow // ignore: cast_nullable_to_non_nullable
              as double,
      mavHigh: null == mavHigh
          ? _self.mavHigh
          : mavHigh // ignore: cast_nullable_to_non_nullable
              as double,
      mrv: null == mrv
          ? _self.mrv
          : mrv // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$MuscleWeek {
  MuscleGroup get muscle;
  double get hardSets;
  double get tonnageKg;
  LandmarkStatus get status;
  VolumeLandmarks get landmarks;
  bool get owned;

  /// Create a copy of MuscleWeek
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MuscleWeekCopyWith<MuscleWeek> get copyWith =>
      _$MuscleWeekCopyWithImpl<MuscleWeek>(this as MuscleWeek, _$identity);

  /// Serializes this MuscleWeek to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MuscleWeek &&
            (identical(other.muscle, muscle) || other.muscle == muscle) &&
            (identical(other.hardSets, hardSets) ||
                other.hardSets == hardSets) &&
            (identical(other.tonnageKg, tonnageKg) ||
                other.tonnageKg == tonnageKg) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.landmarks, landmarks) ||
                other.landmarks == landmarks) &&
            (identical(other.owned, owned) || other.owned == owned));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, muscle, hardSets, tonnageKg, status, landmarks, owned);

  @override
  String toString() {
    return 'MuscleWeek(muscle: $muscle, hardSets: $hardSets, tonnageKg: $tonnageKg, status: $status, landmarks: $landmarks, owned: $owned)';
  }
}

/// @nodoc
abstract mixin class $MuscleWeekCopyWith<$Res> {
  factory $MuscleWeekCopyWith(
          MuscleWeek value, $Res Function(MuscleWeek) _then) =
      _$MuscleWeekCopyWithImpl;
  @useResult
  $Res call(
      {MuscleGroup muscle,
      double hardSets,
      double tonnageKg,
      LandmarkStatus status,
      VolumeLandmarks landmarks,
      bool owned});

  $VolumeLandmarksCopyWith<$Res> get landmarks;
}

/// @nodoc
class _$MuscleWeekCopyWithImpl<$Res> implements $MuscleWeekCopyWith<$Res> {
  _$MuscleWeekCopyWithImpl(this._self, this._then);

  final MuscleWeek _self;
  final $Res Function(MuscleWeek) _then;

  /// Create a copy of MuscleWeek
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? muscle = null,
    Object? hardSets = null,
    Object? tonnageKg = null,
    Object? status = null,
    Object? landmarks = null,
    Object? owned = null,
  }) {
    return _then(_self.copyWith(
      muscle: null == muscle
          ? _self.muscle
          : muscle // ignore: cast_nullable_to_non_nullable
              as MuscleGroup,
      hardSets: null == hardSets
          ? _self.hardSets
          : hardSets // ignore: cast_nullable_to_non_nullable
              as double,
      tonnageKg: null == tonnageKg
          ? _self.tonnageKg
          : tonnageKg // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LandmarkStatus,
      landmarks: null == landmarks
          ? _self.landmarks
          : landmarks // ignore: cast_nullable_to_non_nullable
              as VolumeLandmarks,
      owned: null == owned
          ? _self.owned
          : owned // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of MuscleWeek
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VolumeLandmarksCopyWith<$Res> get landmarks {
    return $VolumeLandmarksCopyWith<$Res>(_self.landmarks, (value) {
      return _then(_self.copyWith(landmarks: value));
    });
  }
}

/// Adds pattern-matching-related methods to [MuscleWeek].
extension MuscleWeekPatterns on MuscleWeek {
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
    TResult Function(_MuscleWeek value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MuscleWeek() when $default != null:
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
    TResult Function(_MuscleWeek value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MuscleWeek():
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
    TResult? Function(_MuscleWeek value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MuscleWeek() when $default != null:
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
    TResult Function(MuscleGroup muscle, double hardSets, double tonnageKg,
            LandmarkStatus status, VolumeLandmarks landmarks, bool owned)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MuscleWeek() when $default != null:
        return $default(_that.muscle, _that.hardSets, _that.tonnageKg,
            _that.status, _that.landmarks, _that.owned);
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
    TResult Function(MuscleGroup muscle, double hardSets, double tonnageKg,
            LandmarkStatus status, VolumeLandmarks landmarks, bool owned)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MuscleWeek():
        return $default(_that.muscle, _that.hardSets, _that.tonnageKg,
            _that.status, _that.landmarks, _that.owned);
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
    TResult? Function(MuscleGroup muscle, double hardSets, double tonnageKg,
            LandmarkStatus status, VolumeLandmarks landmarks, bool owned)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MuscleWeek() when $default != null:
        return $default(_that.muscle, _that.hardSets, _that.tonnageKg,
            _that.status, _that.landmarks, _that.owned);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MuscleWeek implements MuscleWeek {
  const _MuscleWeek(
      {required this.muscle,
      required this.hardSets,
      required this.tonnageKg,
      required this.status,
      required this.landmarks,
      required this.owned});
  factory _MuscleWeek.fromJson(Map<String, dynamic> json) =>
      _$MuscleWeekFromJson(json);

  @override
  final MuscleGroup muscle;
  @override
  final double hardSets;
  @override
  final double tonnageKg;
  @override
  final LandmarkStatus status;
  @override
  final VolumeLandmarks landmarks;
  @override
  final bool owned;

  /// Create a copy of MuscleWeek
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MuscleWeekCopyWith<_MuscleWeek> get copyWith =>
      __$MuscleWeekCopyWithImpl<_MuscleWeek>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MuscleWeekToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MuscleWeek &&
            (identical(other.muscle, muscle) || other.muscle == muscle) &&
            (identical(other.hardSets, hardSets) ||
                other.hardSets == hardSets) &&
            (identical(other.tonnageKg, tonnageKg) ||
                other.tonnageKg == tonnageKg) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.landmarks, landmarks) ||
                other.landmarks == landmarks) &&
            (identical(other.owned, owned) || other.owned == owned));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, muscle, hardSets, tonnageKg, status, landmarks, owned);

  @override
  String toString() {
    return 'MuscleWeek(muscle: $muscle, hardSets: $hardSets, tonnageKg: $tonnageKg, status: $status, landmarks: $landmarks, owned: $owned)';
  }
}

/// @nodoc
abstract mixin class _$MuscleWeekCopyWith<$Res>
    implements $MuscleWeekCopyWith<$Res> {
  factory _$MuscleWeekCopyWith(
          _MuscleWeek value, $Res Function(_MuscleWeek) _then) =
      __$MuscleWeekCopyWithImpl;
  @override
  @useResult
  $Res call(
      {MuscleGroup muscle,
      double hardSets,
      double tonnageKg,
      LandmarkStatus status,
      VolumeLandmarks landmarks,
      bool owned});

  @override
  $VolumeLandmarksCopyWith<$Res> get landmarks;
}

/// @nodoc
class __$MuscleWeekCopyWithImpl<$Res> implements _$MuscleWeekCopyWith<$Res> {
  __$MuscleWeekCopyWithImpl(this._self, this._then);

  final _MuscleWeek _self;
  final $Res Function(_MuscleWeek) _then;

  /// Create a copy of MuscleWeek
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? muscle = null,
    Object? hardSets = null,
    Object? tonnageKg = null,
    Object? status = null,
    Object? landmarks = null,
    Object? owned = null,
  }) {
    return _then(_MuscleWeek(
      muscle: null == muscle
          ? _self.muscle
          : muscle // ignore: cast_nullable_to_non_nullable
              as MuscleGroup,
      hardSets: null == hardSets
          ? _self.hardSets
          : hardSets // ignore: cast_nullable_to_non_nullable
              as double,
      tonnageKg: null == tonnageKg
          ? _self.tonnageKg
          : tonnageKg // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LandmarkStatus,
      landmarks: null == landmarks
          ? _self.landmarks
          : landmarks // ignore: cast_nullable_to_non_nullable
              as VolumeLandmarks,
      owned: null == owned
          ? _self.owned
          : owned // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of MuscleWeek
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VolumeLandmarksCopyWith<$Res> get landmarks {
    return $VolumeLandmarksCopyWith<$Res>(_self.landmarks, (value) {
      return _then(_self.copyWith(landmarks: value));
    });
  }
}

/// @nodoc
mixin _$VolumeWeek {
  String get isoWeek;
  List<MuscleWeek> get muscles;

  /// Create a copy of VolumeWeek
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VolumeWeekCopyWith<VolumeWeek> get copyWith =>
      _$VolumeWeekCopyWithImpl<VolumeWeek>(this as VolumeWeek, _$identity);

  /// Serializes this VolumeWeek to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VolumeWeek &&
            (identical(other.isoWeek, isoWeek) || other.isoWeek == isoWeek) &&
            const DeepCollectionEquality().equals(other.muscles, muscles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, isoWeek, const DeepCollectionEquality().hash(muscles));

  @override
  String toString() {
    return 'VolumeWeek(isoWeek: $isoWeek, muscles: $muscles)';
  }
}

/// @nodoc
abstract mixin class $VolumeWeekCopyWith<$Res> {
  factory $VolumeWeekCopyWith(
          VolumeWeek value, $Res Function(VolumeWeek) _then) =
      _$VolumeWeekCopyWithImpl;
  @useResult
  $Res call({String isoWeek, List<MuscleWeek> muscles});
}

/// @nodoc
class _$VolumeWeekCopyWithImpl<$Res> implements $VolumeWeekCopyWith<$Res> {
  _$VolumeWeekCopyWithImpl(this._self, this._then);

  final VolumeWeek _self;
  final $Res Function(VolumeWeek) _then;

  /// Create a copy of VolumeWeek
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isoWeek = null,
    Object? muscles = null,
  }) {
    return _then(_self.copyWith(
      isoWeek: null == isoWeek
          ? _self.isoWeek
          : isoWeek // ignore: cast_nullable_to_non_nullable
              as String,
      muscles: null == muscles
          ? _self.muscles
          : muscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleWeek>,
    ));
  }
}

/// Adds pattern-matching-related methods to [VolumeWeek].
extension VolumeWeekPatterns on VolumeWeek {
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
    TResult Function(_VolumeWeek value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VolumeWeek() when $default != null:
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
    TResult Function(_VolumeWeek value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeWeek():
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
    TResult? Function(_VolumeWeek value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeWeek() when $default != null:
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
    TResult Function(String isoWeek, List<MuscleWeek> muscles)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VolumeWeek() when $default != null:
        return $default(_that.isoWeek, _that.muscles);
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
    TResult Function(String isoWeek, List<MuscleWeek> muscles) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeWeek():
        return $default(_that.isoWeek, _that.muscles);
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
    TResult? Function(String isoWeek, List<MuscleWeek> muscles)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeWeek() when $default != null:
        return $default(_that.isoWeek, _that.muscles);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _VolumeWeek implements VolumeWeek {
  const _VolumeWeek(
      {required this.isoWeek, required final List<MuscleWeek> muscles})
      : _muscles = muscles;
  factory _VolumeWeek.fromJson(Map<String, dynamic> json) =>
      _$VolumeWeekFromJson(json);

  @override
  final String isoWeek;
  final List<MuscleWeek> _muscles;
  @override
  List<MuscleWeek> get muscles {
    if (_muscles is EqualUnmodifiableListView) return _muscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_muscles);
  }

  /// Create a copy of VolumeWeek
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VolumeWeekCopyWith<_VolumeWeek> get copyWith =>
      __$VolumeWeekCopyWithImpl<_VolumeWeek>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VolumeWeekToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VolumeWeek &&
            (identical(other.isoWeek, isoWeek) || other.isoWeek == isoWeek) &&
            const DeepCollectionEquality().equals(other._muscles, _muscles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, isoWeek, const DeepCollectionEquality().hash(_muscles));

  @override
  String toString() {
    return 'VolumeWeek(isoWeek: $isoWeek, muscles: $muscles)';
  }
}

/// @nodoc
abstract mixin class _$VolumeWeekCopyWith<$Res>
    implements $VolumeWeekCopyWith<$Res> {
  factory _$VolumeWeekCopyWith(
          _VolumeWeek value, $Res Function(_VolumeWeek) _then) =
      __$VolumeWeekCopyWithImpl;
  @override
  @useResult
  $Res call({String isoWeek, List<MuscleWeek> muscles});
}

/// @nodoc
class __$VolumeWeekCopyWithImpl<$Res> implements _$VolumeWeekCopyWith<$Res> {
  __$VolumeWeekCopyWithImpl(this._self, this._then);

  final _VolumeWeek _self;
  final $Res Function(_VolumeWeek) _then;

  /// Create a copy of VolumeWeek
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? isoWeek = null,
    Object? muscles = null,
  }) {
    return _then(_VolumeWeek(
      isoWeek: null == isoWeek
          ? _self.isoWeek
          : isoWeek // ignore: cast_nullable_to_non_nullable
              as String,
      muscles: null == muscles
          ? _self._muscles
          : muscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleWeek>,
    ));
  }
}

/// @nodoc
mixin _$VolumeResponse {
  List<VolumeWeek> get weeks;
  List<MuscleGroup> get owned;
  List<NeglectedMuscle> get neglected;
  int? get mesocycleWeek;
  DeloadState get deload;

  /// Create a copy of VolumeResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VolumeResponseCopyWith<VolumeResponse> get copyWith =>
      _$VolumeResponseCopyWithImpl<VolumeResponse>(
          this as VolumeResponse, _$identity);

  /// Serializes this VolumeResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VolumeResponse &&
            const DeepCollectionEquality().equals(other.weeks, weeks) &&
            const DeepCollectionEquality().equals(other.owned, owned) &&
            const DeepCollectionEquality().equals(other.neglected, neglected) &&
            (identical(other.mesocycleWeek, mesocycleWeek) ||
                other.mesocycleWeek == mesocycleWeek) &&
            (identical(other.deload, deload) || other.deload == deload));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(weeks),
      const DeepCollectionEquality().hash(owned),
      const DeepCollectionEquality().hash(neglected),
      mesocycleWeek,
      deload);

  @override
  String toString() {
    return 'VolumeResponse(weeks: $weeks, owned: $owned, neglected: $neglected, mesocycleWeek: $mesocycleWeek, deload: $deload)';
  }
}

/// @nodoc
abstract mixin class $VolumeResponseCopyWith<$Res> {
  factory $VolumeResponseCopyWith(
          VolumeResponse value, $Res Function(VolumeResponse) _then) =
      _$VolumeResponseCopyWithImpl;
  @useResult
  $Res call(
      {List<VolumeWeek> weeks,
      List<MuscleGroup> owned,
      List<NeglectedMuscle> neglected,
      int? mesocycleWeek,
      DeloadState deload});

  $DeloadStateCopyWith<$Res> get deload;
}

/// @nodoc
class _$VolumeResponseCopyWithImpl<$Res>
    implements $VolumeResponseCopyWith<$Res> {
  _$VolumeResponseCopyWithImpl(this._self, this._then);

  final VolumeResponse _self;
  final $Res Function(VolumeResponse) _then;

  /// Create a copy of VolumeResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? weeks = null,
    Object? owned = null,
    Object? neglected = null,
    Object? mesocycleWeek = freezed,
    Object? deload = null,
  }) {
    return _then(_self.copyWith(
      weeks: null == weeks
          ? _self.weeks
          : weeks // ignore: cast_nullable_to_non_nullable
              as List<VolumeWeek>,
      owned: null == owned
          ? _self.owned
          : owned // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      neglected: null == neglected
          ? _self.neglected
          : neglected // ignore: cast_nullable_to_non_nullable
              as List<NeglectedMuscle>,
      mesocycleWeek: freezed == mesocycleWeek
          ? _self.mesocycleWeek
          : mesocycleWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      deload: null == deload
          ? _self.deload
          : deload // ignore: cast_nullable_to_non_nullable
              as DeloadState,
    ));
  }

  /// Create a copy of VolumeResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeloadStateCopyWith<$Res> get deload {
    return $DeloadStateCopyWith<$Res>(_self.deload, (value) {
      return _then(_self.copyWith(deload: value));
    });
  }
}

/// Adds pattern-matching-related methods to [VolumeResponse].
extension VolumeResponsePatterns on VolumeResponse {
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
    TResult Function(_VolumeResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VolumeResponse() when $default != null:
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
    TResult Function(_VolumeResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeResponse():
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
    TResult? Function(_VolumeResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeResponse() when $default != null:
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
            List<VolumeWeek> weeks,
            List<MuscleGroup> owned,
            List<NeglectedMuscle> neglected,
            int? mesocycleWeek,
            DeloadState deload)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VolumeResponse() when $default != null:
        return $default(_that.weeks, _that.owned, _that.neglected,
            _that.mesocycleWeek, _that.deload);
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
            List<VolumeWeek> weeks,
            List<MuscleGroup> owned,
            List<NeglectedMuscle> neglected,
            int? mesocycleWeek,
            DeloadState deload)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeResponse():
        return $default(_that.weeks, _that.owned, _that.neglected,
            _that.mesocycleWeek, _that.deload);
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
            List<VolumeWeek> weeks,
            List<MuscleGroup> owned,
            List<NeglectedMuscle> neglected,
            int? mesocycleWeek,
            DeloadState deload)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VolumeResponse() when $default != null:
        return $default(_that.weeks, _that.owned, _that.neglected,
            _that.mesocycleWeek, _that.deload);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _VolumeResponse implements VolumeResponse {
  const _VolumeResponse(
      {required final List<VolumeWeek> weeks,
      required final List<MuscleGroup> owned,
      required final List<NeglectedMuscle> neglected,
      required this.mesocycleWeek,
      required this.deload})
      : _weeks = weeks,
        _owned = owned,
        _neglected = neglected;
  factory _VolumeResponse.fromJson(Map<String, dynamic> json) =>
      _$VolumeResponseFromJson(json);

  final List<VolumeWeek> _weeks;
  @override
  List<VolumeWeek> get weeks {
    if (_weeks is EqualUnmodifiableListView) return _weeks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weeks);
  }

  final List<MuscleGroup> _owned;
  @override
  List<MuscleGroup> get owned {
    if (_owned is EqualUnmodifiableListView) return _owned;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_owned);
  }

  final List<NeglectedMuscle> _neglected;
  @override
  List<NeglectedMuscle> get neglected {
    if (_neglected is EqualUnmodifiableListView) return _neglected;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_neglected);
  }

  @override
  final int? mesocycleWeek;
  @override
  final DeloadState deload;

  /// Create a copy of VolumeResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VolumeResponseCopyWith<_VolumeResponse> get copyWith =>
      __$VolumeResponseCopyWithImpl<_VolumeResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VolumeResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VolumeResponse &&
            const DeepCollectionEquality().equals(other._weeks, _weeks) &&
            const DeepCollectionEquality().equals(other._owned, _owned) &&
            const DeepCollectionEquality()
                .equals(other._neglected, _neglected) &&
            (identical(other.mesocycleWeek, mesocycleWeek) ||
                other.mesocycleWeek == mesocycleWeek) &&
            (identical(other.deload, deload) || other.deload == deload));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_weeks),
      const DeepCollectionEquality().hash(_owned),
      const DeepCollectionEquality().hash(_neglected),
      mesocycleWeek,
      deload);

  @override
  String toString() {
    return 'VolumeResponse(weeks: $weeks, owned: $owned, neglected: $neglected, mesocycleWeek: $mesocycleWeek, deload: $deload)';
  }
}

/// @nodoc
abstract mixin class _$VolumeResponseCopyWith<$Res>
    implements $VolumeResponseCopyWith<$Res> {
  factory _$VolumeResponseCopyWith(
          _VolumeResponse value, $Res Function(_VolumeResponse) _then) =
      __$VolumeResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<VolumeWeek> weeks,
      List<MuscleGroup> owned,
      List<NeglectedMuscle> neglected,
      int? mesocycleWeek,
      DeloadState deload});

  @override
  $DeloadStateCopyWith<$Res> get deload;
}

/// @nodoc
class __$VolumeResponseCopyWithImpl<$Res>
    implements _$VolumeResponseCopyWith<$Res> {
  __$VolumeResponseCopyWithImpl(this._self, this._then);

  final _VolumeResponse _self;
  final $Res Function(_VolumeResponse) _then;

  /// Create a copy of VolumeResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? weeks = null,
    Object? owned = null,
    Object? neglected = null,
    Object? mesocycleWeek = freezed,
    Object? deload = null,
  }) {
    return _then(_VolumeResponse(
      weeks: null == weeks
          ? _self._weeks
          : weeks // ignore: cast_nullable_to_non_nullable
              as List<VolumeWeek>,
      owned: null == owned
          ? _self._owned
          : owned // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      neglected: null == neglected
          ? _self._neglected
          : neglected // ignore: cast_nullable_to_non_nullable
              as List<NeglectedMuscle>,
      mesocycleWeek: freezed == mesocycleWeek
          ? _self.mesocycleWeek
          : mesocycleWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      deload: null == deload
          ? _self.deload
          : deload // ignore: cast_nullable_to_non_nullable
              as DeloadState,
    ));
  }

  /// Create a copy of VolumeResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeloadStateCopyWith<$Res> get deload {
    return $DeloadStateCopyWith<$Res>(_self.deload, (value) {
      return _then(_self.copyWith(deload: value));
    });
  }
}

/// @nodoc
mixin _$ProgressionTarget {
  int get repMin;
  int get repMax;
  int get targetRir;
  int get sets;
  double get incrementKg;

  /// Create a copy of ProgressionTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgressionTargetCopyWith<ProgressionTarget> get copyWith =>
      _$ProgressionTargetCopyWithImpl<ProgressionTarget>(
          this as ProgressionTarget, _$identity);

  /// Serializes this ProgressionTarget to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProgressionTarget &&
            (identical(other.repMin, repMin) || other.repMin == repMin) &&
            (identical(other.repMax, repMax) || other.repMax == repMax) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.sets, sets) || other.sets == sets) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, repMin, repMax, targetRir, sets, incrementKg);

  @override
  String toString() {
    return 'ProgressionTarget(repMin: $repMin, repMax: $repMax, targetRir: $targetRir, sets: $sets, incrementKg: $incrementKg)';
  }
}

/// @nodoc
abstract mixin class $ProgressionTargetCopyWith<$Res> {
  factory $ProgressionTargetCopyWith(
          ProgressionTarget value, $Res Function(ProgressionTarget) _then) =
      _$ProgressionTargetCopyWithImpl;
  @useResult
  $Res call(
      {int repMin, int repMax, int targetRir, int sets, double incrementKg});
}

/// @nodoc
class _$ProgressionTargetCopyWithImpl<$Res>
    implements $ProgressionTargetCopyWith<$Res> {
  _$ProgressionTargetCopyWithImpl(this._self, this._then);

  final ProgressionTarget _self;
  final $Res Function(ProgressionTarget) _then;

  /// Create a copy of ProgressionTarget
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? repMin = null,
    Object? repMax = null,
    Object? targetRir = null,
    Object? sets = null,
    Object? incrementKg = null,
  }) {
    return _then(_self.copyWith(
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
      sets: null == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProgressionTarget].
extension ProgressionTargetPatterns on ProgressionTarget {
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
    TResult Function(_ProgressionTarget value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionTarget() when $default != null:
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
    TResult Function(_ProgressionTarget value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionTarget():
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
    TResult? Function(_ProgressionTarget value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionTarget() when $default != null:
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
    TResult Function(int repMin, int repMax, int targetRir, int sets,
            double incrementKg)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionTarget() when $default != null:
        return $default(_that.repMin, _that.repMax, _that.targetRir, _that.sets,
            _that.incrementKg);
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
            int repMin, int repMax, int targetRir, int sets, double incrementKg)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionTarget():
        return $default(_that.repMin, _that.repMax, _that.targetRir, _that.sets,
            _that.incrementKg);
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
    TResult? Function(int repMin, int repMax, int targetRir, int sets,
            double incrementKg)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionTarget() when $default != null:
        return $default(_that.repMin, _that.repMax, _that.targetRir, _that.sets,
            _that.incrementKg);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProgressionTarget implements ProgressionTarget {
  const _ProgressionTarget(
      {required this.repMin,
      required this.repMax,
      required this.targetRir,
      required this.sets,
      required this.incrementKg});
  factory _ProgressionTarget.fromJson(Map<String, dynamic> json) =>
      _$ProgressionTargetFromJson(json);

  @override
  final int repMin;
  @override
  final int repMax;
  @override
  final int targetRir;
  @override
  final int sets;
  @override
  final double incrementKg;

  /// Create a copy of ProgressionTarget
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgressionTargetCopyWith<_ProgressionTarget> get copyWith =>
      __$ProgressionTargetCopyWithImpl<_ProgressionTarget>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgressionTargetToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProgressionTarget &&
            (identical(other.repMin, repMin) || other.repMin == repMin) &&
            (identical(other.repMax, repMax) || other.repMax == repMax) &&
            (identical(other.targetRir, targetRir) ||
                other.targetRir == targetRir) &&
            (identical(other.sets, sets) || other.sets == sets) &&
            (identical(other.incrementKg, incrementKg) ||
                other.incrementKg == incrementKg));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, repMin, repMax, targetRir, sets, incrementKg);

  @override
  String toString() {
    return 'ProgressionTarget(repMin: $repMin, repMax: $repMax, targetRir: $targetRir, sets: $sets, incrementKg: $incrementKg)';
  }
}

/// @nodoc
abstract mixin class _$ProgressionTargetCopyWith<$Res>
    implements $ProgressionTargetCopyWith<$Res> {
  factory _$ProgressionTargetCopyWith(
          _ProgressionTarget value, $Res Function(_ProgressionTarget) _then) =
      __$ProgressionTargetCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int repMin, int repMax, int targetRir, int sets, double incrementKg});
}

/// @nodoc
class __$ProgressionTargetCopyWithImpl<$Res>
    implements _$ProgressionTargetCopyWith<$Res> {
  __$ProgressionTargetCopyWithImpl(this._self, this._then);

  final _ProgressionTarget _self;
  final $Res Function(_ProgressionTarget) _then;

  /// Create a copy of ProgressionTarget
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? repMin = null,
    Object? repMax = null,
    Object? targetRir = null,
    Object? sets = null,
    Object? incrementKg = null,
  }) {
    return _then(_ProgressionTarget(
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
      sets: null == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as int,
      incrementKg: null == incrementKg
          ? _self.incrementKg
          : incrementKg // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$ProgressionHistorySet {
  int get setIndex;
  double? get weightKg;
  int get reps;
  int? get rir;

  /// Create a copy of ProgressionHistorySet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgressionHistorySetCopyWith<ProgressionHistorySet> get copyWith =>
      _$ProgressionHistorySetCopyWithImpl<ProgressionHistorySet>(
          this as ProgressionHistorySet, _$identity);

  /// Serializes this ProgressionHistorySet to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProgressionHistorySet &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, setIndex, weightKg, reps, rir);

  @override
  String toString() {
    return 'ProgressionHistorySet(setIndex: $setIndex, weightKg: $weightKg, reps: $reps, rir: $rir)';
  }
}

/// @nodoc
abstract mixin class $ProgressionHistorySetCopyWith<$Res> {
  factory $ProgressionHistorySetCopyWith(ProgressionHistorySet value,
          $Res Function(ProgressionHistorySet) _then) =
      _$ProgressionHistorySetCopyWithImpl;
  @useResult
  $Res call({int setIndex, double? weightKg, int reps, int? rir});
}

/// @nodoc
class _$ProgressionHistorySetCopyWithImpl<$Res>
    implements $ProgressionHistorySetCopyWith<$Res> {
  _$ProgressionHistorySetCopyWithImpl(this._self, this._then);

  final ProgressionHistorySet _self;
  final $Res Function(ProgressionHistorySet) _then;

  /// Create a copy of ProgressionHistorySet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setIndex = null,
    Object? weightKg = freezed,
    Object? reps = null,
    Object? rir = freezed,
  }) {
    return _then(_self.copyWith(
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProgressionHistorySet].
extension ProgressionHistorySetPatterns on ProgressionHistorySet {
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
    TResult Function(_ProgressionHistorySet value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistorySet() when $default != null:
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
    TResult Function(_ProgressionHistorySet value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistorySet():
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
    TResult? Function(_ProgressionHistorySet value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistorySet() when $default != null:
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
    TResult Function(int setIndex, double? weightKg, int reps, int? rir)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistorySet() when $default != null:
        return $default(_that.setIndex, _that.weightKg, _that.reps, _that.rir);
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
    TResult Function(int setIndex, double? weightKg, int reps, int? rir)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistorySet():
        return $default(_that.setIndex, _that.weightKg, _that.reps, _that.rir);
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
    TResult? Function(int setIndex, double? weightKg, int reps, int? rir)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistorySet() when $default != null:
        return $default(_that.setIndex, _that.weightKg, _that.reps, _that.rir);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProgressionHistorySet implements ProgressionHistorySet {
  const _ProgressionHistorySet(
      {required this.setIndex,
      required this.weightKg,
      required this.reps,
      required this.rir});
  factory _ProgressionHistorySet.fromJson(Map<String, dynamic> json) =>
      _$ProgressionHistorySetFromJson(json);

  @override
  final int setIndex;
  @override
  final double? weightKg;
  @override
  final int reps;
  @override
  final int? rir;

  /// Create a copy of ProgressionHistorySet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgressionHistorySetCopyWith<_ProgressionHistorySet> get copyWith =>
      __$ProgressionHistorySetCopyWithImpl<_ProgressionHistorySet>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgressionHistorySetToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProgressionHistorySet &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, setIndex, weightKg, reps, rir);

  @override
  String toString() {
    return 'ProgressionHistorySet(setIndex: $setIndex, weightKg: $weightKg, reps: $reps, rir: $rir)';
  }
}

/// @nodoc
abstract mixin class _$ProgressionHistorySetCopyWith<$Res>
    implements $ProgressionHistorySetCopyWith<$Res> {
  factory _$ProgressionHistorySetCopyWith(_ProgressionHistorySet value,
          $Res Function(_ProgressionHistorySet) _then) =
      __$ProgressionHistorySetCopyWithImpl;
  @override
  @useResult
  $Res call({int setIndex, double? weightKg, int reps, int? rir});
}

/// @nodoc
class __$ProgressionHistorySetCopyWithImpl<$Res>
    implements _$ProgressionHistorySetCopyWith<$Res> {
  __$ProgressionHistorySetCopyWithImpl(this._self, this._then);

  final _ProgressionHistorySet _self;
  final $Res Function(_ProgressionHistorySet) _then;

  /// Create a copy of ProgressionHistorySet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? setIndex = null,
    Object? weightKg = freezed,
    Object? reps = null,
    Object? rir = freezed,
  }) {
    return _then(_ProgressionHistorySet(
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
mixin _$ProgressionHistoryEntry {
  String get sessionId;
  String get date;
  List<ProgressionHistorySet> get sets;

  /// Create a copy of ProgressionHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgressionHistoryEntryCopyWith<ProgressionHistoryEntry> get copyWith =>
      _$ProgressionHistoryEntryCopyWithImpl<ProgressionHistoryEntry>(
          this as ProgressionHistoryEntry, _$identity);

  /// Serializes this ProgressionHistoryEntry to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProgressionHistoryEntry &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.date, date) || other.date == date) &&
            const DeepCollectionEquality().equals(other.sets, sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, sessionId, date, const DeepCollectionEquality().hash(sets));

  @override
  String toString() {
    return 'ProgressionHistoryEntry(sessionId: $sessionId, date: $date, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class $ProgressionHistoryEntryCopyWith<$Res> {
  factory $ProgressionHistoryEntryCopyWith(ProgressionHistoryEntry value,
          $Res Function(ProgressionHistoryEntry) _then) =
      _$ProgressionHistoryEntryCopyWithImpl;
  @useResult
  $Res call({String sessionId, String date, List<ProgressionHistorySet> sets});
}

/// @nodoc
class _$ProgressionHistoryEntryCopyWithImpl<$Res>
    implements $ProgressionHistoryEntryCopyWith<$Res> {
  _$ProgressionHistoryEntryCopyWithImpl(this._self, this._then);

  final ProgressionHistoryEntry _self;
  final $Res Function(ProgressionHistoryEntry) _then;

  /// Create a copy of ProgressionHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? date = null,
    Object? sets = null,
  }) {
    return _then(_self.copyWith(
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      sets: null == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<ProgressionHistorySet>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProgressionHistoryEntry].
extension ProgressionHistoryEntryPatterns on ProgressionHistoryEntry {
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
    TResult Function(_ProgressionHistoryEntry value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistoryEntry() when $default != null:
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
    TResult Function(_ProgressionHistoryEntry value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistoryEntry():
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
    TResult? Function(_ProgressionHistoryEntry value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistoryEntry() when $default != null:
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
            String sessionId, String date, List<ProgressionHistorySet> sets)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistoryEntry() when $default != null:
        return $default(_that.sessionId, _that.date, _that.sets);
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
            String sessionId, String date, List<ProgressionHistorySet> sets)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistoryEntry():
        return $default(_that.sessionId, _that.date, _that.sets);
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
            String sessionId, String date, List<ProgressionHistorySet> sets)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionHistoryEntry() when $default != null:
        return $default(_that.sessionId, _that.date, _that.sets);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProgressionHistoryEntry implements ProgressionHistoryEntry {
  const _ProgressionHistoryEntry(
      {required this.sessionId,
      required this.date,
      required final List<ProgressionHistorySet> sets})
      : _sets = sets;
  factory _ProgressionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$ProgressionHistoryEntryFromJson(json);

  @override
  final String sessionId;
  @override
  final String date;
  final List<ProgressionHistorySet> _sets;
  @override
  List<ProgressionHistorySet> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  /// Create a copy of ProgressionHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgressionHistoryEntryCopyWith<_ProgressionHistoryEntry> get copyWith =>
      __$ProgressionHistoryEntryCopyWithImpl<_ProgressionHistoryEntry>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgressionHistoryEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProgressionHistoryEntry &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.date, date) || other.date == date) &&
            const DeepCollectionEquality().equals(other._sets, _sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, sessionId, date, const DeepCollectionEquality().hash(_sets));

  @override
  String toString() {
    return 'ProgressionHistoryEntry(sessionId: $sessionId, date: $date, sets: $sets)';
  }
}

/// @nodoc
abstract mixin class _$ProgressionHistoryEntryCopyWith<$Res>
    implements $ProgressionHistoryEntryCopyWith<$Res> {
  factory _$ProgressionHistoryEntryCopyWith(_ProgressionHistoryEntry value,
          $Res Function(_ProgressionHistoryEntry) _then) =
      __$ProgressionHistoryEntryCopyWithImpl;
  @override
  @useResult
  $Res call({String sessionId, String date, List<ProgressionHistorySet> sets});
}

/// @nodoc
class __$ProgressionHistoryEntryCopyWithImpl<$Res>
    implements _$ProgressionHistoryEntryCopyWith<$Res> {
  __$ProgressionHistoryEntryCopyWithImpl(this._self, this._then);

  final _ProgressionHistoryEntry _self;
  final $Res Function(_ProgressionHistoryEntry) _then;

  /// Create a copy of ProgressionHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sessionId = null,
    Object? date = null,
    Object? sets = null,
  }) {
    return _then(_ProgressionHistoryEntry(
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      sets: null == sets
          ? _self._sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<ProgressionHistorySet>,
    ));
  }
}

/// @nodoc
mixin _$ProgressionDetail {
  String get exerciseId;
  String get name;
  ProgressionTarget? get target;
  ProgressionRecommendation get recommendation;
  List<ProgressionHistoryEntry> get history;

  /// Create a copy of ProgressionDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgressionDetailCopyWith<ProgressionDetail> get copyWith =>
      _$ProgressionDetailCopyWithImpl<ProgressionDetail>(
          this as ProgressionDetail, _$identity);

  /// Serializes this ProgressionDetail to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProgressionDetail &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.target, target) || other.target == target) &&
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation) &&
            const DeepCollectionEquality().equals(other.history, history));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, exerciseId, name, target,
      recommendation, const DeepCollectionEquality().hash(history));

  @override
  String toString() {
    return 'ProgressionDetail(exerciseId: $exerciseId, name: $name, target: $target, recommendation: $recommendation, history: $history)';
  }
}

/// @nodoc
abstract mixin class $ProgressionDetailCopyWith<$Res> {
  factory $ProgressionDetailCopyWith(
          ProgressionDetail value, $Res Function(ProgressionDetail) _then) =
      _$ProgressionDetailCopyWithImpl;
  @useResult
  $Res call(
      {String exerciseId,
      String name,
      ProgressionTarget? target,
      ProgressionRecommendation recommendation,
      List<ProgressionHistoryEntry> history});

  $ProgressionTargetCopyWith<$Res>? get target;
  $ProgressionRecommendationCopyWith<$Res> get recommendation;
}

/// @nodoc
class _$ProgressionDetailCopyWithImpl<$Res>
    implements $ProgressionDetailCopyWith<$Res> {
  _$ProgressionDetailCopyWithImpl(this._self, this._then);

  final ProgressionDetail _self;
  final $Res Function(ProgressionDetail) _then;

  /// Create a copy of ProgressionDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exerciseId = null,
    Object? name = null,
    Object? target = freezed,
    Object? recommendation = null,
    Object? history = null,
  }) {
    return _then(_self.copyWith(
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      target: freezed == target
          ? _self.target
          : target // ignore: cast_nullable_to_non_nullable
              as ProgressionTarget?,
      recommendation: null == recommendation
          ? _self.recommendation
          : recommendation // ignore: cast_nullable_to_non_nullable
              as ProgressionRecommendation,
      history: null == history
          ? _self.history
          : history // ignore: cast_nullable_to_non_nullable
              as List<ProgressionHistoryEntry>,
    ));
  }

  /// Create a copy of ProgressionDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressionTargetCopyWith<$Res>? get target {
    if (_self.target == null) {
      return null;
    }

    return $ProgressionTargetCopyWith<$Res>(_self.target!, (value) {
      return _then(_self.copyWith(target: value));
    });
  }

  /// Create a copy of ProgressionDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressionRecommendationCopyWith<$Res> get recommendation {
    return $ProgressionRecommendationCopyWith<$Res>(_self.recommendation,
        (value) {
      return _then(_self.copyWith(recommendation: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ProgressionDetail].
extension ProgressionDetailPatterns on ProgressionDetail {
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
    TResult Function(_ProgressionDetail value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionDetail() when $default != null:
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
    TResult Function(_ProgressionDetail value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionDetail():
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
    TResult? Function(_ProgressionDetail value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionDetail() when $default != null:
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
            String name,
            ProgressionTarget? target,
            ProgressionRecommendation recommendation,
            List<ProgressionHistoryEntry> history)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProgressionDetail() when $default != null:
        return $default(_that.exerciseId, _that.name, _that.target,
            _that.recommendation, _that.history);
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
            String name,
            ProgressionTarget? target,
            ProgressionRecommendation recommendation,
            List<ProgressionHistoryEntry> history)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionDetail():
        return $default(_that.exerciseId, _that.name, _that.target,
            _that.recommendation, _that.history);
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
            String name,
            ProgressionTarget? target,
            ProgressionRecommendation recommendation,
            List<ProgressionHistoryEntry> history)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProgressionDetail() when $default != null:
        return $default(_that.exerciseId, _that.name, _that.target,
            _that.recommendation, _that.history);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProgressionDetail implements ProgressionDetail {
  const _ProgressionDetail(
      {required this.exerciseId,
      required this.name,
      required this.target,
      required this.recommendation,
      required final List<ProgressionHistoryEntry> history})
      : _history = history;
  factory _ProgressionDetail.fromJson(Map<String, dynamic> json) =>
      _$ProgressionDetailFromJson(json);

  @override
  final String exerciseId;
  @override
  final String name;
  @override
  final ProgressionTarget? target;
  @override
  final ProgressionRecommendation recommendation;
  final List<ProgressionHistoryEntry> _history;
  @override
  List<ProgressionHistoryEntry> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

  /// Create a copy of ProgressionDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgressionDetailCopyWith<_ProgressionDetail> get copyWith =>
      __$ProgressionDetailCopyWithImpl<_ProgressionDetail>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgressionDetailToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProgressionDetail &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.target, target) || other.target == target) &&
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation) &&
            const DeepCollectionEquality().equals(other._history, _history));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, exerciseId, name, target,
      recommendation, const DeepCollectionEquality().hash(_history));

  @override
  String toString() {
    return 'ProgressionDetail(exerciseId: $exerciseId, name: $name, target: $target, recommendation: $recommendation, history: $history)';
  }
}

/// @nodoc
abstract mixin class _$ProgressionDetailCopyWith<$Res>
    implements $ProgressionDetailCopyWith<$Res> {
  factory _$ProgressionDetailCopyWith(
          _ProgressionDetail value, $Res Function(_ProgressionDetail) _then) =
      __$ProgressionDetailCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String exerciseId,
      String name,
      ProgressionTarget? target,
      ProgressionRecommendation recommendation,
      List<ProgressionHistoryEntry> history});

  @override
  $ProgressionTargetCopyWith<$Res>? get target;
  @override
  $ProgressionRecommendationCopyWith<$Res> get recommendation;
}

/// @nodoc
class __$ProgressionDetailCopyWithImpl<$Res>
    implements _$ProgressionDetailCopyWith<$Res> {
  __$ProgressionDetailCopyWithImpl(this._self, this._then);

  final _ProgressionDetail _self;
  final $Res Function(_ProgressionDetail) _then;

  /// Create a copy of ProgressionDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? exerciseId = null,
    Object? name = null,
    Object? target = freezed,
    Object? recommendation = null,
    Object? history = null,
  }) {
    return _then(_ProgressionDetail(
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      target: freezed == target
          ? _self.target
          : target // ignore: cast_nullable_to_non_nullable
              as ProgressionTarget?,
      recommendation: null == recommendation
          ? _self.recommendation
          : recommendation // ignore: cast_nullable_to_non_nullable
              as ProgressionRecommendation,
      history: null == history
          ? _self._history
          : history // ignore: cast_nullable_to_non_nullable
              as List<ProgressionHistoryEntry>,
    ));
  }

  /// Create a copy of ProgressionDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressionTargetCopyWith<$Res>? get target {
    if (_self.target == null) {
      return null;
    }

    return $ProgressionTargetCopyWith<$Res>(_self.target!, (value) {
      return _then(_self.copyWith(target: value));
    });
  }

  /// Create a copy of ProgressionDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressionRecommendationCopyWith<$Res> get recommendation {
    return $ProgressionRecommendationCopyWith<$Res>(_self.recommendation,
        (value) {
      return _then(_self.copyWith(recommendation: value));
    });
  }
}

/// @nodoc
mixin _$SeededExercise {
  String get clientExerciseId;
  String get exerciseId;
  String? get plannedExerciseId;
  int get orderIndex;

  /// Create a copy of SeededExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SeededExerciseCopyWith<SeededExercise> get copyWith =>
      _$SeededExerciseCopyWithImpl<SeededExercise>(
          this as SeededExercise, _$identity);

  /// Serializes this SeededExercise to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SeededExercise &&
            (identical(other.clientExerciseId, clientExerciseId) ||
                other.clientExerciseId == clientExerciseId) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.plannedExerciseId, plannedExerciseId) ||
                other.plannedExerciseId == plannedExerciseId) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, clientExerciseId, exerciseId, plannedExerciseId, orderIndex);

  @override
  String toString() {
    return 'SeededExercise(clientExerciseId: $clientExerciseId, exerciseId: $exerciseId, plannedExerciseId: $plannedExerciseId, orderIndex: $orderIndex)';
  }
}

/// @nodoc
abstract mixin class $SeededExerciseCopyWith<$Res> {
  factory $SeededExerciseCopyWith(
          SeededExercise value, $Res Function(SeededExercise) _then) =
      _$SeededExerciseCopyWithImpl;
  @useResult
  $Res call(
      {String clientExerciseId,
      String exerciseId,
      String? plannedExerciseId,
      int orderIndex});
}

/// @nodoc
class _$SeededExerciseCopyWithImpl<$Res>
    implements $SeededExerciseCopyWith<$Res> {
  _$SeededExerciseCopyWithImpl(this._self, this._then);

  final SeededExercise _self;
  final $Res Function(SeededExercise) _then;

  /// Create a copy of SeededExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? clientExerciseId = null,
    Object? exerciseId = null,
    Object? plannedExerciseId = freezed,
    Object? orderIndex = null,
  }) {
    return _then(_self.copyWith(
      clientExerciseId: null == clientExerciseId
          ? _self.clientExerciseId
          : clientExerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      plannedExerciseId: freezed == plannedExerciseId
          ? _self.plannedExerciseId
          : plannedExerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [SeededExercise].
extension SeededExercisePatterns on SeededExercise {
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
    TResult Function(_SeededExercise value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SeededExercise() when $default != null:
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
    TResult Function(_SeededExercise value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SeededExercise():
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
    TResult? Function(_SeededExercise value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SeededExercise() when $default != null:
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
    TResult Function(String clientExerciseId, String exerciseId,
            String? plannedExerciseId, int orderIndex)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SeededExercise() when $default != null:
        return $default(_that.clientExerciseId, _that.exerciseId,
            _that.plannedExerciseId, _that.orderIndex);
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
    TResult Function(String clientExerciseId, String exerciseId,
            String? plannedExerciseId, int orderIndex)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SeededExercise():
        return $default(_that.clientExerciseId, _that.exerciseId,
            _that.plannedExerciseId, _that.orderIndex);
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
    TResult? Function(String clientExerciseId, String exerciseId,
            String? plannedExerciseId, int orderIndex)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SeededExercise() when $default != null:
        return $default(_that.clientExerciseId, _that.exerciseId,
            _that.plannedExerciseId, _that.orderIndex);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SeededExercise implements SeededExercise {
  const _SeededExercise(
      {required this.clientExerciseId,
      required this.exerciseId,
      this.plannedExerciseId,
      required this.orderIndex});
  factory _SeededExercise.fromJson(Map<String, dynamic> json) =>
      _$SeededExerciseFromJson(json);

  @override
  final String clientExerciseId;
  @override
  final String exerciseId;
  @override
  final String? plannedExerciseId;
  @override
  final int orderIndex;

  /// Create a copy of SeededExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SeededExerciseCopyWith<_SeededExercise> get copyWith =>
      __$SeededExerciseCopyWithImpl<_SeededExercise>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SeededExerciseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SeededExercise &&
            (identical(other.clientExerciseId, clientExerciseId) ||
                other.clientExerciseId == clientExerciseId) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.plannedExerciseId, plannedExerciseId) ||
                other.plannedExerciseId == plannedExerciseId) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, clientExerciseId, exerciseId, plannedExerciseId, orderIndex);

  @override
  String toString() {
    return 'SeededExercise(clientExerciseId: $clientExerciseId, exerciseId: $exerciseId, plannedExerciseId: $plannedExerciseId, orderIndex: $orderIndex)';
  }
}

/// @nodoc
abstract mixin class _$SeededExerciseCopyWith<$Res>
    implements $SeededExerciseCopyWith<$Res> {
  factory _$SeededExerciseCopyWith(
          _SeededExercise value, $Res Function(_SeededExercise) _then) =
      __$SeededExerciseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String clientExerciseId,
      String exerciseId,
      String? plannedExerciseId,
      int orderIndex});
}

/// @nodoc
class __$SeededExerciseCopyWithImpl<$Res>
    implements _$SeededExerciseCopyWith<$Res> {
  __$SeededExerciseCopyWithImpl(this._self, this._then);

  final _SeededExercise _self;
  final $Res Function(_SeededExercise) _then;

  /// Create a copy of SeededExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? clientExerciseId = null,
    Object? exerciseId = null,
    Object? plannedExerciseId = freezed,
    Object? orderIndex = null,
  }) {
    return _then(_SeededExercise(
      clientExerciseId: null == clientExerciseId
          ? _self.clientExerciseId
          : clientExerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      plannedExerciseId: freezed == plannedExerciseId
          ? _self.plannedExerciseId
          : plannedExerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      orderIndex: null == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$StartSessionRequest {
  String get clientSessionId;
  String? get programDayId;
  String get startedAt;
  List<SeededExercise>? get exercises;

  /// Create a copy of StartSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StartSessionRequestCopyWith<StartSessionRequest> get copyWith =>
      _$StartSessionRequestCopyWithImpl<StartSessionRequest>(
          this as StartSessionRequest, _$identity);

  /// Serializes this StartSessionRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StartSessionRequest &&
            (identical(other.clientSessionId, clientSessionId) ||
                other.clientSessionId == clientSessionId) &&
            (identical(other.programDayId, programDayId) ||
                other.programDayId == programDayId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            const DeepCollectionEquality().equals(other.exercises, exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, clientSessionId, programDayId,
      startedAt, const DeepCollectionEquality().hash(exercises));

  @override
  String toString() {
    return 'StartSessionRequest(clientSessionId: $clientSessionId, programDayId: $programDayId, startedAt: $startedAt, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class $StartSessionRequestCopyWith<$Res> {
  factory $StartSessionRequestCopyWith(
          StartSessionRequest value, $Res Function(StartSessionRequest) _then) =
      _$StartSessionRequestCopyWithImpl;
  @useResult
  $Res call(
      {String clientSessionId,
      String? programDayId,
      String startedAt,
      List<SeededExercise>? exercises});
}

/// @nodoc
class _$StartSessionRequestCopyWithImpl<$Res>
    implements $StartSessionRequestCopyWith<$Res> {
  _$StartSessionRequestCopyWithImpl(this._self, this._then);

  final StartSessionRequest _self;
  final $Res Function(StartSessionRequest) _then;

  /// Create a copy of StartSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? clientSessionId = null,
    Object? programDayId = freezed,
    Object? startedAt = null,
    Object? exercises = freezed,
  }) {
    return _then(_self.copyWith(
      clientSessionId: null == clientSessionId
          ? _self.clientSessionId
          : clientSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      programDayId: freezed == programDayId
          ? _self.programDayId
          : programDayId // ignore: cast_nullable_to_non_nullable
              as String?,
      startedAt: null == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as String,
      exercises: freezed == exercises
          ? _self.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<SeededExercise>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [StartSessionRequest].
extension StartSessionRequestPatterns on StartSessionRequest {
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
    TResult Function(_StartSessionRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StartSessionRequest() when $default != null:
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
    TResult Function(_StartSessionRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StartSessionRequest():
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
    TResult? Function(_StartSessionRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StartSessionRequest() when $default != null:
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
    TResult Function(String clientSessionId, String? programDayId,
            String startedAt, List<SeededExercise>? exercises)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StartSessionRequest() when $default != null:
        return $default(_that.clientSessionId, _that.programDayId,
            _that.startedAt, _that.exercises);
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
    TResult Function(String clientSessionId, String? programDayId,
            String startedAt, List<SeededExercise>? exercises)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StartSessionRequest():
        return $default(_that.clientSessionId, _that.programDayId,
            _that.startedAt, _that.exercises);
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
    TResult? Function(String clientSessionId, String? programDayId,
            String startedAt, List<SeededExercise>? exercises)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StartSessionRequest() when $default != null:
        return $default(_that.clientSessionId, _that.programDayId,
            _that.startedAt, _that.exercises);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _StartSessionRequest implements StartSessionRequest {
  const _StartSessionRequest(
      {required this.clientSessionId,
      this.programDayId,
      required this.startedAt,
      final List<SeededExercise>? exercises})
      : _exercises = exercises;
  factory _StartSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$StartSessionRequestFromJson(json);

  @override
  final String clientSessionId;
  @override
  final String? programDayId;
  @override
  final String startedAt;
  final List<SeededExercise>? _exercises;
  @override
  List<SeededExercise>? get exercises {
    final value = _exercises;
    if (value == null) return null;
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of StartSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StartSessionRequestCopyWith<_StartSessionRequest> get copyWith =>
      __$StartSessionRequestCopyWithImpl<_StartSessionRequest>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$StartSessionRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _StartSessionRequest &&
            (identical(other.clientSessionId, clientSessionId) ||
                other.clientSessionId == clientSessionId) &&
            (identical(other.programDayId, programDayId) ||
                other.programDayId == programDayId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, clientSessionId, programDayId,
      startedAt, const DeepCollectionEquality().hash(_exercises));

  @override
  String toString() {
    return 'StartSessionRequest(clientSessionId: $clientSessionId, programDayId: $programDayId, startedAt: $startedAt, exercises: $exercises)';
  }
}

/// @nodoc
abstract mixin class _$StartSessionRequestCopyWith<$Res>
    implements $StartSessionRequestCopyWith<$Res> {
  factory _$StartSessionRequestCopyWith(_StartSessionRequest value,
          $Res Function(_StartSessionRequest) _then) =
      __$StartSessionRequestCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String clientSessionId,
      String? programDayId,
      String startedAt,
      List<SeededExercise>? exercises});
}

/// @nodoc
class __$StartSessionRequestCopyWithImpl<$Res>
    implements _$StartSessionRequestCopyWith<$Res> {
  __$StartSessionRequestCopyWithImpl(this._self, this._then);

  final _StartSessionRequest _self;
  final $Res Function(_StartSessionRequest) _then;

  /// Create a copy of StartSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? clientSessionId = null,
    Object? programDayId = freezed,
    Object? startedAt = null,
    Object? exercises = freezed,
  }) {
    return _then(_StartSessionRequest(
      clientSessionId: null == clientSessionId
          ? _self.clientSessionId
          : clientSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      programDayId: freezed == programDayId
          ? _self.programDayId
          : programDayId // ignore: cast_nullable_to_non_nullable
              as String?,
      startedAt: null == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as String,
      exercises: freezed == exercises
          ? _self._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<SeededExercise>?,
    ));
  }
}

/// @nodoc
mixin _$LogSetInput {
  String get clientSetId;
  String get clientExerciseId;
  int get setIndex;
  SetType get setType;
  double? get weightKg;
  int get reps;
  int? get rir;
  String get loggedAt;
  String? get plannedSetId;

  /// Create a copy of LogSetInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LogSetInputCopyWith<LogSetInput> get copyWith =>
      _$LogSetInputCopyWithImpl<LogSetInput>(this as LogSetInput, _$identity);

  /// Serializes this LogSetInput to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LogSetInput &&
            (identical(other.clientSetId, clientSetId) ||
                other.clientSetId == clientSetId) &&
            (identical(other.clientExerciseId, clientExerciseId) ||
                other.clientExerciseId == clientExerciseId) &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.setType, setType) || other.setType == setType) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir) &&
            (identical(other.loggedAt, loggedAt) ||
                other.loggedAt == loggedAt) &&
            (identical(other.plannedSetId, plannedSetId) ||
                other.plannedSetId == plannedSetId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, clientSetId, clientExerciseId,
      setIndex, setType, weightKg, reps, rir, loggedAt, plannedSetId);

  @override
  String toString() {
    return 'LogSetInput(clientSetId: $clientSetId, clientExerciseId: $clientExerciseId, setIndex: $setIndex, setType: $setType, weightKg: $weightKg, reps: $reps, rir: $rir, loggedAt: $loggedAt, plannedSetId: $plannedSetId)';
  }
}

/// @nodoc
abstract mixin class $LogSetInputCopyWith<$Res> {
  factory $LogSetInputCopyWith(
          LogSetInput value, $Res Function(LogSetInput) _then) =
      _$LogSetInputCopyWithImpl;
  @useResult
  $Res call(
      {String clientSetId,
      String clientExerciseId,
      int setIndex,
      SetType setType,
      double? weightKg,
      int reps,
      int? rir,
      String loggedAt,
      String? plannedSetId});
}

/// @nodoc
class _$LogSetInputCopyWithImpl<$Res> implements $LogSetInputCopyWith<$Res> {
  _$LogSetInputCopyWithImpl(this._self, this._then);

  final LogSetInput _self;
  final $Res Function(LogSetInput) _then;

  /// Create a copy of LogSetInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? clientSetId = null,
    Object? clientExerciseId = null,
    Object? setIndex = null,
    Object? setType = null,
    Object? weightKg = freezed,
    Object? reps = null,
    Object? rir = freezed,
    Object? loggedAt = null,
    Object? plannedSetId = freezed,
  }) {
    return _then(_self.copyWith(
      clientSetId: null == clientSetId
          ? _self.clientSetId
          : clientSetId // ignore: cast_nullable_to_non_nullable
              as String,
      clientExerciseId: null == clientExerciseId
          ? _self.clientExerciseId
          : clientExerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      setType: null == setType
          ? _self.setType
          : setType // ignore: cast_nullable_to_non_nullable
              as SetType,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
      loggedAt: null == loggedAt
          ? _self.loggedAt
          : loggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      plannedSetId: freezed == plannedSetId
          ? _self.plannedSetId
          : plannedSetId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [LogSetInput].
extension LogSetInputPatterns on LogSetInput {
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
    TResult Function(_LogSetInput value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LogSetInput() when $default != null:
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
    TResult Function(_LogSetInput value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LogSetInput():
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
    TResult? Function(_LogSetInput value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LogSetInput() when $default != null:
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
            String clientSetId,
            String clientExerciseId,
            int setIndex,
            SetType setType,
            double? weightKg,
            int reps,
            int? rir,
            String loggedAt,
            String? plannedSetId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LogSetInput() when $default != null:
        return $default(
            _that.clientSetId,
            _that.clientExerciseId,
            _that.setIndex,
            _that.setType,
            _that.weightKg,
            _that.reps,
            _that.rir,
            _that.loggedAt,
            _that.plannedSetId);
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
            String clientSetId,
            String clientExerciseId,
            int setIndex,
            SetType setType,
            double? weightKg,
            int reps,
            int? rir,
            String loggedAt,
            String? plannedSetId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LogSetInput():
        return $default(
            _that.clientSetId,
            _that.clientExerciseId,
            _that.setIndex,
            _that.setType,
            _that.weightKg,
            _that.reps,
            _that.rir,
            _that.loggedAt,
            _that.plannedSetId);
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
            String clientSetId,
            String clientExerciseId,
            int setIndex,
            SetType setType,
            double? weightKg,
            int reps,
            int? rir,
            String loggedAt,
            String? plannedSetId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LogSetInput() when $default != null:
        return $default(
            _that.clientSetId,
            _that.clientExerciseId,
            _that.setIndex,
            _that.setType,
            _that.weightKg,
            _that.reps,
            _that.rir,
            _that.loggedAt,
            _that.plannedSetId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LogSetInput implements LogSetInput {
  const _LogSetInput(
      {required this.clientSetId,
      required this.clientExerciseId,
      required this.setIndex,
      required this.setType,
      required this.weightKg,
      required this.reps,
      required this.rir,
      required this.loggedAt,
      this.plannedSetId});
  factory _LogSetInput.fromJson(Map<String, dynamic> json) =>
      _$LogSetInputFromJson(json);

  @override
  final String clientSetId;
  @override
  final String clientExerciseId;
  @override
  final int setIndex;
  @override
  final SetType setType;
  @override
  final double? weightKg;
  @override
  final int reps;
  @override
  final int? rir;
  @override
  final String loggedAt;
  @override
  final String? plannedSetId;

  /// Create a copy of LogSetInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LogSetInputCopyWith<_LogSetInput> get copyWith =>
      __$LogSetInputCopyWithImpl<_LogSetInput>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LogSetInputToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LogSetInput &&
            (identical(other.clientSetId, clientSetId) ||
                other.clientSetId == clientSetId) &&
            (identical(other.clientExerciseId, clientExerciseId) ||
                other.clientExerciseId == clientExerciseId) &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.setType, setType) || other.setType == setType) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir) &&
            (identical(other.loggedAt, loggedAt) ||
                other.loggedAt == loggedAt) &&
            (identical(other.plannedSetId, plannedSetId) ||
                other.plannedSetId == plannedSetId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, clientSetId, clientExerciseId,
      setIndex, setType, weightKg, reps, rir, loggedAt, plannedSetId);

  @override
  String toString() {
    return 'LogSetInput(clientSetId: $clientSetId, clientExerciseId: $clientExerciseId, setIndex: $setIndex, setType: $setType, weightKg: $weightKg, reps: $reps, rir: $rir, loggedAt: $loggedAt, plannedSetId: $plannedSetId)';
  }
}

/// @nodoc
abstract mixin class _$LogSetInputCopyWith<$Res>
    implements $LogSetInputCopyWith<$Res> {
  factory _$LogSetInputCopyWith(
          _LogSetInput value, $Res Function(_LogSetInput) _then) =
      __$LogSetInputCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String clientSetId,
      String clientExerciseId,
      int setIndex,
      SetType setType,
      double? weightKg,
      int reps,
      int? rir,
      String loggedAt,
      String? plannedSetId});
}

/// @nodoc
class __$LogSetInputCopyWithImpl<$Res> implements _$LogSetInputCopyWith<$Res> {
  __$LogSetInputCopyWithImpl(this._self, this._then);

  final _LogSetInput _self;
  final $Res Function(_LogSetInput) _then;

  /// Create a copy of LogSetInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? clientSetId = null,
    Object? clientExerciseId = null,
    Object? setIndex = null,
    Object? setType = null,
    Object? weightKg = freezed,
    Object? reps = null,
    Object? rir = freezed,
    Object? loggedAt = null,
    Object? plannedSetId = freezed,
  }) {
    return _then(_LogSetInput(
      clientSetId: null == clientSetId
          ? _self.clientSetId
          : clientSetId // ignore: cast_nullable_to_non_nullable
              as String,
      clientExerciseId: null == clientExerciseId
          ? _self.clientExerciseId
          : clientExerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      setIndex: null == setIndex
          ? _self.setIndex
          : setIndex // ignore: cast_nullable_to_non_nullable
              as int,
      setType: null == setType
          ? _self.setType
          : setType // ignore: cast_nullable_to_non_nullable
              as SetType,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      reps: null == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
      loggedAt: null == loggedAt
          ? _self.loggedAt
          : loggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      plannedSetId: freezed == plannedSetId
          ? _self.plannedSetId
          : plannedSetId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$LogSetsRequest {
  List<LogSetInput> get sets;
  bool get merge;

  /// Create a copy of LogSetsRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LogSetsRequestCopyWith<LogSetsRequest> get copyWith =>
      _$LogSetsRequestCopyWithImpl<LogSetsRequest>(
          this as LogSetsRequest, _$identity);

  /// Serializes this LogSetsRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LogSetsRequest &&
            const DeepCollectionEquality().equals(other.sets, sets) &&
            (identical(other.merge, merge) || other.merge == merge));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(sets), merge);

  @override
  String toString() {
    return 'LogSetsRequest(sets: $sets, merge: $merge)';
  }
}

/// @nodoc
abstract mixin class $LogSetsRequestCopyWith<$Res> {
  factory $LogSetsRequestCopyWith(
          LogSetsRequest value, $Res Function(LogSetsRequest) _then) =
      _$LogSetsRequestCopyWithImpl;
  @useResult
  $Res call({List<LogSetInput> sets, bool merge});
}

/// @nodoc
class _$LogSetsRequestCopyWithImpl<$Res>
    implements $LogSetsRequestCopyWith<$Res> {
  _$LogSetsRequestCopyWithImpl(this._self, this._then);

  final LogSetsRequest _self;
  final $Res Function(LogSetsRequest) _then;

  /// Create a copy of LogSetsRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sets = null,
    Object? merge = null,
  }) {
    return _then(_self.copyWith(
      sets: null == sets
          ? _self.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<LogSetInput>,
      merge: null == merge
          ? _self.merge
          : merge // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [LogSetsRequest].
extension LogSetsRequestPatterns on LogSetsRequest {
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
    TResult Function(_LogSetsRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LogSetsRequest() when $default != null:
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
    TResult Function(_LogSetsRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LogSetsRequest():
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
    TResult? Function(_LogSetsRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LogSetsRequest() when $default != null:
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
    TResult Function(List<LogSetInput> sets, bool merge)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LogSetsRequest() when $default != null:
        return $default(_that.sets, _that.merge);
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
    TResult Function(List<LogSetInput> sets, bool merge) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LogSetsRequest():
        return $default(_that.sets, _that.merge);
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
    TResult? Function(List<LogSetInput> sets, bool merge)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LogSetsRequest() when $default != null:
        return $default(_that.sets, _that.merge);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LogSetsRequest implements LogSetsRequest {
  const _LogSetsRequest(
      {required final List<LogSetInput> sets, this.merge = false})
      : _sets = sets;
  factory _LogSetsRequest.fromJson(Map<String, dynamic> json) =>
      _$LogSetsRequestFromJson(json);

  final List<LogSetInput> _sets;
  @override
  List<LogSetInput> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  @override
  @JsonKey()
  final bool merge;

  /// Create a copy of LogSetsRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LogSetsRequestCopyWith<_LogSetsRequest> get copyWith =>
      __$LogSetsRequestCopyWithImpl<_LogSetsRequest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LogSetsRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LogSetsRequest &&
            const DeepCollectionEquality().equals(other._sets, _sets) &&
            (identical(other.merge, merge) || other.merge == merge));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_sets), merge);

  @override
  String toString() {
    return 'LogSetsRequest(sets: $sets, merge: $merge)';
  }
}

/// @nodoc
abstract mixin class _$LogSetsRequestCopyWith<$Res>
    implements $LogSetsRequestCopyWith<$Res> {
  factory _$LogSetsRequestCopyWith(
          _LogSetsRequest value, $Res Function(_LogSetsRequest) _then) =
      __$LogSetsRequestCopyWithImpl;
  @override
  @useResult
  $Res call({List<LogSetInput> sets, bool merge});
}

/// @nodoc
class __$LogSetsRequestCopyWithImpl<$Res>
    implements _$LogSetsRequestCopyWith<$Res> {
  __$LogSetsRequestCopyWithImpl(this._self, this._then);

  final _LogSetsRequest _self;
  final $Res Function(_LogSetsRequest) _then;

  /// Create a copy of LogSetsRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sets = null,
    Object? merge = null,
  }) {
    return _then(_LogSetsRequest(
      sets: null == sets
          ? _self._sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<LogSetInput>,
      merge: null == merge
          ? _self.merge
          : merge // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$PatchSetRequest {
  SetType? get setType;

  /// `weightCleared` sends an explicit null.
  double? get weightKg;
  bool get weightCleared;
  int? get reps;
  int? get rir;
  bool get rirCleared;

  /// Create a copy of PatchSetRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PatchSetRequestCopyWith<PatchSetRequest> get copyWith =>
      _$PatchSetRequestCopyWithImpl<PatchSetRequest>(
          this as PatchSetRequest, _$identity);

  /// Serializes this PatchSetRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PatchSetRequest &&
            (identical(other.setType, setType) || other.setType == setType) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.weightCleared, weightCleared) ||
                other.weightCleared == weightCleared) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir) &&
            (identical(other.rirCleared, rirCleared) ||
                other.rirCleared == rirCleared));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, setType, weightKg, weightCleared, reps, rir, rirCleared);

  @override
  String toString() {
    return 'PatchSetRequest(setType: $setType, weightKg: $weightKg, weightCleared: $weightCleared, reps: $reps, rir: $rir, rirCleared: $rirCleared)';
  }
}

/// @nodoc
abstract mixin class $PatchSetRequestCopyWith<$Res> {
  factory $PatchSetRequestCopyWith(
          PatchSetRequest value, $Res Function(PatchSetRequest) _then) =
      _$PatchSetRequestCopyWithImpl;
  @useResult
  $Res call(
      {SetType? setType,
      double? weightKg,
      bool weightCleared,
      int? reps,
      int? rir,
      bool rirCleared});
}

/// @nodoc
class _$PatchSetRequestCopyWithImpl<$Res>
    implements $PatchSetRequestCopyWith<$Res> {
  _$PatchSetRequestCopyWithImpl(this._self, this._then);

  final PatchSetRequest _self;
  final $Res Function(PatchSetRequest) _then;

  /// Create a copy of PatchSetRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setType = freezed,
    Object? weightKg = freezed,
    Object? weightCleared = null,
    Object? reps = freezed,
    Object? rir = freezed,
    Object? rirCleared = null,
  }) {
    return _then(_self.copyWith(
      setType: freezed == setType
          ? _self.setType
          : setType // ignore: cast_nullable_to_non_nullable
              as SetType?,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      weightCleared: null == weightCleared
          ? _self.weightCleared
          : weightCleared // ignore: cast_nullable_to_non_nullable
              as bool,
      reps: freezed == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int?,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
      rirCleared: null == rirCleared
          ? _self.rirCleared
          : rirCleared // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [PatchSetRequest].
extension PatchSetRequestPatterns on PatchSetRequest {
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
    TResult Function(_PatchSetRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PatchSetRequest() when $default != null:
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
    TResult Function(_PatchSetRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchSetRequest():
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
    TResult? Function(_PatchSetRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchSetRequest() when $default != null:
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
    TResult Function(SetType? setType, double? weightKg, bool weightCleared,
            int? reps, int? rir, bool rirCleared)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PatchSetRequest() when $default != null:
        return $default(_that.setType, _that.weightKg, _that.weightCleared,
            _that.reps, _that.rir, _that.rirCleared);
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
    TResult Function(SetType? setType, double? weightKg, bool weightCleared,
            int? reps, int? rir, bool rirCleared)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchSetRequest():
        return $default(_that.setType, _that.weightKg, _that.weightCleared,
            _that.reps, _that.rir, _that.rirCleared);
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
    TResult? Function(SetType? setType, double? weightKg, bool weightCleared,
            int? reps, int? rir, bool rirCleared)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchSetRequest() when $default != null:
        return $default(_that.setType, _that.weightKg, _that.weightCleared,
            _that.reps, _that.rir, _that.rirCleared);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PatchSetRequest implements PatchSetRequest {
  const _PatchSetRequest(
      {this.setType,
      this.weightKg,
      this.weightCleared = false,
      this.reps,
      this.rir,
      this.rirCleared = false});
  factory _PatchSetRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchSetRequestFromJson(json);

  @override
  final SetType? setType;

  /// `weightCleared` sends an explicit null.
  @override
  final double? weightKg;
  @override
  @JsonKey()
  final bool weightCleared;
  @override
  final int? reps;
  @override
  final int? rir;
  @override
  @JsonKey()
  final bool rirCleared;

  /// Create a copy of PatchSetRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PatchSetRequestCopyWith<_PatchSetRequest> get copyWith =>
      __$PatchSetRequestCopyWithImpl<_PatchSetRequest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PatchSetRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PatchSetRequest &&
            (identical(other.setType, setType) || other.setType == setType) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.weightCleared, weightCleared) ||
                other.weightCleared == weightCleared) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.rir, rir) || other.rir == rir) &&
            (identical(other.rirCleared, rirCleared) ||
                other.rirCleared == rirCleared));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, setType, weightKg, weightCleared, reps, rir, rirCleared);

  @override
  String toString() {
    return 'PatchSetRequest(setType: $setType, weightKg: $weightKg, weightCleared: $weightCleared, reps: $reps, rir: $rir, rirCleared: $rirCleared)';
  }
}

/// @nodoc
abstract mixin class _$PatchSetRequestCopyWith<$Res>
    implements $PatchSetRequestCopyWith<$Res> {
  factory _$PatchSetRequestCopyWith(
          _PatchSetRequest value, $Res Function(_PatchSetRequest) _then) =
      __$PatchSetRequestCopyWithImpl;
  @override
  @useResult
  $Res call(
      {SetType? setType,
      double? weightKg,
      bool weightCleared,
      int? reps,
      int? rir,
      bool rirCleared});
}

/// @nodoc
class __$PatchSetRequestCopyWithImpl<$Res>
    implements _$PatchSetRequestCopyWith<$Res> {
  __$PatchSetRequestCopyWithImpl(this._self, this._then);

  final _PatchSetRequest _self;
  final $Res Function(_PatchSetRequest) _then;

  /// Create a copy of PatchSetRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? setType = freezed,
    Object? weightKg = freezed,
    Object? weightCleared = null,
    Object? reps = freezed,
    Object? rir = freezed,
    Object? rirCleared = null,
  }) {
    return _then(_PatchSetRequest(
      setType: freezed == setType
          ? _self.setType
          : setType // ignore: cast_nullable_to_non_nullable
              as SetType?,
      weightKg: freezed == weightKg
          ? _self.weightKg
          : weightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      weightCleared: null == weightCleared
          ? _self.weightCleared
          : weightCleared // ignore: cast_nullable_to_non_nullable
              as bool,
      reps: freezed == reps
          ? _self.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int?,
      rir: freezed == rir
          ? _self.rir
          : rir // ignore: cast_nullable_to_non_nullable
              as int?,
      rirCleared: null == rirCleared
          ? _self.rirCleared
          : rirCleared // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$AddSessionExerciseRequest {
  String get clientExerciseId;
  String get exerciseId;
  String? get plannedExerciseId;
  int? get orderIndex;
  int? get supersetGroup;

  /// Create a copy of AddSessionExerciseRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AddSessionExerciseRequestCopyWith<AddSessionExerciseRequest> get copyWith =>
      _$AddSessionExerciseRequestCopyWithImpl<AddSessionExerciseRequest>(
          this as AddSessionExerciseRequest, _$identity);

  /// Serializes this AddSessionExerciseRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AddSessionExerciseRequest &&
            (identical(other.clientExerciseId, clientExerciseId) ||
                other.clientExerciseId == clientExerciseId) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.plannedExerciseId, plannedExerciseId) ||
                other.plannedExerciseId == plannedExerciseId) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.supersetGroup, supersetGroup) ||
                other.supersetGroup == supersetGroup));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, clientExerciseId, exerciseId,
      plannedExerciseId, orderIndex, supersetGroup);

  @override
  String toString() {
    return 'AddSessionExerciseRequest(clientExerciseId: $clientExerciseId, exerciseId: $exerciseId, plannedExerciseId: $plannedExerciseId, orderIndex: $orderIndex, supersetGroup: $supersetGroup)';
  }
}

/// @nodoc
abstract mixin class $AddSessionExerciseRequestCopyWith<$Res> {
  factory $AddSessionExerciseRequestCopyWith(AddSessionExerciseRequest value,
          $Res Function(AddSessionExerciseRequest) _then) =
      _$AddSessionExerciseRequestCopyWithImpl;
  @useResult
  $Res call(
      {String clientExerciseId,
      String exerciseId,
      String? plannedExerciseId,
      int? orderIndex,
      int? supersetGroup});
}

/// @nodoc
class _$AddSessionExerciseRequestCopyWithImpl<$Res>
    implements $AddSessionExerciseRequestCopyWith<$Res> {
  _$AddSessionExerciseRequestCopyWithImpl(this._self, this._then);

  final AddSessionExerciseRequest _self;
  final $Res Function(AddSessionExerciseRequest) _then;

  /// Create a copy of AddSessionExerciseRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? clientExerciseId = null,
    Object? exerciseId = null,
    Object? plannedExerciseId = freezed,
    Object? orderIndex = freezed,
    Object? supersetGroup = freezed,
  }) {
    return _then(_self.copyWith(
      clientExerciseId: null == clientExerciseId
          ? _self.clientExerciseId
          : clientExerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      plannedExerciseId: freezed == plannedExerciseId
          ? _self.plannedExerciseId
          : plannedExerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      orderIndex: freezed == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      supersetGroup: freezed == supersetGroup
          ? _self.supersetGroup
          : supersetGroup // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AddSessionExerciseRequest].
extension AddSessionExerciseRequestPatterns on AddSessionExerciseRequest {
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
    TResult Function(_AddSessionExerciseRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AddSessionExerciseRequest() when $default != null:
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
    TResult Function(_AddSessionExerciseRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddSessionExerciseRequest():
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
    TResult? Function(_AddSessionExerciseRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddSessionExerciseRequest() when $default != null:
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
    TResult Function(String clientExerciseId, String exerciseId,
            String? plannedExerciseId, int? orderIndex, int? supersetGroup)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AddSessionExerciseRequest() when $default != null:
        return $default(_that.clientExerciseId, _that.exerciseId,
            _that.plannedExerciseId, _that.orderIndex, _that.supersetGroup);
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
    TResult Function(String clientExerciseId, String exerciseId,
            String? plannedExerciseId, int? orderIndex, int? supersetGroup)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddSessionExerciseRequest():
        return $default(_that.clientExerciseId, _that.exerciseId,
            _that.plannedExerciseId, _that.orderIndex, _that.supersetGroup);
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
    TResult? Function(String clientExerciseId, String exerciseId,
            String? plannedExerciseId, int? orderIndex, int? supersetGroup)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddSessionExerciseRequest() when $default != null:
        return $default(_that.clientExerciseId, _that.exerciseId,
            _that.plannedExerciseId, _that.orderIndex, _that.supersetGroup);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AddSessionExerciseRequest implements AddSessionExerciseRequest {
  const _AddSessionExerciseRequest(
      {required this.clientExerciseId,
      required this.exerciseId,
      this.plannedExerciseId,
      this.orderIndex,
      this.supersetGroup});
  factory _AddSessionExerciseRequest.fromJson(Map<String, dynamic> json) =>
      _$AddSessionExerciseRequestFromJson(json);

  @override
  final String clientExerciseId;
  @override
  final String exerciseId;
  @override
  final String? plannedExerciseId;
  @override
  final int? orderIndex;
  @override
  final int? supersetGroup;

  /// Create a copy of AddSessionExerciseRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AddSessionExerciseRequestCopyWith<_AddSessionExerciseRequest>
      get copyWith =>
          __$AddSessionExerciseRequestCopyWithImpl<_AddSessionExerciseRequest>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AddSessionExerciseRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AddSessionExerciseRequest &&
            (identical(other.clientExerciseId, clientExerciseId) ||
                other.clientExerciseId == clientExerciseId) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.plannedExerciseId, plannedExerciseId) ||
                other.plannedExerciseId == plannedExerciseId) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.supersetGroup, supersetGroup) ||
                other.supersetGroup == supersetGroup));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, clientExerciseId, exerciseId,
      plannedExerciseId, orderIndex, supersetGroup);

  @override
  String toString() {
    return 'AddSessionExerciseRequest(clientExerciseId: $clientExerciseId, exerciseId: $exerciseId, plannedExerciseId: $plannedExerciseId, orderIndex: $orderIndex, supersetGroup: $supersetGroup)';
  }
}

/// @nodoc
abstract mixin class _$AddSessionExerciseRequestCopyWith<$Res>
    implements $AddSessionExerciseRequestCopyWith<$Res> {
  factory _$AddSessionExerciseRequestCopyWith(_AddSessionExerciseRequest value,
          $Res Function(_AddSessionExerciseRequest) _then) =
      __$AddSessionExerciseRequestCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String clientExerciseId,
      String exerciseId,
      String? plannedExerciseId,
      int? orderIndex,
      int? supersetGroup});
}

/// @nodoc
class __$AddSessionExerciseRequestCopyWithImpl<$Res>
    implements _$AddSessionExerciseRequestCopyWith<$Res> {
  __$AddSessionExerciseRequestCopyWithImpl(this._self, this._then);

  final _AddSessionExerciseRequest _self;
  final $Res Function(_AddSessionExerciseRequest) _then;

  /// Create a copy of AddSessionExerciseRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? clientExerciseId = null,
    Object? exerciseId = null,
    Object? plannedExerciseId = freezed,
    Object? orderIndex = freezed,
    Object? supersetGroup = freezed,
  }) {
    return _then(_AddSessionExerciseRequest(
      clientExerciseId: null == clientExerciseId
          ? _self.clientExerciseId
          : clientExerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: null == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      plannedExerciseId: freezed == plannedExerciseId
          ? _self.plannedExerciseId
          : plannedExerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      orderIndex: freezed == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      supersetGroup: freezed == supersetGroup
          ? _self.supersetGroup
          : supersetGroup // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
mixin _$PatchSessionExerciseRequest {
  int? get orderIndex;
  int? get supersetGroup;
  bool get supersetCleared;
  String? get exerciseId;
  bool get removed;

  /// Create a copy of PatchSessionExerciseRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PatchSessionExerciseRequestCopyWith<PatchSessionExerciseRequest>
      get copyWith => _$PatchSessionExerciseRequestCopyWithImpl<
              PatchSessionExerciseRequest>(
          this as PatchSessionExerciseRequest, _$identity);

  /// Serializes this PatchSessionExerciseRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PatchSessionExerciseRequest &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.supersetGroup, supersetGroup) ||
                other.supersetGroup == supersetGroup) &&
            (identical(other.supersetCleared, supersetCleared) ||
                other.supersetCleared == supersetCleared) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.removed, removed) || other.removed == removed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, orderIndex, supersetGroup,
      supersetCleared, exerciseId, removed);

  @override
  String toString() {
    return 'PatchSessionExerciseRequest(orderIndex: $orderIndex, supersetGroup: $supersetGroup, supersetCleared: $supersetCleared, exerciseId: $exerciseId, removed: $removed)';
  }
}

/// @nodoc
abstract mixin class $PatchSessionExerciseRequestCopyWith<$Res> {
  factory $PatchSessionExerciseRequestCopyWith(
          PatchSessionExerciseRequest value,
          $Res Function(PatchSessionExerciseRequest) _then) =
      _$PatchSessionExerciseRequestCopyWithImpl;
  @useResult
  $Res call(
      {int? orderIndex,
      int? supersetGroup,
      bool supersetCleared,
      String? exerciseId,
      bool removed});
}

/// @nodoc
class _$PatchSessionExerciseRequestCopyWithImpl<$Res>
    implements $PatchSessionExerciseRequestCopyWith<$Res> {
  _$PatchSessionExerciseRequestCopyWithImpl(this._self, this._then);

  final PatchSessionExerciseRequest _self;
  final $Res Function(PatchSessionExerciseRequest) _then;

  /// Create a copy of PatchSessionExerciseRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderIndex = freezed,
    Object? supersetGroup = freezed,
    Object? supersetCleared = null,
    Object? exerciseId = freezed,
    Object? removed = null,
  }) {
    return _then(_self.copyWith(
      orderIndex: freezed == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      supersetGroup: freezed == supersetGroup
          ? _self.supersetGroup
          : supersetGroup // ignore: cast_nullable_to_non_nullable
              as int?,
      supersetCleared: null == supersetCleared
          ? _self.supersetCleared
          : supersetCleared // ignore: cast_nullable_to_non_nullable
              as bool,
      exerciseId: freezed == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      removed: null == removed
          ? _self.removed
          : removed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [PatchSessionExerciseRequest].
extension PatchSessionExerciseRequestPatterns on PatchSessionExerciseRequest {
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
    TResult Function(_PatchSessionExerciseRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PatchSessionExerciseRequest() when $default != null:
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
    TResult Function(_PatchSessionExerciseRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchSessionExerciseRequest():
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
    TResult? Function(_PatchSessionExerciseRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchSessionExerciseRequest() when $default != null:
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
    TResult Function(int? orderIndex, int? supersetGroup, bool supersetCleared,
            String? exerciseId, bool removed)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PatchSessionExerciseRequest() when $default != null:
        return $default(_that.orderIndex, _that.supersetGroup,
            _that.supersetCleared, _that.exerciseId, _that.removed);
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
    TResult Function(int? orderIndex, int? supersetGroup, bool supersetCleared,
            String? exerciseId, bool removed)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchSessionExerciseRequest():
        return $default(_that.orderIndex, _that.supersetGroup,
            _that.supersetCleared, _that.exerciseId, _that.removed);
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
    TResult? Function(int? orderIndex, int? supersetGroup, bool supersetCleared,
            String? exerciseId, bool removed)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PatchSessionExerciseRequest() when $default != null:
        return $default(_that.orderIndex, _that.supersetGroup,
            _that.supersetCleared, _that.exerciseId, _that.removed);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PatchSessionExerciseRequest implements PatchSessionExerciseRequest {
  const _PatchSessionExerciseRequest(
      {this.orderIndex,
      this.supersetGroup,
      this.supersetCleared = false,
      this.exerciseId,
      this.removed = false});
  factory _PatchSessionExerciseRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchSessionExerciseRequestFromJson(json);

  @override
  final int? orderIndex;
  @override
  final int? supersetGroup;
  @override
  @JsonKey()
  final bool supersetCleared;
  @override
  final String? exerciseId;
  @override
  @JsonKey()
  final bool removed;

  /// Create a copy of PatchSessionExerciseRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PatchSessionExerciseRequestCopyWith<_PatchSessionExerciseRequest>
      get copyWith => __$PatchSessionExerciseRequestCopyWithImpl<
          _PatchSessionExerciseRequest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PatchSessionExerciseRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PatchSessionExerciseRequest &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.supersetGroup, supersetGroup) ||
                other.supersetGroup == supersetGroup) &&
            (identical(other.supersetCleared, supersetCleared) ||
                other.supersetCleared == supersetCleared) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.removed, removed) || other.removed == removed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, orderIndex, supersetGroup,
      supersetCleared, exerciseId, removed);

  @override
  String toString() {
    return 'PatchSessionExerciseRequest(orderIndex: $orderIndex, supersetGroup: $supersetGroup, supersetCleared: $supersetCleared, exerciseId: $exerciseId, removed: $removed)';
  }
}

/// @nodoc
abstract mixin class _$PatchSessionExerciseRequestCopyWith<$Res>
    implements $PatchSessionExerciseRequestCopyWith<$Res> {
  factory _$PatchSessionExerciseRequestCopyWith(
          _PatchSessionExerciseRequest value,
          $Res Function(_PatchSessionExerciseRequest) _then) =
      __$PatchSessionExerciseRequestCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int? orderIndex,
      int? supersetGroup,
      bool supersetCleared,
      String? exerciseId,
      bool removed});
}

/// @nodoc
class __$PatchSessionExerciseRequestCopyWithImpl<$Res>
    implements _$PatchSessionExerciseRequestCopyWith<$Res> {
  __$PatchSessionExerciseRequestCopyWithImpl(this._self, this._then);

  final _PatchSessionExerciseRequest _self;
  final $Res Function(_PatchSessionExerciseRequest) _then;

  /// Create a copy of PatchSessionExerciseRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? orderIndex = freezed,
    Object? supersetGroup = freezed,
    Object? supersetCleared = null,
    Object? exerciseId = freezed,
    Object? removed = null,
  }) {
    return _then(_PatchSessionExerciseRequest(
      orderIndex: freezed == orderIndex
          ? _self.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      supersetGroup: freezed == supersetGroup
          ? _self.supersetGroup
          : supersetGroup // ignore: cast_nullable_to_non_nullable
              as int?,
      supersetCleared: null == supersetCleared
          ? _self.supersetCleared
          : supersetCleared // ignore: cast_nullable_to_non_nullable
              as bool,
      exerciseId: freezed == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      removed: null == removed
          ? _self.removed
          : removed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$CompleteSessionRequest {
  String get completedAt;
  String? get notes;

  /// Create a copy of CompleteSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CompleteSessionRequestCopyWith<CompleteSessionRequest> get copyWith =>
      _$CompleteSessionRequestCopyWithImpl<CompleteSessionRequest>(
          this as CompleteSessionRequest, _$identity);

  /// Serializes this CompleteSessionRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CompleteSessionRequest &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, completedAt, notes);

  @override
  String toString() {
    return 'CompleteSessionRequest(completedAt: $completedAt, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $CompleteSessionRequestCopyWith<$Res> {
  factory $CompleteSessionRequestCopyWith(CompleteSessionRequest value,
          $Res Function(CompleteSessionRequest) _then) =
      _$CompleteSessionRequestCopyWithImpl;
  @useResult
  $Res call({String completedAt, String? notes});
}

/// @nodoc
class _$CompleteSessionRequestCopyWithImpl<$Res>
    implements $CompleteSessionRequestCopyWith<$Res> {
  _$CompleteSessionRequestCopyWithImpl(this._self, this._then);

  final CompleteSessionRequest _self;
  final $Res Function(CompleteSessionRequest) _then;

  /// Create a copy of CompleteSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? completedAt = null,
    Object? notes = freezed,
  }) {
    return _then(_self.copyWith(
      completedAt: null == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as String,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CompleteSessionRequest].
extension CompleteSessionRequestPatterns on CompleteSessionRequest {
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
    TResult Function(_CompleteSessionRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CompleteSessionRequest() when $default != null:
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
    TResult Function(_CompleteSessionRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CompleteSessionRequest():
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
    TResult? Function(_CompleteSessionRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CompleteSessionRequest() when $default != null:
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
    TResult Function(String completedAt, String? notes)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CompleteSessionRequest() when $default != null:
        return $default(_that.completedAt, _that.notes);
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
    TResult Function(String completedAt, String? notes) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CompleteSessionRequest():
        return $default(_that.completedAt, _that.notes);
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
    TResult? Function(String completedAt, String? notes)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CompleteSessionRequest() when $default != null:
        return $default(_that.completedAt, _that.notes);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CompleteSessionRequest implements CompleteSessionRequest {
  const _CompleteSessionRequest({required this.completedAt, this.notes});
  factory _CompleteSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$CompleteSessionRequestFromJson(json);

  @override
  final String completedAt;
  @override
  final String? notes;

  /// Create a copy of CompleteSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CompleteSessionRequestCopyWith<_CompleteSessionRequest> get copyWith =>
      __$CompleteSessionRequestCopyWithImpl<_CompleteSessionRequest>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CompleteSessionRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CompleteSessionRequest &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, completedAt, notes);

  @override
  String toString() {
    return 'CompleteSessionRequest(completedAt: $completedAt, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class _$CompleteSessionRequestCopyWith<$Res>
    implements $CompleteSessionRequestCopyWith<$Res> {
  factory _$CompleteSessionRequestCopyWith(_CompleteSessionRequest value,
          $Res Function(_CompleteSessionRequest) _then) =
      __$CompleteSessionRequestCopyWithImpl;
  @override
  @useResult
  $Res call({String completedAt, String? notes});
}

/// @nodoc
class __$CompleteSessionRequestCopyWithImpl<$Res>
    implements _$CompleteSessionRequestCopyWith<$Res> {
  __$CompleteSessionRequestCopyWithImpl(this._self, this._then);

  final _CompleteSessionRequest _self;
  final $Res Function(_CompleteSessionRequest) _then;

  /// Create a copy of CompleteSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? completedAt = null,
    Object? notes = freezed,
  }) {
    return _then(_CompleteSessionRequest(
      completedAt: null == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as String,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
