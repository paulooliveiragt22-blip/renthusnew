import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmDeviceSync {
  FcmDeviceSync._();

  static SupabaseClient? _supabaseOverride;
  static SupabaseClient get _supabase =>
      _supabaseOverride ?? Supabase.instance.client;
  static final _fcm = FirebaseMessaging.instance;

  static void setSupabaseClient(SupabaseClient client) {
    _supabaseOverride = client;
  }

  /// Chamar sempre que o usuário estiver logado.
  static Future<void> registerCurrentDevice() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Pede permissão (iOS principalmente, mas não atrapalha no Android)
    await _fcm.requestPermission();

    final token = await _fcm.getToken();
    if (token == null) return;

    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'other';

    // Grava ou atualiza na tabela public.user_devices
    await _supabase.from('user_devices').upsert(
      {
        'user_id': user.id,
        'fcm_token': token,
        'platform': platform,
      },
      // se você criou unique index em (user_id, platform), use o nome aqui:
      onConflict: 'user_id,platform',
    );
  }

  /// Escuta quando o token mudar e atualiza no Supabase.
  static void listenTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'other';

      await _supabase.from('user_devices').upsert(
        {
          'user_id': user.id,
          'fcm_token': newToken,
          'platform': platform,
        },
        onConflict: 'user_id,platform',
      );
    });
  }
}
