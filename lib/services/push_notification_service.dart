import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef NotificationNavigationHandler = void Function(
  Map<String, dynamic> data,
);

class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  SupabaseClient? _supabaseOverride;

  SupabaseClient get _supabase => _supabaseOverride ?? Supabase.instance.client;

  void setSupabaseClient(SupabaseClient client) {
    _supabaseOverride = client;
  }

  bool _initialized = false;

  Future<void> init({
    required NotificationNavigationHandler onNavigate,
    SupabaseClient? supabaseClient,
  }) async {
    if (_initialized) return;
    if (supabaseClient != null) _supabaseOverride = supabaseClient;

    // NADA de push em web/desktop
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }

    // 1) Permissões
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('🔔 FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _initialized = true;
      return;
    }

    // 2) Token inicial
    final token = await _messaging.getToken();
    print('🔥 FCM TOKEN (init): $token');
    await _saveDeviceToken(token);

    // 3) Refresh de token
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('♻️ FCM TOKEN REFRESH: $newToken');
      _saveDeviceToken(newToken);
    });

    // 4) Mensagem em foreground
    FirebaseMessaging.onMessage.listen((message) {
      print('📥 PUSH (onMessage): ${message.data}');
      // aqui depois a gente pode plugar notificação local (popup)
    });

    // 5) App em background → usuário clicou na notificação
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('👉 onMessageOpenedApp: ${message.data}');
      onNavigate(message.data);
    });

    // 6) App fechado e aberto pela notificação
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 getInitialMessage: ${initialMessage.data}');
      onNavigate(initialMessage.data);
    }

    _initialized = true;
  }

  Future<void> _saveDeviceToken(String? token) async {
    if (token == null) return;
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print('⚠️ _saveDeviceToken: user == null');
      return;
    }

    final platform = kIsWeb
        ? 'web'
        : Platform.isAndroid
            ? 'android'
            : Platform.isIOS
                ? 'ios'
                : 'unknown';

    print('💾 Salvando token no Supabase: user=${user.id}, platform=$platform');

    await _supabase.from('user_devices').upsert(
      {
        'user_id': user.id,
        // 👇 ESSA É A COLUNA QUE O EDGE FUNCTION USA
        'fcm_token': token,
        // opcional: manter também em device_token, se quiser
        'device_token': token,
        'platform': platform,
      },
      // um registro por usuário + plataforma
      onConflict: 'user_id,platform',
    );
  }
}
