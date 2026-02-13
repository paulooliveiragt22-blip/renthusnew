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
  const NetworkException([super.message = 'Erro de conexão', super.details]);
}

/// Exceção de autenticação
final class AuthException extends AppException {
  const AuthException([super.message = 'Erro de autenticação', super.details]);
}

/// Exceção de permissão
final class PermissionException extends AppException {
  const PermissionException([super.message = 'Sem permissão', super.details]);
}

/// Exceção de validação
final class ValidationException extends AppException {
  const ValidationException([super.message = 'Dados inválidos', super.details]);
}

/// Exceção de servidor
final class ServerException extends AppException {
  const ServerException([super.message = 'Erro no servidor', super.details]);
}

/// Exceção de cache
final class CacheException extends AppException {
  const CacheException([super.message = 'Erro no cache', super.details]);
}

/// Exceção de não encontrado
final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Não encontrado', super.details]);
}

/// Exceção de timeout
final class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Tempo esgotado', super.details]);
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
