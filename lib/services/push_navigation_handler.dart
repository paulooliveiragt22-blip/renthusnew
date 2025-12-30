import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_navigator.dart';
import '../screens/app_gate_page.dart';

class PushNavigationHandler {
  PushNavigationHandler._();

  static final _supabase = Supabase.instance.client;

  /// `data` vem do PushNotificationService (payload do push).
  /// Este handler:
  /// - garante que existe usuário logado
  /// - resolve role no banco via v_role_me
  /// - decide rota
  static Future<void> handle(Map<String, dynamic> data) async {
    final nav = AppNavigator.navigatorKey.currentState;
    if (nav == null) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      // Sem sessão: manda pro Gate (ele vai cair em Login)
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGatePage()),
        (route) => false,
      );
      return;
    }

    String? role;
    try {
      final row =
          await _supabase.from('v_role_me').select('role').maybeSingle();
      role = row?['role'] as String?;
    } catch (_) {
      role = null;
    }

    if (role == null) {
      // Role ainda não definida -> Gate (vai cair em RoleSelection)
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGatePage()),
        (route) => false,
      );
      return;
    }

    // ------------------------------------------------------------
    // Exemplo de roteamento por tipo de notificação.
    // Ajuste de acordo com seu payload real.
    // ------------------------------------------------------------
    final type = (data['type'] ?? '').toString();

    // Se você ainda não tem rotas específicas, o comportamento mais robusto
    // é sempre cair no Gate e deixar ele abrir a home correta.
    if (type.isEmpty) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGatePage()),
        (route) => false,
      );
      return;
    }

    // Exemplos (adicione os seus):
    // - type: "job"
    // - type: "chat"
    // - type: "booking"
    //
    // ⚠️ Como você não me passou as telas de destino do push,
    // deixo aqui a política segura: Gate -> home correta.
    // Depois você me diz quais payloads existem e eu conecto
    // para telas específicas (job_details, chat, dispute, etc.).

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppGatePage()),
      (route) => false,
    );
  }
}
