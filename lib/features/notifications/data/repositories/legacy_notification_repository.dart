import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:renthus/models/app_notification.dart';

/// Repositório legado: fetchLatest, fetchUnreadCount (home/client).
class LegacyNotificationRepository {

  LegacyNotificationRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;

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

  Future<List<AppNotification>> fetchNotifications({int limit = 30}) async {
    return fetchLatest(limit: limit);
  }

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
    return fetchUnreadCount();
  }

  Future<void> markAsRead(String notificationId) async {
    await _db
        .from('notifications')
        .update({'read': true}).eq('id', notificationId);
  }

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
