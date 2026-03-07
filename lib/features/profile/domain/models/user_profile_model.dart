import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

/// Model do perfil do usuário
@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String email,
    String? name,
    String? phone,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @Default('client') String role,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

/// Extension para helpers
extension UserProfileX on UserProfile {
  /// É provider?
  bool get isProvider => role == 'provider';

  /// É client?
  bool get isClient => role == 'client';

  /// Nome de exibição
  String get displayName => name ?? 'Sem nome';

  /// Iniciais para avatar
  String get initials {
    if (name == null || name!.isEmpty) return '??';
    final parts = name!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }
}
