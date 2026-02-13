import 'package:flutter/material.dart';

class JobBottomBar extends StatelessWidget {

  const JobBottomBar({
    super.key,
    required this.job,
    required this.isAssigned,
    required this.isCandidate,
    required this.isChangingStatus,
    required this.hasOpenDispute,
    required this.canAcceptBeforeMatch,
    required this.onRejectJob,
    required this.onAcceptBeforeMatch,
    required this.onSetOnTheWay,
    required this.onSetInProgress,
    required this.onSetCompleted,
    required this.onOpenChat,
    this.onOpenDispute,
    this.onCancelAfterMatch,
  });
  final Map<String, dynamic> job;
  final bool isAssigned;
  final bool isCandidate;
  final bool isChangingStatus;
  final bool hasOpenDispute;

  /// Mantido por compatibilidade, mas a validação agora é feita ao clicar
  final bool canAcceptBeforeMatch;

  final VoidCallback onRejectJob;
  final VoidCallback onAcceptBeforeMatch;

  final VoidCallback onSetOnTheWay;
  final VoidCallback onSetInProgress;
  final VoidCallback onSetCompleted;

  final VoidCallback onOpenChat;
  final VoidCallback? onOpenDispute;

  /// não vamos usar mais, mas mantido por compatibilidade
  final VoidCallback? onCancelAfterMatch;

  static const _roxo = Color(0xFF3B246B);
  static const _verde = Color(0xFF0DAA00);

  bool _isCancelled(String status) =>
      status == 'cancelled' || status.startsWith('cancelled_');

  @override
  Widget build(BuildContext context) {
    final String status = (job['status'] as String?) ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child:
            isAssigned ? _buildAfterMatchArea(status) : _buildBeforeMatchArea(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ANTES DO MATCH  (Recusar / Aceitar serviço)
  // --------------------------------------------------------------------------
  Widget _buildBeforeMatchArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isChangingStatus ? null : onRejectJob,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: _roxo),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: const Text('Recusar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isChangingStatus ? null : onAcceptBeforeMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _roxo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: const Text(
                  'Aceitar serviço',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // DEPOIS DO MATCH (status + conversar com cliente lado a lado)
  // --------------------------------------------------------------------------
  Widget _buildAfterMatchArea(String status) {
    final bool isDispute = status == 'dispute' || status == 'dispute_open';

    final bool isClosed =
        status == 'completed' || status == 'refunded' || _isCancelled(status);

    // Pode abrir disputa quando estiver fechado (completed/cancelled),
    // e ainda não houver disputa aberta
    final bool canOpenDispute =
        isClosed && !hasOpenDispute && onOpenDispute != null;

    // Chat:
    // - sempre liberado em disputa
    // - se fechado, só libera quando há disputa aberta
    // - caso contrário, liberado normal
    final bool chatLocked = (!isDispute && isClosed && !hasOpenDispute);

    String? infoText;
    String? mainLabel;
    VoidCallback? mainAction;
    Color primaryColor = _verde;

    // Fluxo de status só quando NÃO estiver fechado e NÃO estiver em disputa
    if (!isClosed && !isDispute) {
      if (status == 'accepted' ||
          status == 'payment_approved' ||
          status == 'approved' ||
          status == 'paid' ||
          status == 'succeeded') {
        infoText =
            'Serviço aprovado! Atualize o status quando estiver a caminho, iniciar ou finalizar.';
        mainLabel = 'A caminho';
        mainAction = onSetOnTheWay;
        primaryColor = _verde;
      } else if (status == 'on_the_way') {
        infoText =
            'Você informou que está a caminho.\nToque em "Iniciado" ao chegar.';
        mainLabel = 'Iniciado';
        mainAction = onSetInProgress;
        primaryColor = _roxo;
      } else if (status == 'in_progress') {
        infoText =
            'O serviço está em andamento.\nToque em "Finalizar serviço" ao concluir.';
        mainLabel = 'Finalizar serviço';
        mainAction = onSetCompleted;
        primaryColor = _roxo;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (infoText != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              infoText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),

        // Linha principal:
        // - Se tiver ação de status (mainAction), mostra [Status] + [Chat]
        // - Se estiver fechado/sem ação, mostra [Chat] + [Abrir disputa?]
        Row(
          children: [
            if (mainAction != null) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: isChangingStatus ? null : mainAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: Text(
                    mainLabel ?? '',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: OutlinedButton(
                onPressed: (isChangingStatus || chatLocked) ? null : onOpenChat,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: _roxo),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Text(
                  chatLocked ? 'Chat indisponível' : 'Conversar com o cliente',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (mainAction == null && canOpenDispute) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenDispute,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: const Text(
                    'Abrir disputa',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),

        if (hasOpenDispute)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Já existe uma disputa aberta para este serviço.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
      ],
    );
  }
}
