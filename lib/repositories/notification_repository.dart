import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

class NotificationRepository {
  final SupabaseClient _db;

  NotificationRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  /// Versão original que você já usava
  Future<List<AppNotification>> fetchLatest({int limit = 30}) async {
    final user = _db.auth.currentUser;
    if (user == null) return [];

    final response = await _db
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .eq('channel', 'app')
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Alias mais genérico (para quem chama `fetchNotifications`)
  Future<List<AppNotification>> fetchNotifications({int limit = 30}) async {
    return fetchLatest(limit: limit);
  }

  /// Versão original: quantidade de notificações não lidas
  Future<int> fetchUnreadCount() async {
    final user = _db.auth.currentUser;
    if (user == null) return 0;

    final response = await _db
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('channel', 'app')
        .eq('read', false);

    return (response as List).length;
  }

  /// Alias compatível com o que estamos usando na Home
  /// Aceita opcionalmente um userId (para futuros usos), mas pode ser chamado sem nada.
  Future<int> getUnreadCount([String? userId]) async {
    if (userId != null) {
      final response = await _db
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('channel', 'app')
          .eq('read', false);

      return (response as List).length;
    }

    // fallback: usa o usuário logado
    return fetchUnreadCount();
  }

  /// Marca uma notificação como lida
  Future<void> markAsRead(String notificationId) async {
    await _db
        .from('notifications')
        .update({'read': true}).eq('id', notificationId);
  }

  /// Marca todas as notificações como lidas
  Future<void> markAllAsRead() async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    await _db
        .from('notifications')
        .update({'read': true})
        .eq('user_id', user.id)
        .eq('channel', 'app')
        .eq('read', false);
  }
}
