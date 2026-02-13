import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🆕 ADICIONAR

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:renthus/firebase_options.dart';

import 'package:renthus/core/router/app_router.dart';

// IMPORTS INTERNOS
import 'package:renthus/services/push_notification_service.dart';
import 'package:renthus/services/push_navigation_handler.dart';
import 'package:renthus/services/fcm_device_sync.dart';
import 'package:renthus/user_role_holder.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 1) CARREGAR VARIÁVEIS DE AMBIENTE
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ Variáveis de ambiente carregadas com sucesso');
  } catch (e) {
    debugPrint('⚠️ Erro ao carregar .env: $e');
    debugPrint(
        '⚠️ Certifique-se de que o arquivo .env existe na raiz do projeto',);
  }

  // 2) Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔐 3) Supabase com variáveis de ambiente
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  // Validação das variáveis
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception(
      '❌ SUPABASE_URL não encontrada no .env\n'
      'Certifique-se de:\n'
      '1. Criar arquivo .env na raiz do projeto\n'
      '2. Adicionar SUPABASE_URL=sua_url\n'
      '3. Adicionar .env aos assets no pubspec.yaml',
    );
  }

  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception(
      '❌ SUPABASE_ANON_KEY não encontrada no .env\n'
      'Certifique-se de:\n'
      '1. Criar arquivo .env na raiz do projeto\n'
      '2. Adicionar SUPABASE_ANON_KEY=sua_chave\n'
      '3. Adicionar .env aos assets no pubspec.yaml',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  debugPrint('✅ Supabase inicializado com sucesso');
  debugPrint('📍 URL: $supabaseUrl');

  // 4) Push Notifications (somente dispositivos móveis)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final supa = Supabase.instance.client;
    FcmDeviceSync.setSupabaseClient(supa);

    // Registra/atualiza o device atual
    await FcmDeviceSync.registerCurrentDevice();

    // Escuta mudanças de token do FCM
    FcmDeviceSync.listenTokenRefresh();

    // Quando o usuário logar ou o token da sessão mudar
    supa.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        FcmDeviceSync.registerCurrentDevice();
      }
    });

    // PushNotificationService para reagir às notificações
    await PushNotificationService.instance.init(
      supabaseClient: supa,
      onNavigate: (data) {
        final user = supa.auth.currentUser;
        if (user == null) return;

        final role = UserRoleHolder.currentRole;

        PushNavigationHandler.handle(
          data,
          role,
          user.id,
        );
      },
    );
  }

  // 🆕 5) ENVOLVER COM ProviderScope (ESSENCIAL PARA RIVERPOD!)
  runApp(
    const ProviderScope(  // 🆕 ADICIONAR
      child: RenthusApp(),
    ),
  );
}

class RenthusApp extends StatelessWidget {
  const RenthusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
      title: 'Renthus Service',
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