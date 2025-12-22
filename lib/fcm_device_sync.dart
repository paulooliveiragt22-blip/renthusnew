import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmDeviceSync {
  FcmDeviceSync._();

  static final _supabase = Supabase.instance.client;
  static final _fcm = FirebaseMessaging.instance;

  /// Registra/atualiza o device atual (chamar sempre que o user estiver logado)
  static Future<void> registerCurrentDevice() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Pede permissão (iOS; no Android não atrapalha)
    await _fcm.requestPermission();

    final token = await _fcm.getToken();
    if (token == null) return;

    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'other';

    await _supabase.from('user_devices').upsert(
      {
        'user_id': user.id,
        'fcm_token': token,
        'platform': platform,
      },
      // precisa bater com o índice único que vamos criar abaixo
      onConflict: 'user_id,platform',
    );
  }

  /// Atualiza o Supabase quando o FCM trocar o token.
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
