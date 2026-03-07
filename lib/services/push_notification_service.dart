import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/logger/app_logger.dart';

typedef NotificationNavigationHandler = void Function(
  Map<String, dynamic> data,
);

typedef NotificationBadgeHandler = void Function(String? type);

/// IDs dos canais Android por tipo.
class _AndroidChannels {
  static const String default_ = 'renthus_default';
  static const String chat = 'renthus_chat';
  static const String jobs = 'renthus_jobs';
}

class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  SupabaseClient? _supabaseOverride;
  NotificationNavigationHandler? _onNavigate;
  NotificationBadgeHandler? _onBadge;

  SupabaseClient get _supabase => _supabaseOverride ?? Supabase.instance.client;

  void setSupabaseClient(SupabaseClient client) {
    _supabaseOverride = client;
  }

  bool _initialized = false;

  Future<void> init({
    required NotificationNavigationHandler onNavigate,
    NotificationBadgeHandler? onBadge,
    SupabaseClient? supabaseClient,
  }) async {
    if (_initialized) return;
    if (supabaseClient != null) _supabaseOverride = supabaseClient;
    _onNavigate = onNavigate;
    _onBadge = onBadge;

    // NADA de push em web/desktop
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }

    // 0) Local notifications (para foreground)
    await _initLocalNotifications();

    // 1) Permissões
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    appLogger.d('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _initialized = true;
      return;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2) Token inicial
    final token = await _messaging.getToken();
    appLogger.d('FCM TOKEN (init): $token');
    await _saveDeviceToken(token);

    // 3) Refresh de token
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      appLogger.d('FCM TOKEN REFRESH: $newToken');
      _saveDeviceToken(newToken);
    });

    // 4) Mensagem em foreground → mostrar notificação local
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 5) App em background → usuário clicou na notificação
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      appLogger.d('onMessageOpenedApp: ${message.data}');
      final type = message.data['type'] as String?;
      _onBadge?.call(type);
      onNavigate(message.data);
    });

    // 6) App fechado e aberto pela notificação
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      appLogger.d('getInitialMessage: ${initialMessage.data}');
      final type = initialMessage.data['type'] as String?;
      _onBadge?.call(type);
      onNavigate(initialMessage.data);
    }

    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final channels = [
        const AndroidNotificationChannel(
          _AndroidChannels.default_,
          'Renthus',
          description: 'Notificações gerais do Renthus',
          importance: Importance.high,
        ),
        const AndroidNotificationChannel(
          _AndroidChannels.chat,
          'Chat',
          description: 'Mensagens de chat',
          importance: Importance.high,
        ),
        const AndroidNotificationChannel(
          _AndroidChannels.jobs,
          'Serviços',
          description: 'Atualizações de pedidos e propostas',
          importance: Importance.high,
        ),
      ];

      for (final channel in channels) {
        await androidPlugin?.createNotificationChannel(channel);
      }
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final type = data['type'] as String?;
      _onBadge?.call(type);
      _onNavigate?.call(data);
    } catch (e) {
      appLogger.w('Erro ao parsear payload da notificação: $e');
    }
  }

  String _channelIdForType(String? type) {
    switch (type) {
      case 'chat_message':
      case 'new_message':
        return _AndroidChannels.chat;
      case 'job_status':
      case 'new_candidate':
      case 'new_quote':
      case 'quote_accepted':
      case 'quote_rejected':
      case 'job_started':
      case 'new_job':
      case 'job_accepted':
      case 'job_completed':
      case 'job_cancelled':
      case 'payment_received':
      case 'payment_confirmed':
      case 'payment_failed':
      case 'review_received':
      case 'dispute_opened':
      case 'dispute_resolved':
        return _AndroidChannels.jobs;
      default:
        return _AndroidChannels.default_;
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    appLogger.d('PUSH (onMessage): ${message.data}');
    debugPrint('🔔 PUSH FOREGROUND recebido: ${message.data}');

    final type = message.data['type'] as String?;
    final channelId = _channelIdForType(type);

    debugPrint('🔔 Tipo da notificação: $type');
    
    // Ativa o badge para a seção correspondente
    if (_onBadge != null) {
      debugPrint('🔔 Chamando onBadge callback...');
      _onBadge!(type);
    } else {
      debugPrint('🔔 AVISO: onBadge callback é null!');
    }

    final title = message.notification?.title ?? message.data['title'] ?? 'Renthus';
    final body = message.notification?.body ?? message.data['body'] ?? 'Nova notificação';
    final payload = jsonEncode(message.data);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _AndroidChannels.chat ? 'Chat' : (channelId == _AndroidChannels.jobs ? 'Serviços' : 'Renthus'),
      channelDescription: channelId == _AndroidChannels.chat ? 'Mensagens de chat' : (channelId == _AndroidChannels.jobs ? 'Atualizações de pedidos' : 'Notificações gerais'),
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  Future<void> _saveDeviceToken(String? token) async {
    if (token == null) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final platform = Platform.isAndroid ? 'android' : 'ios';

    try {
      await _supabase.rpc('upsert_fcm_token', params: {
        'p_fcm_token': token,
        'p_platform': platform,
      });
      appLogger.d('FCM token saved via RPC for $platform');
    } catch (e) {
      appLogger.w('RPC upsert_fcm_token failed: $e — trying direct upsert');
      try {
        await _supabase.from('user_devices').upsert(
          {
            'user_id': user.id,
            'fcm_token': token,
            'platform': platform,
            'device_token': token,
          },
          onConflict: 'user_id,platform',
        );
        appLogger.d('FCM token saved via direct upsert for $platform');
      } catch (e2) {
        appLogger.w('Direct upsert also failed: $e2');
      }
    }
  }
}
