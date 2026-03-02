import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:renthus/core/exceptions/app_exceptions.dart';
import 'package:renthus/features/notifications/domain/models/app_notification_model.dart';

class NotificationRepository {
  const NotificationRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return data.map((e) => AppNotification.fromMap(e)).toList();
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _supabase.from('notifications').update({
        'read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase.from('notifications').update({
        'read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId).eq('read', false);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final data = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);

      return (data as List).length;
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  /// Counts per category for badge display
  Future<Map<String, int>> getUnreadCountsByCategory(String userId) async {
    try {
      final rows = await _supabase
          .from('notifications')
          .select('type')
          .eq('user_id', userId)
          .eq('read', false);

      int jobs = 0, chat = 0, profile = 0;
      for (final row in rows as List) {
        final t = row['type'] as String?;
        if (t == null) continue;
        final cat = NotificationType.fromString(t).category;
        switch (cat) {
          case NotificationCategory.jobs: jobs++;
          case NotificationCategory.chat: chat++;
          case NotificationCategory.profile: profile++;
          case NotificationCategory.general: break;
        }
      }
      return {'jobs': jobs, 'chat': chat, 'profile': profile, 'total': jobs + chat + profile};
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => AppNotification.fromMap(e)).toList());
  }
}
