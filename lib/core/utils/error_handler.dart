import 'package:flutter/material.dart';

import 'package:renthus/core/exceptions/app_exceptions.dart';

/// Utilitário para tratamento padronizado de erros.
class ErrorHandler {
  ErrorHandler._();

  /// Exibe SnackBar com mensagem do erro.
  static void showSnackBar(BuildContext context, dynamic error) {
    if (!context.mounted) return;
    final msg = _messageFromError(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  /// Converte erro para mensagem amigável.
  static String _messageFromError(dynamic error) {
    if (error is AppException) return error.message;
    if (error is Exception) return error.toString().replaceFirst('Exception: ', '');
    return error?.toString() ?? 'Erro desconhecido';
  }
}
