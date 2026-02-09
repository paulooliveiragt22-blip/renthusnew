// lib/models/user.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Model tipado para Cliente
@freezed
class Client with _$Client {
  const factory Client({
    required String id,
    required String userId,
    required String name,
    required String email,
    required String phone,
    required String city,
    required String state,
    String? cpf,
    String? addressStreet,
    String? addressNumber,
    String? addressDistrict,
    String? addressZipCode,
    String? photoUrl,
    bool? phoneVerified,
    bool? emailVerified,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Client;

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      city: map['city'] as String,
      state: map['address_state'] as String? ?? map['state'] as String,
      cpf: map['cpf'] as String?,
      addressStreet: map['address_street'] as String?,
      addressNumber: map['address_number'] as String?,
      addressDistrict: map['address_district'] as String?,
      addressZipCode: map['address_zip_code'] as String?,
      photoUrl: map['photo_url'] as String?,
      phoneVerified: map['phone_verified'] as bool?,
      emailVerified: map['email_verified'] as bool?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}

/// Model tipado para Prestador
@freezed
class Provider with _$Provider {
  const factory Provider({
    required String id,
    required String userId,
    required String name,
    required String email,
    required String phone,
    required String city,
    required String state,
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

    // Configurações de privacidade
    @Default(true) bool phoneVisibility,
    @Default(true) bool emailVisibility,
    @Default(true) bool addressVisibility,

    // Estatísticas (vêm das views)
    int? totalJobs,
    int? completedJobs,
    double? rating,
    int? reviewsCount,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Provider;

  factory Provider.fromJson(Map<String, dynamic> json) =>
      _$ProviderFromJson(json);

  factory Provider.fromMap(Map<String, dynamic> map) {
    return Provider(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      city: map['city'] as String,
      state: map['address_state'] as String? ?? map['state'] as String,
      cpf: map['cpf'] as String?,
      cnpj: map['cnpj'] as String?,
      addressStreet: map['address_street'] as String?,
      addressNumber: map['address_number'] as String?,
      addressDistrict: map['address_district'] as String?,
      addressZipCode: map['address_zip_code'] as String?,
      photoUrl: map['photo_url'] as String?,
      bio: map['bio'] as String?,
      phoneVerified: map['phone_verified'] as bool?,
      emailVerified: map['email_verified'] as bool?,
      documentsVerified: map['documents_verified'] as bool?,
      status: map['status'] != null
          ? ProviderStatus.fromString(map['status'] as String)
          : null,
      phoneVisibility: map['phone_visibility'] as bool? ?? true,
      emailVisibility: map['email_visibility'] as bool? ?? true,
      addressVisibility: map['address_visibility'] as bool? ?? true,
      totalJobs: map['total_jobs'] as int?,
      completedJobs: map['completed_jobs'] as int?,
      rating: (map['rating'] as num?)?.toDouble(),
      reviewsCount: map['reviews_count'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}

/// Status do Prestador
enum ProviderStatus {
  active,
  inactive,
  suspended,
  pendingVerification;

  String toJson() => name;

  static ProviderStatus fromString(String value) {
    switch (value) {
      case 'active':
        return ProviderStatus.active;
      case 'inactive':
        return ProviderStatus.inactive;
      case 'suspended':
        return ProviderStatus.suspended;
      case 'pending_verification':
        return ProviderStatus.pendingVerification;
      default:
        throw ArgumentError('Invalid ProviderStatus: $value');
    }
  }

  String get displayName {
    switch (this) {
      case ProviderStatus.active:
        return 'Ativo';
      case ProviderStatus.inactive:
        return 'Inativo';
      case ProviderStatus.suspended:
        return 'Suspenso';
      case ProviderStatus.pendingVerification:
        return 'Aguardando Verificação';
    }
  }
}
