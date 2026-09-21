// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HealthMetric {
  HealthMetricKind get kind;
  HealthAvailability get availability;
  double? get value;
  String get unit;
  String? get start;
  String? get end;

  /// Provider package names that contributed (internal; never on the
  /// primary UI).
  List<String> get sources;

  /// When the provider was asked (ISO-8601 UTC).
  String? get updatedAt;

  /// Create a copy of HealthMetric
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<HealthMetric> get copyWith =>
      _$HealthMetricCopyWithImpl<HealthMetric>(
          this as HealthMetric, _$identity);

  /// Serializes this HealthMetric to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HealthMetric &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.availability, availability) ||
                other.availability == availability) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end) &&
            const DeepCollectionEquality().equals(other.sources, sources) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, kind, availability, value, unit,
      start, end, const DeepCollectionEquality().hash(sources), updatedAt);

  @override
  String toString() {
    return 'HealthMetric(kind: $kind, availability: $availability, value: $value, unit: $unit, start: $start, end: $end, sources: $sources, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $HealthMetricCopyWith<$Res> {
  factory $HealthMetricCopyWith(
          HealthMetric value, $Res Function(HealthMetric) _then) =
      _$HealthMetricCopyWithImpl;
  @useResult
  $Res call(
      {HealthMetricKind kind,
      HealthAvailability availability,
      double? value,
      String unit,
      String? start,
      String? end,
      List<String> sources,
      String? updatedAt});
}

/// @nodoc
class _$HealthMetricCopyWithImpl<$Res> implements $HealthMetricCopyWith<$Res> {
  _$HealthMetricCopyWithImpl(this._self, this._then);

  final HealthMetric _self;
  final $Res Function(HealthMetric) _then;

  /// Create a copy of HealthMetric
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kind = null,
    Object? availability = null,
    Object? value = freezed,
    Object? unit = null,
    Object? start = freezed,
    Object? end = freezed,
    Object? sources = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_self.copyWith(
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as HealthMetricKind,
      availability: null == availability
          ? _self.availability
          : availability // ignore: cast_nullable_to_non_nullable
              as HealthAvailability,
      value: freezed == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double?,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      start: freezed == start
          ? _self.start
          : start // ignore: cast_nullable_to_non_nullable
              as String?,
      end: freezed == end
          ? _self.end
          : end // ignore: cast_nullable_to_non_nullable
              as String?,
      sources: null == sources
          ? _self.sources
          : sources // ignore: cast_nullable_to_non_nullable
              as List<String>,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [HealthMetric].
extension HealthMetricPatterns on HealthMetric {
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
    TResult Function(_HealthMetric value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthMetric() when $default != null:
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
    TResult Function(_HealthMetric value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthMetric():
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
    TResult? Function(_HealthMetric value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthMetric() when $default != null:
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
            HealthMetricKind kind,
            HealthAvailability availability,
            double? value,
            String unit,
            String? start,
            String? end,
            List<String> sources,
            String? updatedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthMetric() when $default != null:
        return $default(_that.kind, _that.availability, _that.value, _that.unit,
            _that.start, _that.end, _that.sources, _that.updatedAt);
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
            HealthMetricKind kind,
            HealthAvailability availability,
            double? value,
            String unit,
            String? start,
            String? end,
            List<String> sources,
            String? updatedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthMetric():
        return $default(_that.kind, _that.availability, _that.value, _that.unit,
            _that.start, _that.end, _that.sources, _that.updatedAt);
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
            HealthMetricKind kind,
            HealthAvailability availability,
            double? value,
            String unit,
            String? start,
            String? end,
            List<String> sources,
            String? updatedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthMetric() when $default != null:
        return $default(_that.kind, _that.availability, _that.value, _that.unit,
            _that.start, _that.end, _that.sources, _that.updatedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HealthMetric extends HealthMetric {
  const _HealthMetric(
      {required this.kind,
      required this.availability,
      required this.value,
      required this.unit,
      required this.start,
      required this.end,
      final List<String> sources = const <String>[],
      required this.updatedAt})
      : _sources = sources,
        super._();
  factory _HealthMetric.fromJson(Map<String, dynamic> json) =>
      _$HealthMetricFromJson(json);

  @override
  final HealthMetricKind kind;
  @override
  final HealthAvailability availability;
  @override
  final double? value;
  @override
  final String unit;
  @override
  final String? start;
  @override
  final String? end;

  /// Provider package names that contributed (internal; never on the
  /// primary UI).
  final List<String> _sources;

  /// Provider package names that contributed (internal; never on the
  /// primary UI).
  @override
  @JsonKey()
  List<String> get sources {
    if (_sources is EqualUnmodifiableListView) return _sources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sources);
  }

  /// When the provider was asked (ISO-8601 UTC).
  @override
  final String? updatedAt;

  /// Create a copy of HealthMetric
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HealthMetricCopyWith<_HealthMetric> get copyWith =>
      __$HealthMetricCopyWithImpl<_HealthMetric>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HealthMetricToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HealthMetric &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.availability, availability) ||
                other.availability == availability) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end) &&
            const DeepCollectionEquality().equals(other._sources, _sources) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, kind, availability, value, unit,
      start, end, const DeepCollectionEquality().hash(_sources), updatedAt);

  @override
  String toString() {
    return 'HealthMetric(kind: $kind, availability: $availability, value: $value, unit: $unit, start: $start, end: $end, sources: $sources, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$HealthMetricCopyWith<$Res>
    implements $HealthMetricCopyWith<$Res> {
  factory _$HealthMetricCopyWith(
          _HealthMetric value, $Res Function(_HealthMetric) _then) =
      __$HealthMetricCopyWithImpl;
  @override
  @useResult
  $Res call(
      {HealthMetricKind kind,
      HealthAvailability availability,
      double? value,
      String unit,
      String? start,
      String? end,
      List<String> sources,
      String? updatedAt});
}

/// @nodoc
class __$HealthMetricCopyWithImpl<$Res>
    implements _$HealthMetricCopyWith<$Res> {
  __$HealthMetricCopyWithImpl(this._self, this._then);

  final _HealthMetric _self;
  final $Res Function(_HealthMetric) _then;

  /// Create a copy of HealthMetric
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? kind = null,
    Object? availability = null,
    Object? value = freezed,
    Object? unit = null,
    Object? start = freezed,
    Object? end = freezed,
    Object? sources = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_HealthMetric(
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as HealthMetricKind,
      availability: null == availability
          ? _self.availability
          : availability // ignore: cast_nullable_to_non_nullable
              as HealthAvailability,
      value: freezed == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double?,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      start: freezed == start
          ? _self.start
          : start // ignore: cast_nullable_to_non_nullable
              as String?,
      end: freezed == end
          ? _self.end
          : end // ignore: cast_nullable_to_non_nullable
              as String?,
      sources: null == sources
          ? _self._sources
          : sources // ignore: cast_nullable_to_non_nullable
              as List<String>,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$HealthExerciseSession {
  String get start;
  String get end;

  /// Health Connect's exercise type code; kept for later mapping.
  int get type;
  String? get title;
  String get source;

  /// Create a copy of HealthExerciseSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HealthExerciseSessionCopyWith<HealthExerciseSession> get copyWith =>
      _$HealthExerciseSessionCopyWithImpl<HealthExerciseSession>(
          this as HealthExerciseSession, _$identity);

  /// Serializes this HealthExerciseSession to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HealthExerciseSession &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, start, end, type, title, source);

  @override
  String toString() {
    return 'HealthExerciseSession(start: $start, end: $end, type: $type, title: $title, source: $source)';
  }
}

/// @nodoc
abstract mixin class $HealthExerciseSessionCopyWith<$Res> {
  factory $HealthExerciseSessionCopyWith(HealthExerciseSession value,
          $Res Function(HealthExerciseSession) _then) =
      _$HealthExerciseSessionCopyWithImpl;
  @useResult
  $Res call({String start, String end, int type, String? title, String source});
}

/// @nodoc
class _$HealthExerciseSessionCopyWithImpl<$Res>
    implements $HealthExerciseSessionCopyWith<$Res> {
  _$HealthExerciseSessionCopyWithImpl(this._self, this._then);

  final HealthExerciseSession _self;
  final $Res Function(HealthExerciseSession) _then;

  /// Create a copy of HealthExerciseSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? start = null,
    Object? end = null,
    Object? type = null,
    Object? title = freezed,
    Object? source = null,
  }) {
    return _then(_self.copyWith(
      start: null == start
          ? _self.start
          : start // ignore: cast_nullable_to_non_nullable
              as String,
      end: null == end
          ? _self.end
          : end // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as int,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [HealthExerciseSession].
extension HealthExerciseSessionPatterns on HealthExerciseSession {
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
    TResult Function(_HealthExerciseSession value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthExerciseSession() when $default != null:
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
    TResult Function(_HealthExerciseSession value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthExerciseSession():
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
    TResult? Function(_HealthExerciseSession value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthExerciseSession() when $default != null:
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
            String start, String end, int type, String? title, String source)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthExerciseSession() when $default != null:
        return $default(
            _that.start, _that.end, _that.type, _that.title, _that.source);
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
            String start, String end, int type, String? title, String source)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthExerciseSession():
        return $default(
            _that.start, _that.end, _that.type, _that.title, _that.source);
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
            String start, String end, int type, String? title, String source)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthExerciseSession() when $default != null:
        return $default(
            _that.start, _that.end, _that.type, _that.title, _that.source);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HealthExerciseSession implements HealthExerciseSession {
  const _HealthExerciseSession(
      {required this.start,
      required this.end,
      required this.type,
      required this.title,
      required this.source});
  factory _HealthExerciseSession.fromJson(Map<String, dynamic> json) =>
      _$HealthExerciseSessionFromJson(json);

  @override
  final String start;
  @override
  final String end;

  /// Health Connect's exercise type code; kept for later mapping.
  @override
  final int type;
  @override
  final String? title;
  @override
  final String source;

  /// Create a copy of HealthExerciseSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HealthExerciseSessionCopyWith<_HealthExerciseSession> get copyWith =>
      __$HealthExerciseSessionCopyWithImpl<_HealthExerciseSession>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HealthExerciseSessionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HealthExerciseSession &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, start, end, type, title, source);

  @override
  String toString() {
    return 'HealthExerciseSession(start: $start, end: $end, type: $type, title: $title, source: $source)';
  }
}

/// @nodoc
abstract mixin class _$HealthExerciseSessionCopyWith<$Res>
    implements $HealthExerciseSessionCopyWith<$Res> {
  factory _$HealthExerciseSessionCopyWith(_HealthExerciseSession value,
          $Res Function(_HealthExerciseSession) _then) =
      __$HealthExerciseSessionCopyWithImpl;
  @override
  @useResult
  $Res call({String start, String end, int type, String? title, String source});
}

/// @nodoc
class __$HealthExerciseSessionCopyWithImpl<$Res>
    implements _$HealthExerciseSessionCopyWith<$Res> {
  __$HealthExerciseSessionCopyWithImpl(this._self, this._then);

  final _HealthExerciseSession _self;
  final $Res Function(_HealthExerciseSession) _then;

  /// Create a copy of HealthExerciseSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? start = null,
    Object? end = null,
    Object? type = null,
    Object? title = freezed,
    Object? source = null,
  }) {
    return _then(_HealthExerciseSession(
      start: null == start
          ? _self.start
          : start // ignore: cast_nullable_to_non_nullable
              as String,
      end: null == end
          ? _self.end
          : end // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as int,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$HealthSnapshot {
  /// Local date yyyy-mm-dd in the user's calendar.
  String get date;
  String get timezone;
  HealthMetric get steps;
  HealthMetric get distance;
  HealthMetric get activeCalories;
  HealthMetric get totalCalories;
  HealthMetric get sleep;
  HealthMetric get restingHeartRate;
  HealthMetric get weight;
  HealthMetric get bodyFat;
  HealthMetric get bmr;
  List<HealthExerciseSession> get exerciseSessions;

  /// Exercise-session availability (the list alone cannot say "denied").
  HealthAvailability get exerciseAvailability;

  /// Steps per local day for the current week, Monday first; null = no
  /// data or not permitted that day.
  List<double?> get weekSteps;

  /// Sleep minutes per local night for the current week, Monday first.
  List<double?> get weekSleep;
  String get fetchedAt;
  bool get fromCache;

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HealthSnapshotCopyWith<HealthSnapshot> get copyWith =>
      _$HealthSnapshotCopyWithImpl<HealthSnapshot>(
          this as HealthSnapshot, _$identity);

  /// Serializes this HealthSnapshot to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HealthSnapshot &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.steps, steps) || other.steps == steps) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.activeCalories, activeCalories) ||
                other.activeCalories == activeCalories) &&
            (identical(other.totalCalories, totalCalories) ||
                other.totalCalories == totalCalories) &&
            (identical(other.sleep, sleep) || other.sleep == sleep) &&
            (identical(other.restingHeartRate, restingHeartRate) ||
                other.restingHeartRate == restingHeartRate) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            (identical(other.bodyFat, bodyFat) || other.bodyFat == bodyFat) &&
            (identical(other.bmr, bmr) || other.bmr == bmr) &&
            const DeepCollectionEquality()
                .equals(other.exerciseSessions, exerciseSessions) &&
            (identical(other.exerciseAvailability, exerciseAvailability) ||
                other.exerciseAvailability == exerciseAvailability) &&
            const DeepCollectionEquality().equals(other.weekSteps, weekSteps) &&
            const DeepCollectionEquality().equals(other.weekSleep, weekSleep) &&
            (identical(other.fetchedAt, fetchedAt) ||
                other.fetchedAt == fetchedAt) &&
            (identical(other.fromCache, fromCache) ||
                other.fromCache == fromCache));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      date,
      timezone,
      steps,
      distance,
      activeCalories,
      totalCalories,
      sleep,
      restingHeartRate,
      weight,
      bodyFat,
      bmr,
      const DeepCollectionEquality().hash(exerciseSessions),
      exerciseAvailability,
      const DeepCollectionEquality().hash(weekSteps),
      const DeepCollectionEquality().hash(weekSleep),
      fetchedAt,
      fromCache);

  @override
  String toString() {
    return 'HealthSnapshot(date: $date, timezone: $timezone, steps: $steps, distance: $distance, activeCalories: $activeCalories, totalCalories: $totalCalories, sleep: $sleep, restingHeartRate: $restingHeartRate, weight: $weight, bodyFat: $bodyFat, bmr: $bmr, exerciseSessions: $exerciseSessions, exerciseAvailability: $exerciseAvailability, weekSteps: $weekSteps, weekSleep: $weekSleep, fetchedAt: $fetchedAt, fromCache: $fromCache)';
  }
}

/// @nodoc
abstract mixin class $HealthSnapshotCopyWith<$Res> {
  factory $HealthSnapshotCopyWith(
          HealthSnapshot value, $Res Function(HealthSnapshot) _then) =
      _$HealthSnapshotCopyWithImpl;
  @useResult
  $Res call(
      {String date,
      String timezone,
      HealthMetric steps,
      HealthMetric distance,
      HealthMetric activeCalories,
      HealthMetric totalCalories,
      HealthMetric sleep,
      HealthMetric restingHeartRate,
      HealthMetric weight,
      HealthMetric bodyFat,
      HealthMetric bmr,
      List<HealthExerciseSession> exerciseSessions,
      HealthAvailability exerciseAvailability,
      List<double?> weekSteps,
      List<double?> weekSleep,
      String fetchedAt,
      bool fromCache});

  $HealthMetricCopyWith<$Res> get steps;
  $HealthMetricCopyWith<$Res> get distance;
  $HealthMetricCopyWith<$Res> get activeCalories;
  $HealthMetricCopyWith<$Res> get totalCalories;
  $HealthMetricCopyWith<$Res> get sleep;
  $HealthMetricCopyWith<$Res> get restingHeartRate;
  $HealthMetricCopyWith<$Res> get weight;
  $HealthMetricCopyWith<$Res> get bodyFat;
  $HealthMetricCopyWith<$Res> get bmr;
}

/// @nodoc
class _$HealthSnapshotCopyWithImpl<$Res>
    implements $HealthSnapshotCopyWith<$Res> {
  _$HealthSnapshotCopyWithImpl(this._self, this._then);

  final HealthSnapshot _self;
  final $Res Function(HealthSnapshot) _then;

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? timezone = null,
    Object? steps = null,
    Object? distance = null,
    Object? activeCalories = null,
    Object? totalCalories = null,
    Object? sleep = null,
    Object? restingHeartRate = null,
    Object? weight = null,
    Object? bodyFat = null,
    Object? bmr = null,
    Object? exerciseSessions = null,
    Object? exerciseAvailability = null,
    Object? weekSteps = null,
    Object? weekSleep = null,
    Object? fetchedAt = null,
    Object? fromCache = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      steps: null == steps
          ? _self.steps
          : steps // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      distance: null == distance
          ? _self.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      activeCalories: null == activeCalories
          ? _self.activeCalories
          : activeCalories // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      totalCalories: null == totalCalories
          ? _self.totalCalories
          : totalCalories // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      sleep: null == sleep
          ? _self.sleep
          : sleep // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      restingHeartRate: null == restingHeartRate
          ? _self.restingHeartRate
          : restingHeartRate // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      weight: null == weight
          ? _self.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      bodyFat: null == bodyFat
          ? _self.bodyFat
          : bodyFat // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      bmr: null == bmr
          ? _self.bmr
          : bmr // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      exerciseSessions: null == exerciseSessions
          ? _self.exerciseSessions
          : exerciseSessions // ignore: cast_nullable_to_non_nullable
              as List<HealthExerciseSession>,
      exerciseAvailability: null == exerciseAvailability
          ? _self.exerciseAvailability
          : exerciseAvailability // ignore: cast_nullable_to_non_nullable
              as HealthAvailability,
      weekSteps: null == weekSteps
          ? _self.weekSteps
          : weekSteps // ignore: cast_nullable_to_non_nullable
              as List<double?>,
      weekSleep: null == weekSleep
          ? _self.weekSleep
          : weekSleep // ignore: cast_nullable_to_non_nullable
              as List<double?>,
      fetchedAt: null == fetchedAt
          ? _self.fetchedAt
          : fetchedAt // ignore: cast_nullable_to_non_nullable
              as String,
      fromCache: null == fromCache
          ? _self.fromCache
          : fromCache // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get steps {
    return $HealthMetricCopyWith<$Res>(_self.steps, (value) {
      return _then(_self.copyWith(steps: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get distance {
    return $HealthMetricCopyWith<$Res>(_self.distance, (value) {
      return _then(_self.copyWith(distance: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get activeCalories {
    return $HealthMetricCopyWith<$Res>(_self.activeCalories, (value) {
      return _then(_self.copyWith(activeCalories: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get totalCalories {
    return $HealthMetricCopyWith<$Res>(_self.totalCalories, (value) {
      return _then(_self.copyWith(totalCalories: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get sleep {
    return $HealthMetricCopyWith<$Res>(_self.sleep, (value) {
      return _then(_self.copyWith(sleep: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get restingHeartRate {
    return $HealthMetricCopyWith<$Res>(_self.restingHeartRate, (value) {
      return _then(_self.copyWith(restingHeartRate: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get weight {
    return $HealthMetricCopyWith<$Res>(_self.weight, (value) {
      return _then(_self.copyWith(weight: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get bodyFat {
    return $HealthMetricCopyWith<$Res>(_self.bodyFat, (value) {
      return _then(_self.copyWith(bodyFat: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get bmr {
    return $HealthMetricCopyWith<$Res>(_self.bmr, (value) {
      return _then(_self.copyWith(bmr: value));
    });
  }
}

/// Adds pattern-matching-related methods to [HealthSnapshot].
extension HealthSnapshotPatterns on HealthSnapshot {
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
    TResult Function(_HealthSnapshot value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthSnapshot() when $default != null:
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
    TResult Function(_HealthSnapshot value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthSnapshot():
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
    TResult? Function(_HealthSnapshot value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthSnapshot() when $default != null:
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
            String timezone,
            HealthMetric steps,
            HealthMetric distance,
            HealthMetric activeCalories,
            HealthMetric totalCalories,
            HealthMetric sleep,
            HealthMetric restingHeartRate,
            HealthMetric weight,
            HealthMetric bodyFat,
            HealthMetric bmr,
            List<HealthExerciseSession> exerciseSessions,
            HealthAvailability exerciseAvailability,
            List<double?> weekSteps,
            List<double?> weekSleep,
            String fetchedAt,
            bool fromCache)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthSnapshot() when $default != null:
        return $default(
            _that.date,
            _that.timezone,
            _that.steps,
            _that.distance,
            _that.activeCalories,
            _that.totalCalories,
            _that.sleep,
            _that.restingHeartRate,
            _that.weight,
            _that.bodyFat,
            _that.bmr,
            _that.exerciseSessions,
            _that.exerciseAvailability,
            _that.weekSteps,
            _that.weekSleep,
            _that.fetchedAt,
            _that.fromCache);
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
            String timezone,
            HealthMetric steps,
            HealthMetric distance,
            HealthMetric activeCalories,
            HealthMetric totalCalories,
            HealthMetric sleep,
            HealthMetric restingHeartRate,
            HealthMetric weight,
            HealthMetric bodyFat,
            HealthMetric bmr,
            List<HealthExerciseSession> exerciseSessions,
            HealthAvailability exerciseAvailability,
            List<double?> weekSteps,
            List<double?> weekSleep,
            String fetchedAt,
            bool fromCache)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthSnapshot():
        return $default(
            _that.date,
            _that.timezone,
            _that.steps,
            _that.distance,
            _that.activeCalories,
            _that.totalCalories,
            _that.sleep,
            _that.restingHeartRate,
            _that.weight,
            _that.bodyFat,
            _that.bmr,
            _that.exerciseSessions,
            _that.exerciseAvailability,
            _that.weekSteps,
            _that.weekSleep,
            _that.fetchedAt,
            _that.fromCache);
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
            String timezone,
            HealthMetric steps,
            HealthMetric distance,
            HealthMetric activeCalories,
            HealthMetric totalCalories,
            HealthMetric sleep,
            HealthMetric restingHeartRate,
            HealthMetric weight,
            HealthMetric bodyFat,
            HealthMetric bmr,
            List<HealthExerciseSession> exerciseSessions,
            HealthAvailability exerciseAvailability,
            List<double?> weekSteps,
            List<double?> weekSleep,
            String fetchedAt,
            bool fromCache)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthSnapshot() when $default != null:
        return $default(
            _that.date,
            _that.timezone,
            _that.steps,
            _that.distance,
            _that.activeCalories,
            _that.totalCalories,
            _that.sleep,
            _that.restingHeartRate,
            _that.weight,
            _that.bodyFat,
            _that.bmr,
            _that.exerciseSessions,
            _that.exerciseAvailability,
            _that.weekSteps,
            _that.weekSleep,
            _that.fetchedAt,
            _that.fromCache);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HealthSnapshot extends HealthSnapshot {
  const _HealthSnapshot(
      {required this.date,
      required this.timezone,
      required this.steps,
      required this.distance,
      required this.activeCalories,
      required this.totalCalories,
      required this.sleep,
      required this.restingHeartRate,
      required this.weight,
      required this.bodyFat,
      required this.bmr,
      final List<HealthExerciseSession> exerciseSessions =
          const <HealthExerciseSession>[],
      required this.exerciseAvailability,
      final List<double?> weekSteps = const <double?>[],
      final List<double?> weekSleep = const <double?>[],
      required this.fetchedAt,
      this.fromCache = false})
      : _exerciseSessions = exerciseSessions,
        _weekSteps = weekSteps,
        _weekSleep = weekSleep,
        super._();
  factory _HealthSnapshot.fromJson(Map<String, dynamic> json) =>
      _$HealthSnapshotFromJson(json);

  /// Local date yyyy-mm-dd in the user's calendar.
  @override
  final String date;
  @override
  final String timezone;
  @override
  final HealthMetric steps;
  @override
  final HealthMetric distance;
  @override
  final HealthMetric activeCalories;
  @override
  final HealthMetric totalCalories;
  @override
  final HealthMetric sleep;
  @override
  final HealthMetric restingHeartRate;
  @override
  final HealthMetric weight;
  @override
  final HealthMetric bodyFat;
  @override
  final HealthMetric bmr;
  final List<HealthExerciseSession> _exerciseSessions;
  @override
  @JsonKey()
  List<HealthExerciseSession> get exerciseSessions {
    if (_exerciseSessions is EqualUnmodifiableListView)
      return _exerciseSessions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exerciseSessions);
  }

  /// Exercise-session availability (the list alone cannot say "denied").
  @override
  final HealthAvailability exerciseAvailability;

  /// Steps per local day for the current week, Monday first; null = no
  /// data or not permitted that day.
  final List<double?> _weekSteps;

  /// Steps per local day for the current week, Monday first; null = no
  /// data or not permitted that day.
  @override
  @JsonKey()
  List<double?> get weekSteps {
    if (_weekSteps is EqualUnmodifiableListView) return _weekSteps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weekSteps);
  }

  /// Sleep minutes per local night for the current week, Monday first.
  final List<double?> _weekSleep;

  /// Sleep minutes per local night for the current week, Monday first.
  @override
  @JsonKey()
  List<double?> get weekSleep {
    if (_weekSleep is EqualUnmodifiableListView) return _weekSleep;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weekSleep);
  }

  @override
  final String fetchedAt;
  @override
  @JsonKey()
  final bool fromCache;

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HealthSnapshotCopyWith<_HealthSnapshot> get copyWith =>
      __$HealthSnapshotCopyWithImpl<_HealthSnapshot>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HealthSnapshotToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HealthSnapshot &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.steps, steps) || other.steps == steps) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.activeCalories, activeCalories) ||
                other.activeCalories == activeCalories) &&
            (identical(other.totalCalories, totalCalories) ||
                other.totalCalories == totalCalories) &&
            (identical(other.sleep, sleep) || other.sleep == sleep) &&
            (identical(other.restingHeartRate, restingHeartRate) ||
                other.restingHeartRate == restingHeartRate) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            (identical(other.bodyFat, bodyFat) || other.bodyFat == bodyFat) &&
            (identical(other.bmr, bmr) || other.bmr == bmr) &&
            const DeepCollectionEquality()
                .equals(other._exerciseSessions, _exerciseSessions) &&
            (identical(other.exerciseAvailability, exerciseAvailability) ||
                other.exerciseAvailability == exerciseAvailability) &&
            const DeepCollectionEquality()
                .equals(other._weekSteps, _weekSteps) &&
            const DeepCollectionEquality()
                .equals(other._weekSleep, _weekSleep) &&
            (identical(other.fetchedAt, fetchedAt) ||
                other.fetchedAt == fetchedAt) &&
            (identical(other.fromCache, fromCache) ||
                other.fromCache == fromCache));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      date,
      timezone,
      steps,
      distance,
      activeCalories,
      totalCalories,
      sleep,
      restingHeartRate,
      weight,
      bodyFat,
      bmr,
      const DeepCollectionEquality().hash(_exerciseSessions),
      exerciseAvailability,
      const DeepCollectionEquality().hash(_weekSteps),
      const DeepCollectionEquality().hash(_weekSleep),
      fetchedAt,
      fromCache);

  @override
  String toString() {
    return 'HealthSnapshot(date: $date, timezone: $timezone, steps: $steps, distance: $distance, activeCalories: $activeCalories, totalCalories: $totalCalories, sleep: $sleep, restingHeartRate: $restingHeartRate, weight: $weight, bodyFat: $bodyFat, bmr: $bmr, exerciseSessions: $exerciseSessions, exerciseAvailability: $exerciseAvailability, weekSteps: $weekSteps, weekSleep: $weekSleep, fetchedAt: $fetchedAt, fromCache: $fromCache)';
  }
}

/// @nodoc
abstract mixin class _$HealthSnapshotCopyWith<$Res>
    implements $HealthSnapshotCopyWith<$Res> {
  factory _$HealthSnapshotCopyWith(
          _HealthSnapshot value, $Res Function(_HealthSnapshot) _then) =
      __$HealthSnapshotCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String date,
      String timezone,
      HealthMetric steps,
      HealthMetric distance,
      HealthMetric activeCalories,
      HealthMetric totalCalories,
      HealthMetric sleep,
      HealthMetric restingHeartRate,
      HealthMetric weight,
      HealthMetric bodyFat,
      HealthMetric bmr,
      List<HealthExerciseSession> exerciseSessions,
      HealthAvailability exerciseAvailability,
      List<double?> weekSteps,
      List<double?> weekSleep,
      String fetchedAt,
      bool fromCache});

  @override
  $HealthMetricCopyWith<$Res> get steps;
  @override
  $HealthMetricCopyWith<$Res> get distance;
  @override
  $HealthMetricCopyWith<$Res> get activeCalories;
  @override
  $HealthMetricCopyWith<$Res> get totalCalories;
  @override
  $HealthMetricCopyWith<$Res> get sleep;
  @override
  $HealthMetricCopyWith<$Res> get restingHeartRate;
  @override
  $HealthMetricCopyWith<$Res> get weight;
  @override
  $HealthMetricCopyWith<$Res> get bodyFat;
  @override
  $HealthMetricCopyWith<$Res> get bmr;
}

/// @nodoc
class __$HealthSnapshotCopyWithImpl<$Res>
    implements _$HealthSnapshotCopyWith<$Res> {
  __$HealthSnapshotCopyWithImpl(this._self, this._then);

  final _HealthSnapshot _self;
  final $Res Function(_HealthSnapshot) _then;

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? timezone = null,
    Object? steps = null,
    Object? distance = null,
    Object? activeCalories = null,
    Object? totalCalories = null,
    Object? sleep = null,
    Object? restingHeartRate = null,
    Object? weight = null,
    Object? bodyFat = null,
    Object? bmr = null,
    Object? exerciseSessions = null,
    Object? exerciseAvailability = null,
    Object? weekSteps = null,
    Object? weekSleep = null,
    Object? fetchedAt = null,
    Object? fromCache = null,
  }) {
    return _then(_HealthSnapshot(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      steps: null == steps
          ? _self.steps
          : steps // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      distance: null == distance
          ? _self.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      activeCalories: null == activeCalories
          ? _self.activeCalories
          : activeCalories // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      totalCalories: null == totalCalories
          ? _self.totalCalories
          : totalCalories // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      sleep: null == sleep
          ? _self.sleep
          : sleep // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      restingHeartRate: null == restingHeartRate
          ? _self.restingHeartRate
          : restingHeartRate // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      weight: null == weight
          ? _self.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      bodyFat: null == bodyFat
          ? _self.bodyFat
          : bodyFat // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      bmr: null == bmr
          ? _self.bmr
          : bmr // ignore: cast_nullable_to_non_nullable
              as HealthMetric,
      exerciseSessions: null == exerciseSessions
          ? _self._exerciseSessions
          : exerciseSessions // ignore: cast_nullable_to_non_nullable
              as List<HealthExerciseSession>,
      exerciseAvailability: null == exerciseAvailability
          ? _self.exerciseAvailability
          : exerciseAvailability // ignore: cast_nullable_to_non_nullable
              as HealthAvailability,
      weekSteps: null == weekSteps
          ? _self._weekSteps
          : weekSteps // ignore: cast_nullable_to_non_nullable
              as List<double?>,
      weekSleep: null == weekSleep
          ? _self._weekSleep
          : weekSleep // ignore: cast_nullable_to_non_nullable
              as List<double?>,
      fetchedAt: null == fetchedAt
          ? _self.fetchedAt
          : fetchedAt // ignore: cast_nullable_to_non_nullable
              as String,
      fromCache: null == fromCache
          ? _self.fromCache
          : fromCache // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get steps {
    return $HealthMetricCopyWith<$Res>(_self.steps, (value) {
      return _then(_self.copyWith(steps: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get distance {
    return $HealthMetricCopyWith<$Res>(_self.distance, (value) {
      return _then(_self.copyWith(distance: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get activeCalories {
    return $HealthMetricCopyWith<$Res>(_self.activeCalories, (value) {
      return _then(_self.copyWith(activeCalories: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get totalCalories {
    return $HealthMetricCopyWith<$Res>(_self.totalCalories, (value) {
      return _then(_self.copyWith(totalCalories: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get sleep {
    return $HealthMetricCopyWith<$Res>(_self.sleep, (value) {
      return _then(_self.copyWith(sleep: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get restingHeartRate {
    return $HealthMetricCopyWith<$Res>(_self.restingHeartRate, (value) {
      return _then(_self.copyWith(restingHeartRate: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get weight {
    return $HealthMetricCopyWith<$Res>(_self.weight, (value) {
      return _then(_self.copyWith(weight: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get bodyFat {
    return $HealthMetricCopyWith<$Res>(_self.bodyFat, (value) {
      return _then(_self.copyWith(bodyFat: value));
    });
  }

  /// Create a copy of HealthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HealthMetricCopyWith<$Res> get bmr {
    return $HealthMetricCopyWith<$Res>(_self.bmr, (value) {
      return _then(_self.copyWith(bmr: value));
    });
  }
}

/// @nodoc
mixin _$HealthConnectionState {
  HealthSdkStatus get sdk;

  /// Metrics whose read permission is granted right now.
  Set<HealthMetricKind> get granted;

  /// Create a copy of HealthConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HealthConnectionStateCopyWith<HealthConnectionState> get copyWith =>
      _$HealthConnectionStateCopyWithImpl<HealthConnectionState>(
          this as HealthConnectionState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HealthConnectionState &&
            (identical(other.sdk, sdk) || other.sdk == sdk) &&
            const DeepCollectionEquality().equals(other.granted, granted));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, sdk, const DeepCollectionEquality().hash(granted));

  @override
  String toString() {
    return 'HealthConnectionState(sdk: $sdk, granted: $granted)';
  }
}

/// @nodoc
abstract mixin class $HealthConnectionStateCopyWith<$Res> {
  factory $HealthConnectionStateCopyWith(HealthConnectionState value,
          $Res Function(HealthConnectionState) _then) =
      _$HealthConnectionStateCopyWithImpl;
  @useResult
  $Res call({HealthSdkStatus sdk, Set<HealthMetricKind> granted});
}

/// @nodoc
class _$HealthConnectionStateCopyWithImpl<$Res>
    implements $HealthConnectionStateCopyWith<$Res> {
  _$HealthConnectionStateCopyWithImpl(this._self, this._then);

  final HealthConnectionState _self;
  final $Res Function(HealthConnectionState) _then;

  /// Create a copy of HealthConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sdk = null,
    Object? granted = null,
  }) {
    return _then(_self.copyWith(
      sdk: null == sdk
          ? _self.sdk
          : sdk // ignore: cast_nullable_to_non_nullable
              as HealthSdkStatus,
      granted: null == granted
          ? _self.granted
          : granted // ignore: cast_nullable_to_non_nullable
              as Set<HealthMetricKind>,
    ));
  }
}

/// Adds pattern-matching-related methods to [HealthConnectionState].
extension HealthConnectionStatePatterns on HealthConnectionState {
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
    TResult Function(_HealthConnectionState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthConnectionState() when $default != null:
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
    TResult Function(_HealthConnectionState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthConnectionState():
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
    TResult? Function(_HealthConnectionState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthConnectionState() when $default != null:
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
    TResult Function(HealthSdkStatus sdk, Set<HealthMetricKind> granted)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthConnectionState() when $default != null:
        return $default(_that.sdk, _that.granted);
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
    TResult Function(HealthSdkStatus sdk, Set<HealthMetricKind> granted)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthConnectionState():
        return $default(_that.sdk, _that.granted);
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
    TResult? Function(HealthSdkStatus sdk, Set<HealthMetricKind> granted)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthConnectionState() when $default != null:
        return $default(_that.sdk, _that.granted);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _HealthConnectionState extends HealthConnectionState {
  const _HealthConnectionState(
      {required this.sdk, required final Set<HealthMetricKind> granted})
      : _granted = granted,
        super._();

  @override
  final HealthSdkStatus sdk;

  /// Metrics whose read permission is granted right now.
  final Set<HealthMetricKind> _granted;

  /// Metrics whose read permission is granted right now.
  @override
  Set<HealthMetricKind> get granted {
    if (_granted is EqualUnmodifiableSetView) return _granted;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_granted);
  }

  /// Create a copy of HealthConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HealthConnectionStateCopyWith<_HealthConnectionState> get copyWith =>
      __$HealthConnectionStateCopyWithImpl<_HealthConnectionState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HealthConnectionState &&
            (identical(other.sdk, sdk) || other.sdk == sdk) &&
            const DeepCollectionEquality().equals(other._granted, _granted));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, sdk, const DeepCollectionEquality().hash(_granted));

  @override
  String toString() {
    return 'HealthConnectionState(sdk: $sdk, granted: $granted)';
  }
}

/// @nodoc
abstract mixin class _$HealthConnectionStateCopyWith<$Res>
    implements $HealthConnectionStateCopyWith<$Res> {
  factory _$HealthConnectionStateCopyWith(_HealthConnectionState value,
          $Res Function(_HealthConnectionState) _then) =
      __$HealthConnectionStateCopyWithImpl;
  @override
  @useResult
  $Res call({HealthSdkStatus sdk, Set<HealthMetricKind> granted});
}

/// @nodoc
class __$HealthConnectionStateCopyWithImpl<$Res>
    implements _$HealthConnectionStateCopyWith<$Res> {
  __$HealthConnectionStateCopyWithImpl(this._self, this._then);

  final _HealthConnectionState _self;
  final $Res Function(_HealthConnectionState) _then;

  /// Create a copy of HealthConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sdk = null,
    Object? granted = null,
  }) {
    return _then(_HealthConnectionState(
      sdk: null == sdk
          ? _self.sdk
          : sdk // ignore: cast_nullable_to_non_nullable
              as HealthSdkStatus,
      granted: null == granted
          ? _self._granted
          : granted // ignore: cast_nullable_to_non_nullable
              as Set<HealthMetricKind>,
    ));
  }
}

// dart format on
