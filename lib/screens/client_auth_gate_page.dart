// lib/gates/client_auth_gate_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/login_screen.dart';
import '../screens/client_signup_step1_page.dart';
import '../screens/client_signup_step2_page.dart';
import '../screens/client_main_page.dart'; // ✅ IMPORTA O MAIN (com bottom nav)

class ClientAuthGatePage extends StatefulWidget {
  const ClientAuthGatePage({super.key});

  @override
  State<ClientAuthGatePage> createState() => _ClientAuthGatePageState();
}

class _ClientAuthGatePageState extends State<ClientAuthGatePage> {
  final _supabase = Supabase.instance.client;

  Future<_GateResult> _check() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return _GateResult.login;

      final me = await _supabase
          .from('v_client_me')
          .select('profile_completed,address_completed')
          .maybeSingle();

      final profileCompleted = (me?['profile_completed'] as bool?) ?? false;
      final addressCompleted = (me?['address_completed'] as bool?) ?? false;

      if (!profileCompleted) return _GateResult.step1;
      if (!addressCompleted) return _GateResult.step2;
      return _GateResult.home;
    } catch (_) {
      // fallback seguro: se falhar leitura da view, manda pro Step1
      final session = _supabase.auth.currentSession;
      if (session == null) return _GateResult.login;
      return _GateResult.step1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateResult>(
      future: _check(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data ?? _GateResult.login;

        switch (result) {
          case _GateResult.login:
            return const LoginScreen();
          case _GateResult.step1:
            return const ClientSignUpStep1Page();
          case _GateResult.step2:
            return const ClientSignUpStep2Page();
          case _GateResult.home:
            // ✅ A HOME DO CLIENTE DEVE SER O MAIN PAGE (único Scaffold com bottom nav)
            return const ClientMainPage();
        }
      },
    );
  }
}

enum _GateResult { login, step1, step2, home }
