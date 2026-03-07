import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/services/fcm_device_sync.dart';

const _kRoxo = Color(0xFF3B246B);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _navigated = false;

  late final AnimationController _spinCtrl;
  late final Animation<double> _spinAnim;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _spinAnim = CurvedAnimation(
      parent: _spinCtrl,
      curve: Curves.easeOutCubic,
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    ));

    _startSequence();

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_navigated) {
        debugPrint('⚠️ Splash timeout — forçando navegação');
        _navigateTo(AppRoutes.login);
      }
    });
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _spinCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    _fadeCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _navigated) return;

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    if (_navigated) return;

    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        // Registrar FCM token agora que temos sessão ativa
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          try {
            await FcmDeviceSync.registerCurrentDevice();
          } catch (_) {}
        }

        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('user_role');

        if (!mounted || _navigated) return;
        switch (role) {
          case 'client':
            _navigateTo(AppRoutes.clientHome);
          case 'provider':
            _navigateTo(AppRoutes.providerHome);
          default:
            _navigateTo(AppRoutes.home);
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_completed') ?? false;

      if (!mounted || _navigated) return;
      if (onboardingDone) {
        _navigateTo(AppRoutes.login);
      } else {
        _navigateTo(AppRoutes.onboarding);
      }
    } catch (e) {
      debugPrint('❌ Splash error: $e');
      _navigateTo(AppRoutes.login);
    }
  }

  void _navigateTo(String route) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(route);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kRoxo,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _spinAnim,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spinAnim.value * 2 * math.pi,
                  child: child,
                );
              },
              child: Image.asset(
                'assets/images/renthus_icon_transparent.png',
                width: 120,
                height: 120,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 24),
            SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Image.asset(
                  'assets/images/renthus_text_transparent.png',
                  width: 220,
                  errorBuilder: (_, __, ___) => const Text(
                    'Renthus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
