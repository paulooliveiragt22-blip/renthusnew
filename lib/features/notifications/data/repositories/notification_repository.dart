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
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId).eq('is_read', false);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final count = await _supabase
          .from('notifications')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('user_id', userId)
          .eq('is_read', false);

      return count.count ?? 0;
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
