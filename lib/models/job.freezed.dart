// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Job _$JobFromJson(Map<String, dynamic> json) {
  return _Job.fromJson(json);
}

/// @nodoc
mixin _$Job {
  String get id => throw _privateConstructorUsedError;
  String get clientId => throw _privateConstructorUsedError;
  String get serviceTypeId => throw _privateConstructorUsedError;
  String get categoryId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get serviceDetected => throw _privateConstructorUsedError;
  JobStatus get status => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get state => throw _privateConstructorUsedError;
  String? get zipcode => throw _privateConstructorUsedError;
  double? get lat => throw _privateConstructorUsedError;
  double? get lng =>
      throw _privateConstructorUsedError; // Campos calculados (vêm das views)
  String? get clientName => throw _privateConstructorUsedError;
  String? get clientPhone => throw _privateConstructorUsedError;
  String? get serviceTypeName => throw _privateConstructorUsedError;
  String? get categoryName => throw _privateConstructorUsedError;
  int? get candidatesCount => throw _privateConstructorUsedError;
  int? get quotesCount => throw _privateConstructorUsedError; // Timestamps
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  DateTime? get scheduledAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  DateTime? get cancelledAt => throw _privateConstructorUsedError;

  /// Serializes this Job to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JobCopyWith<Job> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobCopyWith<$Res> {
  factory $JobCopyWith(Job value, $Res Function(Job) then) =
      _$JobCopyWithImpl<$Res, Job>;
  @useResult
  $Res call(
      {String id,
      String clientId,
      String serviceTypeId,
      String categoryId,
      String title,
      String description,
      String serviceDetected,
      JobStatus status,
      String city,
      String state,
      String? zipcode,
      double? lat,
      double? lng,
      String? clientName,
      String? clientPhone,
      String? serviceTypeName,
      String? categoryName,
      int? candidatesCount,
      int? quotesCount,
      DateTime createdAt,
      DateTime? updatedAt,
      DateTime? scheduledAt,
      DateTime? completedAt,
      DateTime? cancelledAt});
}

/// @nodoc
class _$JobCopyWithImpl<$Res, $Val extends Job> implements $JobCopyWith<$Res> {
  _$JobCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? serviceTypeId = null,
    Object? categoryId = null,
    Object? title = null,
    Object? description = null,
    Object? serviceDetected = null,
    Object? status = null,
    Object? city = null,
    Object? state = null,
    Object? zipcode = freezed,
    Object? lat = freezed,
    Object? lng = freezed,
    Object? clientName = freezed,
    Object? clientPhone = freezed,
    Object? serviceTypeName = freezed,
    Object? categoryName = freezed,
    Object? candidatesCount = freezed,
    Object? quotesCount = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? scheduledAt = freezed,
    Object? completedAt = freezed,
    Object? cancelledAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientId: null == clientId
          ? _value.clientId
          : clientId // ignore: cast_nullable_to_non_nullable
              as String,
      serviceTypeId: null == serviceTypeId
          ? _value.serviceTypeId
          : serviceTypeId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      serviceDetected: null == serviceDetected
          ? _value.serviceDetected
          : serviceDetected // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as JobStatus,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      zipcode: freezed == zipcode
          ? _value.zipcode
          : zipcode // ignore: cast_nullable_to_non_nullable
              as String?,
      lat: freezed == lat
          ? _value.lat
          : lat // ignore: cast_nullable_to_non_nullable
              as double?,
      lng: freezed == lng
          ? _value.lng
          : lng // ignore: cast_nullable_to_non_nullable
              as double?,
      clientName: freezed == clientName
          ? _value.clientName
          : clientName // ignore: cast_nullable_to_non_nullable
              as String?,
      clientPhone: freezed == clientPhone
          ? _value.clientPhone
          : clientPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      serviceTypeName: freezed == serviceTypeName
          ? _value.serviceTypeName
          : serviceTypeName // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryName: freezed == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      candidatesCount: freezed == candidatesCount
          ? _value.candidatesCount
          : candidatesCount // ignore: cast_nullable_to_non_nullable
              as int?,
      quotesCount: freezed == quotesCount
          ? _value.quotesCount
          : quotesCount // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      scheduledAt: freezed == scheduledAt
          ? _value.scheduledAt
          : scheduledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JobImplCopyWith<$Res> implements $JobCopyWith<$Res> {
  factory _$$JobImplCopyWith(_$JobImpl value, $Res Function(_$JobImpl) then) =
      __$$JobImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String clientId,
      String serviceTypeId,
      String categoryId,
      String title,
      String description,
      String serviceDetected,
      JobStatus status,
      String city,
      String state,
      String? zipcode,
      double? lat,
      double? lng,
      String? clientName,
      String? clientPhone,
      String? serviceTypeName,
      String? categoryName,
      int? candidatesCount,
      int? quotesCount,
      DateTime createdAt,
      DateTime? updatedAt,
      DateTime? scheduledAt,
      DateTime? completedAt,
      DateTime? cancelledAt});
}

/// @nodoc
class __$$JobImplCopyWithImpl<$Res> extends _$JobCopyWithImpl<$Res, _$JobImpl>
    implements _$$JobImplCopyWith<$Res> {
  __$$JobImplCopyWithImpl(_$JobImpl _value, $Res Function(_$JobImpl) _then)
      : super(_value, _then);

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? serviceTypeId = null,
    Object? categoryId = null,
    Object? title = null,
    Object? description = null,
    Object? serviceDetected = null,
    Object? status = null,
    Object? city = null,
    Object? state = null,
    Object? zipcode = freezed,
    Object? lat = freezed,
    Object? lng = freezed,
    Object? clientName = freezed,
    Object? clientPhone = freezed,
    Object? serviceTypeName = freezed,
    Object? categoryName = freezed,
    Object? candidatesCount = freezed,
    Object? quotesCount = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? scheduledAt = freezed,
    Object? completedAt = freezed,
    Object? cancelledAt = freezed,
  }) {
    return _then(_$JobImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      clientId: null == clientId
          ? _value.clientId
          : clientId // ignore: cast_nullable_to_non_nullable
              as String,
      serviceTypeId: null == serviceTypeId
          ? _value.serviceTypeId
          : serviceTypeId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      serviceDetected: null == serviceDetected
          ? _value.serviceDetected
          : serviceDetected // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as JobStatus,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      zipcode: freezed == zipcode
          ? _value.zipcode
          : zipcode // ignore: cast_nullable_to_non_nullable
              as String?,
      lat: freezed == lat
          ? _value.lat
          : lat // ignore: cast_nullable_to_non_nullable
              as double?,
      lng: freezed == lng
          ? _value.lng
          : lng // ignore: cast_nullable_to_non_nullable
              as double?,
      clientName: freezed == clientName
          ? _value.clientName
          : clientName // ignore: cast_nullable_to_non_nullable
              as String?,
      clientPhone: freezed == clientPhone
          ? _value.clientPhone
          : clientPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      serviceTypeName: freezed == serviceTypeName
          ? _value.serviceTypeName
          : serviceTypeName // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryName: freezed == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      candidatesCount: freezed == candidatesCount
          ? _value.candidatesCount
          : candidatesCount // ignore: cast_nullable_to_non_nullable
              as int?,
      quotesCount: freezed == quotesCount
          ? _value.quotesCount
          : quotesCount // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      scheduledAt: freezed == scheduledAt
          ? _value.scheduledAt
          : scheduledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$JobImpl implements _Job {
  const _$JobImpl(
      {required this.id,
      required this.clientId,
      required this.serviceTypeId,
      required this.categoryId,
      required this.title,
      required this.description,
      required this.serviceDetected,
      required this.status,
      required this.city,
      required this.state,
      this.zipcode,
      this.lat,
      this.lng,
      this.clientName,
      this.clientPhone,
      this.serviceTypeName,
      this.categoryName,
      this.candidatesCount,
      this.quotesCount,
      required this.createdAt,
      this.updatedAt,
      this.scheduledAt,
      this.completedAt,
      this.cancelledAt});

  factory _$JobImpl.fromJson(Map<String, dynamic> json) =>
      _$$JobImplFromJson(json);

  @override
  final String id;
  @override
  final String clientId;
  @override
  final String serviceTypeId;
  @override
  final String categoryId;
  @override
  final String title;
  @override
  final String description;
  @override
  final String serviceDetected;
  @override
  final JobStatus status;
  @override
  final String city;
  @override
  final String state;
  @override
  final String? zipcode;
  @override
  final double? lat;
  @override
  final double? lng;
// Campos calculados (vêm das views)
  @override
  final String? clientName;
  @override
  final String? clientPhone;
  @override
  final String? serviceTypeName;
  @override
  final String? categoryName;
  @override
  final int? candidatesCount;
  @override
  final int? quotesCount;
// Timestamps
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final DateTime? scheduledAt;
  @override
  final DateTime? completedAt;
  @override
  final DateTime? cancelledAt;

  @override
  String toString() {
    return 'Job(id: $id, clientId: $clientId, serviceTypeId: $serviceTypeId, categoryId: $categoryId, title: $title, description: $description, serviceDetected: $serviceDetected, status: $status, city: $city, state: $state, zipcode: $zipcode, lat: $lat, lng: $lng, clientName: $clientName, clientPhone: $clientPhone, serviceTypeName: $serviceTypeName, categoryName: $categoryName, candidatesCount: $candidatesCount, quotesCount: $quotesCount, createdAt: $createdAt, updatedAt: $updatedAt, scheduledAt: $scheduledAt, completedAt: $completedAt, cancelledAt: $cancelledAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            (identical(other.serviceTypeId, serviceTypeId) ||
                other.serviceTypeId == serviceTypeId) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.serviceDetected, serviceDetected) ||
                other.serviceDetected == serviceDetected) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.zipcode, zipcode) || other.zipcode == zipcode) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.clientName, clientName) ||
                other.clientName == clientName) &&
            (identical(other.clientPhone, clientPhone) ||
                other.clientPhone == clientPhone) &&
            (identical(other.serviceTypeName, serviceTypeName) ||
                other.serviceTypeName == serviceTypeName) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.candidatesCount, candidatesCount) ||
                other.candidatesCount == candidatesCount) &&
            (identical(other.quotesCount, quotesCount) ||
                other.quotesCount == quotesCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.scheduledAt, scheduledAt) ||
                other.scheduledAt == scheduledAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        clientId,
        serviceTypeId,
        categoryId,
        title,
        description,
        serviceDetected,
        status,
        city,
        state,
        zipcode,
        lat,
        lng,
        clientName,
        clientPhone,
        serviceTypeName,
        categoryName,
        candidatesCount,
        quotesCount,
        createdAt,
        updatedAt,
        scheduledAt,
        completedAt,
        cancelledAt
      ]);

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobImplCopyWith<_$JobImpl> get copyWith =>
      __$$JobImplCopyWithImpl<_$JobImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JobImplToJson(
      this,
    );
  }
}

abstract class _Job implements Job {
  const factory _Job(
      {required final String id,
      required final String clientId,
      required final String serviceTypeId,
      required final String categoryId,
      required final String title,
      required final String description,
      required final String serviceDetected,
      required final JobStatus status,
      required final String city,
      required final String state,
      final String? zipcode,
      final double? lat,
      final double? lng,
      final String? clientName,
      final String? clientPhone,
      final String? serviceTypeName,
      final String? categoryName,
      final int? candidatesCount,
      final int? quotesCount,
      required final DateTime createdAt,
      final DateTime? updatedAt,
      final DateTime? scheduledAt,
      final DateTime? completedAt,
      final DateTime? cancelledAt}) = _$JobImpl;

  factory _Job.fromJson(Map<String, dynamic> json) = _$JobImpl.fromJson;

  @override
  String get id;
  @override
  String get clientId;
  @override
  String get serviceTypeId;
  @override
  String get categoryId;
  @override
  String get title;
  @override
  String get description;
  @override
  String get serviceDetected;
  @override
  JobStatus get status;
  @override
  String get city;
  @override
  String get state;
  @override
  String? get zipcode;
  @override
  double? get lat;
  @override
  double? get lng; // Campos calculados (vêm das views)
  @override
  String? get clientName;
  @override
  String? get clientPhone;
  @override
  String? get serviceTypeName;
  @override
  String? get categoryName;
  @override
  int? get candidatesCount;
  @override
  int? get quotesCount; // Timestamps
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  DateTime? get scheduledAt;
  @override
  DateTime? get completedAt;
  @override
  DateTime? get cancelledAt;

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobImplCopyWith<_$JobImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
