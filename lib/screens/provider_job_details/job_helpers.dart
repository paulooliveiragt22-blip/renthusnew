import 'package:flutter/material.dart';

/// Helpers gerais usados na tela de detalhes do job do prestador.
class JobHelpers {
  /// Retorna se o status indica pagamento aprovado / job em andamento.
  ///
  /// Usado para mostrar o card verde de "Pagamento aprovado" mesmo depois
  /// que o status mudou para `accepted`, `on_the_way`, etc.
  static bool isPaymentApprovedStatus(String status) {
    const approvedStatuses = <String>[
      'payment_approved', // se existir na sua API
      'accepted',
      'on_the_way',
      'in_progress',
      'completed',
      'dispute',
    ];
    return approvedStatuses.contains(status);
  }

  /// Mensagem amigável para o Snackbar quando o status é atualizado.
  static String friendlyStatusUpdatedMessage(String newStatus) {
    switch (newStatus) {
      case 'accepted':
        return 'Serviço aprovado! Agora você pode seguir para o atendimento.';
      case 'on_the_way':
        return 'Tudo certo! Você marcou como "A caminho do cliente".';
      case 'in_progress':
        return 'Perfeito! O serviço foi marcado como "Em andamento".';
      case 'completed':
        return 'Serviço finalizado com sucesso!';
      case 'cancelled_by_provider':
        return 'Você cancelou este serviço.';
      case 'cancelled_by_client':
        return 'O cliente cancelou este serviço.';
      case 'dispute':
        return 'Este serviço entrou em análise. Fique de olho nas notificações.';
      default:
        return 'Status do serviço atualizado.';
    }
  }

  /// Mensagem amigável para erro ao atualizar status.
  static String friendlyUpdateErrorMessage([Object? error]) {
    // Se quiser, pode logar o erro em outro lugar.
    debugPrint('Erro ao atualizar status: $error');
    return 'Não foi possível atualizar o status agora. Tente novamente em alguns instantes.';
  }
}
