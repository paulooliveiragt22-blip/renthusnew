import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/notifications/data/repositories/legacy_notification_repository.dart';

part 'legacy_notification_provider.g.dart';

@Riverpod(keepAlive: true)
LegacyNotificationRepository legacyNotificationRepository(
    LegacyNotificationRepositoryRef ref,) {
  final supabase = ref.watch(supabaseProvider);
  return LegacyNotificationRepository(client: supabase);
}
