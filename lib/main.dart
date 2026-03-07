import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:renthus/firebase_options.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:renthus/core/router/app_router.dart' show goRouter, AppRoutes;

import 'package:renthus/services/push_notification_service.dart';
import 'package:renthus/services/push_navigation_handler.dart';
import 'package:renthus/services/fcm_device_sync.dart';
import 'package:renthus/user_role_holder.dart';
import 'package:renthus/core/providers/notification_badge_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Carregar .env
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'];
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (url == null || url.trim().isEmpty || key == null || key.trim().isEmpty) {
      throw Exception('Variáveis do .env vazias');
    }
    debugPrint('✅ .env carregado: URL=${url.substring(0, 20)}... KEY=${key.substring(0, 20)}...');
  } catch (e) {
    debugPrint('❌ dotenv: $e');
  }

  // 2) Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('✅ Firebase inicializado');
  } catch (e) {
    debugPrint('⚠️ Firebase falhou: $e — continuando sem push');
  }

  // 3) Supabase
  try {
    await Supabase.initialize(
      url: (dotenv.env['SUPABASE_URL'] ?? '').trim(),
      anonKey: (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim(),
    );
    debugPrint('✅ Supabase inicializado');
  } catch (e) {
    debugPrint('❌ Supabase: $e');
  }

  // 4) Hive
  try {
    await Hive.initFlutter();
    debugPrint('✅ Hive inicializado');
  } catch (e) {
    debugPrint('⚠️ Hive: $e');
  }

  // 5) Push Notifications (somente mobile)
  try {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final supa = Supabase.instance.client;
      FcmDeviceSync.setSupabaseClient(supa);

      await FcmDeviceSync.registerCurrentDevice();
      FcmDeviceSync.listenTokenRefresh();

      supa.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          FcmDeviceSync.registerCurrentDevice();
        }
      });

      await PushNotificationService.instance.init(
        supabaseClient: supa,
        onBadge: (type) {
          NotificationBadgeController.instance.showBadgeForType(type);
        },
        onNavigate: (data) {
          final user = supa.auth.currentUser;
          if (user == null) return;

          final role = UserRoleHolder.currentRole;
          debugPrint('onNavigate: data=$data');

          PushNavigationHandler.handle(data, role, user.id);
        },
      );
    }
  } catch (e) {
    debugPrint('⚠️ Push setup: $e');
  }

  // 6) Carregar badges de notificações não lidas
  try {
    if (Supabase.instance.client.auth.currentUser != null) {
      await NotificationBadgeController.instance.loadFromDatabase();
    }
  } catch (_) {}

  // 7) SEMPRE rodar o app
  runApp(const ProviderScope(child: RenthusApp()));

  // 8) Deep link
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final appLinks = AppLinks();
      final uri = await appLinks.getInitialLink();
      if (uri != null && _isResetPasswordLink(uri.toString())) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        goRouter.go(AppRoutes.resetPassword);
      }
    } catch (_) {}
  });
}

bool _isResetPasswordLink(String link) {
  return link.startsWith('renthus://reset-password') ||
      link.contains('reset-password');
}

class RenthusApp extends StatelessWidget {
  const RenthusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
      title: 'Renthus Serviços',
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF3B246B),
        fontFamily: 'Poppins',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
    );
  }
}
