import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> saveFcmTokenToSupabase() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    debugPrint('saveFcmTokenToSupabase: usuário não logado');
    return;
  }

  final fcm = FirebaseMessaging.instance;
  final token = await fcm.getToken();

  if (token == null) {
    debugPrint('saveFcmTokenToSupabase: token FCM veio null');
    return;
  }

  // Só pra debug
  debugPrint('Registrando FCM token no Supabase: $token');

  final platform =
      defaultTargetPlatform.toString(); // ex: TargetPlatform.android

  await supabase.from('user_devices').upsert({
    'user_id': user.id,
    'fcm_token': token,
    'platform': platform,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
}
