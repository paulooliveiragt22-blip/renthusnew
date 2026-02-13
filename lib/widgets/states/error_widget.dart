import 'package:flutter/material.dart';

/// Widget de Error State
///
/// Uso:
/// ```dart
/// ErrorWidget.network(onRetry: () => fetch())
/// ErrorWidget.generic(message: 'Algo deu errado')
/// ErrorWidget.notFound(message: 'Item não encontrado')
/// ErrorWidget.permission(message: 'Sem permissão')
/// ```
class ErrorStateWidget extends StatelessWidget {

  const ErrorStateWidget({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.iconColor,
    this.onRetry,
    this.retryButtonText = 'Tentar novamente',
    this.fullScreen = false,
  });

  /// Erro de rede (sem conexão)
  const ErrorStateWidget.network({
    super.key,
    String? message,
    VoidCallback? onRetry,
  })  : title = 'Sem conexão',
        message = message ??
            'Verifique sua conexão com a internet e tente novamente.',
        icon = Icons.wifi_off,
        iconColor = Colors.orange,
        onRetry = onRetry,
        retryButtonText = 'Tentar novamente',
        fullScreen = false;

  /// Erro genérico
  const ErrorStateWidget.generic({
    super.key,
    String? message,
    VoidCallback? onRetry,
  })  : title = 'Algo deu errado',
        message = message ?? 'Ocorreu um erro inesperado. Tente novamente.',
        icon = Icons.error_outline,
        iconColor = Colors.red,
        onRetry = onRetry,
        retryButtonText = 'Tentar novamente',
        fullScreen = false;

  /// Erro de servidor (500)
  const ErrorStateWidget.server({
    super.key,
    VoidCallback? onRetry,
  })  : title = 'Erro no servidor',
        message =
            'Nosso servidor está com problemas. Tente novamente em alguns minutos.',
        icon = Icons.cloud_off,
        iconColor = Colors.red,
        onRetry = onRetry,
        retryButtonText = 'Tentar novamente',
        fullScreen = false;

  /// Timeout (demora demais)
  const ErrorStateWidget.timeout({
    super.key,
    VoidCallback? onRetry,
  })  : title = 'Tempo esgotado',
        message =
            'A operação demorou muito. Verifique sua conexão e tente novamente.',
        icon = Icons.hourglass_empty,
        iconColor = Colors.orange,
        onRetry = onRetry,
        retryButtonText = 'Tentar novamente',
        fullScreen = false;

  /// Permissão negada
  const ErrorStateWidget.permission({
    super.key,
    String? message,
  })  : title = 'Sem permissão',
        message =
            message ?? 'Você não tem permissão para acessar este recurso.',
        icon = Icons.lock_outline,
        iconColor = Colors.grey,
        onRetry = null,
        retryButtonText = null,
        fullScreen = false;

  /// Não encontrado (404)
  const ErrorStateWidget.notFound({
    super.key,
    String? message,
  })  : title = 'Não encontrado',
        message = message ?? 'O item que você procura não foi encontrado.',
        icon = Icons.search_off,
        iconColor = Colors.grey,
        onRetry = null,
        retryButtonText = null,
        fullScreen = false;

  /// Versão fullscreen
  const ErrorStateWidget.fullScreen({
    super.key,
    required String title,
    required String message,
    required IconData icon,
    Color? iconColor,
    VoidCallback? onRetry,
  })  : title = title,
        message = message,
        icon = icon,
        iconColor = iconColor,
        onRetry = onRetry,
        retryButtonText = 'Tentar novamente',
        fullScreen = true;
  final String title;
  final String message;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onRetry;
  final String? retryButtonText;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ícone
        Icon(
          icon,
          size: fullScreen ? 80 : 60,
          color: iconColor ?? Colors.grey,
        ),
        const SizedBox(height: 24),

        // Título
        Text(
          title,
          style: TextStyle(
            fontSize: fullScreen ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Mensagem
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            style: TextStyle(
              fontSize: fullScreen ? 16 : 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Botão de retry
        if (onRetry != null) ...[
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryButtonText ?? 'Tentar novamente'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return ColoredBox(
        color: Colors.white,
        child: Center(child: content),
      );
    }

    return Center(child: content);
  }
}

/// Erro inline (para cards, etc)
class ErrorInline extends StatelessWidget {

  const ErrorInline({
    super.key,
    required this.message,
    this.onRetry,
  });
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade900,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text('Tentar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Toast de erro (notificação temporária)
class ErrorToast {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showRetryable(
    BuildContext context,
    String message,
    VoidCallback onRetry,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'TENTAR',
          textColor: Colors.white,
          onPressed: onRetry,
        ),
      ),
    );
  }
}
