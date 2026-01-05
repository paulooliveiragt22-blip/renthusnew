import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'fcm_device_sync.dart';

typedef NotificationNavigationHandler = void Function(
  Map<String, dynamic> data,
);

class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  final _messaging = FirebaseMessaging.instance;

  bool _initialized = false;

  Future<void> init({
    required NotificationNavigationHandler onNavigate,
  }) async {
    if (_initialized) return;

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
    await FcmDeviceSync.registerCurrentDevice();

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
}
