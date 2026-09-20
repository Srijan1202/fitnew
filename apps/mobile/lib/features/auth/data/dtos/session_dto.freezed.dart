// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateSessionResponse {
  UserProfile get user;
  bool get isNewUser;

  /// Create a copy of CreateSessionResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CreateSessionResponseCopyWith<CreateSessionResponse> get copyWith =>
      _$CreateSessionResponseCopyWithImpl<CreateSessionResponse>(
          this as CreateSessionResponse, _$identity);

  /// Serializes this CreateSessionResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CreateSessionResponse &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.isNewUser, isNewUser) ||
                other.isNewUser == isNewUser));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, user, isNewUser);

  @override
  String toString() {
    return 'CreateSessionResponse(user: $user, isNewUser: $isNewUser)';
  }
}

/// @nodoc
abstract mixin class $CreateSessionResponseCopyWith<$Res> {
  factory $CreateSessionResponseCopyWith(CreateSessionResponse value,
          $Res Function(CreateSessionResponse) _then) =
      _$CreateSessionResponseCopyWithImpl;
  @useResult
  $Res call({UserProfile user, bool isNewUser});

  $UserProfileCopyWith<$Res> get user;
}

/// @nodoc
class _$CreateSessionResponseCopyWithImpl<$Res>
    implements $CreateSessionResponseCopyWith<$Res> {
  _$CreateSessionResponseCopyWithImpl(this._self, this._then);

  final CreateSessionResponse _self;
  final $Res Function(CreateSessionResponse) _then;

  /// Create a copy of CreateSessionResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? isNewUser = null,
  }) {
    return _then(_self.copyWith(
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as UserProfile,
      isNewUser: null == isNewUser
          ? _self.isNewUser
          : isNewUser // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of CreateSessionResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserProfileCopyWith<$Res> get user {
    return $UserProfileCopyWith<$Res>(_self.user, (value) {
      return _then(_self.copyWith(user: value));
    });
  }
}

/// Adds pattern-matching-related methods to [CreateSessionResponse].
extension CreateSessionResponsePatterns on CreateSessionResponse {
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
    TResult Function(_CreateSessionResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CreateSessionResponse() when $default != null:
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
    TResult Function(_CreateSessionResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateSessionResponse():
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
    TResult? Function(_CreateSessionResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateSessionResponse() when $default != null:
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
    TResult Function(UserProfile user, bool isNewUser)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CreateSessionResponse() when $default != null:
        return $default(_that.user, _that.isNewUser);
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
    TResult Function(UserProfile user, bool isNewUser) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateSessionResponse():
        return $default(_that.user, _that.isNewUser);
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
    TResult? Function(UserProfile user, bool isNewUser)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateSessionResponse() when $default != null:
        return $default(_that.user, _that.isNewUser);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CreateSessionResponse implements CreateSessionResponse {
  const _CreateSessionResponse({required this.user, required this.isNewUser});
  factory _CreateSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionResponseFromJson(json);

  @override
  final UserProfile user;
  @override
  final bool isNewUser;

  /// Create a copy of CreateSessionResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CreateSessionResponseCopyWith<_CreateSessionResponse> get copyWith =>
      __$CreateSessionResponseCopyWithImpl<_CreateSessionResponse>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CreateSessionResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CreateSessionResponse &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.isNewUser, isNewUser) ||
                other.isNewUser == isNewUser));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, user, isNewUser);

  @override
  String toString() {
    return 'CreateSessionResponse(user: $user, isNewUser: $isNewUser)';
  }
}

/// @nodoc
abstract mixin class _$CreateSessionResponseCopyWith<$Res>
    implements $CreateSessionResponseCopyWith<$Res> {
  factory _$CreateSessionResponseCopyWith(_CreateSessionResponse value,
          $Res Function(_CreateSessionResponse) _then) =
      __$CreateSessionResponseCopyWithImpl;
  @override
  @useResult
  $Res call({UserProfile user, bool isNewUser});

  @override
  $UserProfileCopyWith<$Res> get user;
}

/// @nodoc
class __$CreateSessionResponseCopyWithImpl<$Res>
    implements _$CreateSessionResponseCopyWith<$Res> {
  __$CreateSessionResponseCopyWithImpl(this._self, this._then);

  final _CreateSessionResponse _self;
  final $Res Function(_CreateSessionResponse) _then;

  /// Create a copy of CreateSessionResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? user = null,
    Object? isNewUser = null,
  }) {
    return _then(_CreateSessionResponse(
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as UserProfile,
      isNewUser: null == isNewUser
          ? _self.isNewUser
          : isNewUser // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of CreateSessionResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserProfileCopyWith<$Res> get user {
    return $UserProfileCopyWith<$Res>(_self.user, (value) {
      return _then(_self.copyWith(user: value));
    });
  }
}

/// @nodoc
mixin _$CreateSessionRequest {
  String? get timezone;
  String? get locale;

  /// Create a copy of CreateSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CreateSessionRequestCopyWith<CreateSessionRequest> get copyWith =>
      _$CreateSessionRequestCopyWithImpl<CreateSessionRequest>(
          this as CreateSessionRequest, _$identity);

  /// Serializes this CreateSessionRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CreateSessionRequest &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.locale, locale) || other.locale == locale));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, timezone, locale);

  @override
  String toString() {
    return 'CreateSessionRequest(timezone: $timezone, locale: $locale)';
  }
}

/// @nodoc
abstract mixin class $CreateSessionRequestCopyWith<$Res> {
  factory $CreateSessionRequestCopyWith(CreateSessionRequest value,
          $Res Function(CreateSessionRequest) _then) =
      _$CreateSessionRequestCopyWithImpl;
  @useResult
  $Res call({String? timezone, String? locale});
}

/// @nodoc
class _$CreateSessionRequestCopyWithImpl<$Res>
    implements $CreateSessionRequestCopyWith<$Res> {
  _$CreateSessionRequestCopyWithImpl(this._self, this._then);

  final CreateSessionRequest _self;
  final $Res Function(CreateSessionRequest) _then;

  /// Create a copy of CreateSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timezone = freezed,
    Object? locale = freezed,
  }) {
    return _then(_self.copyWith(
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      locale: freezed == locale
          ? _self.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CreateSessionRequest].
extension CreateSessionRequestPatterns on CreateSessionRequest {
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
    TResult Function(_CreateSessionRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CreateSessionRequest() when $default != null:
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
    TResult Function(_CreateSessionRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateSessionRequest():
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
    TResult? Function(_CreateSessionRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateSessionRequest() when $default != null:
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
    TResult Function(String? timezone, String? locale)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CreateSessionRequest() when $default != null:
        return $default(_that.timezone, _that.locale);
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
    TResult Function(String? timezone, String? locale) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateSessionRequest():
        return $default(_that.timezone, _that.locale);
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
    TResult? Function(String? timezone, String? locale)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateSessionRequest() when $default != null:
        return $default(_that.timezone, _that.locale);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CreateSessionRequest implements CreateSessionRequest {
  const _CreateSessionRequest({this.timezone, this.locale});
  factory _CreateSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionRequestFromJson(json);

  @override
  final String? timezone;
  @override
  final String? locale;

  /// Create a copy of CreateSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CreateSessionRequestCopyWith<_CreateSessionRequest> get copyWith =>
      __$CreateSessionRequestCopyWithImpl<_CreateSessionRequest>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CreateSessionRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CreateSessionRequest &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.locale, locale) || other.locale == locale));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, timezone, locale);

  @override
  String toString() {
    return 'CreateSessionRequest(timezone: $timezone, locale: $locale)';
  }
}

/// @nodoc
abstract mixin class _$CreateSessionRequestCopyWith<$Res>
    implements $CreateSessionRequestCopyWith<$Res> {
  factory _$CreateSessionRequestCopyWith(_CreateSessionRequest value,
          $Res Function(_CreateSessionRequest) _then) =
      __$CreateSessionRequestCopyWithImpl;
  @override
  @useResult
  $Res call({String? timezone, String? locale});
}

/// @nodoc
class __$CreateSessionRequestCopyWithImpl<$Res>
    implements _$CreateSessionRequestCopyWith<$Res> {
  __$CreateSessionRequestCopyWithImpl(this._self, this._then);

  final _CreateSessionRequest _self;
  final $Res Function(_CreateSessionRequest) _then;

  /// Create a copy of CreateSessionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? timezone = freezed,
    Object? locale = freezed,
  }) {
    return _then(_CreateSessionRequest(
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      locale: freezed == locale
          ? _self.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
