import 'package:flutter/material.dart';

import 'package:renthus/core/exceptions/app_exceptions.dart';

/// Utilitário para tratamento padronizado de erros.
class ErrorHandler {
  ErrorHandler._();

  /// Converte exceções técnicas (Supabase/Postgrest) em mensagens amigáveis.
  static String friendlyErrorMessage(dynamic error) {
    if (error == null) return 'Algo deu errado. Tente novamente.';
    if (error is AppException) return error.message;

    final msg = error.toString().toLowerCase();

    // Erros de banco/Supabase
    if (msg.contains('pgrst') || msg.contains('postgrest')) {
      return 'Ops! Algo deu errado no servidor. Tente novamente em instantes.';
    }
    if (msg.contains('could not find') && msg.contains('column')) {
      return 'Ops! Algo deu errado no servidor. Tente novamente em instantes.';
    }
    if (msg.contains('violates check constraint')) {
      return 'Dados inválidos. Verifique as informações e tente novamente.';
    }
    if (msg.contains('violates unique constraint')) {
      return 'Este registro já existe.';
    }
    if (msg.contains('violates foreign key')) {
      return 'Não foi possível completar. Um item relacionado não foi encontrado.';
    }
    if (msg.contains('permission denied') || msg.contains('rls')) {
      return 'Você não tem permissão para esta ação.';
    }
    if (msg.contains('jwt expired') || msg.contains('not authenticated')) {
      return 'Sua sessão expirou. Faça login novamente.';
    }

    // Erros de rede
    if (msg.contains('socketexception') || msg.contains('connection refused')) {
      return 'Sem conexão com a internet. Verifique sua rede.';
    }
    if (msg.contains('timeout')) {
      return 'O servidor demorou para responder. Tente novamente.';
    }
    if (msg.contains('handshake')) {
      return 'Erro de conexão segura. Verifique sua rede.';
    }

    // Erros de storage/upload
    if (msg.contains('payload too large') || msg.contains('file size')) {
      return 'Arquivo muito grande. Tente com uma foto menor.';
    }
    if (msg.contains('storage') && msg.contains('not found')) {
      return 'Erro ao enviar arquivo. Tente novamente.';
    }

    // Fallback genérico
    return 'Algo deu errado. Tente novamente.';
  }

  /// Exibe SnackBar com mensagem amigável do erro.
  static void showSnackBar(BuildContext context, dynamic error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(friendlyErrorMessage(error)),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}
