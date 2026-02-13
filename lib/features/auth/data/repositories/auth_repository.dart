import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {

  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() async => _client.auth.signOut();
}
