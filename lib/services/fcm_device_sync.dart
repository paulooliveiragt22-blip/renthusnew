import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class FcmDeviceSync {
  FcmDeviceSync._();

  static final _supabase = Supabase.instance.client;
  static final _fcm = FirebaseMessaging.instance;
  static final _deviceInfo = DeviceInfoPlugin();
  static const _deviceIdKey = 'renthus_device_id';

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  /// ✅ Device ID estável e seguro (UUID persistido)
  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final newId = const Uuid().v4();
    await prefs.setString(_deviceIdKey, newId);
    return newId;
  }

  static Future<void> registerCurrentDevice() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _fcm.requestPermission();

    final fcmToken = await _fcm.getToken();
    if (fcmToken == null) return;

    final platform = _platform();
    final deviceId = await _getOrCreateDeviceId();

    // 🔐 Formato final do device_token
    final deviceToken = '$platform:$deviceId';

    try {
      await _supabase.rpc('register_device_and_push', params: {
        'p_fcm_token': fcmToken,
        'p_platform': platform,
        'p_device_token': deviceToken,
      });
      return;
    } catch (e) {
      debugPrint('❌ RPC register_device_and_push falhou: $e');
    }

    // Fallback de segurança
    await _supabase.from('user_devices').upsert(
      {
        'user_id': user.id,
        'fcm_token': fcmToken,
        'platform': platform,
        'device_token': deviceToken,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,device_token',
    );
  }

  static void listenTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final platform = _platform();
      final deviceId = await _getOrCreateDeviceId();
      final deviceToken = '$platform:$deviceId';

      try {
        await _supabase.rpc('register_device_and_push', params: {
          'p_fcm_token': newToken,
          'p_platform': platform,
          'p_device_token': deviceToken,
        });
        return;
      } catch (e) {
        debugPrint('❌ RPC token refresh falhou: $e');
      }

      await _supabase.from('user_devices').upsert(
        {
          'user_id': user.id,
          'fcm_token': newToken,
          'platform': platform,
          'device_token': deviceToken,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,device_token',
      );
    });
  }
}
