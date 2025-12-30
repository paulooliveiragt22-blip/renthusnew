import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'welcome_page.dart';
import 'provider_main_page.dart';
import 'client_main_page.dart';
import 'admin/admin_home_page.dart';
import 'signup_step2_unified_page.dart';

class AppGatePage extends StatefulWidget {
  const AppGatePage({super.key});

  @override
  State<AppGatePage> createState() => _AppGatePageState();
}

class _AppGatePageState extends State<AppGatePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isAdmin(User user) {
    final appMeta = user.appMetadata;
    final userMeta = user.userMetadata;
    return appMeta['is_admin'] == true || userMeta?['is_admin'] == true;
  }

  Future<Widget> _resolve() async {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;

    // Sem sessão → WelcomePage
    if (session == null || user == null) {
      return const WelcomePage();
    }

    // Mantém o fluxo de admin existente (não mexe no layout/fluxo atual)
    if (_isAdmin(user)) {
      return const AdminHomePage();
    }

    final uid = user.id;

    // Fonte de verdade:
    // Se existe providers com user_id = auth.uid() → ProviderMainPage
    final provider = await _supabase
        .from('providers')
        .select('id')
        .eq('user_id', uid)
        .maybeSingle();
    if (provider != null) return const ProviderMainPage();

    // Else se existe clients com id = auth.uid() → ClientMainPage
    final client = await _supabase
        .from('clients')
        .select('id')
        .eq('id', uid)
        .maybeSingle();
    if (client != null) return const ClientMainPage();

    // Else → SignupStep2UnifiedPage (cadastro incompleto)
    return const SignupStep2UnifiedPage();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final userId = _supabase.auth.currentUser?.id ?? 'guest';

        return FutureBuilder<Widget>(
          // ✅ Key força o FutureBuilder “refazer” quando o user muda (deep link / login / logout)
          key: ValueKey(userId),
          future: _resolve(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return snapshot.data ?? const WelcomePage();
          },
        );
      },
    );
  }
}
