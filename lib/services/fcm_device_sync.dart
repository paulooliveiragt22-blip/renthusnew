import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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

  static Future<void> removeCurrentDevice() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      await _supabase
          .from('user_devices')
          .delete()
          .eq('fcm_token', token);

      debugPrint('🔔 FCM token removed');
    } catch (e) {
      debugPrint('🔔 removeCurrentDevice error: $e');
    }
  }

  static Future<void> registerCurrentDevice() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('🔔 registerCurrentDevice: skipped (no user)');
      return;
    }

    try {
      final settings = await _fcm.requestPermission(
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('🔔 Push permission denied');
        return;
      }

      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('🔔 FCM token is null');
        return;
      }
      debugPrint('🔔 FCM token: ${token.substring(0, 20)}...');

      final platform = Platform.isAndroid ? 'android' : 'ios';

      try {
        await _supabase.rpc('upsert_fcm_token', params: {
          'p_fcm_token': token,
          'p_platform': platform,
        });
        debugPrint('🔔 Token saved via RPC');
      } catch (rpcErr) {
        debugPrint('🔔 RPC failed: $rpcErr, trying direct upsert');
        await _supabase.from('user_devices').upsert(
          {
            'user_id': user.id,
            'fcm_token': token,
            'platform': platform,
            'device_token': token,
          },
          onConflict: 'user_id,platform',
        );
      }
    } catch (e) {
      debugPrint('🔔 registerCurrentDevice error: $e');
    }
  }

  static void listenTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final platform = Platform.isAndroid ? 'android' : 'ios';

      try {
        await _supabase.rpc('upsert_fcm_token', params: {
          'p_fcm_token': newToken,
          'p_platform': platform,
        });
        debugPrint('🔔 FCM token refreshed');
      } catch (e) {
        debugPrint('🔔 onTokenRefresh error: $e');
      }
    });
  }
}
