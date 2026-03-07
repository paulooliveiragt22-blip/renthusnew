import 'package:flutter/material.dart';

/// Widget de Empty State
///
/// Uso:
/// ```dart
/// EmptyWidget.jobs(onAction: () => createJob())
/// EmptyWidget.candidates()
/// EmptyWidget.messages()
/// EmptyWidget.notifications()
/// EmptyWidget.generic(title: 'Nada aqui', message: '...')
/// ```
class EmptyWidget extends StatelessWidget {

  const EmptyWidget({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionButtonText,
    this.onAction,
    this.fullScreen = false,
  });

  /// Empty para lista de jobs
  const EmptyWidget.jobs({
    super.key,
    VoidCallback? onAction,
  })  : title = 'Nenhum serviço encontrado',
        message =
            'Quando houver serviços disponíveis na sua região, eles aparecerão aqui.',
        icon = Icons.work_outline,
        actionButtonText = 'Atualizar',
        onAction = onAction,
        fullScreen = false;

  /// Empty para lista de candidatos
  const EmptyWidget.candidates({
    super.key,
  })  : title = 'Nenhum candidato ainda',
        message =
            'Quando profissionais se interessarem pelo seu serviço, eles aparecerão aqui.',
        icon = Icons.people_outline,
        actionButtonText = null,
        onAction = null,
        fullScreen = false;

  /// Empty para orçamentos
  const EmptyWidget.quotes({
    super.key,
  })  : title = 'Nenhum orçamento recebido',
        message = 'Os profissionais enviarão orçamentos em breve. Aguarde!',
        icon = Icons.request_quote_outlined,
        actionButtonText = null,
        onAction = null,
        fullScreen = false;

  /// Empty para mensagens
  const EmptyWidget.messages({
    super.key,
  })  : title = 'Nenhuma mensagem',
        message = 'Inicie uma conversa para começar.',
        icon = Icons.chat_bubble_outline,
        actionButtonText = null,
        onAction = null,
        fullScreen = false;

  /// Empty para conversas
  const EmptyWidget.conversations({
    super.key,
  })  : title = 'Nenhuma conversa',
        message = 'Você ainda não possui conversas ativas.',
        icon = Icons.forum_outlined,
        actionButtonText = null,
        onAction = null,
        fullScreen = false;

  /// Empty para notificações
  const EmptyWidget.notifications({
    super.key,
  })  : title = 'Nenhuma notificação',
        message = 'Você está em dia! Não há notificações novas.',
        icon = Icons.notifications_none,
        actionButtonText = null,
        onAction = null,
        fullScreen = false;

  /// Empty para histórico
  const EmptyWidget.history({
    super.key,
  })  : title = 'Nenhum histórico',
        message = 'Seus serviços anteriores aparecerão aqui.',
        icon = Icons.history,
        actionButtonText = null,
        onAction = null,
        fullScreen = false;

  /// Empty para pesquisa
  const EmptyWidget.search({
    super.key,
    String? searchTerm,
  })  : title = 'Nenhum resultado',
        message = searchTerm != null
            ? 'Não encontramos resultados para "$searchTerm".'
            : 'Tente buscar com outros termos.',
        icon = Icons.search_off,
        actionButtonText = null,
        onAction = null,
        fullScreen = false;

  /// Empty para favoritos
  const EmptyWidget.favorites({
    super.key,
  })  : title = 'Nenhum favorito',
        message =
            'Adicione profissionais aos favoritos para encontrá-los rapidamente.',
        icon = Icons.favorite_border,
        actionButtonText = null,
        onAction = null,
        fullScreen = false;

  /// Empty genérico
  const EmptyWidget.generic({
    super.key,
    required String title,
    required String message,
    IconData icon = Icons.inbox_outlined,
    String? actionButtonText,
    VoidCallback? onAction,
  })  : title = title,
        message = message,
        icon = icon,
        actionButtonText = actionButtonText,
        onAction = onAction,
        fullScreen = false;

  /// Empty fullscreen
  const EmptyWidget.fullScreen({
    super.key,
    required String title,
    required String message,
    required IconData icon,
    String? actionButtonText,
    VoidCallback? onAction,
  })  : title = title,
        message = message,
        icon = icon,
        actionButtonText = actionButtonText,
        onAction = onAction,
        fullScreen = true;
  final String title;
  final String message;
  final IconData icon;
  final String? actionButtonText;
  final VoidCallback? onAction;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ícone
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: fullScreen ? 80 : 60,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 24),

        // Título
        Text(
          title,
          style: TextStyle(
            fontSize: fullScreen ? 22 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
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
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Botão de ação
        if (onAction != null && actionButtonText != null) ...[
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh),
            label: Text(actionButtonText!),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: content,
      ),
    );
  }
}

/// Empty inline (para cards, seções)
class EmptyInline extends StatelessWidget {

  const EmptyInline({
    super.key,
    required this.message,
    this.icon,
  });
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
