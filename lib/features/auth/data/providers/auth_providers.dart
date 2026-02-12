import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/auth/domain/models/login_destination.dart';
import 'package:renthus/repositories/auth_repository.dart';
import 'package:renthus/repositories/client_repository.dart';
import 'package:renthus/repositories/provider_repository.dart';

part 'auth_providers.g.dart';

/// Provider do AuthRepository
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return AuthRepository(client: supabase);
}

/// Provider do ClientRepository
@riverpod
ClientRepository clientRepository(ClientRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return ClientRepository(client: supabase);
}

/// Provider do ProviderRepository
@riverpod
ProviderRepository providerRepository(ProviderRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return ProviderRepository(client: supabase);
}

/// Provider de ações de autenticação (login, logout)
@riverpod
class AuthActions extends _$AuthActions {
  @override
  Future<LoginDestination?> build() async => null;

  /// Realiza login e retorna o destino de navegação
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authRepo = ref.read(authRepositoryProvider);
      final clientRepo = ref.read(clientRepositoryProvider);
      final providerRepo = ref.read(providerRepositoryProvider);

      final authResponse = await authRepo.signInWithEmail(
        email: email,
        password: password,
      );

      final user =
          authResponse.user ?? Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Não foi possível obter o usuário autenticado.');
      }

      // 1) ADMIN → direto pro dashboard
      if (_isAdminFromUser(user)) {
        return LoginDestination.admin;
      }

      // 2) Decide papel: provider ou client
      final providerMe = await providerRepo.getMe();
      final bool isProvider = providerMe != null;

      if (isProvider) {
        return LoginDestination.provider;
      }

      // 3) Cliente
      await clientRepo.getMe();
      return LoginDestination.client;
    });
  }

  bool _isAdminFromUser(User user) {
    final appMeta = user.appMetadata;
    final userMeta = user.userMetadata;
    final a = appMeta['is_admin'];
    final u = userMeta?['is_admin'];
    return (a == true) || (u == true);
  }

  /// Reseta o estado após navegação (evita re-navegação em rebuild)
  void reset() {
    state = const AsyncValue.data(null);
  }
}
