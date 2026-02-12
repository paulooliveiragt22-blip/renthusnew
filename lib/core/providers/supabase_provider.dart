import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_provider.g.dart';

/// Provider do cliente Supabase
/// 
/// Fornece acesso global ao cliente Supabase para
/// realizar operações no banco de dados.
@Riverpod(keepAlive: true)
SupabaseClient supabase(SupabaseRef ref) {
  return Supabase.instance.client;
}

/// Provider da sessão atual do usuário
/// 
/// Atualiza automaticamente quando o estado de auth muda
@riverpod
Stream<AuthState> authState(AuthStateRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange;
}

/// Provider do usuário autenticado
/// 
/// Retorna null se não houver usuário logado
@riverpod
User? currentUser(CurrentUserRef ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user;
}

/// Provider do ID do usuário atual
/// 
/// Throws exception se não houver usuário logado
@riverpod
String currentUserId(CurrentUserIdRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw Exception('User not authenticated');
  }
  return user.id;
}

/// Provider de autenticação
/// 
/// Verifica se o usuário está autenticado
@riverpod
bool isAuthenticated(IsAuthenticatedRef ref) {
  return ref.watch(currentUserProvider) != null;
}
