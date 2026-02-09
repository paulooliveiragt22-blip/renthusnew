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
  final String title;
  final String message;
  final IconData icon;
  final String? actionButtonText;
  final VoidCallback? onAction;
  final bool fullScreen;

  const EmptyWidget({
    Key? key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionButtonText,
    this.onAction,
    this.fullScreen = false,
  }) : super(key: key);

  /// Empty para lista de jobs
  const EmptyWidget.jobs({
    Key? key,
    VoidCallback? onAction,
  })  : title = 'Nenhum serviço encontrado',
        message =
            'Quando houver serviços disponíveis na sua região, eles aparecerão aqui.',
        icon = Icons.work_outline,
        actionButtonText = 'Atualizar',
        onAction = onAction,
        fullScreen = false,
        super(key: key);

  /// Empty para lista de candidatos
  const EmptyWidget.candidates({
    Key? key,
  })  : title = 'Nenhum candidato ainda',
        message =
            'Quando profissionais se interessarem pelo seu serviço, eles aparecerão aqui.',
        icon = Icons.people_outline,
        actionButtonText = null,
        onAction = null,
        fullScreen = false,
        super(key: key);

  /// Empty para orçamentos
  const EmptyWidget.quotes({
    Key? key,
  })  : title = 'Nenhum orçamento recebido',
        message = 'Os profissionais enviarão orçamentos em breve. Aguarde!',
        icon = Icons.request_quote_outlined,
        actionButtonText = null,
        onAction = null,
        fullScreen = false,
        super(key: key);

  /// Empty para mensagens
  const EmptyWidget.messages({
    Key? key,
  })  : title = 'Nenhuma mensagem',
        message = 'Inicie uma conversa para começar.',
        icon = Icons.chat_bubble_outline,
        actionButtonText = null,
        onAction = null,
        fullScreen = false,
        super(key: key);

  /// Empty para conversas
  const EmptyWidget.conversations({
    Key? key,
  })  : title = 'Nenhuma conversa',
        message = 'Você ainda não possui conversas ativas.',
        icon = Icons.forum_outlined,
        actionButtonText = null,
        onAction = null,
        fullScreen = false,
        super(key: key);

  /// Empty para notificações
  const EmptyWidget.notifications({
    Key? key,
  })  : title = 'Nenhuma notificação',
        message = 'Você está em dia! Não há notificações novas.',
        icon = Icons.notifications_none,
        actionButtonText = null,
        onAction = null,
        fullScreen = false,
        super(key: key);

  /// Empty para histórico
  const EmptyWidget.history({
    Key? key,
  })  : title = 'Nenhum histórico',
        message = 'Seus serviços anteriores aparecerão aqui.',
        icon = Icons.history,
        actionButtonText = null,
        onAction = null,
        fullScreen = false,
        super(key: key);

  /// Empty para pesquisa
  const EmptyWidget.search({
    Key? key,
    String? searchTerm,
  })  : title = 'Nenhum resultado',
        message = searchTerm != null
            ? 'Não encontramos resultados para "$searchTerm".'
            : 'Tente buscar com outros termos.',
        icon = Icons.search_off,
        actionButtonText = null,
        onAction = null,
        fullScreen = false,
        super(key: key);

  /// Empty para favoritos
  const EmptyWidget.favorites({
    Key? key,
  })  : title = 'Nenhum favorito',
        message =
            'Adicione profissionais aos favoritos para encontrá-los rapidamente.',
        icon = Icons.favorite_border,
        actionButtonText = null,
        onAction = null,
        fullScreen = false,
        super(key: key);

  /// Empty genérico
  const EmptyWidget.generic({
    Key? key,
    required String title,
    required String message,
    IconData icon = Icons.inbox_outlined,
    String? actionButtonText,
    VoidCallback? onAction,
  })  : this.title = title,
        this.message = message,
        this.icon = icon,
        this.actionButtonText = actionButtonText,
        this.onAction = onAction,
        fullScreen = false,
        super(key: key);

  /// Empty fullscreen
  const EmptyWidget.fullScreen({
    Key? key,
    required String title,
    required String message,
    required IconData icon,
    String? actionButtonText,
    VoidCallback? onAction,
  })  : this.title = title,
        this.message = message,
        this.icon = icon,
        this.actionButtonText = actionButtonText,
        this.onAction = onAction,
        fullScreen = true,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ícone
        Container(
          padding: EdgeInsets.all(24),
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
        SizedBox(height: 24),

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
        SizedBox(height: 12),

        // Mensagem
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
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
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: Icon(Icons.refresh),
            label: Text(actionButtonText!),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Container(
        color: Colors.white,
        child: Center(child: content),
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: content,
      ),
    );
  }
}

/// Empty inline (para cards, seções)
class EmptyInline extends StatelessWidget {
  final String message;
  final IconData? icon;

  const EmptyInline({
    Key? key,
    required this.message,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 40,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 12),
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
