import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/notifications/data/repositories/notification_repository.dart';
import 'package:renthus/features/notifications/domain/models/app_notification_model.dart';

part 'notification_providers.g.dart';

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return NotificationRepository(supabase);
}

@riverpod
Future<List<AppNotification>> notificationsList(NotificationsListRef ref, String userId) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return await repository.getNotifications(userId);
}

@riverpod
Stream<List<AppNotification>> notificationsStream(NotificationsStreamRef ref, String userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.watchNotifications(userId);
}

@riverpod
Future<int> unreadNotificationsCount(UnreadNotificationsCountRef ref, String userId) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return await repository.getUnreadCount(userId);
}

@riverpod
class NotificationActions extends _$NotificationActions {
  @override
  FutureOr<void> build() async {}

  Future<void> markAsRead(String id, String userId) async {
    final repository = ref.read(notificationRepositoryProvider);
    await repository.markAsRead(id);
    ref.invalidate(notificationsListProvider(userId));
    ref.invalidate(unreadNotificationsCountProvider(userId));
  }

  Future<void> markAllAsRead(String userId) async {
    final repository = ref.read(notificationRepositoryProvider);
    await repository.markAllAsRead(userId);
    ref.invalidate(notificationsListProvider(userId));
    ref.invalidate(unreadNotificationsCountProvider(userId));
  }
}
