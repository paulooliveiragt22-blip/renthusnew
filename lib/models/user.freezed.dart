// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Client _$ClientFromJson(Map<String, dynamic> json) {
  return _Client.fromJson(json);
}

/// @nodoc
mixin _$Client {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get state => throw _privateConstructorUsedError;
  String? get cpf => throw _privateConstructorUsedError;
  String? get addressStreet => throw _privateConstructorUsedError;
  String? get addressNumber => throw _privateConstructorUsedError;
  String? get addressDistrict => throw _privateConstructorUsedError;
  String? get addressZipCode => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  bool? get phoneVerified => throw _privateConstructorUsedError;
  bool? get emailVerified => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Client to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClientCopyWith<Client> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClientCopyWith<$Res> {
  factory $ClientCopyWith(Client value, $Res Function(Client) then) =
      _$ClientCopyWithImpl<$Res, Client>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String name,
      String email,
      String phone,
      String city,
      String state,
      String? cpf,
      String? addressStreet,
      String? addressNumber,
      String? addressDistrict,
      String? addressZipCode,
      String? photoUrl,
      bool? phoneVerified,
      bool? emailVerified,
      DateTime createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$ClientCopyWithImpl<$Res, $Val extends Client>
    implements $ClientCopyWith<$Res> {
  _$ClientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? city = null,
    Object? state = null,
    Object? cpf = freezed,
    Object? addressStreet = freezed,
    Object? addressNumber = freezed,
    Object? addressDistrict = freezed,
    Object? addressZipCode = freezed,
    Object? photoUrl = freezed,
    Object? phoneVerified = freezed,
    Object? emailVerified = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      cpf: freezed == cpf
          ? _value.cpf
          : cpf // ignore: cast_nullable_to_non_nullable
              as String?,
      addressStreet: freezed == addressStreet
          ? _value.addressStreet
          : addressStreet // ignore: cast_nullable_to_non_nullable
              as String?,
      addressNumber: freezed == addressNumber
          ? _value.addressNumber
          : addressNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      addressDistrict: freezed == addressDistrict
          ? _value.addressDistrict
          : addressDistrict // ignore: cast_nullable_to_non_nullable
              as String?,
      addressZipCode: freezed == addressZipCode
          ? _value.addressZipCode
          : addressZipCode // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      phoneVerified: freezed == phoneVerified
          ? _value.phoneVerified
          : phoneVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      emailVerified: freezed == emailVerified
          ? _value.emailVerified
          : emailVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ClientImplCopyWith<$Res> implements $ClientCopyWith<$Res> {
  factory _$$ClientImplCopyWith(
          _$ClientImpl value, $Res Function(_$ClientImpl) then) =
      __$$ClientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String name,
      String email,
      String phone,
      String city,
      String state,
      String? cpf,
      String? addressStreet,
      String? addressNumber,
      String? addressDistrict,
      String? addressZipCode,
      String? photoUrl,
      bool? phoneVerified,
      bool? emailVerified,
      DateTime createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$ClientImplCopyWithImpl<$Res>
    extends _$ClientCopyWithImpl<$Res, _$ClientImpl>
    implements _$$ClientImplCopyWith<$Res> {
  __$$ClientImplCopyWithImpl(
      _$ClientImpl _value, $Res Function(_$ClientImpl) _then)
      : super(_value, _then);

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? city = null,
    Object? state = null,
    Object? cpf = freezed,
    Object? addressStreet = freezed,
    Object? addressNumber = freezed,
    Object? addressDistrict = freezed,
    Object? addressZipCode = freezed,
    Object? photoUrl = freezed,
    Object? phoneVerified = freezed,
    Object? emailVerified = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ClientImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      cpf: freezed == cpf
          ? _value.cpf
          : cpf // ignore: cast_nullable_to_non_nullable
              as String?,
      addressStreet: freezed == addressStreet
          ? _value.addressStreet
          : addressStreet // ignore: cast_nullable_to_non_nullable
              as String?,
      addressNumber: freezed == addressNumber
          ? _value.addressNumber
          : addressNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      addressDistrict: freezed == addressDistrict
          ? _value.addressDistrict
          : addressDistrict // ignore: cast_nullable_to_non_nullable
              as String?,
      addressZipCode: freezed == addressZipCode
          ? _value.addressZipCode
          : addressZipCode // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      phoneVerified: freezed == phoneVerified
          ? _value.phoneVerified
          : phoneVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      emailVerified: freezed == emailVerified
          ? _value.emailVerified
          : emailVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ClientImpl implements _Client {
  const _$ClientImpl(
      {required this.id,
      required this.userId,
      required this.name,
      required this.email,
      required this.phone,
      required this.city,
      required this.state,
      this.cpf,
      this.addressStreet,
      this.addressNumber,
      this.addressDistrict,
      this.addressZipCode,
      this.photoUrl,
      this.phoneVerified,
      this.emailVerified,
      required this.createdAt,
      this.updatedAt});

  factory _$ClientImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClientImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String name;
  @override
  final String email;
  @override
  final String phone;
  @override
  final String city;
  @override
  final String state;
  @override
  final String? cpf;
  @override
  final String? addressStreet;
  @override
  final String? addressNumber;
  @override
  final String? addressDistrict;
  @override
  final String? addressZipCode;
  @override
  final String? photoUrl;
  @override
  final bool? phoneVerified;
  @override
  final bool? emailVerified;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Client(id: $id, userId: $userId, name: $name, email: $email, phone: $phone, city: $city, state: $state, cpf: $cpf, addressStreet: $addressStreet, addressNumber: $addressNumber, addressDistrict: $addressDistrict, addressZipCode: $addressZipCode, photoUrl: $photoUrl, phoneVerified: $phoneVerified, emailVerified: $emailVerified, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClientImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.cpf, cpf) || other.cpf == cpf) &&
            (identical(other.addressStreet, addressStreet) ||
                other.addressStreet == addressStreet) &&
            (identical(other.addressNumber, addressNumber) ||
                other.addressNumber == addressNumber) &&
            (identical(other.addressDistrict, addressDistrict) ||
                other.addressDistrict == addressDistrict) &&
            (identical(other.addressZipCode, addressZipCode) ||
                other.addressZipCode == addressZipCode) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.phoneVerified, phoneVerified) ||
                other.phoneVerified == phoneVerified) &&
            (identical(other.emailVerified, emailVerified) ||
                other.emailVerified == emailVerified) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      name,
      email,
      phone,
      city,
      state,
      cpf,
      addressStreet,
      addressNumber,
      addressDistrict,
      addressZipCode,
      photoUrl,
      phoneVerified,
      emailVerified,
      createdAt,
      updatedAt);

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClientImplCopyWith<_$ClientImpl> get copyWith =>
      __$$ClientImplCopyWithImpl<_$ClientImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ClientImplToJson(
      this,
    );
  }
}

abstract class _Client implements Client {
  const factory _Client(
      {required final String id,
      required final String userId,
      required final String name,
      required final String email,
      required final String phone,
      required final String city,
      required final String state,
      final String? cpf,
      final String? addressStreet,
      final String? addressNumber,
      final String? addressDistrict,
      final String? addressZipCode,
      final String? photoUrl,
      final bool? phoneVerified,
      final bool? emailVerified,
      required final DateTime createdAt,
      final DateTime? updatedAt}) = _$ClientImpl;

  factory _Client.fromJson(Map<String, dynamic> json) = _$ClientImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get name;
  @override
  String get email;
  @override
  String get phone;
  @override
  String get city;
  @override
  String get state;
  @override
  String? get cpf;
  @override
  String? get addressStreet;
  @override
  String? get addressNumber;
  @override
  String? get addressDistrict;
  @override
  String? get addressZipCode;
  @override
  String? get photoUrl;
  @override
  bool? get phoneVerified;
  @override
  bool? get emailVerified;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClientImplCopyWith<_$ClientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Provider _$ProviderFromJson(Map<String, dynamic> json) {
  return _Provider.fromJson(json);
}

/// @nodoc
mixin _$Provider {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get state => throw _privateConstructorUsedError;
  String? get cpf => throw _privateConstructorUsedError;
  String? get cnpj => throw _privateConstructorUsedError;
  String? get addressStreet => throw _privateConstructorUsedError;
  String? get addressNumber => throw _privateConstructorUsedError;
  String? get addressDistrict => throw _privateConstructorUsedError;
  String? get addressZipCode => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  bool? get phoneVerified => throw _privateConstructorUsedError;
  bool? get emailVerified => throw _privateConstructorUsedError;
  bool? get documentsVerified => throw _privateConstructorUsedError;
  ProviderStatus? get status =>
      throw _privateConstructorUsedError; // Configurações de privacidade
  bool get phoneVisibility => throw _privateConstructorUsedError;
  bool get emailVisibility => throw _privateConstructorUsedError;
  bool get addressVisibility =>
      throw _privateConstructorUsedError; // Estatísticas (vêm das views)
  int? get totalJobs => throw _privateConstructorUsedError;
  int? get completedJobs => throw _privateConstructorUsedError;
  double? get rating => throw _privateConstructorUsedError;
  int? get reviewsCount => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Provider to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProviderCopyWith<Provider> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProviderCopyWith<$Res> {
  factory $ProviderCopyWith(Provider value, $Res Function(Provider) then) =
      _$ProviderCopyWithImpl<$Res, Provider>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String name,
      String email,
      String phone,
      String city,
      String state,
      String? cpf,
      String? cnpj,
      String? addressStreet,
      String? addressNumber,
      String? addressDistrict,
      String? addressZipCode,
      String? photoUrl,
      String? bio,
      bool? phoneVerified,
      bool? emailVerified,
      bool? documentsVerified,
      ProviderStatus? status,
      bool phoneVisibility,
      bool emailVisibility,
      bool addressVisibility,
      int? totalJobs,
      int? completedJobs,
      double? rating,
      int? reviewsCount,
      DateTime createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$ProviderCopyWithImpl<$Res, $Val extends Provider>
    implements $ProviderCopyWith<$Res> {
  _$ProviderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? city = null,
    Object? state = null,
    Object? cpf = freezed,
    Object? cnpj = freezed,
    Object? addressStreet = freezed,
    Object? addressNumber = freezed,
    Object? addressDistrict = freezed,
    Object? addressZipCode = freezed,
    Object? photoUrl = freezed,
    Object? bio = freezed,
    Object? phoneVerified = freezed,
    Object? emailVerified = freezed,
    Object? documentsVerified = freezed,
    Object? status = freezed,
    Object? phoneVisibility = null,
    Object? emailVisibility = null,
    Object? addressVisibility = null,
    Object? totalJobs = freezed,
    Object? completedJobs = freezed,
    Object? rating = freezed,
    Object? reviewsCount = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      cpf: freezed == cpf
          ? _value.cpf
          : cpf // ignore: cast_nullable_to_non_nullable
              as String?,
      cnpj: freezed == cnpj
          ? _value.cnpj
          : cnpj // ignore: cast_nullable_to_non_nullable
              as String?,
      addressStreet: freezed == addressStreet
          ? _value.addressStreet
          : addressStreet // ignore: cast_nullable_to_non_nullable
              as String?,
      addressNumber: freezed == addressNumber
          ? _value.addressNumber
          : addressNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      addressDistrict: freezed == addressDistrict
          ? _value.addressDistrict
          : addressDistrict // ignore: cast_nullable_to_non_nullable
              as String?,
      addressZipCode: freezed == addressZipCode
          ? _value.addressZipCode
          : addressZipCode // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      phoneVerified: freezed == phoneVerified
          ? _value.phoneVerified
          : phoneVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      emailVerified: freezed == emailVerified
          ? _value.emailVerified
          : emailVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      documentsVerified: freezed == documentsVerified
          ? _value.documentsVerified
          : documentsVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ProviderStatus?,
      phoneVisibility: null == phoneVisibility
          ? _value.phoneVisibility
          : phoneVisibility // ignore: cast_nullable_to_non_nullable
              as bool,
      emailVisibility: null == emailVisibility
          ? _value.emailVisibility
          : emailVisibility // ignore: cast_nullable_to_non_nullable
              as bool,
      addressVisibility: null == addressVisibility
          ? _value.addressVisibility
          : addressVisibility // ignore: cast_nullable_to_non_nullable
              as bool,
      totalJobs: freezed == totalJobs
          ? _value.totalJobs
          : totalJobs // ignore: cast_nullable_to_non_nullable
              as int?,
      completedJobs: freezed == completedJobs
          ? _value.completedJobs
          : completedJobs // ignore: cast_nullable_to_non_nullable
              as int?,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      reviewsCount: freezed == reviewsCount
          ? _value.reviewsCount
          : reviewsCount // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ProviderImplCopyWith<$Res>
    implements $ProviderCopyWith<$Res> {
  factory _$$ProviderImplCopyWith(
          _$ProviderImpl value, $Res Function(_$ProviderImpl) then) =
      __$$ProviderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String name,
      String email,
      String phone,
      String city,
      String state,
      String? cpf,
      String? cnpj,
      String? addressStreet,
      String? addressNumber,
      String? addressDistrict,
      String? addressZipCode,
      String? photoUrl,
      String? bio,
      bool? phoneVerified,
      bool? emailVerified,
      bool? documentsVerified,
      ProviderStatus? status,
      bool phoneVisibility,
      bool emailVisibility,
      bool addressVisibility,
      int? totalJobs,
      int? completedJobs,
      double? rating,
      int? reviewsCount,
      DateTime createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$ProviderImplCopyWithImpl<$Res>
    extends _$ProviderCopyWithImpl<$Res, _$ProviderImpl>
    implements _$$ProviderImplCopyWith<$Res> {
  __$$ProviderImplCopyWithImpl(
      _$ProviderImpl _value, $Res Function(_$ProviderImpl) _then)
      : super(_value, _then);

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? city = null,
    Object? state = null,
    Object? cpf = freezed,
    Object? cnpj = freezed,
    Object? addressStreet = freezed,
    Object? addressNumber = freezed,
    Object? addressDistrict = freezed,
    Object? addressZipCode = freezed,
    Object? photoUrl = freezed,
    Object? bio = freezed,
    Object? phoneVerified = freezed,
    Object? emailVerified = freezed,
    Object? documentsVerified = freezed,
    Object? status = freezed,
    Object? phoneVisibility = null,
    Object? emailVisibility = null,
    Object? addressVisibility = null,
    Object? totalJobs = freezed,
    Object? completedJobs = freezed,
    Object? rating = freezed,
    Object? reviewsCount = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ProviderImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      cpf: freezed == cpf
          ? _value.cpf
          : cpf // ignore: cast_nullable_to_non_nullable
              as String?,
      cnpj: freezed == cnpj
          ? _value.cnpj
          : cnpj // ignore: cast_nullable_to_non_nullable
              as String?,
      addressStreet: freezed == addressStreet
          ? _value.addressStreet
          : addressStreet // ignore: cast_nullable_to_non_nullable
              as String?,
      addressNumber: freezed == addressNumber
          ? _value.addressNumber
          : addressNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      addressDistrict: freezed == addressDistrict
          ? _value.addressDistrict
          : addressDistrict // ignore: cast_nullable_to_non_nullable
              as String?,
      addressZipCode: freezed == addressZipCode
          ? _value.addressZipCode
          : addressZipCode // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      phoneVerified: freezed == phoneVerified
          ? _value.phoneVerified
          : phoneVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      emailVerified: freezed == emailVerified
          ? _value.emailVerified
          : emailVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      documentsVerified: freezed == documentsVerified
          ? _value.documentsVerified
          : documentsVerified // ignore: cast_nullable_to_non_nullable
              as bool?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ProviderStatus?,
      phoneVisibility: null == phoneVisibility
          ? _value.phoneVisibility
          : phoneVisibility // ignore: cast_nullable_to_non_nullable
              as bool,
      emailVisibility: null == emailVisibility
          ? _value.emailVisibility
          : emailVisibility // ignore: cast_nullable_to_non_nullable
              as bool,
      addressVisibility: null == addressVisibility
          ? _value.addressVisibility
          : addressVisibility // ignore: cast_nullable_to_non_nullable
              as bool,
      totalJobs: freezed == totalJobs
          ? _value.totalJobs
          : totalJobs // ignore: cast_nullable_to_non_nullable
              as int?,
      completedJobs: freezed == completedJobs
          ? _value.completedJobs
          : completedJobs // ignore: cast_nullable_to_non_nullable
              as int?,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      reviewsCount: freezed == reviewsCount
          ? _value.reviewsCount
          : reviewsCount // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ProviderImpl implements _Provider {
  const _$ProviderImpl(
      {required this.id,
      required this.userId,
      required this.name,
      required this.email,
      required this.phone,
      required this.city,
      required this.state,
      this.cpf,
      this.cnpj,
      this.addressStreet,
      this.addressNumber,
      this.addressDistrict,
      this.addressZipCode,
      this.photoUrl,
      this.bio,
      this.phoneVerified,
      this.emailVerified,
      this.documentsVerified,
      this.status,
      this.phoneVisibility = true,
      this.emailVisibility = true,
      this.addressVisibility = true,
      this.totalJobs,
      this.completedJobs,
      this.rating,
      this.reviewsCount,
      required this.createdAt,
      this.updatedAt});

  factory _$ProviderImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProviderImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String name;
  @override
  final String email;
  @override
  final String phone;
  @override
  final String city;
  @override
  final String state;
  @override
  final String? cpf;
  @override
  final String? cnpj;
  @override
  final String? addressStreet;
  @override
  final String? addressNumber;
  @override
  final String? addressDistrict;
  @override
  final String? addressZipCode;
  @override
  final String? photoUrl;
  @override
  final String? bio;
  @override
  final bool? phoneVerified;
  @override
  final bool? emailVerified;
  @override
  final bool? documentsVerified;
  @override
  final ProviderStatus? status;
// Configurações de privacidade
  @override
  @JsonKey()
  final bool phoneVisibility;
  @override
  @JsonKey()
  final bool emailVisibility;
  @override
  @JsonKey()
  final bool addressVisibility;
// Estatísticas (vêm das views)
  @override
  final int? totalJobs;
  @override
  final int? completedJobs;
  @override
  final double? rating;
  @override
  final int? reviewsCount;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Provider(id: $id, userId: $userId, name: $name, email: $email, phone: $phone, city: $city, state: $state, cpf: $cpf, cnpj: $cnpj, addressStreet: $addressStreet, addressNumber: $addressNumber, addressDistrict: $addressDistrict, addressZipCode: $addressZipCode, photoUrl: $photoUrl, bio: $bio, phoneVerified: $phoneVerified, emailVerified: $emailVerified, documentsVerified: $documentsVerified, status: $status, phoneVisibility: $phoneVisibility, emailVisibility: $emailVisibility, addressVisibility: $addressVisibility, totalJobs: $totalJobs, completedJobs: $completedJobs, rating: $rating, reviewsCount: $reviewsCount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProviderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.cpf, cpf) || other.cpf == cpf) &&
            (identical(other.cnpj, cnpj) || other.cnpj == cnpj) &&
            (identical(other.addressStreet, addressStreet) ||
                other.addressStreet == addressStreet) &&
            (identical(other.addressNumber, addressNumber) ||
                other.addressNumber == addressNumber) &&
            (identical(other.addressDistrict, addressDistrict) ||
                other.addressDistrict == addressDistrict) &&
            (identical(other.addressZipCode, addressZipCode) ||
                other.addressZipCode == addressZipCode) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.phoneVerified, phoneVerified) ||
                other.phoneVerified == phoneVerified) &&
            (identical(other.emailVerified, emailVerified) ||
                other.emailVerified == emailVerified) &&
            (identical(other.documentsVerified, documentsVerified) ||
                other.documentsVerified == documentsVerified) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.phoneVisibility, phoneVisibility) ||
                other.phoneVisibility == phoneVisibility) &&
            (identical(other.emailVisibility, emailVisibility) ||
                other.emailVisibility == emailVisibility) &&
            (identical(other.addressVisibility, addressVisibility) ||
                other.addressVisibility == addressVisibility) &&
            (identical(other.totalJobs, totalJobs) ||
                other.totalJobs == totalJobs) &&
            (identical(other.completedJobs, completedJobs) ||
                other.completedJobs == completedJobs) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.reviewsCount, reviewsCount) ||
                other.reviewsCount == reviewsCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        userId,
        name,
        email,
        phone,
        city,
        state,
        cpf,
        cnpj,
        addressStreet,
        addressNumber,
        addressDistrict,
        addressZipCode,
        photoUrl,
        bio,
        phoneVerified,
        emailVerified,
        documentsVerified,
        status,
        phoneVisibility,
        emailVisibility,
        addressVisibility,
        totalJobs,
        completedJobs,
        rating,
        reviewsCount,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProviderImplCopyWith<_$ProviderImpl> get copyWith =>
      __$$ProviderImplCopyWithImpl<_$ProviderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProviderImplToJson(
      this,
    );
  }
}

abstract class _Provider implements Provider {
  const factory _Provider(
      {required final String id,
      required final String userId,
      required final String name,
      required final String email,
      required final String phone,
      required final String city,
      required final String state,
      final String? cpf,
      final String? cnpj,
      final String? addressStreet,
      final String? addressNumber,
      final String? addressDistrict,
      final String? addressZipCode,
      final String? photoUrl,
      final String? bio,
      final bool? phoneVerified,
      final bool? emailVerified,
      final bool? documentsVerified,
      final ProviderStatus? status,
      final bool phoneVisibility,
      final bool emailVisibility,
      final bool addressVisibility,
      final int? totalJobs,
      final int? completedJobs,
      final double? rating,
      final int? reviewsCount,
      required final DateTime createdAt,
      final DateTime? updatedAt}) = _$ProviderImpl;

  factory _Provider.fromJson(Map<String, dynamic> json) =
      _$ProviderImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get name;
  @override
  String get email;
  @override
  String get phone;
  @override
  String get city;
  @override
  String get state;
  @override
  String? get cpf;
  @override
  String? get cnpj;
  @override
  String? get addressStreet;
  @override
  String? get addressNumber;
  @override
  String? get addressDistrict;
  @override
  String? get addressZipCode;
  @override
  String? get photoUrl;
  @override
  String? get bio;
  @override
  bool? get phoneVerified;
  @override
  bool? get emailVerified;
  @override
  bool? get documentsVerified;
  @override
  ProviderStatus? get status; // Configurações de privacidade
  @override
  bool get phoneVisibility;
  @override
  bool get emailVisibility;
  @override
  bool get addressVisibility; // Estatísticas (vêm das views)
  @override
  int? get totalJobs;
  @override
  int? get completedJobs;
  @override
  double? get rating;
  @override
  int? get reviewsCount;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProviderImplCopyWith<_$ProviderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
