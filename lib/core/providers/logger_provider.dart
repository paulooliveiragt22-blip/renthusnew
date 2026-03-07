import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger_provider.g.dart';

/// Provider do Logger
/// 
/// Fornece um logger estruturado para toda a aplicação
@Riverpod(keepAlive: true)
Logger logger(LoggerRef ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 2, // Número de métodos no stack trace
      errorMethodCount: 8, // Número de métodos em erros
      lineLength: 120, // Largura da linha
      colors: true, // Cores no console
      printEmojis: true, // Emojis nos logs
      printTime: true, // Timestamp nos logs
    ),
    level: _getLogLevel(),
  );
}

/// Determina o nível de log baseado no ambiente
Level _getLogLevel() {
  // Em produção, apenas warnings e errors
  // Em desenvolvimento, tudo
  const isProduction = bool.fromEnvironment('dart.vm.product');
  
  if (isProduction) {
    return Level.warning;
  }
  
  return Level.debug;
}

/// Extension para facilitar uso do logger
extension LoggerX on Logger {
  /// Log de navegação
  void navigation(String from, String to) {
    i('🧭 Navigation: $from → $to');
  }

  /// Log de API call
  void api(String method, String endpoint) {
    d('🌐 API: $method $endpoint');
  }

  /// Log de cache hit/miss
  void cache(String key, bool hit) {
    d('💾 Cache: $key → ${hit ? "HIT" : "MISS"}');
  }

  /// Log de auth
  void auth(String action) {
    i('🔐 Auth: $action');
  }

  /// Log de performance
  void performance(String operation, Duration duration) {
    if (duration.inMilliseconds > 1000) {
      w('⚡ Performance: $operation took ${duration.inMilliseconds}ms');
    } else {
      d('⚡ Performance: $operation took ${duration.inMilliseconds}ms');
    }
  }
}
