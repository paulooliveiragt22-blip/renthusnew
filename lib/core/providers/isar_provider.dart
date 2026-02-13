import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'isar_provider.g.dart';

/// Provider do Isar (banco de dados local)
/// 
/// Fornece acesso ao Isar para operações de cache local
@Riverpod(keepAlive: true)
Future<Isar> isar(IsarRef ref) async {
  final dir = await getApplicationDocumentsDirectory();
  
  final isar = await Isar.open(
    [
      // Adicione seus schemas aqui quando criar os models
      // Exemplo:
      // CachedJobSchema,
      // CachedConversationSchema,
    ],
    directory: dir.path,
    name: 'renthus_cache',
  );
  
  return isar;
}

/// Provider de cache service
/// 
/// Serviço de alto nível para operações de cache
@riverpod
CacheService cacheService(CacheServiceRef ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) {
    throw Exception('Isar not initialized');
  }
  return CacheService(isar);
}

/// Serviço de cache
class CacheService {
  const CacheService(this._isar);

  final Isar _isar;

  /// Limpa todo o cache
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.clear();
    });
  }

  /// Limpa cache antigo (mais de 7 dias)
  Future<void> clearOld() async {
    await _isar.writeTxn(() async {
      // TODO: implementar limpeza baseada em data quando tiver os schemas
    });
  }

  /// Verifica se o cache está válido (menos de 5 minutos)
  bool isCacheValid(DateTime cachedAt, {Duration validity = const Duration(minutes: 5)}) {
    return DateTime.now().difference(cachedAt) < validity;
  }
}
