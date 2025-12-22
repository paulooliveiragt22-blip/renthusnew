import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentSummarySection extends StatelessWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic>? payment;
  final bool showAddress;
  final VoidCallback? onOpenMap;

  const PaymentSummarySection({
    super.key,
    required this.job,
    required this.payment,
    required this.showAddress,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    // formatador de moeda BR (agora local)
    final currencyBr = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$ ',
      decimalDigits: 2,
    );

    // valor aprovado (prioriza payments, cai para jobs)
    final double? approvedPriceFromPayment =
        (payment?['amount_total'] as num?)?.toDouble();

    final double? approvedPriceFromJob = (job['price'] as num?)?.toDouble() ??
        (job['daily_total'] as num?)?.toDouble() ??
        (job['client_budget'] as num?)?.toDouble();

    final double? approvedPrice =
        approvedPriceFromPayment ?? approvedPriceFromJob;

    // data da execução
    final scheduledStr = job['scheduled_at'] as String?;
    String dateLabel = 'Data a combinar';

    if (scheduledStr != null) {
      try {
        final dt = DateTime.parse(scheduledStr).toLocal();
        dateLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
            'às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    // endereço
    final street = (job['address_street'] as String?)?.trim();
    final number = (job['address_number'] as String?)?.trim();
    final district = (job['address_district'] as String?)?.trim();
    final city = (job['city'] as String?)?.trim();

    String addressText = 'Endereço do cliente não disponível';

    final line1 = [
      if (street != null && street.isNotEmpty) street,
      if (number != null && number.isNotEmpty) number,
    ].join(', ');

    final line2 = [
      if (district != null && district.isNotEmpty) district,
      if (city != null && city.isNotEmpty) city,
    ].join(' - ');

    if (line1.isNotEmpty || line2.isNotEmpty) {
      addressText = [line1, line2].where((s) => s.isNotEmpty).join('\n');
    }

    final valueText = approvedPrice != null && approvedPrice > 0
        ? currencyBr.format(approvedPrice)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner verde
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0DAA00),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pagamento aprovado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Card branco
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumo do pedido',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B246B),
                ),
              ),
              const SizedBox(height: 8),
              _valueLine('Valor aprovado', valueText, highlight: true),
              const SizedBox(height: 4),
              _valueLine('Data da execução ', dateLabel),
              const SizedBox(height: 12),
              if (showAddress) ...[
                const Text(
                  'Endereço do cliente',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B246B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  addressText,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Ver localização no mapa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B246B),
                      side: const BorderSide(color: Color(0xFF3B246B)),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  static Widget _valueLine(String label, String value,
      {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlight ? const Color(0xFF3B246B) : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
