// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthState {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is AuthState);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AuthState()';
  }
}

/// @nodoc
class $AuthStateCopyWith<$Res> {
  $AuthStateCopyWith(AuthState _, $Res Function(AuthState) __);
}

/// Adds pattern-matching-related methods to [AuthState].
extension AuthStatePatterns on AuthState {
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
    TResult Function(AuthUnknown value)? unknown,
    TResult Function(AuthSignedOut value)? signedOut,
    TResult Function(AuthSignedIn value)? signedIn,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case AuthUnknown() when unknown != null:
        return unknown(_that);
      case AuthSignedOut() when signedOut != null:
        return signedOut(_that);
      case AuthSignedIn() when signedIn != null:
        return signedIn(_that);
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
    required TResult Function(AuthUnknown value) unknown,
    required TResult Function(AuthSignedOut value) signedOut,
    required TResult Function(AuthSignedIn value) signedIn,
  }) {
    final _that = this;
    switch (_that) {
      case AuthUnknown():
        return unknown(_that);
      case AuthSignedOut():
        return signedOut(_that);
      case AuthSignedIn():
        return signedIn(_that);
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
    TResult? Function(AuthUnknown value)? unknown,
    TResult? Function(AuthSignedOut value)? signedOut,
    TResult? Function(AuthSignedIn value)? signedIn,
  }) {
    final _that = this;
    switch (_that) {
      case AuthUnknown() when unknown != null:
        return unknown(_that);
      case AuthSignedOut() when signedOut != null:
        return signedOut(_that);
      case AuthSignedIn() when signedIn != null:
        return signedIn(_that);
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
    TResult Function()? unknown,
    TResult Function()? signedOut,
    TResult Function(UserProfile profile, bool isNewUser)? signedIn,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case AuthUnknown() when unknown != null:
        return unknown();
      case AuthSignedOut() when signedOut != null:
        return signedOut();
      case AuthSignedIn() when signedIn != null:
        return signedIn(_that.profile, _that.isNewUser);
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
    required TResult Function() unknown,
    required TResult Function() signedOut,
    required TResult Function(UserProfile profile, bool isNewUser) signedIn,
  }) {
    final _that = this;
    switch (_that) {
      case AuthUnknown():
        return unknown();
      case AuthSignedOut():
        return signedOut();
      case AuthSignedIn():
        return signedIn(_that.profile, _that.isNewUser);
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
    TResult? Function()? unknown,
    TResult? Function()? signedOut,
    TResult? Function(UserProfile profile, bool isNewUser)? signedIn,
  }) {
    final _that = this;
    switch (_that) {
      case AuthUnknown() when unknown != null:
        return unknown();
      case AuthSignedOut() when signedOut != null:
        return signedOut();
      case AuthSignedIn() when signedIn != null:
        return signedIn(_that.profile, _that.isNewUser);
      case _:
        return null;
    }
  }
}

/// @nodoc

class AuthUnknown implements AuthState {
  const AuthUnknown();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is AuthUnknown);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AuthState.unknown()';
  }
}

/// @nodoc

class AuthSignedOut implements AuthState {
  const AuthSignedOut();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is AuthSignedOut);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AuthState.signedOut()';
  }
}

/// @nodoc

class AuthSignedIn implements AuthState {
  const AuthSignedIn(this.profile, {this.isNewUser = false});

  final UserProfile profile;
  @JsonKey()
  final bool isNewUser;

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AuthSignedInCopyWith<AuthSignedIn> get copyWith =>
      _$AuthSignedInCopyWithImpl<AuthSignedIn>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AuthSignedIn &&
            (identical(other.profile, profile) || other.profile == profile) &&
            (identical(other.isNewUser, isNewUser) ||
                other.isNewUser == isNewUser));
  }

  @override
  int get hashCode => Object.hash(runtimeType, profile, isNewUser);

  @override
  String toString() {
    return 'AuthState.signedIn(profile: $profile, isNewUser: $isNewUser)';
  }
}

/// @nodoc
abstract mixin class $AuthSignedInCopyWith<$Res>
    implements $AuthStateCopyWith<$Res> {
  factory $AuthSignedInCopyWith(
          AuthSignedIn value, $Res Function(AuthSignedIn) _then) =
      _$AuthSignedInCopyWithImpl;
  @useResult
  $Res call({UserProfile profile, bool isNewUser});

  $UserProfileCopyWith<$Res> get profile;
}

/// @nodoc
class _$AuthSignedInCopyWithImpl<$Res> implements $AuthSignedInCopyWith<$Res> {
  _$AuthSignedInCopyWithImpl(this._self, this._then);

  final AuthSignedIn _self;
  final $Res Function(AuthSignedIn) _then;

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? profile = null,
    Object? isNewUser = null,
  }) {
    return _then(AuthSignedIn(
      null == profile
          ? _self.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as UserProfile,
      isNewUser: null == isNewUser
          ? _self.isNewUser
          : isNewUser // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserProfileCopyWith<$Res> get profile {
    return $UserProfileCopyWith<$Res>(_self.profile, (value) {
      return _then(_self.copyWith(profile: value));
    });
  }
}

// dart format on
