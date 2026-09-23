// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'food.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FoodNutrition {
  NutritionBasis get basis;
  String get servingLabel;
  double? get servingGrams;
  double get kcalLow;
  double get kcalHigh;
  double get proteinLow;
  double get proteinHigh;
  double get carbLow;
  double get carbHigh;
  double get fatLow;
  double get fatHigh;
  double? get fibreLow;
  double? get fibreHigh;
  NutritionConfidence get confidence;

  /// Create a copy of FoodNutrition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FoodNutritionCopyWith<FoodNutrition> get copyWith =>
      _$FoodNutritionCopyWithImpl<FoodNutrition>(
          this as FoodNutrition, _$identity);

  /// Serializes this FoodNutrition to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FoodNutrition &&
            (identical(other.basis, basis) || other.basis == basis) &&
            (identical(other.servingLabel, servingLabel) ||
                other.servingLabel == servingLabel) &&
            (identical(other.servingGrams, servingGrams) ||
                other.servingGrams == servingGrams) &&
            (identical(other.kcalLow, kcalLow) || other.kcalLow == kcalLow) &&
            (identical(other.kcalHigh, kcalHigh) ||
                other.kcalHigh == kcalHigh) &&
            (identical(other.proteinLow, proteinLow) ||
                other.proteinLow == proteinLow) &&
            (identical(other.proteinHigh, proteinHigh) ||
                other.proteinHigh == proteinHigh) &&
            (identical(other.carbLow, carbLow) || other.carbLow == carbLow) &&
            (identical(other.carbHigh, carbHigh) ||
                other.carbHigh == carbHigh) &&
            (identical(other.fatLow, fatLow) || other.fatLow == fatLow) &&
            (identical(other.fatHigh, fatHigh) || other.fatHigh == fatHigh) &&
            (identical(other.fibreLow, fibreLow) ||
                other.fibreLow == fibreLow) &&
            (identical(other.fibreHigh, fibreHigh) ||
                other.fibreHigh == fibreHigh) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      basis,
      servingLabel,
      servingGrams,
      kcalLow,
      kcalHigh,
      proteinLow,
      proteinHigh,
      carbLow,
      carbHigh,
      fatLow,
      fatHigh,
      fibreLow,
      fibreHigh,
      confidence);

  @override
  String toString() {
    return 'FoodNutrition(basis: $basis, servingLabel: $servingLabel, servingGrams: $servingGrams, kcalLow: $kcalLow, kcalHigh: $kcalHigh, proteinLow: $proteinLow, proteinHigh: $proteinHigh, carbLow: $carbLow, carbHigh: $carbHigh, fatLow: $fatLow, fatHigh: $fatHigh, fibreLow: $fibreLow, fibreHigh: $fibreHigh, confidence: $confidence)';
  }
}

/// @nodoc
abstract mixin class $FoodNutritionCopyWith<$Res> {
  factory $FoodNutritionCopyWith(
          FoodNutrition value, $Res Function(FoodNutrition) _then) =
      _$FoodNutritionCopyWithImpl;
  @useResult
  $Res call(
      {NutritionBasis basis,
      String servingLabel,
      double? servingGrams,
      double kcalLow,
      double kcalHigh,
      double proteinLow,
      double proteinHigh,
      double carbLow,
      double carbHigh,
      double fatLow,
      double fatHigh,
      double? fibreLow,
      double? fibreHigh,
      NutritionConfidence confidence});
}

/// @nodoc
class _$FoodNutritionCopyWithImpl<$Res>
    implements $FoodNutritionCopyWith<$Res> {
  _$FoodNutritionCopyWithImpl(this._self, this._then);

  final FoodNutrition _self;
  final $Res Function(FoodNutrition) _then;

  /// Create a copy of FoodNutrition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? basis = null,
    Object? servingLabel = null,
    Object? servingGrams = freezed,
    Object? kcalLow = null,
    Object? kcalHigh = null,
    Object? proteinLow = null,
    Object? proteinHigh = null,
    Object? carbLow = null,
    Object? carbHigh = null,
    Object? fatLow = null,
    Object? fatHigh = null,
    Object? fibreLow = freezed,
    Object? fibreHigh = freezed,
    Object? confidence = null,
  }) {
    return _then(_self.copyWith(
      basis: null == basis
          ? _self.basis
          : basis // ignore: cast_nullable_to_non_nullable
              as NutritionBasis,
      servingLabel: null == servingLabel
          ? _self.servingLabel
          : servingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      servingGrams: freezed == servingGrams
          ? _self.servingGrams
          : servingGrams // ignore: cast_nullable_to_non_nullable
              as double?,
      kcalLow: null == kcalLow
          ? _self.kcalLow
          : kcalLow // ignore: cast_nullable_to_non_nullable
              as double,
      kcalHigh: null == kcalHigh
          ? _self.kcalHigh
          : kcalHigh // ignore: cast_nullable_to_non_nullable
              as double,
      proteinLow: null == proteinLow
          ? _self.proteinLow
          : proteinLow // ignore: cast_nullable_to_non_nullable
              as double,
      proteinHigh: null == proteinHigh
          ? _self.proteinHigh
          : proteinHigh // ignore: cast_nullable_to_non_nullable
              as double,
      carbLow: null == carbLow
          ? _self.carbLow
          : carbLow // ignore: cast_nullable_to_non_nullable
              as double,
      carbHigh: null == carbHigh
          ? _self.carbHigh
          : carbHigh // ignore: cast_nullable_to_non_nullable
              as double,
      fatLow: null == fatLow
          ? _self.fatLow
          : fatLow // ignore: cast_nullable_to_non_nullable
              as double,
      fatHigh: null == fatHigh
          ? _self.fatHigh
          : fatHigh // ignore: cast_nullable_to_non_nullable
              as double,
      fibreLow: freezed == fibreLow
          ? _self.fibreLow
          : fibreLow // ignore: cast_nullable_to_non_nullable
              as double?,
      fibreHigh: freezed == fibreHigh
          ? _self.fibreHigh
          : fibreHigh // ignore: cast_nullable_to_non_nullable
              as double?,
      confidence: null == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as NutritionConfidence,
    ));
  }
}

/// Adds pattern-matching-related methods to [FoodNutrition].
extension FoodNutritionPatterns on FoodNutrition {
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
    TResult Function(_FoodNutrition value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FoodNutrition() when $default != null:
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
    TResult Function(_FoodNutrition value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodNutrition():
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
    TResult? Function(_FoodNutrition value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodNutrition() when $default != null:
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
            NutritionBasis basis,
            String servingLabel,
            double? servingGrams,
            double kcalLow,
            double kcalHigh,
            double proteinLow,
            double proteinHigh,
            double carbLow,
            double carbHigh,
            double fatLow,
            double fatHigh,
            double? fibreLow,
            double? fibreHigh,
            NutritionConfidence confidence)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FoodNutrition() when $default != null:
        return $default(
            _that.basis,
            _that.servingLabel,
            _that.servingGrams,
            _that.kcalLow,
            _that.kcalHigh,
            _that.proteinLow,
            _that.proteinHigh,
            _that.carbLow,
            _that.carbHigh,
            _that.fatLow,
            _that.fatHigh,
            _that.fibreLow,
            _that.fibreHigh,
            _that.confidence);
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
            NutritionBasis basis,
            String servingLabel,
            double? servingGrams,
            double kcalLow,
            double kcalHigh,
            double proteinLow,
            double proteinHigh,
            double carbLow,
            double carbHigh,
            double fatLow,
            double fatHigh,
            double? fibreLow,
            double? fibreHigh,
            NutritionConfidence confidence)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodNutrition():
        return $default(
            _that.basis,
            _that.servingLabel,
            _that.servingGrams,
            _that.kcalLow,
            _that.kcalHigh,
            _that.proteinLow,
            _that.proteinHigh,
            _that.carbLow,
            _that.carbHigh,
            _that.fatLow,
            _that.fatHigh,
            _that.fibreLow,
            _that.fibreHigh,
            _that.confidence);
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
            NutritionBasis basis,
            String servingLabel,
            double? servingGrams,
            double kcalLow,
            double kcalHigh,
            double proteinLow,
            double proteinHigh,
            double carbLow,
            double carbHigh,
            double fatLow,
            double fatHigh,
            double? fibreLow,
            double? fibreHigh,
            NutritionConfidence confidence)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodNutrition() when $default != null:
        return $default(
            _that.basis,
            _that.servingLabel,
            _that.servingGrams,
            _that.kcalLow,
            _that.kcalHigh,
            _that.proteinLow,
            _that.proteinHigh,
            _that.carbLow,
            _that.carbHigh,
            _that.fatLow,
            _that.fatHigh,
            _that.fibreLow,
            _that.fibreHigh,
            _that.confidence);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FoodNutrition extends FoodNutrition {
  const _FoodNutrition(
      {required this.basis,
      required this.servingLabel,
      required this.servingGrams,
      required this.kcalLow,
      required this.kcalHigh,
      required this.proteinLow,
      required this.proteinHigh,
      required this.carbLow,
      required this.carbHigh,
      required this.fatLow,
      required this.fatHigh,
      required this.fibreLow,
      required this.fibreHigh,
      required this.confidence})
      : super._();
  factory _FoodNutrition.fromJson(Map<String, dynamic> json) =>
      _$FoodNutritionFromJson(json);

  @override
  final NutritionBasis basis;
  @override
  final String servingLabel;
  @override
  final double? servingGrams;
  @override
  final double kcalLow;
  @override
  final double kcalHigh;
  @override
  final double proteinLow;
  @override
  final double proteinHigh;
  @override
  final double carbLow;
  @override
  final double carbHigh;
  @override
  final double fatLow;
  @override
  final double fatHigh;
  @override
  final double? fibreLow;
  @override
  final double? fibreHigh;
  @override
  final NutritionConfidence confidence;

  /// Create a copy of FoodNutrition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FoodNutritionCopyWith<_FoodNutrition> get copyWith =>
      __$FoodNutritionCopyWithImpl<_FoodNutrition>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FoodNutritionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FoodNutrition &&
            (identical(other.basis, basis) || other.basis == basis) &&
            (identical(other.servingLabel, servingLabel) ||
                other.servingLabel == servingLabel) &&
            (identical(other.servingGrams, servingGrams) ||
                other.servingGrams == servingGrams) &&
            (identical(other.kcalLow, kcalLow) || other.kcalLow == kcalLow) &&
            (identical(other.kcalHigh, kcalHigh) ||
                other.kcalHigh == kcalHigh) &&
            (identical(other.proteinLow, proteinLow) ||
                other.proteinLow == proteinLow) &&
            (identical(other.proteinHigh, proteinHigh) ||
                other.proteinHigh == proteinHigh) &&
            (identical(other.carbLow, carbLow) || other.carbLow == carbLow) &&
            (identical(other.carbHigh, carbHigh) ||
                other.carbHigh == carbHigh) &&
            (identical(other.fatLow, fatLow) || other.fatLow == fatLow) &&
            (identical(other.fatHigh, fatHigh) || other.fatHigh == fatHigh) &&
            (identical(other.fibreLow, fibreLow) ||
                other.fibreLow == fibreLow) &&
            (identical(other.fibreHigh, fibreHigh) ||
                other.fibreHigh == fibreHigh) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      basis,
      servingLabel,
      servingGrams,
      kcalLow,
      kcalHigh,
      proteinLow,
      proteinHigh,
      carbLow,
      carbHigh,
      fatLow,
      fatHigh,
      fibreLow,
      fibreHigh,
      confidence);

  @override
  String toString() {
    return 'FoodNutrition(basis: $basis, servingLabel: $servingLabel, servingGrams: $servingGrams, kcalLow: $kcalLow, kcalHigh: $kcalHigh, proteinLow: $proteinLow, proteinHigh: $proteinHigh, carbLow: $carbLow, carbHigh: $carbHigh, fatLow: $fatLow, fatHigh: $fatHigh, fibreLow: $fibreLow, fibreHigh: $fibreHigh, confidence: $confidence)';
  }
}

/// @nodoc
abstract mixin class _$FoodNutritionCopyWith<$Res>
    implements $FoodNutritionCopyWith<$Res> {
  factory _$FoodNutritionCopyWith(
          _FoodNutrition value, $Res Function(_FoodNutrition) _then) =
      __$FoodNutritionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {NutritionBasis basis,
      String servingLabel,
      double? servingGrams,
      double kcalLow,
      double kcalHigh,
      double proteinLow,
      double proteinHigh,
      double carbLow,
      double carbHigh,
      double fatLow,
      double fatHigh,
      double? fibreLow,
      double? fibreHigh,
      NutritionConfidence confidence});
}

/// @nodoc
class __$FoodNutritionCopyWithImpl<$Res>
    implements _$FoodNutritionCopyWith<$Res> {
  __$FoodNutritionCopyWithImpl(this._self, this._then);

  final _FoodNutrition _self;
  final $Res Function(_FoodNutrition) _then;

  /// Create a copy of FoodNutrition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? basis = null,
    Object? servingLabel = null,
    Object? servingGrams = freezed,
    Object? kcalLow = null,
    Object? kcalHigh = null,
    Object? proteinLow = null,
    Object? proteinHigh = null,
    Object? carbLow = null,
    Object? carbHigh = null,
    Object? fatLow = null,
    Object? fatHigh = null,
    Object? fibreLow = freezed,
    Object? fibreHigh = freezed,
    Object? confidence = null,
  }) {
    return _then(_FoodNutrition(
      basis: null == basis
          ? _self.basis
          : basis // ignore: cast_nullable_to_non_nullable
              as NutritionBasis,
      servingLabel: null == servingLabel
          ? _self.servingLabel
          : servingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      servingGrams: freezed == servingGrams
          ? _self.servingGrams
          : servingGrams // ignore: cast_nullable_to_non_nullable
              as double?,
      kcalLow: null == kcalLow
          ? _self.kcalLow
          : kcalLow // ignore: cast_nullable_to_non_nullable
              as double,
      kcalHigh: null == kcalHigh
          ? _self.kcalHigh
          : kcalHigh // ignore: cast_nullable_to_non_nullable
              as double,
      proteinLow: null == proteinLow
          ? _self.proteinLow
          : proteinLow // ignore: cast_nullable_to_non_nullable
              as double,
      proteinHigh: null == proteinHigh
          ? _self.proteinHigh
          : proteinHigh // ignore: cast_nullable_to_non_nullable
              as double,
      carbLow: null == carbLow
          ? _self.carbLow
          : carbLow // ignore: cast_nullable_to_non_nullable
              as double,
      carbHigh: null == carbHigh
          ? _self.carbHigh
          : carbHigh // ignore: cast_nullable_to_non_nullable
              as double,
      fatLow: null == fatLow
          ? _self.fatLow
          : fatLow // ignore: cast_nullable_to_non_nullable
              as double,
      fatHigh: null == fatHigh
          ? _self.fatHigh
          : fatHigh // ignore: cast_nullable_to_non_nullable
              as double,
      fibreLow: freezed == fibreLow
          ? _self.fibreLow
          : fibreLow // ignore: cast_nullable_to_non_nullable
              as double?,
      fibreHigh: freezed == fibreHigh
          ? _self.fibreHigh
          : fibreHigh // ignore: cast_nullable_to_non_nullable
              as double?,
      confidence: null == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as NutritionConfidence,
    ));
  }
}

/// @nodoc
mixin _$Food {
  String get id;
  String get slug;
  String get name;
  String? get brand;
  String? get barcode;
  FoodSource get source;
  String? get sourceRef;
  bool get isVerified;
  bool get isCustom;
  List<String> get aliases;
  List<FoodNutrition> get nutrition;

  /// Create a copy of Food
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FoodCopyWith<Food> get copyWith =>
      _$FoodCopyWithImpl<Food>(this as Food, _$identity);

  /// Serializes this Food to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Food &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.barcode, barcode) || other.barcode == barcode) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.sourceRef, sourceRef) ||
                other.sourceRef == sourceRef) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isCustom, isCustom) ||
                other.isCustom == isCustom) &&
            const DeepCollectionEquality().equals(other.aliases, aliases) &&
            const DeepCollectionEquality().equals(other.nutrition, nutrition));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      slug,
      name,
      brand,
      barcode,
      source,
      sourceRef,
      isVerified,
      isCustom,
      const DeepCollectionEquality().hash(aliases),
      const DeepCollectionEquality().hash(nutrition));

  @override
  String toString() {
    return 'Food(id: $id, slug: $slug, name: $name, brand: $brand, barcode: $barcode, source: $source, sourceRef: $sourceRef, isVerified: $isVerified, isCustom: $isCustom, aliases: $aliases, nutrition: $nutrition)';
  }
}

/// @nodoc
abstract mixin class $FoodCopyWith<$Res> {
  factory $FoodCopyWith(Food value, $Res Function(Food) _then) =
      _$FoodCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String slug,
      String name,
      String? brand,
      String? barcode,
      FoodSource source,
      String? sourceRef,
      bool isVerified,
      bool isCustom,
      List<String> aliases,
      List<FoodNutrition> nutrition});
}

/// @nodoc
class _$FoodCopyWithImpl<$Res> implements $FoodCopyWith<$Res> {
  _$FoodCopyWithImpl(this._self, this._then);

  final Food _self;
  final $Res Function(Food) _then;

  /// Create a copy of Food
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? name = null,
    Object? brand = freezed,
    Object? barcode = freezed,
    Object? source = null,
    Object? sourceRef = freezed,
    Object? isVerified = null,
    Object? isCustom = null,
    Object? aliases = null,
    Object? nutrition = null,
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
      brand: freezed == brand
          ? _self.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String?,
      barcode: freezed == barcode
          ? _self.barcode
          : barcode // ignore: cast_nullable_to_non_nullable
              as String?,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as FoodSource,
      sourceRef: freezed == sourceRef
          ? _self.sourceRef
          : sourceRef // ignore: cast_nullable_to_non_nullable
              as String?,
      isVerified: null == isVerified
          ? _self.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      isCustom: null == isCustom
          ? _self.isCustom
          : isCustom // ignore: cast_nullable_to_non_nullable
              as bool,
      aliases: null == aliases
          ? _self.aliases
          : aliases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      nutrition: null == nutrition
          ? _self.nutrition
          : nutrition // ignore: cast_nullable_to_non_nullable
              as List<FoodNutrition>,
    ));
  }
}

/// Adds pattern-matching-related methods to [Food].
extension FoodPatterns on Food {
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
    TResult Function(_Food value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Food() when $default != null:
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
    TResult Function(_Food value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Food():
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
    TResult? Function(_Food value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Food() when $default != null:
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
            String? brand,
            String? barcode,
            FoodSource source,
            String? sourceRef,
            bool isVerified,
            bool isCustom,
            List<String> aliases,
            List<FoodNutrition> nutrition)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Food() when $default != null:
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.brand,
            _that.barcode,
            _that.source,
            _that.sourceRef,
            _that.isVerified,
            _that.isCustom,
            _that.aliases,
            _that.nutrition);
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
            String? brand,
            String? barcode,
            FoodSource source,
            String? sourceRef,
            bool isVerified,
            bool isCustom,
            List<String> aliases,
            List<FoodNutrition> nutrition)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Food():
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.brand,
            _that.barcode,
            _that.source,
            _that.sourceRef,
            _that.isVerified,
            _that.isCustom,
            _that.aliases,
            _that.nutrition);
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
            String? brand,
            String? barcode,
            FoodSource source,
            String? sourceRef,
            bool isVerified,
            bool isCustom,
            List<String> aliases,
            List<FoodNutrition> nutrition)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Food() when $default != null:
        return $default(
            _that.id,
            _that.slug,
            _that.name,
            _that.brand,
            _that.barcode,
            _that.source,
            _that.sourceRef,
            _that.isVerified,
            _that.isCustom,
            _that.aliases,
            _that.nutrition);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Food extends Food {
  const _Food(
      {required this.id,
      required this.slug,
      required this.name,
      required this.brand,
      required this.barcode,
      required this.source,
      required this.sourceRef,
      required this.isVerified,
      required this.isCustom,
      required final List<String> aliases,
      required final List<FoodNutrition> nutrition})
      : _aliases = aliases,
        _nutrition = nutrition,
        super._();
  factory _Food.fromJson(Map<String, dynamic> json) => _$FoodFromJson(json);

  @override
  final String id;
  @override
  final String slug;
  @override
  final String name;
  @override
  final String? brand;
  @override
  final String? barcode;
  @override
  final FoodSource source;
  @override
  final String? sourceRef;
  @override
  final bool isVerified;
  @override
  final bool isCustom;
  final List<String> _aliases;
  @override
  List<String> get aliases {
    if (_aliases is EqualUnmodifiableListView) return _aliases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_aliases);
  }

  final List<FoodNutrition> _nutrition;
  @override
  List<FoodNutrition> get nutrition {
    if (_nutrition is EqualUnmodifiableListView) return _nutrition;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_nutrition);
  }

  /// Create a copy of Food
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FoodCopyWith<_Food> get copyWith =>
      __$FoodCopyWithImpl<_Food>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FoodToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Food &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.barcode, barcode) || other.barcode == barcode) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.sourceRef, sourceRef) ||
                other.sourceRef == sourceRef) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isCustom, isCustom) ||
                other.isCustom == isCustom) &&
            const DeepCollectionEquality().equals(other._aliases, _aliases) &&
            const DeepCollectionEquality()
                .equals(other._nutrition, _nutrition));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      slug,
      name,
      brand,
      barcode,
      source,
      sourceRef,
      isVerified,
      isCustom,
      const DeepCollectionEquality().hash(_aliases),
      const DeepCollectionEquality().hash(_nutrition));

  @override
  String toString() {
    return 'Food(id: $id, slug: $slug, name: $name, brand: $brand, barcode: $barcode, source: $source, sourceRef: $sourceRef, isVerified: $isVerified, isCustom: $isCustom, aliases: $aliases, nutrition: $nutrition)';
  }
}

/// @nodoc
abstract mixin class _$FoodCopyWith<$Res> implements $FoodCopyWith<$Res> {
  factory _$FoodCopyWith(_Food value, $Res Function(_Food) _then) =
      __$FoodCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String slug,
      String name,
      String? brand,
      String? barcode,
      FoodSource source,
      String? sourceRef,
      bool isVerified,
      bool isCustom,
      List<String> aliases,
      List<FoodNutrition> nutrition});
}

/// @nodoc
class __$FoodCopyWithImpl<$Res> implements _$FoodCopyWith<$Res> {
  __$FoodCopyWithImpl(this._self, this._then);

  final _Food _self;
  final $Res Function(_Food) _then;

  /// Create a copy of Food
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? name = null,
    Object? brand = freezed,
    Object? barcode = freezed,
    Object? source = null,
    Object? sourceRef = freezed,
    Object? isVerified = null,
    Object? isCustom = null,
    Object? aliases = null,
    Object? nutrition = null,
  }) {
    return _then(_Food(
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
      brand: freezed == brand
          ? _self.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String?,
      barcode: freezed == barcode
          ? _self.barcode
          : barcode // ignore: cast_nullable_to_non_nullable
              as String?,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as FoodSource,
      sourceRef: freezed == sourceRef
          ? _self.sourceRef
          : sourceRef // ignore: cast_nullable_to_non_nullable
              as String?,
      isVerified: null == isVerified
          ? _self.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      isCustom: null == isCustom
          ? _self.isCustom
          : isCustom // ignore: cast_nullable_to_non_nullable
              as bool,
      aliases: null == aliases
          ? _self._aliases
          : aliases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      nutrition: null == nutrition
          ? _self._nutrition
          : nutrition // ignore: cast_nullable_to_non_nullable
              as List<FoodNutrition>,
    ));
  }
}

/// @nodoc
mixin _$FoodSearchResponse {
  @JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
  List<FoodSearchResult> get items;

  /// Create a copy of FoodSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FoodSearchResponseCopyWith<FoodSearchResponse> get copyWith =>
      _$FoodSearchResponseCopyWithImpl<FoodSearchResponse>(
          this as FoodSearchResponse, _$identity);

  /// Serializes this FoodSearchResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FoodSearchResponse &&
            const DeepCollectionEquality().equals(other.items, items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(items));

  @override
  String toString() {
    return 'FoodSearchResponse(items: $items)';
  }
}

/// @nodoc
abstract mixin class $FoodSearchResponseCopyWith<$Res> {
  factory $FoodSearchResponseCopyWith(
          FoodSearchResponse value, $Res Function(FoodSearchResponse) _then) =
      _$FoodSearchResponseCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
      List<FoodSearchResult> items});
}

/// @nodoc
class _$FoodSearchResponseCopyWithImpl<$Res>
    implements $FoodSearchResponseCopyWith<$Res> {
  _$FoodSearchResponseCopyWithImpl(this._self, this._then);

  final FoodSearchResponse _self;
  final $Res Function(FoodSearchResponse) _then;

  /// Create a copy of FoodSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
  }) {
    return _then(_self.copyWith(
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FoodSearchResult>,
    ));
  }
}

/// Adds pattern-matching-related methods to [FoodSearchResponse].
extension FoodSearchResponsePatterns on FoodSearchResponse {
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
    TResult Function(_FoodSearchResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FoodSearchResponse() when $default != null:
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
    TResult Function(_FoodSearchResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodSearchResponse():
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
    TResult? Function(_FoodSearchResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodSearchResponse() when $default != null:
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
            @JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
            List<FoodSearchResult> items)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FoodSearchResponse() when $default != null:
        return $default(_that.items);
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
            @JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
            List<FoodSearchResult> items)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodSearchResponse():
        return $default(_that.items);
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
            @JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
            List<FoodSearchResult> items)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodSearchResponse() when $default != null:
        return $default(_that.items);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FoodSearchResponse implements FoodSearchResponse {
  const _FoodSearchResponse(
      {@JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
      required final List<FoodSearchResult> items})
      : _items = items;
  factory _FoodSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodSearchResponseFromJson(json);

  final List<FoodSearchResult> _items;
  @override
  @JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
  List<FoodSearchResult> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// Create a copy of FoodSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FoodSearchResponseCopyWith<_FoodSearchResponse> get copyWith =>
      __$FoodSearchResponseCopyWithImpl<_FoodSearchResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FoodSearchResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FoodSearchResponse &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_items));

  @override
  String toString() {
    return 'FoodSearchResponse(items: $items)';
  }
}

/// @nodoc
abstract mixin class _$FoodSearchResponseCopyWith<$Res>
    implements $FoodSearchResponseCopyWith<$Res> {
  factory _$FoodSearchResponseCopyWith(
          _FoodSearchResponse value, $Res Function(_FoodSearchResponse) _then) =
      __$FoodSearchResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
      List<FoodSearchResult> items});
}

/// @nodoc
class __$FoodSearchResponseCopyWithImpl<$Res>
    implements _$FoodSearchResponseCopyWith<$Res> {
  __$FoodSearchResponseCopyWithImpl(this._self, this._then);

  final _FoodSearchResponse _self;
  final $Res Function(_FoodSearchResponse) _then;

  /// Create a copy of FoodSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
  }) {
    return _then(_FoodSearchResponse(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FoodSearchResult>,
    ));
  }
}

// dart format on
