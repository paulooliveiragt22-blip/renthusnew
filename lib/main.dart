import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/role_selection_page.dart';

// IMPORTS INTERNOS
import 'services/push_notification_service.dart';
import 'services/push_navigation_handler.dart';
import 'services/fcm_device_sync.dart'; // <-- NOVO
import 'app_navigator.dart';
import 'user_role_holder.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Supabase
  await Supabase.initialize(
    url: 'https://dqfejuakbtcxhymrxoqs.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxZmVqdWFrYnRjeGh5bXJ4b3FzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4MjA4NjUsImV4cCI6MjA3ODM5Njg2NX0.k6dl4CLhdjPEq1DaOOnPWcY6o_Rvv64edJJqdWVPz-4',
  );

  // Somente dispositivos móveis (Android / iOS)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final supa = Supabase.instance.client;

    // 1) registra/atualiza o device atual assim que o app sobe
    await FcmDeviceSync.registerCurrentDevice();

    // 2) escuta mudanças de token do FCM e atualiza no Supabase
    FcmDeviceSync.listenTokenRefresh();

    // 3) quando o usuário logar ou o token da sessão mudar, registramos de novo
    supa.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        FcmDeviceSync.registerCurrentDevice();
      }
    });

    // 4) PushNotificationService para reagir às notificações
    await PushNotificationService.instance.init(
      onNavigate: (data) {
        final user = supa.auth.currentUser;
        if (user == null) return;

        final role = UserRoleHolder.currentRole; // 'client' ou 'provider'

        PushNavigationHandler.handle(
          data,
          role,
          user.id,
        );
      },
    );
  }

  runApp(const RenthusApp());
}

class RenthusApp extends StatelessWidget {
  const RenthusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Renthus Service',
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF3B246B),
        fontFamily: "Poppins",
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
      localeResolutionCallback: (locale, supported) {
        return const Locale('pt', 'BR');
      },
      home: const RoleSelectionPage(),
    );
  }
}
