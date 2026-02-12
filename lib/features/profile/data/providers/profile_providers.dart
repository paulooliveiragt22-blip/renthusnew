import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/profile/data/repositories/profile_repository.dart';
import 'package:renthus/features/profile/domain/models/user_profile_model.dart';

part 'profile_providers.g.dart';

/// Provider do ProfileRepository
@riverpod
ProfileRepository profileRepository(ProfileRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return ProfileRepository(supabase);
}

/// Provider do perfil do usuário
/// 
/// Atualiza automaticamente quando o usuário muda
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  Future<UserProfile> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    return await repository.getProfile();
  }

  /// Atualizar perfil
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? role,
    String? avatarUrl,
  }) async {
    // Mostra loading
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(profileRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);

      final updated = await repository.updateProfile(
        userId: userId,
        name: name,
        phone: phone,
        role: role,
        avatarUrl: avatarUrl,
      );

      return updated;
    });
  }

  /// Upload de avatar
  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final repository = ref.read(profileRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);

      final url = await repository.uploadAvatar(
        userId: userId,
        bytes: bytes,
        fileName: fileName,
      );

      // Atualiza o perfil com a nova URL
      await updateProfile(avatarUrl: url);

      return url;
    } catch (e) {
      return null;
    }
  }

  /// Refresh manual do perfil
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
