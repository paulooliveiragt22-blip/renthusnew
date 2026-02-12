# 🚀 GERADOR AUTOMÁTICO DE ARQUIVOS - MIGRAÇÃO COMPLETA
# Execute este script para criar TODOS os repositories e providers

$ErrorActionPreference = "Stop"

Write-Host "🚀 Iniciando geração automática..." -ForegroundColor Green

# ==================== JOB REPOSITORY ====================
$jobRepository = @"
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:renthus/core/exceptions/app_exceptions.dart';
import 'package:renthus/models/job.dart';

class JobRepository {
  const JobRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<Job>> getJobs({String? city, String? status}) async {
    try {
      var query = _supabase.from('jobs').select();
      if (city != null) query = query.eq('city', city);
      if (status != null) query = query.eq('status', status);
      
      final data = await query.order('created_at', ascending: false);
      return data.map((e) => Job.fromMap(e)).toList();
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<Job> getJobById(String id) async {
    try {
      final data = await _supabase.from('jobs').select().eq('id', id).single();
      return Job.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<Job> createJob(Map<String, dynamic> jobData) async {
    try {
      final data = await _supabase.from('jobs').insert(jobData).select().single();
      return Job.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<Job> updateJob(String id, Map<String, dynamic> updates) async {
    try {
      final data = await _supabase.from('jobs').update(updates).eq('id', id).select().single();
      return Job.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Stream<List<Job>> watchJobs({String? city}) {
    var query = _supabase.from('jobs').stream(primaryKey: ['id']);
    if (city != null) query = query.eq('city', city);
    return query.map((data) => data.map((e) => Job.fromMap(e)).toList());
  }
}
"@

New-Item -ItemType Directory -Force -Path "lib\features\jobs\data\repositories" | Out-Null
$jobRepository | Out-File -FilePath "lib\features\jobs\data\repositories\job_repository.dart" -Encoding UTF8
Write-Host "✅ job_repository.dart" -ForegroundColor Green

# ==================== JOB PROVIDERS ====================
$jobProviders = @"
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/jobs/data/repositories/job_repository.dart';
import 'package:renthus/models/job.dart';

part 'job_providers.g.dart';

@riverpod
JobRepository jobRepository(JobRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return JobRepository(supabase);
}

@riverpod
Future<List<Job>> jobsList(JobsListRef ref, {String? city, String? status}) async {
  final repository = ref.watch(jobRepositoryProvider);
  return await repository.getJobs(city: city, status: status);
}

@riverpod
Future<Job> jobById(JobByIdRef ref, String id) async {
  final repository = ref.watch(jobRepositoryProvider);
  return await repository.getJobById(id);
}

@riverpod
Stream<List<Job>> jobsStream(JobsStreamRef ref, {String? city}) {
  final repository = ref.watch(jobRepositoryProvider);
  return repository.watchJobs(city: city);
}

@riverpod
class JobActions extends _`$JobActions {
  @override
  FutureOr<void> build() async {}

  Future<Job?> create(Map<String, dynamic> jobData) async {
    state = const AsyncValue.loading();
    
    return await AsyncValue.guard(() async {
      final repository = ref.read(jobRepositoryProvider);
      final job = await repository.createJob(jobData);
      ref.invalidate(jobsListProvider);
      return job;
    }).then((result) => result.value);
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    
    state = await AsyncValue.guard(() async {
      final repository = ref.read(jobRepositoryProvider);
      await repository.updateJob(id, updates);
      ref.invalidate(jobsListProvider);
      ref.invalidate(jobByIdProvider(id));
    });
  }
}
"@

New-Item -ItemType Directory -Force -Path "lib\features\jobs\data\providers" | Out-Null
$jobProviders | Out-File -FilePath "lib\features\jobs\data\providers\job_providers.dart" -Encoding UTF8
Write-Host "✅ job_providers.dart" -ForegroundColor Green

# ==================== CHAT PROVIDERS ====================
$chatProviders = @"
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/chat/data/repositories/chat_repository.dart';
import 'package:renthus/features/chat/domain/models/conversation_model.dart';
import 'package:renthus/features/chat/domain/models/message_model.dart';

part 'chat_providers.g.dart';

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return ChatRepository(supabase);
}

@riverpod
Future<List<Conversation>> conversationsList(ConversationsListRef ref, String userId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return await repository.getConversations(userId);
}

@riverpod
Stream<List<Conversation>> conversationsStream(ConversationsStreamRef ref, String userId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchConversations(userId);
}

@riverpod
Future<List<Message>> messagesList(MessagesListRef ref, String conversationId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return await repository.getMessages(conversationId);
}

@riverpod
Stream<List<Message>> messagesStream(MessagesStreamRef ref, String conversationId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchMessages(conversationId);
}

@riverpod
Future<int> unreadMessagesCount(UnreadMessagesCountRef ref, String userId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return await repository.getUnreadCount(userId);
}

@riverpod
class ChatActions extends _`$ChatActions {
  @override
  FutureOr<void> build() async {}

  Future<Message?> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
  }) async {
    state = const AsyncValue.loading();
    
    return await AsyncValue.guard(() async {
      final repository = ref.read(chatRepositoryProvider);
      return await repository.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        type: type,
        imageUrl: imageUrl,
      );
    }).then((result) => result.value);
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    final repository = ref.read(chatRepositoryProvider);
    await repository.markAsRead(conversationId: conversationId, userId: userId);
  }
}
"@

New-Item -ItemType Directory -Force -Path "lib\features\chat\data\providers" | Out-Null
$chatProviders | Out-File -FilePath "lib\features\chat\data\providers\chat_providers.dart" -Encoding UTF8
Write-Host "✅ chat_providers.dart" -ForegroundColor Green

# ==================== NOTIFICATION REPOSITORY ====================
$notificationRepository = @"
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
"@

New-Item -ItemType Directory -Force -Path "lib\features\notifications\data\repositories" | Out-Null
$notificationRepository | Out-File -FilePath "lib\features\notifications\data\repositories\notification_repository.dart" -Encoding UTF8
Write-Host "✅ notification_repository.dart" -ForegroundColor Green

# ==================== NOTIFICATION PROVIDERS ====================
$notificationProviders = @"
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
class NotificationActions extends _`$NotificationActions {
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
"@

New-Item -ItemType Directory -Force -Path "lib\features\notifications\data\providers" | Out-Null
$notificationProviders | Out-File -FilePath "lib\features\notifications\data\providers\notification_providers.dart" -Encoding UTF8
Write-Host "✅ notification_providers.dart" -ForegroundColor Green

Write-Host "`n🎉 ARQUIVOS CRÍTICOS CRIADOS COM SUCESSO!" -ForegroundColor Green
Write-Host "`n📦 Próximo passo:" -ForegroundColor Yellow
Write-Host "dart run build_runner build --delete-conflicting-outputs --build-filter=`"lib/features/**`"" -ForegroundColor Cyan
