import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/exceptions/app_exceptions.dart';
import 'package:renthus/core/providers/logger_provider.dart';

part 'error_handler_provider.g.dart';

/// Provider do Error Handler
@riverpod
class ErrorHandler extends _$ErrorHandler {
  @override
  void build() {}

  /// Trata um erro e retorna uma mensagem amigável
  String handle(Object error, [StackTrace? stackTrace]) {
    final logger = ref.read(loggerProvider);

    // Log do erro
    logger.e('Error occurred', error: error, stackTrace: stackTrace);

    // Converte para AppException se necessário
    final appException = _toAppException(error);

    // Retorna mensagem amigável
    return _getFriendlyMessage(appException);
  }

  /// Converte qualquer erro para AppException
  AppException _toAppException(Object error) {
    if (error is AppException) {
      return error;
    }

    // Tenta parsear erro do Supabase
    try {
      return parseSupabaseException(error);
    } catch (_) {
      return ServerException('Algo deu errado', error);
    }
  }

  /// Retorna mensagem amigável para o usuário
  String _getFriendlyMessage(AppException exception) {
    return switch (exception) {
      NetworkException() => 
        'Sem conexão com a internet. Verifique sua conexão e tente novamente.',
      
      AuthException() => 
        'Sessão expirada. Por favor, faça login novamente.',
      
      PermissionException() => 
        'Você não tem permissão para realizar esta ação.',
      
      ValidationException() => 
        exception.message,
      
      NotFoundException() => 
        'O item solicitado não foi encontrado.',
      
      TimeoutException() => 
        'A operação demorou muito. Tente novamente.',
      
      CacheException() => 
        'Erro ao acessar dados locais.',
      
      ServerException() => 
        'Erro no servidor. Tente novamente em alguns instantes.',
    };
  }

  /// Verifica se o erro é recuperável (pode tentar novamente)
  bool isRecoverable(Object error) {
    final appException = _toAppException(error);
    
    return switch (appException) {
      NetworkException() => true,
      TimeoutException() => true,
      ServerException() => true,
      _ => false,
    };
  }
}
