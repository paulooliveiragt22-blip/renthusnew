import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:app_links/app_links.dart';

import 'firebase_options.dart';

// IMPORTS INTERNOS
import 'services/push_notification_service.dart';
import 'services/push_navigation_handler.dart';
import 'services/fcm_device_sync.dart';
import 'app_navigator.dart';

// ✅ Gate único
import 'screens/app_gate_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Não navegue aqui (background isolate). Só garante init do Firebase.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('❌ FlutterError: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };

  ErrorWidget.builder = (details) {
    return Material(
      child: Center(
        child: Text(
          'Erro:\n${details.exception}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  await Supabase.initialize(
    url: 'https://dqfejuakbtcxhymrxoqs.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxZmVqdWFrYnRjeGh5bXJ4b3FzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4MjA4NjUsImV4cCI6MjA3ODM5Njg2NX0.k6dl4CLhdjPEq1DaOOnPWcY6o_Rvv64edJJqdWVPz-4',
  );

  runApp(const RenthusApp());

  // init pós start
  _initAfterAppStart();
}

Future<void> _initAfterAppStart() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

  final supa = Supabase.instance.client;

  try {
    // Registra device (se logado)
    await FcmDeviceSync.registerCurrentDevice()
        .timeout(const Duration(seconds: 10));

    // Escuta refresh de token
    FcmDeviceSync.listenTokenRefresh();

    // Re-registra device quando logar / renovar sessão
    supa.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        FcmDeviceSync.registerCurrentDevice();
      }
    });

    // Push notifications (robusto: handler resolve role no banco)
    await PushNotificationService.instance.init(
      onNavigate: (data) async {
        await PushNavigationHandler.handle(data);
      },
    ).timeout(const Duration(seconds: 10));
  } catch (e, st) {
    debugPrint('❌ Erro no init pós-start: $e');
    debugPrintStack(stackTrace: st);
  }
}

///
/// ✅ Widget raiz que:
/// - mostra o AppGatePage (seu fluxo atual)
/// - escuta deep link (cold + warm)
/// - troca code/token por sessão no Supabase
/// - e volta pro AppGatePage
///
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  bool _handledAuthCallback = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    // 1) Cold start
    try {
      final Uri? initialUri = await _appLinks.getInitialLink(); // ✅ AQUI
      if (initialUri != null) {
        await _handleIncomingUri(initialUri);
      }
    } catch (e) {
      debugPrint('❌ Erro ao ler initial deep link: $e');
    }

    // 2) Warm (app aberto / background)
    _sub = _appLinks.uriLinkStream.listen((Uri uri) async {
      await _handleIncomingUri(uri);
    }, onError: (err) {
      debugPrint('❌ Erro no stream de deep link: $err');
    });
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    // Só processa o callback do auth
    if (uri.scheme != 'renthus' || uri.host != 'auth-callback') return;

    // Evita processar várias vezes (alguns devices disparam duplicado)
    if (_handledAuthCallback) return;
    _handledAuthCallback = true;

    final supabase = Supabase.instance.client;

    try {
      // Troca code/token por sessão no Supabase
      final res = await supabase.auth.getSessionFromUrl(uri);
      final session = res.session;

      if (session == null) {
        // Se não criou sessão, libera para tentar de novo no futuro.
        _handledAuthCallback = false;
        return;
      }

      // ✅ Volta para o AppGatePage (zera stack)
      AppNavigator.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGatePage()),
        (_) => false,
      );
    } catch (e, st) {
      debugPrint('❌ Erro ao processar auth callback: $e');
      debugPrintStack(stackTrace: st);

      // Se falhou, permite tentar de novo (ex: usuário clicou novamente)
      _handledAuthCallback = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mantém seu fluxo atual
    return const AppGatePage();
  }
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
      localeResolutionCallback: (_, __) {
        return const Locale('pt', 'BR');
      },

      // ✅ antes: AppGatePage()
      // ✅ agora: AppRoot() que escuta deep link e depois cai no mesmo AppGate
      home: const AppRoot(),
    );
  }
}
