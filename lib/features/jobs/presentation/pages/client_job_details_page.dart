import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/chat/presentation/pages/chat_page.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/features/jobs/domain/models/client_job_details_model.dart';
import 'package:renthus/features/jobs/presentation/pages/client_cancel_job_page.dart';
import 'package:renthus/features/jobs/presentation/pages/client_dispute_page.dart';
import 'package:renthus/features/jobs/presentation/pages/client_job_proposal_page.dart';
import 'package:renthus/features/jobs/presentation/pages/client_payment_page.dart';
import 'package:renthus/features/jobs/presentation/pages/client_review_page.dart';
import 'package:renthus/screens/open_dispute_page.dart';

class ClientJobDetailsPage extends ConsumerStatefulWidget {

  const ClientJobDetailsPage({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<ClientJobDetailsPage> createState() =>
      _ClientJobDetailsPageState();
}

class _ClientJobDetailsPageState extends ConsumerState<ClientJobDetailsPage> {
  bool _isResolvingDispute = false;

  final _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  bool _isJobClosedForChat(String status) {
    const closed = [
      'completed',
      'cancelled_by_client',
      'cancelled_by_provider',
      'refunded',
    ];
    return closed.contains(status);
  }

  bool _canAccessDispute(String status, bool hasAnyDispute) =>
      status == 'completed' || hasAnyDispute;

  String _fmtDateTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return _dateFormat.format(dt);
    } catch (_) {
      return iso;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _invalidate() =>
      ref.invalidate(clientJobDetailsProvider(widget.jobId));

  Future<void> _approveCandidate(
      ClientJobDetailsResult result, Map<String, dynamic> candidate,) async {
    final job = result.job;
    final jobStatus = (job['status'] as String?) ?? '';

    final providerId = (candidate['provider_id'] ?? '').toString();
    if (providerId.isEmpty) return;

    final quoteId = candidate['quote_id']?.toString();
    if (quoteId == null || quoteId.isEmpty) {
      _snack('Orçamento inválido para este prestador.');
      return;
    }

    if (result.hasPaid || (job['payment_status']?.toString() == 'paid')) {
      _snack('Pagamento já registrado para este pedido.');
      return;
    }

    if (jobStatus == 'dispute' || result.hasOpenDispute) {
      _snack(
        'Este pedido está em análise de disputa. '
        'Não é possível confirmar um novo pagamento.',
      );
      return;
    }

    try {
      final providerName =
          (candidate['provider_name'] as String?) ?? 'Prestador';
      final jobTitle = (job['title'] as String?) ??
          (job['description'] as String?) ??
          'Serviço';

      final paymentDone = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ClientPaymentPage(
            jobId: job['id'].toString(),
            quoteId: quoteId,
            jobTitle: jobTitle,
            providerName: providerName,
          ),
        ),
      );

      if (paymentDone != true) {
        _snack('Pagamento não foi concluído. Nada foi alterado.');
        return;
      }

      _invalidate();

      _snack(
        'Pagamento confirmado! Prestador aprovado. '
        'Você já pode conversar com ele no chat.',
      );
    } catch (e) {
      debugPrint('Erro ao aprovar candidato (pagamento): $e');
      _snack('Erro ao aprovar prestador: $e');
    }
  }

  Future<void> _openChatForApprovedCandidate(
      ClientJobDetailsResult result, Map<String, dynamic> candidate,) async {
    final job = result.job;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _snack('Faça login novamente para acessar o chat.');
      return;
    }

    final jobId = job['id'].toString();
    final clientId = job['client_id'].toString();
    final providerId = (candidate['provider_id'] ?? '').toString();
    final status = (job['status'] as String?) ?? '';

    if (providerId.isEmpty) {
      _snack('Não foi possível identificar o prestador.');
      return;
    }

    final isJobClosed = _isJobClosedForChat(status);
    final isChatLocked = isJobClosed && !result.hasOpenDispute;

    try {
      final chatRepo = ref.read(legacyChatRepositoryProvider);
      final conv = await chatRepo.upsertConversationForJob(
        jobId: jobId,
        clientId: clientId,
        providerId: providerId,
      );

      if (conv == null || conv['id'] == null) {
        _snack('Não foi possível abrir a conversa. Tente novamente.');
        return;
      }

      final conversationId = conv['id'].toString();
      final jobTitle = (job['title'] as String?) ??
          (job['description'] as String?) ??
          'Conversas do pedido';
      final otherUserName =
          (candidate['provider_name'] as String?) ?? 'Profissional';

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            jobTitle: jobTitle,
            otherUserName: otherUserName,
            currentUserId: user.id,
            currentUserRole: 'client',
            isChatLocked: isChatLocked,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao abrir o chat: $e');
    }
  }

  Future<void> _showQuoteDialogForCandidate(
      ClientJobDetailsResult result, Map<String, dynamic> candidate,) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientJobProposalPage(
          job: result.job,
          candidate: candidate,
          onApprove: (c) => _approveCandidate(result, c),
        ),
      ),
    );

    if (changed == true) _invalidate();
  }

  bool _canClientCancel(Map<String, dynamic> j) {
    final status = j['status'] as String? ?? '';
    const blocked = [
      'in_progress',
      'completed',
      'cancelled_by_client',
      'cancelled_by_provider',
      'refunded',
      'dispute',
    ];
    return !blocked.contains(status);
  }

  Future<void> _goToCancelPage(ClientJobDetailsResult result) async {
    final cancelled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CancelJobPage(
          jobId: result.job['id'].toString(),
          role: 'client',
        ),
      ),
    );

    if (cancelled == true) {
      _invalidate();
      if (!mounted) return;
      _snack(
        'Pedido cancelado com sucesso. '
        'Se houve pagamento, o estorno será processado em breve.',
      );
    }
  }

  Future<void> _goToReviewPage(ClientJobDetailsResult result) async {
    final providerId = result.job['provider_id']?.toString();
    if (providerId == null) return;

    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientReviewPage(
          jobId: result.job['id'].toString(),
          providerId: providerId,
        ),
      ),
    );

    if (done == true) _snack('Avaliação enviada!');
  }

  Future<void> _goToDisputePage(ClientJobDetailsResult result) async {
    final jobId = result.job['id'].toString();

    if (result.hasAnyDispute) {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ClientDisputePage(jobId: jobId),
        ),
      );
      if (changed == true) _invalidate();
      return;
    }

    final opened = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OpenDisputePage(jobId: jobId),
      ),
    );

    if (opened == true) {
      _invalidate();
      if (!mounted) return;
      _snack(
        'Reclamação registrada. O prestador será notificado para entrar em contato.',
      );
    }
  }

  Future<void> _onResolveDisputePressed(ClientJobDetailsResult result) async {
    setState(() => _isResolvingDispute = true);

    try {
      final appRepo = ref.read(appJobRepositoryProvider);
      await appRepo.resolveDisputeForJob(result.job['id'].toString());
      _invalidate();

      if (!mounted) return;
      _snack('Obrigado pelo retorno! Problema marcado como resolvido.');
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao marcar problema como resolvido: $e');
    } finally {
      if (mounted) setState(() => _isResolvingDispute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(clientJobDetailsProvider(widget.jobId));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: dataAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (result) => _buildContent(result),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 8, right: 20, top: 10, bottom: 16),
      color: const Color(0xFF3B246B),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Detalhes do Pedido',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ClientJobDetailsResult result) {
    final j = result.job;
    final title = (j['title'] as String?) ?? 'Serviço';
    final description = (j['description'] as String?) ?? 'Sem descrição';

    final createdAt = j['created_at']?.toString();
    final createdLabel = createdAt != null && createdAt.isNotEmpty
        ? _fmtDateTime(createdAt)
        : '';
    final dateLabel = createdLabel.isNotEmpty
        ? 'Criado em: $createdLabel'
        : 'Data a combinar';

    const pricingText = 'Orçamento';

    final jobStatus = j['status'] as String? ?? '';
    final canCancel = _canClientCancel(j);
    final canReview = jobStatus == 'completed' && j['provider_id'] != null;
    final canOpenDispute = jobStatus == 'completed' && !result.hasAnyDispute;
    final canResolveDispute =
        jobStatus == 'dispute' && result.hasOpenDispute;

    final paymentStatus =
        result.payment?['status']?.toString() ?? j['payment_status']?.toString();
    final gatewayTx = result.payment?['gateway_transaction_id']?.toString();
    final amountTotal =
        (result.payment?['amount_total'] as num?)?.toDouble();
    final refundAmount =
        (result.payment?['refund_amount'] as num?)?.toDouble() ??
            (j['last_refund_amount'] as num?)?.toDouble();
    final refundedAt = result.payment?['refunded_at']?.toString() ??
        j['last_refunded_at']?.toString();
    final paidAt =
        result.payment?['paid_at']?.toString() ?? j['paid_at']?.toString();

    Widget paymentCard() {
      final hasPaymentInfo =
          paymentStatus != null && paymentStatus.trim().isNotEmpty;
      if (result.payment == null && !hasPaymentInfo) {
        return const SizedBox.shrink();
      }

      final String line1 = 'Status: ${paymentStatus ?? '-'}';
      String line2 = '';
      if (amountTotal != null && amountTotal > 0) {
        line2 = 'Total: ${_currencyBr.format(amountTotal)}';
      }
      String line3 = '';
      if (gatewayTx != null && gatewayTx.isNotEmpty) {
        line3 = 'Recibo/ID: $gatewayTx';
      }
      String line4 = '';
      if (paymentStatus == 'paid' && paidAt != null) {
        final paidTxt = _fmtDateTime(paidAt);
        line4 = paidTxt.isNotEmpty ? 'Pago em: $paidTxt' : '';
      } else if (paymentStatus == 'refunded' &&
          refundAmount != null &&
          refundAmount > 0) {
        final refTxt = _currencyBr.format(refundAmount);
        final refDt =
            refundedAt != null ? _fmtDateTime(refundedAt) : '';
        line4 = refDt.isNotEmpty
            ? 'Estornado em: $refDt • $refTxt'
            : 'Estornado: $refTxt';
      }

      final lines = [
        line1,
        if (line2.isNotEmpty) line2,
        if (line3.isNotEmpty) line3,
        if (line4.isNotEmpty) line4,
      ];

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pagamento',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            ...lines.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  t,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget disputeInfoCard() {
      if (!result.hasAnyDispute) return const SizedBox.shrink();

      final reason = (j['dispute_reason'] as String?) ?? '';
      final openedAt = j['dispute_opened_at']?.toString();
      final openedLabel = openedAt != null && openedAt.isNotEmpty
          ? _fmtDateTime(openedAt)
          : '';
      final statusText =
          result.hasOpenDispute ? 'Em análise' : 'Encerrada';

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reclamação',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: $statusText',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            if (openedLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Aberta em: $openedLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            if (reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Motivo: $reason',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações do Pedido',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 12),
          _infoCard(label: 'Serviço', value: title),
          _infoCard(label: 'Modelo de contratação', value: pricingText),
          _infoCard(label: 'Data/Hora', value: dateLabel),
          _infoCard(label: 'Descrição do serviço', value: description),
          paymentCard(),
          disputeInfoCard(),
          const SizedBox(height: 16),
          const Text(
            'Propostas de profissionais',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 8),
          if (result.candidates.isEmpty)
            const Text(
              'Ainda não há profissionais interessados neste pedido.\n'
              'Assim que alguém enviar uma proposta, aparecerá aqui.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            Column(
              children: result.candidates
                  .map((c) => _buildCandidateCard(result, c))
                  .toList(),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Dica:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Você pode ver os detalhes da proposta de cada profissional, '
            'aprovar quem achar melhor para seguir para o pagamento.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (canCancel ||
              canReview ||
              canOpenDispute ||
              canResolveDispute ||
              result.hasAnyDispute) ...[
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Ações do pedido',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            if (canCancel)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _goToCancelPage(result),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar este pedido'),
                ),
              ),
            if (canReview)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToReviewPage(result),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B246B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Avaliar profissional'),
                ),
              ),
            if (canOpenDispute) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _goToDisputePage(result),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Abrir reclamação'),
                ),
              ),
            ],
            if (result.hasAnyDispute) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _goToDisputePage(result),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B246B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.report_gmailerrorred_outlined,
                    size: 18,
                  ),
                  label: const Text('Ver reclamação', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
            if (_canAccessDispute(jobStatus, result.hasAnyDispute))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientDisputePage(
                          jobId: j['id'].toString(),
                        ),
                      ),
                    );
                    if (changed == true) _invalidate();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.report_gmailerrorred_outlined),
                  label: Text(
                    result.hasAnyDispute ? 'Ver reclamação' : 'Abrir reclamação',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            if (canResolveDispute) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isResolvingDispute
                      ? null
                      : () => _onResolveDisputePressed(result),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0DAA00),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isResolvingDispute ? 'Atualizando...' : 'Problema resolvido',
                  ),
                ),
              ),
            ],
            if (!result.hasOpenDispute && result.hasAnyDispute) ...[
              const SizedBox(height: 6),
              const Text(
                'Já existe uma reclamação registrada para este pedido.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
            if (jobStatus == 'dispute') ...[
              const SizedBox(height: 6),
              const Text(
                'Este pedido está em análise de disputa. '
                'Não é possível cancelar ou registrar novo pagamento '
                'enquanto a análise estiver aberta.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _infoCard({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF3B246B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateCard(
      ClientJobDetailsResult result, Map<String, dynamic> c,) {
    final providerName = (c['provider_name'] as String?) ?? 'Prestador';
    final clientStatus = (c['client_status'] as String?) ?? 'pending';
    final createdAt = c['created_at']?.toString();
    final approxPrice = (c['approximate_price'] as num?)?.toDouble();

    final jobProviderId = result.job['provider_id'] as String?;
    final isApprovedProvider = jobProviderId != null &&
        (c['provider_id']?.toString() == jobProviderId);

    final jobStatus = result.job['status'] as String? ?? '';
    final isJobClosed = _isJobClosedForChat(jobStatus);
    final isChatLocked = isJobClosed && !result.hasOpenDispute;

    String statusLabel;
    Color statusColor;

    switch (clientStatus) {
      case 'approved':
        statusLabel = 'Aprovado';
        statusColor = const Color(0xFF0DAA00);
        break;
      case 'rejected':
        statusLabel = 'Recusado';
        statusColor = Colors.grey;
        break;
      default:
        statusLabel = 'Pendente';
        statusColor = Colors.grey;
    }

    if (isApprovedProvider) {
      statusLabel = 'Aprovado';
      statusColor = const Color(0xFF0DAA00);
    }

    final canShowChat = isApprovedProvider && !isChatLocked;

    String createdLabel = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        createdLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showQuoteDialogForCandidate(result, c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    providerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (approxPrice != null)
              Text(
                'Valor: ${_currencyBr.format(approxPrice)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3B246B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (createdLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Proposta enviada em: $createdLabel',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              'Toque para ver a proposta completa deste profissional.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (canShowChat) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _openChatForApprovedCandidate(result, c),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B246B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Ir para o chat', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
