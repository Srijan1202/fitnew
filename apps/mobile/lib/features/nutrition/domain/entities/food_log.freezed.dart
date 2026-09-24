// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'food_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FoodLogItem {
  String get id;
  int get position;
  String? get foodId;

  /// Phase 9: the mess dish it came from (provenance; the numbers are the
  /// snapshot). Null for everything else.
  String? get messDishSlug;
  String get foodName;
  FoodSource get foodSource;
  NutritionBasis? get basis;
  String? get servingLabel;
  double? get servingGrams;
  double get servings;
  double? get grams;
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

  /// Create a copy of FoodLogItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FoodLogItemCopyWith<FoodLogItem> get copyWith =>
      _$FoodLogItemCopyWithImpl<FoodLogItem>(this as FoodLogItem, _$identity);

  /// Serializes this FoodLogItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FoodLogItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.foodId, foodId) || other.foodId == foodId) &&
            (identical(other.messDishSlug, messDishSlug) ||
                other.messDishSlug == messDishSlug) &&
            (identical(other.foodName, foodName) ||
                other.foodName == foodName) &&
            (identical(other.foodSource, foodSource) ||
                other.foodSource == foodSource) &&
            (identical(other.basis, basis) || other.basis == basis) &&
            (identical(other.servingLabel, servingLabel) ||
                other.servingLabel == servingLabel) &&
            (identical(other.servingGrams, servingGrams) ||
                other.servingGrams == servingGrams) &&
            (identical(other.servings, servings) ||
                other.servings == servings) &&
            (identical(other.grams, grams) || other.grams == grams) &&
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
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        position,
        foodId,
        messDishSlug,
        foodName,
        foodSource,
        basis,
        servingLabel,
        servingGrams,
        servings,
        grams,
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
        confidence
      ]);

  @override
  String toString() {
    return 'FoodLogItem(id: $id, position: $position, foodId: $foodId, messDishSlug: $messDishSlug, foodName: $foodName, foodSource: $foodSource, basis: $basis, servingLabel: $servingLabel, servingGrams: $servingGrams, servings: $servings, grams: $grams, kcalLow: $kcalLow, kcalHigh: $kcalHigh, proteinLow: $proteinLow, proteinHigh: $proteinHigh, carbLow: $carbLow, carbHigh: $carbHigh, fatLow: $fatLow, fatHigh: $fatHigh, fibreLow: $fibreLow, fibreHigh: $fibreHigh, confidence: $confidence)';
  }
}

/// @nodoc
abstract mixin class $FoodLogItemCopyWith<$Res> {
  factory $FoodLogItemCopyWith(
          FoodLogItem value, $Res Function(FoodLogItem) _then) =
      _$FoodLogItemCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      int position,
      String? foodId,
      String? messDishSlug,
      String foodName,
      FoodSource foodSource,
      NutritionBasis? basis,
      String? servingLabel,
      double? servingGrams,
      double servings,
      double? grams,
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
class _$FoodLogItemCopyWithImpl<$Res> implements $FoodLogItemCopyWith<$Res> {
  _$FoodLogItemCopyWithImpl(this._self, this._then);

  final FoodLogItem _self;
  final $Res Function(FoodLogItem) _then;

  /// Create a copy of FoodLogItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? position = null,
    Object? foodId = freezed,
    Object? messDishSlug = freezed,
    Object? foodName = null,
    Object? foodSource = null,
    Object? basis = freezed,
    Object? servingLabel = freezed,
    Object? servingGrams = freezed,
    Object? servings = null,
    Object? grams = freezed,
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
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      position: null == position
          ? _self.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      foodId: freezed == foodId
          ? _self.foodId
          : foodId // ignore: cast_nullable_to_non_nullable
              as String?,
      messDishSlug: freezed == messDishSlug
          ? _self.messDishSlug
          : messDishSlug // ignore: cast_nullable_to_non_nullable
              as String?,
      foodName: null == foodName
          ? _self.foodName
          : foodName // ignore: cast_nullable_to_non_nullable
              as String,
      foodSource: null == foodSource
          ? _self.foodSource
          : foodSource // ignore: cast_nullable_to_non_nullable
              as FoodSource,
      basis: freezed == basis
          ? _self.basis
          : basis // ignore: cast_nullable_to_non_nullable
              as NutritionBasis?,
      servingLabel: freezed == servingLabel
          ? _self.servingLabel
          : servingLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      servingGrams: freezed == servingGrams
          ? _self.servingGrams
          : servingGrams // ignore: cast_nullable_to_non_nullable
              as double?,
      servings: null == servings
          ? _self.servings
          : servings // ignore: cast_nullable_to_non_nullable
              as double,
      grams: freezed == grams
          ? _self.grams
          : grams // ignore: cast_nullable_to_non_nullable
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

/// Adds pattern-matching-related methods to [FoodLogItem].
extension FoodLogItemPatterns on FoodLogItem {
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
    TResult Function(_FoodLogItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FoodLogItem() when $default != null:
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
    TResult Function(_FoodLogItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodLogItem():
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
    TResult? Function(_FoodLogItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodLogItem() when $default != null:
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
            int position,
            String? foodId,
            String? messDishSlug,
            String foodName,
            FoodSource foodSource,
            NutritionBasis? basis,
            String? servingLabel,
            double? servingGrams,
            double servings,
            double? grams,
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
      case _FoodLogItem() when $default != null:
        return $default(
            _that.id,
            _that.position,
            _that.foodId,
            _that.messDishSlug,
            _that.foodName,
            _that.foodSource,
            _that.basis,
            _that.servingLabel,
            _that.servingGrams,
            _that.servings,
            _that.grams,
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
            String id,
            int position,
            String? foodId,
            String? messDishSlug,
            String foodName,
            FoodSource foodSource,
            NutritionBasis? basis,
            String? servingLabel,
            double? servingGrams,
            double servings,
            double? grams,
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
      case _FoodLogItem():
        return $default(
            _that.id,
            _that.position,
            _that.foodId,
            _that.messDishSlug,
            _that.foodName,
            _that.foodSource,
            _that.basis,
            _that.servingLabel,
            _that.servingGrams,
            _that.servings,
            _that.grams,
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
            String id,
            int position,
            String? foodId,
            String? messDishSlug,
            String foodName,
            FoodSource foodSource,
            NutritionBasis? basis,
            String? servingLabel,
            double? servingGrams,
            double servings,
            double? grams,
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
      case _FoodLogItem() when $default != null:
        return $default(
            _that.id,
            _that.position,
            _that.foodId,
            _that.messDishSlug,
            _that.foodName,
            _that.foodSource,
            _that.basis,
            _that.servingLabel,
            _that.servingGrams,
            _that.servings,
            _that.grams,
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
class _FoodLogItem extends FoodLogItem {
  const _FoodLogItem(
      {required this.id,
      required this.position,
      required this.foodId,
      this.messDishSlug = null,
      required this.foodName,
      required this.foodSource,
      required this.basis,
      required this.servingLabel,
      required this.servingGrams,
      required this.servings,
      required this.grams,
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
  factory _FoodLogItem.fromJson(Map<String, dynamic> json) =>
      _$FoodLogItemFromJson(json);

  @override
  final String id;
  @override
  final int position;
  @override
  final String? foodId;

  /// Phase 9: the mess dish it came from (provenance; the numbers are the
  /// snapshot). Null for everything else.
  @override
  @JsonKey()
  final String? messDishSlug;
  @override
  final String foodName;
  @override
  final FoodSource foodSource;
  @override
  final NutritionBasis? basis;
  @override
  final String? servingLabel;
  @override
  final double? servingGrams;
  @override
  final double servings;
  @override
  final double? grams;
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

  /// Create a copy of FoodLogItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FoodLogItemCopyWith<_FoodLogItem> get copyWith =>
      __$FoodLogItemCopyWithImpl<_FoodLogItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FoodLogItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FoodLogItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.foodId, foodId) || other.foodId == foodId) &&
            (identical(other.messDishSlug, messDishSlug) ||
                other.messDishSlug == messDishSlug) &&
            (identical(other.foodName, foodName) ||
                other.foodName == foodName) &&
            (identical(other.foodSource, foodSource) ||
                other.foodSource == foodSource) &&
            (identical(other.basis, basis) || other.basis == basis) &&
            (identical(other.servingLabel, servingLabel) ||
                other.servingLabel == servingLabel) &&
            (identical(other.servingGrams, servingGrams) ||
                other.servingGrams == servingGrams) &&
            (identical(other.servings, servings) ||
                other.servings == servings) &&
            (identical(other.grams, grams) || other.grams == grams) &&
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
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        position,
        foodId,
        messDishSlug,
        foodName,
        foodSource,
        basis,
        servingLabel,
        servingGrams,
        servings,
        grams,
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
        confidence
      ]);

  @override
  String toString() {
    return 'FoodLogItem(id: $id, position: $position, foodId: $foodId, messDishSlug: $messDishSlug, foodName: $foodName, foodSource: $foodSource, basis: $basis, servingLabel: $servingLabel, servingGrams: $servingGrams, servings: $servings, grams: $grams, kcalLow: $kcalLow, kcalHigh: $kcalHigh, proteinLow: $proteinLow, proteinHigh: $proteinHigh, carbLow: $carbLow, carbHigh: $carbHigh, fatLow: $fatLow, fatHigh: $fatHigh, fibreLow: $fibreLow, fibreHigh: $fibreHigh, confidence: $confidence)';
  }
}

/// @nodoc
abstract mixin class _$FoodLogItemCopyWith<$Res>
    implements $FoodLogItemCopyWith<$Res> {
  factory _$FoodLogItemCopyWith(
          _FoodLogItem value, $Res Function(_FoodLogItem) _then) =
      __$FoodLogItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      int position,
      String? foodId,
      String? messDishSlug,
      String foodName,
      FoodSource foodSource,
      NutritionBasis? basis,
      String? servingLabel,
      double? servingGrams,
      double servings,
      double? grams,
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
class __$FoodLogItemCopyWithImpl<$Res> implements _$FoodLogItemCopyWith<$Res> {
  __$FoodLogItemCopyWithImpl(this._self, this._then);

  final _FoodLogItem _self;
  final $Res Function(_FoodLogItem) _then;

  /// Create a copy of FoodLogItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? position = null,
    Object? foodId = freezed,
    Object? messDishSlug = freezed,
    Object? foodName = null,
    Object? foodSource = null,
    Object? basis = freezed,
    Object? servingLabel = freezed,
    Object? servingGrams = freezed,
    Object? servings = null,
    Object? grams = freezed,
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
    return _then(_FoodLogItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      position: null == position
          ? _self.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      foodId: freezed == foodId
          ? _self.foodId
          : foodId // ignore: cast_nullable_to_non_nullable
              as String?,
      messDishSlug: freezed == messDishSlug
          ? _self.messDishSlug
          : messDishSlug // ignore: cast_nullable_to_non_nullable
              as String?,
      foodName: null == foodName
          ? _self.foodName
          : foodName // ignore: cast_nullable_to_non_nullable
              as String,
      foodSource: null == foodSource
          ? _self.foodSource
          : foodSource // ignore: cast_nullable_to_non_nullable
              as FoodSource,
      basis: freezed == basis
          ? _self.basis
          : basis // ignore: cast_nullable_to_non_nullable
              as NutritionBasis?,
      servingLabel: freezed == servingLabel
          ? _self.servingLabel
          : servingLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      servingGrams: freezed == servingGrams
          ? _self.servingGrams
          : servingGrams // ignore: cast_nullable_to_non_nullable
              as double?,
      servings: null == servings
          ? _self.servings
          : servings // ignore: cast_nullable_to_non_nullable
              as double,
      grams: freezed == grams
          ? _self.grams
          : grams // ignore: cast_nullable_to_non_nullable
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
mixin _$NutritionTotals {
  double get kcalLow;
  double get kcalHigh;
  double get proteinLow;
  double get proteinHigh;
  double get carbLow;
  double get carbHigh;
  double get fatLow;
  double get fatHigh;
  double get fibreKnownLow;
  double get fibreKnownHigh;
  int get fibreUnknownItems;
  int get itemCount;

  /// Create a copy of NutritionTotals
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NutritionTotalsCopyWith<NutritionTotals> get copyWith =>
      _$NutritionTotalsCopyWithImpl<NutritionTotals>(
          this as NutritionTotals, _$identity);

  /// Serializes this NutritionTotals to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NutritionTotals &&
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
            (identical(other.fibreKnownLow, fibreKnownLow) ||
                other.fibreKnownLow == fibreKnownLow) &&
            (identical(other.fibreKnownHigh, fibreKnownHigh) ||
                other.fibreKnownHigh == fibreKnownHigh) &&
            (identical(other.fibreUnknownItems, fibreUnknownItems) ||
                other.fibreUnknownItems == fibreUnknownItems) &&
            (identical(other.itemCount, itemCount) ||
                other.itemCount == itemCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      kcalLow,
      kcalHigh,
      proteinLow,
      proteinHigh,
      carbLow,
      carbHigh,
      fatLow,
      fatHigh,
      fibreKnownLow,
      fibreKnownHigh,
      fibreUnknownItems,
      itemCount);

  @override
  String toString() {
    return 'NutritionTotals(kcalLow: $kcalLow, kcalHigh: $kcalHigh, proteinLow: $proteinLow, proteinHigh: $proteinHigh, carbLow: $carbLow, carbHigh: $carbHigh, fatLow: $fatLow, fatHigh: $fatHigh, fibreKnownLow: $fibreKnownLow, fibreKnownHigh: $fibreKnownHigh, fibreUnknownItems: $fibreUnknownItems, itemCount: $itemCount)';
  }
}

/// @nodoc
abstract mixin class $NutritionTotalsCopyWith<$Res> {
  factory $NutritionTotalsCopyWith(
          NutritionTotals value, $Res Function(NutritionTotals) _then) =
      _$NutritionTotalsCopyWithImpl;
  @useResult
  $Res call(
      {double kcalLow,
      double kcalHigh,
      double proteinLow,
      double proteinHigh,
      double carbLow,
      double carbHigh,
      double fatLow,
      double fatHigh,
      double fibreKnownLow,
      double fibreKnownHigh,
      int fibreUnknownItems,
      int itemCount});
}

/// @nodoc
class _$NutritionTotalsCopyWithImpl<$Res>
    implements $NutritionTotalsCopyWith<$Res> {
  _$NutritionTotalsCopyWithImpl(this._self, this._then);

  final NutritionTotals _self;
  final $Res Function(NutritionTotals) _then;

  /// Create a copy of NutritionTotals
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kcalLow = null,
    Object? kcalHigh = null,
    Object? proteinLow = null,
    Object? proteinHigh = null,
    Object? carbLow = null,
    Object? carbHigh = null,
    Object? fatLow = null,
    Object? fatHigh = null,
    Object? fibreKnownLow = null,
    Object? fibreKnownHigh = null,
    Object? fibreUnknownItems = null,
    Object? itemCount = null,
  }) {
    return _then(_self.copyWith(
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
      fibreKnownLow: null == fibreKnownLow
          ? _self.fibreKnownLow
          : fibreKnownLow // ignore: cast_nullable_to_non_nullable
              as double,
      fibreKnownHigh: null == fibreKnownHigh
          ? _self.fibreKnownHigh
          : fibreKnownHigh // ignore: cast_nullable_to_non_nullable
              as double,
      fibreUnknownItems: null == fibreUnknownItems
          ? _self.fibreUnknownItems
          : fibreUnknownItems // ignore: cast_nullable_to_non_nullable
              as int,
      itemCount: null == itemCount
          ? _self.itemCount
          : itemCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [NutritionTotals].
extension NutritionTotalsPatterns on NutritionTotals {
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
    TResult Function(_NutritionTotals value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NutritionTotals() when $default != null:
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
    TResult Function(_NutritionTotals value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionTotals():
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
    TResult? Function(_NutritionTotals value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionTotals() when $default != null:
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
            double kcalLow,
            double kcalHigh,
            double proteinLow,
            double proteinHigh,
            double carbLow,
            double carbHigh,
            double fatLow,
            double fatHigh,
            double fibreKnownLow,
            double fibreKnownHigh,
            int fibreUnknownItems,
            int itemCount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NutritionTotals() when $default != null:
        return $default(
            _that.kcalLow,
            _that.kcalHigh,
            _that.proteinLow,
            _that.proteinHigh,
            _that.carbLow,
            _that.carbHigh,
            _that.fatLow,
            _that.fatHigh,
            _that.fibreKnownLow,
            _that.fibreKnownHigh,
            _that.fibreUnknownItems,
            _that.itemCount);
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
            double kcalLow,
            double kcalHigh,
            double proteinLow,
            double proteinHigh,
            double carbLow,
            double carbHigh,
            double fatLow,
            double fatHigh,
            double fibreKnownLow,
            double fibreKnownHigh,
            int fibreUnknownItems,
            int itemCount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionTotals():
        return $default(
            _that.kcalLow,
            _that.kcalHigh,
            _that.proteinLow,
            _that.proteinHigh,
            _that.carbLow,
            _that.carbHigh,
            _that.fatLow,
            _that.fatHigh,
            _that.fibreKnownLow,
            _that.fibreKnownHigh,
            _that.fibreUnknownItems,
            _that.itemCount);
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
            double kcalLow,
            double kcalHigh,
            double proteinLow,
            double proteinHigh,
            double carbLow,
            double carbHigh,
            double fatLow,
            double fatHigh,
            double fibreKnownLow,
            double fibreKnownHigh,
            int fibreUnknownItems,
            int itemCount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionTotals() when $default != null:
        return $default(
            _that.kcalLow,
            _that.kcalHigh,
            _that.proteinLow,
            _that.proteinHigh,
            _that.carbLow,
            _that.carbHigh,
            _that.fatLow,
            _that.fatHigh,
            _that.fibreKnownLow,
            _that.fibreKnownHigh,
            _that.fibreUnknownItems,
            _that.itemCount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _NutritionTotals extends NutritionTotals {
  const _NutritionTotals(
      {required this.kcalLow,
      required this.kcalHigh,
      required this.proteinLow,
      required this.proteinHigh,
      required this.carbLow,
      required this.carbHigh,
      required this.fatLow,
      required this.fatHigh,
      required this.fibreKnownLow,
      required this.fibreKnownHigh,
      required this.fibreUnknownItems,
      required this.itemCount})
      : super._();
  factory _NutritionTotals.fromJson(Map<String, dynamic> json) =>
      _$NutritionTotalsFromJson(json);

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
  final double fibreKnownLow;
  @override
  final double fibreKnownHigh;
  @override
  final int fibreUnknownItems;
  @override
  final int itemCount;

  /// Create a copy of NutritionTotals
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NutritionTotalsCopyWith<_NutritionTotals> get copyWith =>
      __$NutritionTotalsCopyWithImpl<_NutritionTotals>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NutritionTotalsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NutritionTotals &&
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
            (identical(other.fibreKnownLow, fibreKnownLow) ||
                other.fibreKnownLow == fibreKnownLow) &&
            (identical(other.fibreKnownHigh, fibreKnownHigh) ||
                other.fibreKnownHigh == fibreKnownHigh) &&
            (identical(other.fibreUnknownItems, fibreUnknownItems) ||
                other.fibreUnknownItems == fibreUnknownItems) &&
            (identical(other.itemCount, itemCount) ||
                other.itemCount == itemCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      kcalLow,
      kcalHigh,
      proteinLow,
      proteinHigh,
      carbLow,
      carbHigh,
      fatLow,
      fatHigh,
      fibreKnownLow,
      fibreKnownHigh,
      fibreUnknownItems,
      itemCount);

  @override
  String toString() {
    return 'NutritionTotals(kcalLow: $kcalLow, kcalHigh: $kcalHigh, proteinLow: $proteinLow, proteinHigh: $proteinHigh, carbLow: $carbLow, carbHigh: $carbHigh, fatLow: $fatLow, fatHigh: $fatHigh, fibreKnownLow: $fibreKnownLow, fibreKnownHigh: $fibreKnownHigh, fibreUnknownItems: $fibreUnknownItems, itemCount: $itemCount)';
  }
}

/// @nodoc
abstract mixin class _$NutritionTotalsCopyWith<$Res>
    implements $NutritionTotalsCopyWith<$Res> {
  factory _$NutritionTotalsCopyWith(
          _NutritionTotals value, $Res Function(_NutritionTotals) _then) =
      __$NutritionTotalsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {double kcalLow,
      double kcalHigh,
      double proteinLow,
      double proteinHigh,
      double carbLow,
      double carbHigh,
      double fatLow,
      double fatHigh,
      double fibreKnownLow,
      double fibreKnownHigh,
      int fibreUnknownItems,
      int itemCount});
}

/// @nodoc
class __$NutritionTotalsCopyWithImpl<$Res>
    implements _$NutritionTotalsCopyWith<$Res> {
  __$NutritionTotalsCopyWithImpl(this._self, this._then);

  final _NutritionTotals _self;
  final $Res Function(_NutritionTotals) _then;

  /// Create a copy of NutritionTotals
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? kcalLow = null,
    Object? kcalHigh = null,
    Object? proteinLow = null,
    Object? proteinHigh = null,
    Object? carbLow = null,
    Object? carbHigh = null,
    Object? fatLow = null,
    Object? fatHigh = null,
    Object? fibreKnownLow = null,
    Object? fibreKnownHigh = null,
    Object? fibreUnknownItems = null,
    Object? itemCount = null,
  }) {
    return _then(_NutritionTotals(
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
      fibreKnownLow: null == fibreKnownLow
          ? _self.fibreKnownLow
          : fibreKnownLow // ignore: cast_nullable_to_non_nullable
              as double,
      fibreKnownHigh: null == fibreKnownHigh
          ? _self.fibreKnownHigh
          : fibreKnownHigh // ignore: cast_nullable_to_non_nullable
              as double,
      fibreUnknownItems: null == fibreUnknownItems
          ? _self.fibreUnknownItems
          : fibreUnknownItems // ignore: cast_nullable_to_non_nullable
              as int,
      itemCount: null == itemCount
          ? _self.itemCount
          : itemCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$FoodLog {
  String get id;
  String get clientLogId;
  String get loggedAt;
  String get localDate;
  MealSlot get mealSlot;
  EntryMethod get entryMethod;
  String? get savedMealId;

  /// Phase 9: the mess a `mess` log came from.
  String? get messCode;
  List<FoodLogItem> get items;
  NutritionTotals get totals;

  /// Create a copy of FoodLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FoodLogCopyWith<FoodLog> get copyWith =>
      _$FoodLogCopyWithImpl<FoodLog>(this as FoodLog, _$identity);

  /// Serializes this FoodLog to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FoodLog &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientLogId, clientLogId) ||
                other.clientLogId == clientLogId) &&
            (identical(other.loggedAt, loggedAt) ||
                other.loggedAt == loggedAt) &&
            (identical(other.localDate, localDate) ||
                other.localDate == localDate) &&
            (identical(other.mealSlot, mealSlot) ||
                other.mealSlot == mealSlot) &&
            (identical(other.entryMethod, entryMethod) ||
                other.entryMethod == entryMethod) &&
            (identical(other.savedMealId, savedMealId) ||
                other.savedMealId == savedMealId) &&
            (identical(other.messCode, messCode) ||
                other.messCode == messCode) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.totals, totals) || other.totals == totals));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      clientLogId,
      loggedAt,
      localDate,
      mealSlot,
      entryMethod,
      savedMealId,
      messCode,
      const DeepCollectionEquality().hash(items),
      totals);

  @override
  String toString() {
    return 'FoodLog(id: $id, clientLogId: $clientLogId, loggedAt: $loggedAt, localDate: $localDate, mealSlot: $mealSlot, entryMethod: $entryMethod, savedMealId: $savedMealId, messCode: $messCode, items: $items, totals: $totals)';
  }
}

/// @nodoc
abstract mixin class $FoodLogCopyWith<$Res> {
  factory $FoodLogCopyWith(FoodLog value, $Res Function(FoodLog) _then) =
      _$FoodLogCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String clientLogId,
      String loggedAt,
      String localDate,
      MealSlot mealSlot,
      EntryMethod entryMethod,
      String? savedMealId,
      String? messCode,
      List<FoodLogItem> items,
      NutritionTotals totals});

  $NutritionTotalsCopyWith<$Res> get totals;
}

/// @nodoc
class _$FoodLogCopyWithImpl<$Res> implements $FoodLogCopyWith<$Res> {
  _$FoodLogCopyWithImpl(this._self, this._then);

  final FoodLog _self;
  final $Res Function(FoodLog) _then;

  /// Create a copy of FoodLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientLogId = null,
    Object? loggedAt = null,
    Object? localDate = null,
    Object? mealSlot = null,
    Object? entryMethod = null,
    Object? savedMealId = freezed,
    Object? messCode = freezed,
    Object? items = null,
    Object? totals = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientLogId: null == clientLogId
          ? _self.clientLogId
          : clientLogId // ignore: cast_nullable_to_non_nullable
              as String,
      loggedAt: null == loggedAt
          ? _self.loggedAt
          : loggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      localDate: null == localDate
          ? _self.localDate
          : localDate // ignore: cast_nullable_to_non_nullable
              as String,
      mealSlot: null == mealSlot
          ? _self.mealSlot
          : mealSlot // ignore: cast_nullable_to_non_nullable
              as MealSlot,
      entryMethod: null == entryMethod
          ? _self.entryMethod
          : entryMethod // ignore: cast_nullable_to_non_nullable
              as EntryMethod,
      savedMealId: freezed == savedMealId
          ? _self.savedMealId
          : savedMealId // ignore: cast_nullable_to_non_nullable
              as String?,
      messCode: freezed == messCode
          ? _self.messCode
          : messCode // ignore: cast_nullable_to_non_nullable
              as String?,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FoodLogItem>,
      totals: null == totals
          ? _self.totals
          : totals // ignore: cast_nullable_to_non_nullable
              as NutritionTotals,
    ));
  }

  /// Create a copy of FoodLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTotalsCopyWith<$Res> get totals {
    return $NutritionTotalsCopyWith<$Res>(_self.totals, (value) {
      return _then(_self.copyWith(totals: value));
    });
  }
}

/// Adds pattern-matching-related methods to [FoodLog].
extension FoodLogPatterns on FoodLog {
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
    TResult Function(_FoodLog value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FoodLog() when $default != null:
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
    TResult Function(_FoodLog value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodLog():
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
    TResult? Function(_FoodLog value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodLog() when $default != null:
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
            String clientLogId,
            String loggedAt,
            String localDate,
            MealSlot mealSlot,
            EntryMethod entryMethod,
            String? savedMealId,
            String? messCode,
            List<FoodLogItem> items,
            NutritionTotals totals)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FoodLog() when $default != null:
        return $default(
            _that.id,
            _that.clientLogId,
            _that.loggedAt,
            _that.localDate,
            _that.mealSlot,
            _that.entryMethod,
            _that.savedMealId,
            _that.messCode,
            _that.items,
            _that.totals);
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
            String clientLogId,
            String loggedAt,
            String localDate,
            MealSlot mealSlot,
            EntryMethod entryMethod,
            String? savedMealId,
            String? messCode,
            List<FoodLogItem> items,
            NutritionTotals totals)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodLog():
        return $default(
            _that.id,
            _that.clientLogId,
            _that.loggedAt,
            _that.localDate,
            _that.mealSlot,
            _that.entryMethod,
            _that.savedMealId,
            _that.messCode,
            _that.items,
            _that.totals);
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
            String clientLogId,
            String loggedAt,
            String localDate,
            MealSlot mealSlot,
            EntryMethod entryMethod,
            String? savedMealId,
            String? messCode,
            List<FoodLogItem> items,
            NutritionTotals totals)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FoodLog() when $default != null:
        return $default(
            _that.id,
            _that.clientLogId,
            _that.loggedAt,
            _that.localDate,
            _that.mealSlot,
            _that.entryMethod,
            _that.savedMealId,
            _that.messCode,
            _that.items,
            _that.totals);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FoodLog implements FoodLog {
  const _FoodLog(
      {required this.id,
      required this.clientLogId,
      required this.loggedAt,
      required this.localDate,
      required this.mealSlot,
      required this.entryMethod,
      required this.savedMealId,
      this.messCode = null,
      required final List<FoodLogItem> items,
      required this.totals})
      : _items = items;
  factory _FoodLog.fromJson(Map<String, dynamic> json) =>
      _$FoodLogFromJson(json);

  @override
  final String id;
  @override
  final String clientLogId;
  @override
  final String loggedAt;
  @override
  final String localDate;
  @override
  final MealSlot mealSlot;
  @override
  final EntryMethod entryMethod;
  @override
  final String? savedMealId;

  /// Phase 9: the mess a `mess` log came from.
  @override
  @JsonKey()
  final String? messCode;
  final List<FoodLogItem> _items;
  @override
  List<FoodLogItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final NutritionTotals totals;

  /// Create a copy of FoodLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FoodLogCopyWith<_FoodLog> get copyWith =>
      __$FoodLogCopyWithImpl<_FoodLog>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FoodLogToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FoodLog &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientLogId, clientLogId) ||
                other.clientLogId == clientLogId) &&
            (identical(other.loggedAt, loggedAt) ||
                other.loggedAt == loggedAt) &&
            (identical(other.localDate, localDate) ||
                other.localDate == localDate) &&
            (identical(other.mealSlot, mealSlot) ||
                other.mealSlot == mealSlot) &&
            (identical(other.entryMethod, entryMethod) ||
                other.entryMethod == entryMethod) &&
            (identical(other.savedMealId, savedMealId) ||
                other.savedMealId == savedMealId) &&
            (identical(other.messCode, messCode) ||
                other.messCode == messCode) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.totals, totals) || other.totals == totals));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      clientLogId,
      loggedAt,
      localDate,
      mealSlot,
      entryMethod,
      savedMealId,
      messCode,
      const DeepCollectionEquality().hash(_items),
      totals);

  @override
  String toString() {
    return 'FoodLog(id: $id, clientLogId: $clientLogId, loggedAt: $loggedAt, localDate: $localDate, mealSlot: $mealSlot, entryMethod: $entryMethod, savedMealId: $savedMealId, messCode: $messCode, items: $items, totals: $totals)';
  }
}

/// @nodoc
abstract mixin class _$FoodLogCopyWith<$Res> implements $FoodLogCopyWith<$Res> {
  factory _$FoodLogCopyWith(_FoodLog value, $Res Function(_FoodLog) _then) =
      __$FoodLogCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String clientLogId,
      String loggedAt,
      String localDate,
      MealSlot mealSlot,
      EntryMethod entryMethod,
      String? savedMealId,
      String? messCode,
      List<FoodLogItem> items,
      NutritionTotals totals});

  @override
  $NutritionTotalsCopyWith<$Res> get totals;
}

/// @nodoc
class __$FoodLogCopyWithImpl<$Res> implements _$FoodLogCopyWith<$Res> {
  __$FoodLogCopyWithImpl(this._self, this._then);

  final _FoodLog _self;
  final $Res Function(_FoodLog) _then;

  /// Create a copy of FoodLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? clientLogId = null,
    Object? loggedAt = null,
    Object? localDate = null,
    Object? mealSlot = null,
    Object? entryMethod = null,
    Object? savedMealId = freezed,
    Object? messCode = freezed,
    Object? items = null,
    Object? totals = null,
  }) {
    return _then(_FoodLog(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientLogId: null == clientLogId
          ? _self.clientLogId
          : clientLogId // ignore: cast_nullable_to_non_nullable
              as String,
      loggedAt: null == loggedAt
          ? _self.loggedAt
          : loggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      localDate: null == localDate
          ? _self.localDate
          : localDate // ignore: cast_nullable_to_non_nullable
              as String,
      mealSlot: null == mealSlot
          ? _self.mealSlot
          : mealSlot // ignore: cast_nullable_to_non_nullable
              as MealSlot,
      entryMethod: null == entryMethod
          ? _self.entryMethod
          : entryMethod // ignore: cast_nullable_to_non_nullable
              as EntryMethod,
      savedMealId: freezed == savedMealId
          ? _self.savedMealId
          : savedMealId // ignore: cast_nullable_to_non_nullable
              as String?,
      messCode: freezed == messCode
          ? _self.messCode
          : messCode // ignore: cast_nullable_to_non_nullable
              as String?,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FoodLogItem>,
      totals: null == totals
          ? _self.totals
          : totals // ignore: cast_nullable_to_non_nullable
              as NutritionTotals,
    ));
  }

  /// Create a copy of FoodLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTotalsCopyWith<$Res> get totals {
    return $NutritionTotalsCopyWith<$Res>(_self.totals, (value) {
      return _then(_self.copyWith(totals: value));
    });
  }
}

/// @nodoc
mixin _$RemainingRange {
  double get target;
  double get low;
  double get high;
  RemainingState get state;

  /// Create a copy of RemainingRange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<RemainingRange> get copyWith =>
      _$RemainingRangeCopyWithImpl<RemainingRange>(
          this as RemainingRange, _$identity);

  /// Serializes this RemainingRange to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RemainingRange &&
            (identical(other.target, target) || other.target == target) &&
            (identical(other.low, low) || other.low == low) &&
            (identical(other.high, high) || other.high == high) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, target, low, high, state);

  @override
  String toString() {
    return 'RemainingRange(target: $target, low: $low, high: $high, state: $state)';
  }
}

/// @nodoc
abstract mixin class $RemainingRangeCopyWith<$Res> {
  factory $RemainingRangeCopyWith(
          RemainingRange value, $Res Function(RemainingRange) _then) =
      _$RemainingRangeCopyWithImpl;
  @useResult
  $Res call({double target, double low, double high, RemainingState state});
}

/// @nodoc
class _$RemainingRangeCopyWithImpl<$Res>
    implements $RemainingRangeCopyWith<$Res> {
  _$RemainingRangeCopyWithImpl(this._self, this._then);

  final RemainingRange _self;
  final $Res Function(RemainingRange) _then;

  /// Create a copy of RemainingRange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? target = null,
    Object? low = null,
    Object? high = null,
    Object? state = null,
  }) {
    return _then(_self.copyWith(
      target: null == target
          ? _self.target
          : target // ignore: cast_nullable_to_non_nullable
              as double,
      low: null == low
          ? _self.low
          : low // ignore: cast_nullable_to_non_nullable
              as double,
      high: null == high
          ? _self.high
          : high // ignore: cast_nullable_to_non_nullable
              as double,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as RemainingState,
    ));
  }
}

/// Adds pattern-matching-related methods to [RemainingRange].
extension RemainingRangePatterns on RemainingRange {
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
    TResult Function(_RemainingRange value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RemainingRange() when $default != null:
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
    TResult Function(_RemainingRange value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RemainingRange():
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
    TResult? Function(_RemainingRange value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RemainingRange() when $default != null:
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
            double target, double low, double high, RemainingState state)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RemainingRange() when $default != null:
        return $default(_that.target, _that.low, _that.high, _that.state);
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
            double target, double low, double high, RemainingState state)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RemainingRange():
        return $default(_that.target, _that.low, _that.high, _that.state);
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
            double target, double low, double high, RemainingState state)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RemainingRange() when $default != null:
        return $default(_that.target, _that.low, _that.high, _that.state);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RemainingRange implements RemainingRange {
  const _RemainingRange(
      {required this.target,
      required this.low,
      required this.high,
      required this.state});
  factory _RemainingRange.fromJson(Map<String, dynamic> json) =>
      _$RemainingRangeFromJson(json);

  @override
  final double target;
  @override
  final double low;
  @override
  final double high;
  @override
  final RemainingState state;

  /// Create a copy of RemainingRange
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RemainingRangeCopyWith<_RemainingRange> get copyWith =>
      __$RemainingRangeCopyWithImpl<_RemainingRange>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RemainingRangeToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RemainingRange &&
            (identical(other.target, target) || other.target == target) &&
            (identical(other.low, low) || other.low == low) &&
            (identical(other.high, high) || other.high == high) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, target, low, high, state);

  @override
  String toString() {
    return 'RemainingRange(target: $target, low: $low, high: $high, state: $state)';
  }
}

/// @nodoc
abstract mixin class _$RemainingRangeCopyWith<$Res>
    implements $RemainingRangeCopyWith<$Res> {
  factory _$RemainingRangeCopyWith(
          _RemainingRange value, $Res Function(_RemainingRange) _then) =
      __$RemainingRangeCopyWithImpl;
  @override
  @useResult
  $Res call({double target, double low, double high, RemainingState state});
}

/// @nodoc
class __$RemainingRangeCopyWithImpl<$Res>
    implements _$RemainingRangeCopyWith<$Res> {
  __$RemainingRangeCopyWithImpl(this._self, this._then);

  final _RemainingRange _self;
  final $Res Function(_RemainingRange) _then;

  /// Create a copy of RemainingRange
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? target = null,
    Object? low = null,
    Object? high = null,
    Object? state = null,
  }) {
    return _then(_RemainingRange(
      target: null == target
          ? _self.target
          : target // ignore: cast_nullable_to_non_nullable
              as double,
      low: null == low
          ? _self.low
          : low // ignore: cast_nullable_to_non_nullable
              as double,
      high: null == high
          ? _self.high
          : high // ignore: cast_nullable_to_non_nullable
              as double,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as RemainingState,
    ));
  }
}

/// @nodoc
mixin _$NutritionRemaining {
  RemainingRange get kcal;
  RemainingRange get protein;
  RemainingRange get carb;
  RemainingRange get fat;

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NutritionRemainingCopyWith<NutritionRemaining> get copyWith =>
      _$NutritionRemainingCopyWithImpl<NutritionRemaining>(
          this as NutritionRemaining, _$identity);

  /// Serializes this NutritionRemaining to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NutritionRemaining &&
            (identical(other.kcal, kcal) || other.kcal == kcal) &&
            (identical(other.protein, protein) || other.protein == protein) &&
            (identical(other.carb, carb) || other.carb == carb) &&
            (identical(other.fat, fat) || other.fat == fat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, kcal, protein, carb, fat);

  @override
  String toString() {
    return 'NutritionRemaining(kcal: $kcal, protein: $protein, carb: $carb, fat: $fat)';
  }
}

/// @nodoc
abstract mixin class $NutritionRemainingCopyWith<$Res> {
  factory $NutritionRemainingCopyWith(
          NutritionRemaining value, $Res Function(NutritionRemaining) _then) =
      _$NutritionRemainingCopyWithImpl;
  @useResult
  $Res call(
      {RemainingRange kcal,
      RemainingRange protein,
      RemainingRange carb,
      RemainingRange fat});

  $RemainingRangeCopyWith<$Res> get kcal;
  $RemainingRangeCopyWith<$Res> get protein;
  $RemainingRangeCopyWith<$Res> get carb;
  $RemainingRangeCopyWith<$Res> get fat;
}

/// @nodoc
class _$NutritionRemainingCopyWithImpl<$Res>
    implements $NutritionRemainingCopyWith<$Res> {
  _$NutritionRemainingCopyWithImpl(this._self, this._then);

  final NutritionRemaining _self;
  final $Res Function(NutritionRemaining) _then;

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kcal = null,
    Object? protein = null,
    Object? carb = null,
    Object? fat = null,
  }) {
    return _then(_self.copyWith(
      kcal: null == kcal
          ? _self.kcal
          : kcal // ignore: cast_nullable_to_non_nullable
              as RemainingRange,
      protein: null == protein
          ? _self.protein
          : protein // ignore: cast_nullable_to_non_nullable
              as RemainingRange,
      carb: null == carb
          ? _self.carb
          : carb // ignore: cast_nullable_to_non_nullable
              as RemainingRange,
      fat: null == fat
          ? _self.fat
          : fat // ignore: cast_nullable_to_non_nullable
              as RemainingRange,
    ));
  }

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<$Res> get kcal {
    return $RemainingRangeCopyWith<$Res>(_self.kcal, (value) {
      return _then(_self.copyWith(kcal: value));
    });
  }

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<$Res> get protein {
    return $RemainingRangeCopyWith<$Res>(_self.protein, (value) {
      return _then(_self.copyWith(protein: value));
    });
  }

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<$Res> get carb {
    return $RemainingRangeCopyWith<$Res>(_self.carb, (value) {
      return _then(_self.copyWith(carb: value));
    });
  }

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<$Res> get fat {
    return $RemainingRangeCopyWith<$Res>(_self.fat, (value) {
      return _then(_self.copyWith(fat: value));
    });
  }
}

/// Adds pattern-matching-related methods to [NutritionRemaining].
extension NutritionRemainingPatterns on NutritionRemaining {
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
    TResult Function(_NutritionRemaining value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NutritionRemaining() when $default != null:
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
    TResult Function(_NutritionRemaining value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionRemaining():
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
    TResult? Function(_NutritionRemaining value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionRemaining() when $default != null:
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
    TResult Function(RemainingRange kcal, RemainingRange protein,
            RemainingRange carb, RemainingRange fat)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NutritionRemaining() when $default != null:
        return $default(_that.kcal, _that.protein, _that.carb, _that.fat);
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
    TResult Function(RemainingRange kcal, RemainingRange protein,
            RemainingRange carb, RemainingRange fat)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionRemaining():
        return $default(_that.kcal, _that.protein, _that.carb, _that.fat);
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
    TResult? Function(RemainingRange kcal, RemainingRange protein,
            RemainingRange carb, RemainingRange fat)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionRemaining() when $default != null:
        return $default(_that.kcal, _that.protein, _that.carb, _that.fat);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _NutritionRemaining implements NutritionRemaining {
  const _NutritionRemaining(
      {required this.kcal,
      required this.protein,
      required this.carb,
      required this.fat});
  factory _NutritionRemaining.fromJson(Map<String, dynamic> json) =>
      _$NutritionRemainingFromJson(json);

  @override
  final RemainingRange kcal;
  @override
  final RemainingRange protein;
  @override
  final RemainingRange carb;
  @override
  final RemainingRange fat;

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NutritionRemainingCopyWith<_NutritionRemaining> get copyWith =>
      __$NutritionRemainingCopyWithImpl<_NutritionRemaining>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NutritionRemainingToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NutritionRemaining &&
            (identical(other.kcal, kcal) || other.kcal == kcal) &&
            (identical(other.protein, protein) || other.protein == protein) &&
            (identical(other.carb, carb) || other.carb == carb) &&
            (identical(other.fat, fat) || other.fat == fat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, kcal, protein, carb, fat);

  @override
  String toString() {
    return 'NutritionRemaining(kcal: $kcal, protein: $protein, carb: $carb, fat: $fat)';
  }
}

/// @nodoc
abstract mixin class _$NutritionRemainingCopyWith<$Res>
    implements $NutritionRemainingCopyWith<$Res> {
  factory _$NutritionRemainingCopyWith(
          _NutritionRemaining value, $Res Function(_NutritionRemaining) _then) =
      __$NutritionRemainingCopyWithImpl;
  @override
  @useResult
  $Res call(
      {RemainingRange kcal,
      RemainingRange protein,
      RemainingRange carb,
      RemainingRange fat});

  @override
  $RemainingRangeCopyWith<$Res> get kcal;
  @override
  $RemainingRangeCopyWith<$Res> get protein;
  @override
  $RemainingRangeCopyWith<$Res> get carb;
  @override
  $RemainingRangeCopyWith<$Res> get fat;
}

/// @nodoc
class __$NutritionRemainingCopyWithImpl<$Res>
    implements _$NutritionRemainingCopyWith<$Res> {
  __$NutritionRemainingCopyWithImpl(this._self, this._then);

  final _NutritionRemaining _self;
  final $Res Function(_NutritionRemaining) _then;

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? kcal = null,
    Object? protein = null,
    Object? carb = null,
    Object? fat = null,
  }) {
    return _then(_NutritionRemaining(
      kcal: null == kcal
          ? _self.kcal
          : kcal // ignore: cast_nullable_to_non_nullable
              as RemainingRange,
      protein: null == protein
          ? _self.protein
          : protein // ignore: cast_nullable_to_non_nullable
              as RemainingRange,
      carb: null == carb
          ? _self.carb
          : carb // ignore: cast_nullable_to_non_nullable
              as RemainingRange,
      fat: null == fat
          ? _self.fat
          : fat // ignore: cast_nullable_to_non_nullable
              as RemainingRange,
    ));
  }

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<$Res> get kcal {
    return $RemainingRangeCopyWith<$Res>(_self.kcal, (value) {
      return _then(_self.copyWith(kcal: value));
    });
  }

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<$Res> get protein {
    return $RemainingRangeCopyWith<$Res>(_self.protein, (value) {
      return _then(_self.copyWith(protein: value));
    });
  }

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<$Res> get carb {
    return $RemainingRangeCopyWith<$Res>(_self.carb, (value) {
      return _then(_self.copyWith(carb: value));
    });
  }

  /// Create a copy of NutritionRemaining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemainingRangeCopyWith<$Res> get fat {
    return $RemainingRangeCopyWith<$Res>(_self.fat, (value) {
      return _then(_self.copyWith(fat: value));
    });
  }
}

/// @nodoc
mixin _$NutritionDay {
  String get date;
  String get today;
  String get timezone;
  NutritionTargets? get targets;
  NutritionTotals get totals;
  NutritionRemaining? get remaining;
  List<FoodLog> get logs;

  /// Create a copy of NutritionDay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NutritionDayCopyWith<NutritionDay> get copyWith =>
      _$NutritionDayCopyWithImpl<NutritionDay>(
          this as NutritionDay, _$identity);

  /// Serializes this NutritionDay to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NutritionDay &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.today, today) || other.today == today) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.targets, targets) || other.targets == targets) &&
            (identical(other.totals, totals) || other.totals == totals) &&
            (identical(other.remaining, remaining) ||
                other.remaining == remaining) &&
            const DeepCollectionEquality().equals(other.logs, logs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, today, timezone, targets,
      totals, remaining, const DeepCollectionEquality().hash(logs));

  @override
  String toString() {
    return 'NutritionDay(date: $date, today: $today, timezone: $timezone, targets: $targets, totals: $totals, remaining: $remaining, logs: $logs)';
  }
}

/// @nodoc
abstract mixin class $NutritionDayCopyWith<$Res> {
  factory $NutritionDayCopyWith(
          NutritionDay value, $Res Function(NutritionDay) _then) =
      _$NutritionDayCopyWithImpl;
  @useResult
  $Res call(
      {String date,
      String today,
      String timezone,
      NutritionTargets? targets,
      NutritionTotals totals,
      NutritionRemaining? remaining,
      List<FoodLog> logs});

  $NutritionTargetsCopyWith<$Res>? get targets;
  $NutritionTotalsCopyWith<$Res> get totals;
  $NutritionRemainingCopyWith<$Res>? get remaining;
}

/// @nodoc
class _$NutritionDayCopyWithImpl<$Res> implements $NutritionDayCopyWith<$Res> {
  _$NutritionDayCopyWithImpl(this._self, this._then);

  final NutritionDay _self;
  final $Res Function(NutritionDay) _then;

  /// Create a copy of NutritionDay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? today = null,
    Object? timezone = null,
    Object? targets = freezed,
    Object? totals = null,
    Object? remaining = freezed,
    Object? logs = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      today: null == today
          ? _self.today
          : today // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      targets: freezed == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as NutritionTargets?,
      totals: null == totals
          ? _self.totals
          : totals // ignore: cast_nullable_to_non_nullable
              as NutritionTotals,
      remaining: freezed == remaining
          ? _self.remaining
          : remaining // ignore: cast_nullable_to_non_nullable
              as NutritionRemaining?,
      logs: null == logs
          ? _self.logs
          : logs // ignore: cast_nullable_to_non_nullable
              as List<FoodLog>,
    ));
  }

  /// Create a copy of NutritionDay
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

  /// Create a copy of NutritionDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTotalsCopyWith<$Res> get totals {
    return $NutritionTotalsCopyWith<$Res>(_self.totals, (value) {
      return _then(_self.copyWith(totals: value));
    });
  }

  /// Create a copy of NutritionDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionRemainingCopyWith<$Res>? get remaining {
    if (_self.remaining == null) {
      return null;
    }

    return $NutritionRemainingCopyWith<$Res>(_self.remaining!, (value) {
      return _then(_self.copyWith(remaining: value));
    });
  }
}

/// Adds pattern-matching-related methods to [NutritionDay].
extension NutritionDayPatterns on NutritionDay {
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
    TResult Function(_NutritionDay value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NutritionDay() when $default != null:
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
    TResult Function(_NutritionDay value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionDay():
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
    TResult? Function(_NutritionDay value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionDay() when $default != null:
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
            String today,
            String timezone,
            NutritionTargets? targets,
            NutritionTotals totals,
            NutritionRemaining? remaining,
            List<FoodLog> logs)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NutritionDay() when $default != null:
        return $default(_that.date, _that.today, _that.timezone, _that.targets,
            _that.totals, _that.remaining, _that.logs);
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
            String today,
            String timezone,
            NutritionTargets? targets,
            NutritionTotals totals,
            NutritionRemaining? remaining,
            List<FoodLog> logs)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionDay():
        return $default(_that.date, _that.today, _that.timezone, _that.targets,
            _that.totals, _that.remaining, _that.logs);
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
            String today,
            String timezone,
            NutritionTargets? targets,
            NutritionTotals totals,
            NutritionRemaining? remaining,
            List<FoodLog> logs)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NutritionDay() when $default != null:
        return $default(_that.date, _that.today, _that.timezone, _that.targets,
            _that.totals, _that.remaining, _that.logs);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _NutritionDay implements NutritionDay {
  const _NutritionDay(
      {required this.date,
      required this.today,
      required this.timezone,
      required this.targets,
      required this.totals,
      required this.remaining,
      required final List<FoodLog> logs})
      : _logs = logs;
  factory _NutritionDay.fromJson(Map<String, dynamic> json) =>
      _$NutritionDayFromJson(json);

  @override
  final String date;
  @override
  final String today;
  @override
  final String timezone;
  @override
  final NutritionTargets? targets;
  @override
  final NutritionTotals totals;
  @override
  final NutritionRemaining? remaining;
  final List<FoodLog> _logs;
  @override
  List<FoodLog> get logs {
    if (_logs is EqualUnmodifiableListView) return _logs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_logs);
  }

  /// Create a copy of NutritionDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NutritionDayCopyWith<_NutritionDay> get copyWith =>
      __$NutritionDayCopyWithImpl<_NutritionDay>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NutritionDayToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NutritionDay &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.today, today) || other.today == today) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.targets, targets) || other.targets == targets) &&
            (identical(other.totals, totals) || other.totals == totals) &&
            (identical(other.remaining, remaining) ||
                other.remaining == remaining) &&
            const DeepCollectionEquality().equals(other._logs, _logs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, today, timezone, targets,
      totals, remaining, const DeepCollectionEquality().hash(_logs));

  @override
  String toString() {
    return 'NutritionDay(date: $date, today: $today, timezone: $timezone, targets: $targets, totals: $totals, remaining: $remaining, logs: $logs)';
  }
}

/// @nodoc
abstract mixin class _$NutritionDayCopyWith<$Res>
    implements $NutritionDayCopyWith<$Res> {
  factory _$NutritionDayCopyWith(
          _NutritionDay value, $Res Function(_NutritionDay) _then) =
      __$NutritionDayCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String date,
      String today,
      String timezone,
      NutritionTargets? targets,
      NutritionTotals totals,
      NutritionRemaining? remaining,
      List<FoodLog> logs});

  @override
  $NutritionTargetsCopyWith<$Res>? get targets;
  @override
  $NutritionTotalsCopyWith<$Res> get totals;
  @override
  $NutritionRemainingCopyWith<$Res>? get remaining;
}

/// @nodoc
class __$NutritionDayCopyWithImpl<$Res>
    implements _$NutritionDayCopyWith<$Res> {
  __$NutritionDayCopyWithImpl(this._self, this._then);

  final _NutritionDay _self;
  final $Res Function(_NutritionDay) _then;

  /// Create a copy of NutritionDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? today = null,
    Object? timezone = null,
    Object? targets = freezed,
    Object? totals = null,
    Object? remaining = freezed,
    Object? logs = null,
  }) {
    return _then(_NutritionDay(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      today: null == today
          ? _self.today
          : today // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      targets: freezed == targets
          ? _self.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as NutritionTargets?,
      totals: null == totals
          ? _self.totals
          : totals // ignore: cast_nullable_to_non_nullable
              as NutritionTotals,
      remaining: freezed == remaining
          ? _self.remaining
          : remaining // ignore: cast_nullable_to_non_nullable
              as NutritionRemaining?,
      logs: null == logs
          ? _self._logs
          : logs // ignore: cast_nullable_to_non_nullable
              as List<FoodLog>,
    ));
  }

  /// Create a copy of NutritionDay
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

  /// Create a copy of NutritionDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionTotalsCopyWith<$Res> get totals {
    return $NutritionTotalsCopyWith<$Res>(_self.totals, (value) {
      return _then(_self.copyWith(totals: value));
    });
  }

  /// Create a copy of NutritionDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionRemainingCopyWith<$Res>? get remaining {
    if (_self.remaining == null) {
      return null;
    }

    return $NutritionRemainingCopyWith<$Res>(_self.remaining!, (value) {
      return _then(_self.copyWith(remaining: value));
    });
  }
}

/// @nodoc
mixin _$CreateLogResponse {
  FoodLog get log;
  NutritionDay get day;

  /// Create a copy of CreateLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CreateLogResponseCopyWith<CreateLogResponse> get copyWith =>
      _$CreateLogResponseCopyWithImpl<CreateLogResponse>(
          this as CreateLogResponse, _$identity);

  /// Serializes this CreateLogResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CreateLogResponse &&
            (identical(other.log, log) || other.log == log) &&
            (identical(other.day, day) || other.day == day));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, log, day);

  @override
  String toString() {
    return 'CreateLogResponse(log: $log, day: $day)';
  }
}

/// @nodoc
abstract mixin class $CreateLogResponseCopyWith<$Res> {
  factory $CreateLogResponseCopyWith(
          CreateLogResponse value, $Res Function(CreateLogResponse) _then) =
      _$CreateLogResponseCopyWithImpl;
  @useResult
  $Res call({FoodLog log, NutritionDay day});

  $FoodLogCopyWith<$Res> get log;
  $NutritionDayCopyWith<$Res> get day;
}

/// @nodoc
class _$CreateLogResponseCopyWithImpl<$Res>
    implements $CreateLogResponseCopyWith<$Res> {
  _$CreateLogResponseCopyWithImpl(this._self, this._then);

  final CreateLogResponse _self;
  final $Res Function(CreateLogResponse) _then;

  /// Create a copy of CreateLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? log = null,
    Object? day = null,
  }) {
    return _then(_self.copyWith(
      log: null == log
          ? _self.log
          : log // ignore: cast_nullable_to_non_nullable
              as FoodLog,
      day: null == day
          ? _self.day
          : day // ignore: cast_nullable_to_non_nullable
              as NutritionDay,
    ));
  }

  /// Create a copy of CreateLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FoodLogCopyWith<$Res> get log {
    return $FoodLogCopyWith<$Res>(_self.log, (value) {
      return _then(_self.copyWith(log: value));
    });
  }

  /// Create a copy of CreateLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionDayCopyWith<$Res> get day {
    return $NutritionDayCopyWith<$Res>(_self.day, (value) {
      return _then(_self.copyWith(day: value));
    });
  }
}

/// Adds pattern-matching-related methods to [CreateLogResponse].
extension CreateLogResponsePatterns on CreateLogResponse {
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
    TResult Function(_CreateLogResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CreateLogResponse() when $default != null:
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
    TResult Function(_CreateLogResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateLogResponse():
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
    TResult? Function(_CreateLogResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateLogResponse() when $default != null:
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
    TResult Function(FoodLog log, NutritionDay day)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CreateLogResponse() when $default != null:
        return $default(_that.log, _that.day);
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
    TResult Function(FoodLog log, NutritionDay day) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateLogResponse():
        return $default(_that.log, _that.day);
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
    TResult? Function(FoodLog log, NutritionDay day)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreateLogResponse() when $default != null:
        return $default(_that.log, _that.day);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CreateLogResponse implements CreateLogResponse {
  const _CreateLogResponse({required this.log, required this.day});
  factory _CreateLogResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateLogResponseFromJson(json);

  @override
  final FoodLog log;
  @override
  final NutritionDay day;

  /// Create a copy of CreateLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CreateLogResponseCopyWith<_CreateLogResponse> get copyWith =>
      __$CreateLogResponseCopyWithImpl<_CreateLogResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CreateLogResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CreateLogResponse &&
            (identical(other.log, log) || other.log == log) &&
            (identical(other.day, day) || other.day == day));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, log, day);

  @override
  String toString() {
    return 'CreateLogResponse(log: $log, day: $day)';
  }
}

/// @nodoc
abstract mixin class _$CreateLogResponseCopyWith<$Res>
    implements $CreateLogResponseCopyWith<$Res> {
  factory _$CreateLogResponseCopyWith(
          _CreateLogResponse value, $Res Function(_CreateLogResponse) _then) =
      __$CreateLogResponseCopyWithImpl;
  @override
  @useResult
  $Res call({FoodLog log, NutritionDay day});

  @override
  $FoodLogCopyWith<$Res> get log;
  @override
  $NutritionDayCopyWith<$Res> get day;
}

/// @nodoc
class __$CreateLogResponseCopyWithImpl<$Res>
    implements _$CreateLogResponseCopyWith<$Res> {
  __$CreateLogResponseCopyWithImpl(this._self, this._then);

  final _CreateLogResponse _self;
  final $Res Function(_CreateLogResponse) _then;

  /// Create a copy of CreateLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? log = null,
    Object? day = null,
  }) {
    return _then(_CreateLogResponse(
      log: null == log
          ? _self.log
          : log // ignore: cast_nullable_to_non_nullable
              as FoodLog,
      day: null == day
          ? _self.day
          : day // ignore: cast_nullable_to_non_nullable
              as NutritionDay,
    ));
  }

  /// Create a copy of CreateLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FoodLogCopyWith<$Res> get log {
    return $FoodLogCopyWith<$Res>(_self.log, (value) {
      return _then(_self.copyWith(log: value));
    });
  }

  /// Create a copy of CreateLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionDayCopyWith<$Res> get day {
    return $NutritionDayCopyWith<$Res>(_self.day, (value) {
      return _then(_self.copyWith(day: value));
    });
  }
}

/// @nodoc
mixin _$DeleteLogResponse {
  NutritionDay get day;

  /// Create a copy of DeleteLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DeleteLogResponseCopyWith<DeleteLogResponse> get copyWith =>
      _$DeleteLogResponseCopyWithImpl<DeleteLogResponse>(
          this as DeleteLogResponse, _$identity);

  /// Serializes this DeleteLogResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DeleteLogResponse &&
            (identical(other.day, day) || other.day == day));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, day);

  @override
  String toString() {
    return 'DeleteLogResponse(day: $day)';
  }
}

/// @nodoc
abstract mixin class $DeleteLogResponseCopyWith<$Res> {
  factory $DeleteLogResponseCopyWith(
          DeleteLogResponse value, $Res Function(DeleteLogResponse) _then) =
      _$DeleteLogResponseCopyWithImpl;
  @useResult
  $Res call({NutritionDay day});

  $NutritionDayCopyWith<$Res> get day;
}

/// @nodoc
class _$DeleteLogResponseCopyWithImpl<$Res>
    implements $DeleteLogResponseCopyWith<$Res> {
  _$DeleteLogResponseCopyWithImpl(this._self, this._then);

  final DeleteLogResponse _self;
  final $Res Function(DeleteLogResponse) _then;

  /// Create a copy of DeleteLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? day = null,
  }) {
    return _then(_self.copyWith(
      day: null == day
          ? _self.day
          : day // ignore: cast_nullable_to_non_nullable
              as NutritionDay,
    ));
  }

  /// Create a copy of DeleteLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionDayCopyWith<$Res> get day {
    return $NutritionDayCopyWith<$Res>(_self.day, (value) {
      return _then(_self.copyWith(day: value));
    });
  }
}

/// Adds pattern-matching-related methods to [DeleteLogResponse].
extension DeleteLogResponsePatterns on DeleteLogResponse {
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
    TResult Function(_DeleteLogResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeleteLogResponse() when $default != null:
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
    TResult Function(_DeleteLogResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeleteLogResponse():
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
    TResult? Function(_DeleteLogResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeleteLogResponse() when $default != null:
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
    TResult Function(NutritionDay day)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeleteLogResponse() when $default != null:
        return $default(_that.day);
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
    TResult Function(NutritionDay day) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeleteLogResponse():
        return $default(_that.day);
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
    TResult? Function(NutritionDay day)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeleteLogResponse() when $default != null:
        return $default(_that.day);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DeleteLogResponse implements DeleteLogResponse {
  const _DeleteLogResponse({required this.day});
  factory _DeleteLogResponse.fromJson(Map<String, dynamic> json) =>
      _$DeleteLogResponseFromJson(json);

  @override
  final NutritionDay day;

  /// Create a copy of DeleteLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DeleteLogResponseCopyWith<_DeleteLogResponse> get copyWith =>
      __$DeleteLogResponseCopyWithImpl<_DeleteLogResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DeleteLogResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DeleteLogResponse &&
            (identical(other.day, day) || other.day == day));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, day);

  @override
  String toString() {
    return 'DeleteLogResponse(day: $day)';
  }
}

/// @nodoc
abstract mixin class _$DeleteLogResponseCopyWith<$Res>
    implements $DeleteLogResponseCopyWith<$Res> {
  factory _$DeleteLogResponseCopyWith(
          _DeleteLogResponse value, $Res Function(_DeleteLogResponse) _then) =
      __$DeleteLogResponseCopyWithImpl;
  @override
  @useResult
  $Res call({NutritionDay day});

  @override
  $NutritionDayCopyWith<$Res> get day;
}

/// @nodoc
class __$DeleteLogResponseCopyWithImpl<$Res>
    implements _$DeleteLogResponseCopyWith<$Res> {
  __$DeleteLogResponseCopyWithImpl(this._self, this._then);

  final _DeleteLogResponse _self;
  final $Res Function(_DeleteLogResponse) _then;

  /// Create a copy of DeleteLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? day = null,
  }) {
    return _then(_DeleteLogResponse(
      day: null == day
          ? _self.day
          : day // ignore: cast_nullable_to_non_nullable
              as NutritionDay,
    ));
  }

  /// Create a copy of DeleteLogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NutritionDayCopyWith<$Res> get day {
    return $NutritionDayCopyWith<$Res>(_self.day, (value) {
      return _then(_self.copyWith(day: value));
    });
  }
}

/// @nodoc
mixin _$RecentFood {
  Food get food;
  String get lastLoggedAt;
  NutritionBasis get lastBasis;
  String get lastServingLabel;
  double get lastServings;

  /// Create a copy of RecentFood
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RecentFoodCopyWith<RecentFood> get copyWith =>
      _$RecentFoodCopyWithImpl<RecentFood>(this as RecentFood, _$identity);

  /// Serializes this RecentFood to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RecentFood &&
            (identical(other.food, food) || other.food == food) &&
            (identical(other.lastLoggedAt, lastLoggedAt) ||
                other.lastLoggedAt == lastLoggedAt) &&
            (identical(other.lastBasis, lastBasis) ||
                other.lastBasis == lastBasis) &&
            (identical(other.lastServingLabel, lastServingLabel) ||
                other.lastServingLabel == lastServingLabel) &&
            (identical(other.lastServings, lastServings) ||
                other.lastServings == lastServings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, food, lastLoggedAt, lastBasis,
      lastServingLabel, lastServings);

  @override
  String toString() {
    return 'RecentFood(food: $food, lastLoggedAt: $lastLoggedAt, lastBasis: $lastBasis, lastServingLabel: $lastServingLabel, lastServings: $lastServings)';
  }
}

/// @nodoc
abstract mixin class $RecentFoodCopyWith<$Res> {
  factory $RecentFoodCopyWith(
          RecentFood value, $Res Function(RecentFood) _then) =
      _$RecentFoodCopyWithImpl;
  @useResult
  $Res call(
      {Food food,
      String lastLoggedAt,
      NutritionBasis lastBasis,
      String lastServingLabel,
      double lastServings});

  $FoodCopyWith<$Res> get food;
}

/// @nodoc
class _$RecentFoodCopyWithImpl<$Res> implements $RecentFoodCopyWith<$Res> {
  _$RecentFoodCopyWithImpl(this._self, this._then);

  final RecentFood _self;
  final $Res Function(RecentFood) _then;

  /// Create a copy of RecentFood
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? food = null,
    Object? lastLoggedAt = null,
    Object? lastBasis = null,
    Object? lastServingLabel = null,
    Object? lastServings = null,
  }) {
    return _then(_self.copyWith(
      food: null == food
          ? _self.food
          : food // ignore: cast_nullable_to_non_nullable
              as Food,
      lastLoggedAt: null == lastLoggedAt
          ? _self.lastLoggedAt
          : lastLoggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      lastBasis: null == lastBasis
          ? _self.lastBasis
          : lastBasis // ignore: cast_nullable_to_non_nullable
              as NutritionBasis,
      lastServingLabel: null == lastServingLabel
          ? _self.lastServingLabel
          : lastServingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      lastServings: null == lastServings
          ? _self.lastServings
          : lastServings // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }

  /// Create a copy of RecentFood
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FoodCopyWith<$Res> get food {
    return $FoodCopyWith<$Res>(_self.food, (value) {
      return _then(_self.copyWith(food: value));
    });
  }
}

/// Adds pattern-matching-related methods to [RecentFood].
extension RecentFoodPatterns on RecentFood {
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
    TResult Function(_RecentFood value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RecentFood() when $default != null:
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
    TResult Function(_RecentFood value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecentFood():
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
    TResult? Function(_RecentFood value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecentFood() when $default != null:
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
    TResult Function(Food food, String lastLoggedAt, NutritionBasis lastBasis,
            String lastServingLabel, double lastServings)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RecentFood() when $default != null:
        return $default(_that.food, _that.lastLoggedAt, _that.lastBasis,
            _that.lastServingLabel, _that.lastServings);
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
    TResult Function(Food food, String lastLoggedAt, NutritionBasis lastBasis,
            String lastServingLabel, double lastServings)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecentFood():
        return $default(_that.food, _that.lastLoggedAt, _that.lastBasis,
            _that.lastServingLabel, _that.lastServings);
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
    TResult? Function(Food food, String lastLoggedAt, NutritionBasis lastBasis,
            String lastServingLabel, double lastServings)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecentFood() when $default != null:
        return $default(_that.food, _that.lastLoggedAt, _that.lastBasis,
            _that.lastServingLabel, _that.lastServings);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RecentFood implements RecentFood {
  const _RecentFood(
      {required this.food,
      required this.lastLoggedAt,
      required this.lastBasis,
      required this.lastServingLabel,
      required this.lastServings});
  factory _RecentFood.fromJson(Map<String, dynamic> json) =>
      _$RecentFoodFromJson(json);

  @override
  final Food food;
  @override
  final String lastLoggedAt;
  @override
  final NutritionBasis lastBasis;
  @override
  final String lastServingLabel;
  @override
  final double lastServings;

  /// Create a copy of RecentFood
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RecentFoodCopyWith<_RecentFood> get copyWith =>
      __$RecentFoodCopyWithImpl<_RecentFood>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RecentFoodToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RecentFood &&
            (identical(other.food, food) || other.food == food) &&
            (identical(other.lastLoggedAt, lastLoggedAt) ||
                other.lastLoggedAt == lastLoggedAt) &&
            (identical(other.lastBasis, lastBasis) ||
                other.lastBasis == lastBasis) &&
            (identical(other.lastServingLabel, lastServingLabel) ||
                other.lastServingLabel == lastServingLabel) &&
            (identical(other.lastServings, lastServings) ||
                other.lastServings == lastServings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, food, lastLoggedAt, lastBasis,
      lastServingLabel, lastServings);

  @override
  String toString() {
    return 'RecentFood(food: $food, lastLoggedAt: $lastLoggedAt, lastBasis: $lastBasis, lastServingLabel: $lastServingLabel, lastServings: $lastServings)';
  }
}

/// @nodoc
abstract mixin class _$RecentFoodCopyWith<$Res>
    implements $RecentFoodCopyWith<$Res> {
  factory _$RecentFoodCopyWith(
          _RecentFood value, $Res Function(_RecentFood) _then) =
      __$RecentFoodCopyWithImpl;
  @override
  @useResult
  $Res call(
      {Food food,
      String lastLoggedAt,
      NutritionBasis lastBasis,
      String lastServingLabel,
      double lastServings});

  @override
  $FoodCopyWith<$Res> get food;
}

/// @nodoc
class __$RecentFoodCopyWithImpl<$Res> implements _$RecentFoodCopyWith<$Res> {
  __$RecentFoodCopyWithImpl(this._self, this._then);

  final _RecentFood _self;
  final $Res Function(_RecentFood) _then;

  /// Create a copy of RecentFood
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? food = null,
    Object? lastLoggedAt = null,
    Object? lastBasis = null,
    Object? lastServingLabel = null,
    Object? lastServings = null,
  }) {
    return _then(_RecentFood(
      food: null == food
          ? _self.food
          : food // ignore: cast_nullable_to_non_nullable
              as Food,
      lastLoggedAt: null == lastLoggedAt
          ? _self.lastLoggedAt
          : lastLoggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      lastBasis: null == lastBasis
          ? _self.lastBasis
          : lastBasis // ignore: cast_nullable_to_non_nullable
              as NutritionBasis,
      lastServingLabel: null == lastServingLabel
          ? _self.lastServingLabel
          : lastServingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      lastServings: null == lastServings
          ? _self.lastServings
          : lastServings // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }

  /// Create a copy of RecentFood
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FoodCopyWith<$Res> get food {
    return $FoodCopyWith<$Res>(_self.food, (value) {
      return _then(_self.copyWith(food: value));
    });
  }
}

/// @nodoc
mixin _$RecentFoodsResponse {
  List<RecentFood> get items;

  /// Create a copy of RecentFoodsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RecentFoodsResponseCopyWith<RecentFoodsResponse> get copyWith =>
      _$RecentFoodsResponseCopyWithImpl<RecentFoodsResponse>(
          this as RecentFoodsResponse, _$identity);

  /// Serializes this RecentFoodsResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RecentFoodsResponse &&
            const DeepCollectionEquality().equals(other.items, items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(items));

  @override
  String toString() {
    return 'RecentFoodsResponse(items: $items)';
  }
}

/// @nodoc
abstract mixin class $RecentFoodsResponseCopyWith<$Res> {
  factory $RecentFoodsResponseCopyWith(
          RecentFoodsResponse value, $Res Function(RecentFoodsResponse) _then) =
      _$RecentFoodsResponseCopyWithImpl;
  @useResult
  $Res call({List<RecentFood> items});
}

/// @nodoc
class _$RecentFoodsResponseCopyWithImpl<$Res>
    implements $RecentFoodsResponseCopyWith<$Res> {
  _$RecentFoodsResponseCopyWithImpl(this._self, this._then);

  final RecentFoodsResponse _self;
  final $Res Function(RecentFoodsResponse) _then;

  /// Create a copy of RecentFoodsResponse
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
              as List<RecentFood>,
    ));
  }
}

/// Adds pattern-matching-related methods to [RecentFoodsResponse].
extension RecentFoodsResponsePatterns on RecentFoodsResponse {
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
    TResult Function(_RecentFoodsResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RecentFoodsResponse() when $default != null:
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
    TResult Function(_RecentFoodsResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecentFoodsResponse():
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
    TResult? Function(_RecentFoodsResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecentFoodsResponse() when $default != null:
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
    TResult Function(List<RecentFood> items)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RecentFoodsResponse() when $default != null:
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
    TResult Function(List<RecentFood> items) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecentFoodsResponse():
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
    TResult? Function(List<RecentFood> items)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecentFoodsResponse() when $default != null:
        return $default(_that.items);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RecentFoodsResponse implements RecentFoodsResponse {
  const _RecentFoodsResponse({required final List<RecentFood> items})
      : _items = items;
  factory _RecentFoodsResponse.fromJson(Map<String, dynamic> json) =>
      _$RecentFoodsResponseFromJson(json);

  final List<RecentFood> _items;
  @override
  List<RecentFood> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// Create a copy of RecentFoodsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RecentFoodsResponseCopyWith<_RecentFoodsResponse> get copyWith =>
      __$RecentFoodsResponseCopyWithImpl<_RecentFoodsResponse>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RecentFoodsResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RecentFoodsResponse &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_items));

  @override
  String toString() {
    return 'RecentFoodsResponse(items: $items)';
  }
}

/// @nodoc
abstract mixin class _$RecentFoodsResponseCopyWith<$Res>
    implements $RecentFoodsResponseCopyWith<$Res> {
  factory _$RecentFoodsResponseCopyWith(_RecentFoodsResponse value,
          $Res Function(_RecentFoodsResponse) _then) =
      __$RecentFoodsResponseCopyWithImpl;
  @override
  @useResult
  $Res call({List<RecentFood> items});
}

/// @nodoc
class __$RecentFoodsResponseCopyWithImpl<$Res>
    implements _$RecentFoodsResponseCopyWith<$Res> {
  __$RecentFoodsResponseCopyWithImpl(this._self, this._then);

  final _RecentFoodsResponse _self;
  final $Res Function(_RecentFoodsResponse) _then;

  /// Create a copy of RecentFoodsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
  }) {
    return _then(_RecentFoodsResponse(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<RecentFood>,
    ));
  }
}

// dart format on
