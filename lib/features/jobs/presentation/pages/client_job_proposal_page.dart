import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClientJobProposalPage extends StatelessWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic> candidate;
  final Future<void> Function(Map<String, dynamic>) onApprove;

  const ClientJobProposalPage({
    super.key,
    required this.job,
    required this.candidate,
    required this.onApprove,
  });

  final NumberFormat _currencyBr = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final String jobTitle = (job['description'] as String?) ??
        (job['title'] as String?) ??
        'Serviço';

    final String jobStatus = job['status'] as String? ?? '';

    final String providerName =
        candidate['provider_name'] as String? ?? 'Profissional';

    final double? suggestedPrice =
        (candidate['approximate_price'] as num?)?.toDouble();

    final String? message = (candidate['quote_message'] as String?) ??
        (candidate['message'] as String?);

    final bool isJobApproved =
        jobStatus == 'accepted' || jobStatus == 'completed';

    final bool isJobCancelled = [
      'cancelled_by_client',
      'cancelled_by_provider',
      'refunded',
    ].contains(jobStatus);

    final bool isJobLocked = isJobApproved || isJobCancelled;

    final double totalToPay = suggestedPrice ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Resumo do pedido'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(
                            label: 'Profissional',
                            value: providerName,
                          ),
                          const SizedBox(height: 6),
                          _infoRow(
                            label: 'Descrição do serviço',
                            value: jobTitle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Proposta do profissional'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(
                            label: 'Valor sugerido',
                            value: suggestedPrice != null
                                ? _currencyBr.format(suggestedPrice)
                                : 'Não informado',
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Observações do profissional',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B246B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (message == null || message.trim().isEmpty)
                                ? 'O profissional não adicionou observações.'
                                : message,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle(
                      isJobApproved
                          ? 'Resumo do pagamento'
                          : 'Resumo antes do pagamento',
                    ),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(
                            label: 'Valor total',
                            value: _currencyBr.format(totalToPay),
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B246B),
                            ),
                            valueStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B246B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isJobApproved
                                ? 'Pagamento já confirmado para este pedido.'
                                : 'Ao continuar, você será direcionado para a tela de pagamento. '
                                    'O profissional será confirmado somente após o pagamento aprovado.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isJobLocked) _buildBottomButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 8, right: 16, top: 10, bottom: 14),
      color: const Color(0xFF3B246B),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Text(
            'Proposta do profissional',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3B246B),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: labelStyle ??
                const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B246B),
                ),
          ),
          TextSpan(
            text: value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await onApprove(candidate);
            if (context.mounted) Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B246B),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Continuar para o pagamento',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
