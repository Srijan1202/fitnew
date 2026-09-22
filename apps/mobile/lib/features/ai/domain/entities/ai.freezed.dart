// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiStatus {
  bool get configured;
  String get provider;
  String? get model;
  List<String> get excludes;

  /// Create a copy of AiStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiStatusCopyWith<AiStatus> get copyWith =>
      _$AiStatusCopyWithImpl<AiStatus>(this as AiStatus, _$identity);

  /// Serializes this AiStatus to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiStatus &&
            (identical(other.configured, configured) ||
                other.configured == configured) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.model, model) || other.model == model) &&
            const DeepCollectionEquality().equals(other.excludes, excludes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, configured, provider, model,
      const DeepCollectionEquality().hash(excludes));

  @override
  String toString() {
    return 'AiStatus(configured: $configured, provider: $provider, model: $model, excludes: $excludes)';
  }
}

/// @nodoc
abstract mixin class $AiStatusCopyWith<$Res> {
  factory $AiStatusCopyWith(AiStatus value, $Res Function(AiStatus) _then) =
      _$AiStatusCopyWithImpl;
  @useResult
  $Res call(
      {bool configured, String provider, String? model, List<String> excludes});
}

/// @nodoc
class _$AiStatusCopyWithImpl<$Res> implements $AiStatusCopyWith<$Res> {
  _$AiStatusCopyWithImpl(this._self, this._then);

  final AiStatus _self;
  final $Res Function(AiStatus) _then;

  /// Create a copy of AiStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? configured = null,
    Object? provider = null,
    Object? model = freezed,
    Object? excludes = null,
  }) {
    return _then(_self.copyWith(
      configured: null == configured
          ? _self.configured
          : configured // ignore: cast_nullable_to_non_nullable
              as bool,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      model: freezed == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String?,
      excludes: null == excludes
          ? _self.excludes
          : excludes // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiStatus].
extension AiStatusPatterns on AiStatus {
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
    TResult Function(_AiStatus value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiStatus() when $default != null:
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
    TResult Function(_AiStatus value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiStatus():
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
    TResult? Function(_AiStatus value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiStatus() when $default != null:
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
    TResult Function(bool configured, String provider, String? model,
            List<String> excludes)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiStatus() when $default != null:
        return $default(
            _that.configured, _that.provider, _that.model, _that.excludes);
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
    TResult Function(bool configured, String provider, String? model,
            List<String> excludes)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiStatus():
        return $default(
            _that.configured, _that.provider, _that.model, _that.excludes);
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
    TResult? Function(bool configured, String provider, String? model,
            List<String> excludes)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiStatus() when $default != null:
        return $default(
            _that.configured, _that.provider, _that.model, _that.excludes);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiStatus implements AiStatus {
  const _AiStatus(
      {required this.configured,
      required this.provider,
      required this.model,
      final List<String> excludes = const <String>[]})
      : _excludes = excludes;
  factory _AiStatus.fromJson(Map<String, dynamic> json) =>
      _$AiStatusFromJson(json);

  @override
  final bool configured;
  @override
  final String provider;
  @override
  final String? model;
  final List<String> _excludes;
  @override
  @JsonKey()
  List<String> get excludes {
    if (_excludes is EqualUnmodifiableListView) return _excludes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_excludes);
  }

  /// Create a copy of AiStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiStatusCopyWith<_AiStatus> get copyWith =>
      __$AiStatusCopyWithImpl<_AiStatus>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiStatusToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiStatus &&
            (identical(other.configured, configured) ||
                other.configured == configured) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.model, model) || other.model == model) &&
            const DeepCollectionEquality().equals(other._excludes, _excludes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, configured, provider, model,
      const DeepCollectionEquality().hash(_excludes));

  @override
  String toString() {
    return 'AiStatus(configured: $configured, provider: $provider, model: $model, excludes: $excludes)';
  }
}

/// @nodoc
abstract mixin class _$AiStatusCopyWith<$Res>
    implements $AiStatusCopyWith<$Res> {
  factory _$AiStatusCopyWith(_AiStatus value, $Res Function(_AiStatus) _then) =
      __$AiStatusCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool configured, String provider, String? model, List<String> excludes});
}

/// @nodoc
class __$AiStatusCopyWithImpl<$Res> implements _$AiStatusCopyWith<$Res> {
  __$AiStatusCopyWithImpl(this._self, this._then);

  final _AiStatus _self;
  final $Res Function(_AiStatus) _then;

  /// Create a copy of AiStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? configured = null,
    Object? provider = null,
    Object? model = freezed,
    Object? excludes = null,
  }) {
    return _then(_AiStatus(
      configured: null == configured
          ? _self.configured
          : configured // ignore: cast_nullable_to_non_nullable
              as bool,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      model: freezed == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String?,
      excludes: null == excludes
          ? _self._excludes
          : excludes // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
mixin _$AiChatMessage {
  AiRole get role;
  String get content;

  /// Create a copy of AiChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiChatMessageCopyWith<AiChatMessage> get copyWith =>
      _$AiChatMessageCopyWithImpl<AiChatMessage>(
          this as AiChatMessage, _$identity);

  /// Serializes this AiChatMessage to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiChatMessage &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, role, content);

  @override
  String toString() {
    return 'AiChatMessage(role: $role, content: $content)';
  }
}

/// @nodoc
abstract mixin class $AiChatMessageCopyWith<$Res> {
  factory $AiChatMessageCopyWith(
          AiChatMessage value, $Res Function(AiChatMessage) _then) =
      _$AiChatMessageCopyWithImpl;
  @useResult
  $Res call({AiRole role, String content});
}

/// @nodoc
class _$AiChatMessageCopyWithImpl<$Res>
    implements $AiChatMessageCopyWith<$Res> {
  _$AiChatMessageCopyWithImpl(this._self, this._then);

  final AiChatMessage _self;
  final $Res Function(AiChatMessage) _then;

  /// Create a copy of AiChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? role = null,
    Object? content = null,
  }) {
    return _then(_self.copyWith(
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as AiRole,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiChatMessage].
extension AiChatMessagePatterns on AiChatMessage {
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
    TResult Function(_AiChatMessage value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiChatMessage() when $default != null:
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
    TResult Function(_AiChatMessage value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatMessage():
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
    TResult? Function(_AiChatMessage value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatMessage() when $default != null:
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
    TResult Function(AiRole role, String content)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiChatMessage() when $default != null:
        return $default(_that.role, _that.content);
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
    TResult Function(AiRole role, String content) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatMessage():
        return $default(_that.role, _that.content);
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
    TResult? Function(AiRole role, String content)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatMessage() when $default != null:
        return $default(_that.role, _that.content);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiChatMessage implements AiChatMessage {
  const _AiChatMessage({required this.role, required this.content});
  factory _AiChatMessage.fromJson(Map<String, dynamic> json) =>
      _$AiChatMessageFromJson(json);

  @override
  final AiRole role;
  @override
  final String content;

  /// Create a copy of AiChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiChatMessageCopyWith<_AiChatMessage> get copyWith =>
      __$AiChatMessageCopyWithImpl<_AiChatMessage>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiChatMessageToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiChatMessage &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, role, content);

  @override
  String toString() {
    return 'AiChatMessage(role: $role, content: $content)';
  }
}

/// @nodoc
abstract mixin class _$AiChatMessageCopyWith<$Res>
    implements $AiChatMessageCopyWith<$Res> {
  factory _$AiChatMessageCopyWith(
          _AiChatMessage value, $Res Function(_AiChatMessage) _then) =
      __$AiChatMessageCopyWithImpl;
  @override
  @useResult
  $Res call({AiRole role, String content});
}

/// @nodoc
class __$AiChatMessageCopyWithImpl<$Res>
    implements _$AiChatMessageCopyWith<$Res> {
  __$AiChatMessageCopyWithImpl(this._self, this._then);

  final _AiChatMessage _self;
  final $Res Function(_AiChatMessage) _then;

  /// Create a copy of AiChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? role = null,
    Object? content = null,
  }) {
    return _then(_AiChatMessage(
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as AiRole,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$AiChatRequest {
  String get message;
  List<AiChatMessage> get history;

  /// Create a copy of AiChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiChatRequestCopyWith<AiChatRequest> get copyWith =>
      _$AiChatRequestCopyWithImpl<AiChatRequest>(
          this as AiChatRequest, _$identity);

  /// Serializes this AiChatRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiChatRequest &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other.history, history));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, message, const DeepCollectionEquality().hash(history));

  @override
  String toString() {
    return 'AiChatRequest(message: $message, history: $history)';
  }
}

/// @nodoc
abstract mixin class $AiChatRequestCopyWith<$Res> {
  factory $AiChatRequestCopyWith(
          AiChatRequest value, $Res Function(AiChatRequest) _then) =
      _$AiChatRequestCopyWithImpl;
  @useResult
  $Res call({String message, List<AiChatMessage> history});
}

/// @nodoc
class _$AiChatRequestCopyWithImpl<$Res>
    implements $AiChatRequestCopyWith<$Res> {
  _$AiChatRequestCopyWithImpl(this._self, this._then);

  final AiChatRequest _self;
  final $Res Function(AiChatRequest) _then;

  /// Create a copy of AiChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? history = null,
  }) {
    return _then(_self.copyWith(
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      history: null == history
          ? _self.history
          : history // ignore: cast_nullable_to_non_nullable
              as List<AiChatMessage>,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiChatRequest].
extension AiChatRequestPatterns on AiChatRequest {
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
    TResult Function(_AiChatRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiChatRequest() when $default != null:
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
    TResult Function(_AiChatRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatRequest():
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
    TResult? Function(_AiChatRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatRequest() when $default != null:
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
    TResult Function(String message, List<AiChatMessage> history)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiChatRequest() when $default != null:
        return $default(_that.message, _that.history);
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
    TResult Function(String message, List<AiChatMessage> history) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatRequest():
        return $default(_that.message, _that.history);
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
    TResult? Function(String message, List<AiChatMessage> history)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatRequest() when $default != null:
        return $default(_that.message, _that.history);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiChatRequest implements AiChatRequest {
  const _AiChatRequest(
      {required this.message,
      final List<AiChatMessage> history = const <AiChatMessage>[]})
      : _history = history;
  factory _AiChatRequest.fromJson(Map<String, dynamic> json) =>
      _$AiChatRequestFromJson(json);

  @override
  final String message;
  final List<AiChatMessage> _history;
  @override
  @JsonKey()
  List<AiChatMessage> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

  /// Create a copy of AiChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiChatRequestCopyWith<_AiChatRequest> get copyWith =>
      __$AiChatRequestCopyWithImpl<_AiChatRequest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiChatRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiChatRequest &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other._history, _history));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, message, const DeepCollectionEquality().hash(_history));

  @override
  String toString() {
    return 'AiChatRequest(message: $message, history: $history)';
  }
}

/// @nodoc
abstract mixin class _$AiChatRequestCopyWith<$Res>
    implements $AiChatRequestCopyWith<$Res> {
  factory _$AiChatRequestCopyWith(
          _AiChatRequest value, $Res Function(_AiChatRequest) _then) =
      __$AiChatRequestCopyWithImpl;
  @override
  @useResult
  $Res call({String message, List<AiChatMessage> history});
}

/// @nodoc
class __$AiChatRequestCopyWithImpl<$Res>
    implements _$AiChatRequestCopyWith<$Res> {
  __$AiChatRequestCopyWithImpl(this._self, this._then);

  final _AiChatRequest _self;
  final $Res Function(_AiChatRequest) _then;

  /// Create a copy of AiChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? message = null,
    Object? history = null,
  }) {
    return _then(_AiChatRequest(
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      history: null == history
          ? _self._history
          : history // ignore: cast_nullable_to_non_nullable
              as List<AiChatMessage>,
    ));
  }
}

/// @nodoc
mixin _$AiAction {
  AiActionType get type;
  String get label;
  String? get exerciseId;
  String? get sessionId;
  AiProgramRequest? get programRequest;

  /// Create a copy of AiAction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiActionCopyWith<AiAction> get copyWith =>
      _$AiActionCopyWithImpl<AiAction>(this as AiAction, _$identity);

  /// Serializes this AiAction to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiAction &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.programRequest, programRequest) ||
                other.programRequest == programRequest));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, type, label, exerciseId, sessionId, programRequest);

  @override
  String toString() {
    return 'AiAction(type: $type, label: $label, exerciseId: $exerciseId, sessionId: $sessionId, programRequest: $programRequest)';
  }
}

/// @nodoc
abstract mixin class $AiActionCopyWith<$Res> {
  factory $AiActionCopyWith(AiAction value, $Res Function(AiAction) _then) =
      _$AiActionCopyWithImpl;
  @useResult
  $Res call(
      {AiActionType type,
      String label,
      String? exerciseId,
      String? sessionId,
      AiProgramRequest? programRequest});

  $AiProgramRequestCopyWith<$Res>? get programRequest;
}

/// @nodoc
class _$AiActionCopyWithImpl<$Res> implements $AiActionCopyWith<$Res> {
  _$AiActionCopyWithImpl(this._self, this._then);

  final AiAction _self;
  final $Res Function(AiAction) _then;

  /// Create a copy of AiAction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? label = null,
    Object? exerciseId = freezed,
    Object? sessionId = freezed,
    Object? programRequest = freezed,
  }) {
    return _then(_self.copyWith(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as AiActionType,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: freezed == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      sessionId: freezed == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      programRequest: freezed == programRequest
          ? _self.programRequest
          : programRequest // ignore: cast_nullable_to_non_nullable
              as AiProgramRequest?,
    ));
  }

  /// Create a copy of AiAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AiProgramRequestCopyWith<$Res>? get programRequest {
    if (_self.programRequest == null) {
      return null;
    }

    return $AiProgramRequestCopyWith<$Res>(_self.programRequest!, (value) {
      return _then(_self.copyWith(programRequest: value));
    });
  }
}

/// Adds pattern-matching-related methods to [AiAction].
extension AiActionPatterns on AiAction {
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
    TResult Function(_AiAction value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiAction() when $default != null:
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
    TResult Function(_AiAction value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiAction():
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
    TResult? Function(_AiAction value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiAction() when $default != null:
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
    TResult Function(AiActionType type, String label, String? exerciseId,
            String? sessionId, AiProgramRequest? programRequest)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiAction() when $default != null:
        return $default(_that.type, _that.label, _that.exerciseId,
            _that.sessionId, _that.programRequest);
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
    TResult Function(AiActionType type, String label, String? exerciseId,
            String? sessionId, AiProgramRequest? programRequest)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiAction():
        return $default(_that.type, _that.label, _that.exerciseId,
            _that.sessionId, _that.programRequest);
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
    TResult? Function(AiActionType type, String label, String? exerciseId,
            String? sessionId, AiProgramRequest? programRequest)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiAction() when $default != null:
        return $default(_that.type, _that.label, _that.exerciseId,
            _that.sessionId, _that.programRequest);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiAction implements AiAction {
  const _AiAction(
      {required this.type,
      required this.label,
      this.exerciseId = null,
      this.sessionId = null,
      this.programRequest = null});
  factory _AiAction.fromJson(Map<String, dynamic> json) =>
      _$AiActionFromJson(json);

  @override
  final AiActionType type;
  @override
  final String label;
  @override
  @JsonKey()
  final String? exerciseId;
  @override
  @JsonKey()
  final String? sessionId;
  @override
  @JsonKey()
  final AiProgramRequest? programRequest;

  /// Create a copy of AiAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiActionCopyWith<_AiAction> get copyWith =>
      __$AiActionCopyWithImpl<_AiAction>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiActionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiAction &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.programRequest, programRequest) ||
                other.programRequest == programRequest));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, type, label, exerciseId, sessionId, programRequest);

  @override
  String toString() {
    return 'AiAction(type: $type, label: $label, exerciseId: $exerciseId, sessionId: $sessionId, programRequest: $programRequest)';
  }
}

/// @nodoc
abstract mixin class _$AiActionCopyWith<$Res>
    implements $AiActionCopyWith<$Res> {
  factory _$AiActionCopyWith(_AiAction value, $Res Function(_AiAction) _then) =
      __$AiActionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {AiActionType type,
      String label,
      String? exerciseId,
      String? sessionId,
      AiProgramRequest? programRequest});

  @override
  $AiProgramRequestCopyWith<$Res>? get programRequest;
}

/// @nodoc
class __$AiActionCopyWithImpl<$Res> implements _$AiActionCopyWith<$Res> {
  __$AiActionCopyWithImpl(this._self, this._then);

  final _AiAction _self;
  final $Res Function(_AiAction) _then;

  /// Create a copy of AiAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? label = null,
    Object? exerciseId = freezed,
    Object? sessionId = freezed,
    Object? programRequest = freezed,
  }) {
    return _then(_AiAction(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as AiActionType,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: freezed == exerciseId
          ? _self.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String?,
      sessionId: freezed == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      programRequest: freezed == programRequest
          ? _self.programRequest
          : programRequest // ignore: cast_nullable_to_non_nullable
              as AiProgramRequest?,
    ));
  }

  /// Create a copy of AiAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AiProgramRequestCopyWith<$Res>? get programRequest {
    if (_self.programRequest == null) {
      return null;
    }

    return $AiProgramRequestCopyWith<$Res>(_self.programRequest!, (value) {
      return _then(_self.copyWith(programRequest: value));
    });
  }
}

/// @nodoc
mixin _$AiProgramRequest {
  int? get daysPerWeek;
  int? get preferredSessionMinutes;
  String? get template;
  List<MuscleGroup>? get emphasis;

  /// Create a copy of AiProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiProgramRequestCopyWith<AiProgramRequest> get copyWith =>
      _$AiProgramRequestCopyWithImpl<AiProgramRequest>(
          this as AiProgramRequest, _$identity);

  /// Serializes this AiProgramRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiProgramRequest &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            (identical(
                    other.preferredSessionMinutes, preferredSessionMinutes) ||
                other.preferredSessionMinutes == preferredSessionMinutes) &&
            (identical(other.template, template) ||
                other.template == template) &&
            const DeepCollectionEquality().equals(other.emphasis, emphasis));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      daysPerWeek,
      preferredSessionMinutes,
      template,
      const DeepCollectionEquality().hash(emphasis));

  @override
  String toString() {
    return 'AiProgramRequest(daysPerWeek: $daysPerWeek, preferredSessionMinutes: $preferredSessionMinutes, template: $template, emphasis: $emphasis)';
  }
}

/// @nodoc
abstract mixin class $AiProgramRequestCopyWith<$Res> {
  factory $AiProgramRequestCopyWith(
          AiProgramRequest value, $Res Function(AiProgramRequest) _then) =
      _$AiProgramRequestCopyWithImpl;
  @useResult
  $Res call(
      {int? daysPerWeek,
      int? preferredSessionMinutes,
      String? template,
      List<MuscleGroup>? emphasis});
}

/// @nodoc
class _$AiProgramRequestCopyWithImpl<$Res>
    implements $AiProgramRequestCopyWith<$Res> {
  _$AiProgramRequestCopyWithImpl(this._self, this._then);

  final AiProgramRequest _self;
  final $Res Function(AiProgramRequest) _then;

  /// Create a copy of AiProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? daysPerWeek = freezed,
    Object? preferredSessionMinutes = freezed,
    Object? template = freezed,
    Object? emphasis = freezed,
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
      template: freezed == template
          ? _self.template
          : template // ignore: cast_nullable_to_non_nullable
              as String?,
      emphasis: freezed == emphasis
          ? _self.emphasis
          : emphasis // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiProgramRequest].
extension AiProgramRequestPatterns on AiProgramRequest {
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
    TResult Function(_AiProgramRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiProgramRequest() when $default != null:
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
    TResult Function(_AiProgramRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiProgramRequest():
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
    TResult? Function(_AiProgramRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiProgramRequest() when $default != null:
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
    TResult Function(int? daysPerWeek, int? preferredSessionMinutes,
            String? template, List<MuscleGroup>? emphasis)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiProgramRequest() when $default != null:
        return $default(_that.daysPerWeek, _that.preferredSessionMinutes,
            _that.template, _that.emphasis);
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
    TResult Function(int? daysPerWeek, int? preferredSessionMinutes,
            String? template, List<MuscleGroup>? emphasis)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiProgramRequest():
        return $default(_that.daysPerWeek, _that.preferredSessionMinutes,
            _that.template, _that.emphasis);
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
    TResult? Function(int? daysPerWeek, int? preferredSessionMinutes,
            String? template, List<MuscleGroup>? emphasis)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiProgramRequest() when $default != null:
        return $default(_that.daysPerWeek, _that.preferredSessionMinutes,
            _that.template, _that.emphasis);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiProgramRequest implements AiProgramRequest {
  const _AiProgramRequest(
      {this.daysPerWeek = null,
      this.preferredSessionMinutes = null,
      this.template = null,
      final List<MuscleGroup>? emphasis = null})
      : _emphasis = emphasis;
  factory _AiProgramRequest.fromJson(Map<String, dynamic> json) =>
      _$AiProgramRequestFromJson(json);

  @override
  @JsonKey()
  final int? daysPerWeek;
  @override
  @JsonKey()
  final int? preferredSessionMinutes;
  @override
  @JsonKey()
  final String? template;
  final List<MuscleGroup>? _emphasis;
  @override
  @JsonKey()
  List<MuscleGroup>? get emphasis {
    final value = _emphasis;
    if (value == null) return null;
    if (_emphasis is EqualUnmodifiableListView) return _emphasis;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of AiProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiProgramRequestCopyWith<_AiProgramRequest> get copyWith =>
      __$AiProgramRequestCopyWithImpl<_AiProgramRequest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiProgramRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiProgramRequest &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            (identical(
                    other.preferredSessionMinutes, preferredSessionMinutes) ||
                other.preferredSessionMinutes == preferredSessionMinutes) &&
            (identical(other.template, template) ||
                other.template == template) &&
            const DeepCollectionEquality().equals(other._emphasis, _emphasis));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      daysPerWeek,
      preferredSessionMinutes,
      template,
      const DeepCollectionEquality().hash(_emphasis));

  @override
  String toString() {
    return 'AiProgramRequest(daysPerWeek: $daysPerWeek, preferredSessionMinutes: $preferredSessionMinutes, template: $template, emphasis: $emphasis)';
  }
}

/// @nodoc
abstract mixin class _$AiProgramRequestCopyWith<$Res>
    implements $AiProgramRequestCopyWith<$Res> {
  factory _$AiProgramRequestCopyWith(
          _AiProgramRequest value, $Res Function(_AiProgramRequest) _then) =
      __$AiProgramRequestCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int? daysPerWeek,
      int? preferredSessionMinutes,
      String? template,
      List<MuscleGroup>? emphasis});
}

/// @nodoc
class __$AiProgramRequestCopyWithImpl<$Res>
    implements _$AiProgramRequestCopyWith<$Res> {
  __$AiProgramRequestCopyWithImpl(this._self, this._then);

  final _AiProgramRequest _self;
  final $Res Function(_AiProgramRequest) _then;

  /// Create a copy of AiProgramRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? daysPerWeek = freezed,
    Object? preferredSessionMinutes = freezed,
    Object? template = freezed,
    Object? emphasis = freezed,
  }) {
    return _then(_AiProgramRequest(
      daysPerWeek: freezed == daysPerWeek
          ? _self.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int?,
      preferredSessionMinutes: freezed == preferredSessionMinutes
          ? _self.preferredSessionMinutes
          : preferredSessionMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      template: freezed == template
          ? _self.template
          : template // ignore: cast_nullable_to_non_nullable
              as String?,
      emphasis: freezed == emphasis
          ? _self._emphasis
          : emphasis // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>?,
    ));
  }
}

/// @nodoc
mixin _$AiChatResponse {
  String get text;
  List<AiAction> get actions;
  List<String> get toolsUsed;
  String get model;

  /// Create a copy of AiChatResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiChatResponseCopyWith<AiChatResponse> get copyWith =>
      _$AiChatResponseCopyWithImpl<AiChatResponse>(
          this as AiChatResponse, _$identity);

  /// Serializes this AiChatResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiChatResponse &&
            (identical(other.text, text) || other.text == text) &&
            const DeepCollectionEquality().equals(other.actions, actions) &&
            const DeepCollectionEquality().equals(other.toolsUsed, toolsUsed) &&
            (identical(other.model, model) || other.model == model));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      text,
      const DeepCollectionEquality().hash(actions),
      const DeepCollectionEquality().hash(toolsUsed),
      model);

  @override
  String toString() {
    return 'AiChatResponse(text: $text, actions: $actions, toolsUsed: $toolsUsed, model: $model)';
  }
}

/// @nodoc
abstract mixin class $AiChatResponseCopyWith<$Res> {
  factory $AiChatResponseCopyWith(
          AiChatResponse value, $Res Function(AiChatResponse) _then) =
      _$AiChatResponseCopyWithImpl;
  @useResult
  $Res call(
      {String text,
      List<AiAction> actions,
      List<String> toolsUsed,
      String model});
}

/// @nodoc
class _$AiChatResponseCopyWithImpl<$Res>
    implements $AiChatResponseCopyWith<$Res> {
  _$AiChatResponseCopyWithImpl(this._self, this._then);

  final AiChatResponse _self;
  final $Res Function(AiChatResponse) _then;

  /// Create a copy of AiChatResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? actions = null,
    Object? toolsUsed = null,
    Object? model = null,
  }) {
    return _then(_self.copyWith(
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      actions: null == actions
          ? _self.actions
          : actions // ignore: cast_nullable_to_non_nullable
              as List<AiAction>,
      toolsUsed: null == toolsUsed
          ? _self.toolsUsed
          : toolsUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiChatResponse].
extension AiChatResponsePatterns on AiChatResponse {
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
    TResult Function(_AiChatResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiChatResponse() when $default != null:
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
    TResult Function(_AiChatResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatResponse():
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
    TResult? Function(_AiChatResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatResponse() when $default != null:
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
    TResult Function(String text, List<AiAction> actions,
            List<String> toolsUsed, String model)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiChatResponse() when $default != null:
        return $default(
            _that.text, _that.actions, _that.toolsUsed, _that.model);
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
    TResult Function(String text, List<AiAction> actions,
            List<String> toolsUsed, String model)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatResponse():
        return $default(
            _that.text, _that.actions, _that.toolsUsed, _that.model);
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
    TResult? Function(String text, List<AiAction> actions,
            List<String> toolsUsed, String model)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiChatResponse() when $default != null:
        return $default(
            _that.text, _that.actions, _that.toolsUsed, _that.model);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiChatResponse implements AiChatResponse {
  const _AiChatResponse(
      {required this.text,
      final List<AiAction> actions = const <AiAction>[],
      final List<String> toolsUsed = const <String>[],
      required this.model})
      : _actions = actions,
        _toolsUsed = toolsUsed;
  factory _AiChatResponse.fromJson(Map<String, dynamic> json) =>
      _$AiChatResponseFromJson(json);

  @override
  final String text;
  final List<AiAction> _actions;
  @override
  @JsonKey()
  List<AiAction> get actions {
    if (_actions is EqualUnmodifiableListView) return _actions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_actions);
  }

  final List<String> _toolsUsed;
  @override
  @JsonKey()
  List<String> get toolsUsed {
    if (_toolsUsed is EqualUnmodifiableListView) return _toolsUsed;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_toolsUsed);
  }

  @override
  final String model;

  /// Create a copy of AiChatResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiChatResponseCopyWith<_AiChatResponse> get copyWith =>
      __$AiChatResponseCopyWithImpl<_AiChatResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiChatResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiChatResponse &&
            (identical(other.text, text) || other.text == text) &&
            const DeepCollectionEquality().equals(other._actions, _actions) &&
            const DeepCollectionEquality()
                .equals(other._toolsUsed, _toolsUsed) &&
            (identical(other.model, model) || other.model == model));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      text,
      const DeepCollectionEquality().hash(_actions),
      const DeepCollectionEquality().hash(_toolsUsed),
      model);

  @override
  String toString() {
    return 'AiChatResponse(text: $text, actions: $actions, toolsUsed: $toolsUsed, model: $model)';
  }
}

/// @nodoc
abstract mixin class _$AiChatResponseCopyWith<$Res>
    implements $AiChatResponseCopyWith<$Res> {
  factory _$AiChatResponseCopyWith(
          _AiChatResponse value, $Res Function(_AiChatResponse) _then) =
      __$AiChatResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String text,
      List<AiAction> actions,
      List<String> toolsUsed,
      String model});
}

/// @nodoc
class __$AiChatResponseCopyWithImpl<$Res>
    implements _$AiChatResponseCopyWith<$Res> {
  __$AiChatResponseCopyWithImpl(this._self, this._then);

  final _AiChatResponse _self;
  final $Res Function(_AiChatResponse) _then;

  /// Create a copy of AiChatResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? text = null,
    Object? actions = null,
    Object? toolsUsed = null,
    Object? model = null,
  }) {
    return _then(_AiChatResponse(
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      actions: null == actions
          ? _self._actions
          : actions // ignore: cast_nullable_to_non_nullable
              as List<AiAction>,
      toolsUsed: null == toolsUsed
          ? _self._toolsUsed
          : toolsUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
