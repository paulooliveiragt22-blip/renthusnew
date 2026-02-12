/// Exceções customizadas do app
library;

/// Exceção base do app
sealed class AppException implements Exception {
  const AppException(this.message, [this.details]);

  final String message;
  final dynamic details;

  @override
  String toString() => 'AppException: $message${details != null ? ' ($details)' : ''}';
}

/// Exceção de rede
final class NetworkException extends AppException {
  const NetworkException([String message = 'Erro de conexão', dynamic details])
      : super(message, details);
}

/// Exceção de autenticação
final class AuthException extends AppException {
  const AuthException([String message = 'Erro de autenticação', dynamic details])
      : super(message, details);
}

/// Exceção de permissão
final class PermissionException extends AppException {
  const PermissionException([String message = 'Sem permissão', dynamic details])
      : super(message, details);
}

/// Exceção de validação
final class ValidationException extends AppException {
  const ValidationException([String message = 'Dados inválidos', dynamic details])
      : super(message, details);
}

/// Exceção de servidor
final class ServerException extends AppException {
  const ServerException([String message = 'Erro no servidor', dynamic details])
      : super(message, details);
}

/// Exceção de cache
final class CacheException extends AppException {
  const CacheException([String message = 'Erro no cache', dynamic details])
      : super(message, details);
}

/// Exceção de não encontrado
final class NotFoundException extends AppException {
  const NotFoundException([String message = 'Não encontrado', dynamic details])
      : super(message, details);
}

/// Exceção de timeout
final class TimeoutException extends AppException {
  const TimeoutException([String message = 'Tempo esgotado', dynamic details])
      : super(message, details);
}

/// Helper para converter exceções do Supabase
AppException parseSupabaseException(dynamic error) {
  final message = error.toString().toLowerCase();

  if (message.contains('network') || message.contains('socket')) {
    return NetworkException('Sem conexão com a internet', error);
  }

  if (message.contains('jwt') || 
      message.contains('token') || 
      message.contains('unauthorized') ||
      message.contains('invalid_grant')) {
    return const AuthException('Sessão expirada. Faça login novamente');
  }

  if (message.contains('permission') || message.contains('forbidden')) {
    return const PermissionException('Você não tem permissão para esta ação');
  }

  if (message.contains('not found') || message.contains('404')) {
    return const NotFoundException('Recurso não encontrado');
  }

  if (message.contains('timeout')) {
    return const TimeoutException('Operação demorou muito');
  }

  if (message.contains('validation') || message.contains('invalid')) {
    return ValidationException('Dados inválidos', error);
  }

  return ServerException('Erro no servidor', error);
}
