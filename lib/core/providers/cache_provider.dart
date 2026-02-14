import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cache_provider.g.dart';

/// Provider de cache service
///
/// Serviço de cache usando Hive
@riverpod
CacheService cacheService(CacheServiceRef ref) {
  return CacheService();
}

/// Serviço de cache usando Hive
class CacheService {
  Future<Box<dynamic>> get _cacheBox async {
    if (!Hive.isBoxOpen('cache')) {
      return await Hive.openBox('cache');
    }
    return Hive.box('cache');
  }

  Future<Box<dynamic>> get _jobsBox async {
    if (!Hive.isBoxOpen('jobs_cache')) {
      return await Hive.openBox('jobs_cache');
    }
    return Hive.box('jobs_cache');
  }

  Future<Box<dynamic>> get _conversationsBox async {
    if (!Hive.isBoxOpen('conversations_cache')) {
      return await Hive.openBox('conversations_cache');
    }
    return Hive.box('conversations_cache');
  }

  /// Salvar dados no cache com timestamp
  Future<void> set(String key, dynamic value) async {
    final box = await _cacheBox;
    await box.put(key, {
      'data': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Buscar dados do cache (com expiração automática)
  Future<T?> get<T>(
    String key, {
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final box = await _cacheBox;
    final cached = box.get(key);

    if (cached == null) return null;

    final data = cached as Map;
    final timestamp = data['timestamp'] as int;
    final value = data['data'];

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAge.inMilliseconds) {
      await box.delete(key);
      return null;
    }

    return value as T?;
  }

  /// Deletar do cache
  Future<void> delete(String key) async {
    final box = await _cacheBox;
    await box.delete(key);
  }

  /// Limpa cache de jobs
  Future<void> clearJobs() async {
    await (await _jobsBox).clear();
  }

  /// Limpa cache de conversas
  Future<void> clearConversations() async {
    await (await _conversationsBox).clear();
  }

  /// Limpar todo o cache
  Future<void> clearAll() async {
    await (await _cacheBox).clear();
    await (await _jobsBox).clear();
    await (await _conversationsBox).clear();
  }

  /// Limpar cache antigo (mais de 7 dias)
  Future<void> clearOld({Duration maxAge = const Duration(days: 7)}) async {
    final box = await _cacheBox;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = maxAge.inMilliseconds;

    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map && value['timestamp'] != null) {
        final age = now - (value['timestamp'] as int);
        if (age > maxAgeMs) {
          keysToDelete.add(key);
        }
      }
    }

    await box.deleteAll(keysToDelete);
  }

  /// Salvar lista de jobs
  Future<void> saveJobs(String key, List<Map<String, dynamic>> jobs) async {
    final box = await _jobsBox;
    await box.put(key, {
      'jobs': jobs,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Buscar lista de jobs
  Future<List<Map<String, dynamic>>?> getJobs(
    String key, {
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final box = await _jobsBox;
    final cached = box.get(key);

    if (cached == null) return null;

    final data = cached as Map;
    final timestamp = data['timestamp'] as int;
    final jobs = data['jobs'] as List;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAge.inMilliseconds) {
      await box.delete(key);
      return null;
    }

    return jobs.cast<Map<String, dynamic>>();
  }

  /// Salvar lista de conversas
  Future<void> saveConversations(
    String userId,
    List<Map<String, dynamic>> conversations,
  ) async {
    final box = await _conversationsBox;
    await box.put(userId, {
      'conversations': conversations,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Buscar lista de conversas
  Future<List<Map<String, dynamic>>?> getConversations(
    String userId, {
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final box = await _conversationsBox;
    final cached = box.get(userId);

    if (cached == null) return null;

    final data = cached as Map;
    final timestamp = data['timestamp'] as int;
    final conversations = data['conversations'] as List;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAge.inMilliseconds) {
      await box.delete(userId);
      return null;
    }

    return conversations.cast<Map<String, dynamic>>();
  }

  /// Verifica se o cache é válido
  bool isCacheValid(
    DateTime cachedAt, {
    Duration validity = const Duration(minutes: 5),
  }) {
    return DateTime.now().difference(cachedAt) < validity;
  }

  /// Tamanho do cache em MB (aproximado)
  Future<double> getCacheSizeMB() async {
    final box = await _cacheBox;
    return box.length * 0.001;
  }
}
