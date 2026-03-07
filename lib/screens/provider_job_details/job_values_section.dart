import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:renthus/widgets/br_currency_field.dart';

class JobValuesSection extends StatelessWidget {

  const JobValuesSection({
    super.key,
    required this.isAssigned,
    required this.isCandidate,
    required this.currencyBr,
    required this.offeredPrice,
    required this.priceText,
    required this.netIfAcceptText,
    required this.lastQuotePrice,
    required this.quoteNet,
    required this.hasQuote,
    required this.priceChoice,
    required this.counterPriceController,
    required this.counterConfirmed,
    required this.counterNet,
    required this.selectedNetPrice,
    required this.onChangePriceChoice,
    required this.onConfirmCounter,
    required this.onCounterTextChanged,
  });
  final bool isAssigned;
  final bool isCandidate;

  final NumberFormat currencyBr;

  // Mantidos por compatibilidade com a chamada atual (não usados neste layout)
  final double? offeredPrice;
  final String priceText;
  final String netIfAcceptText;
  final double? lastQuotePrice;
  final double? quoteNet;
  final bool hasQuote;
  final String priceChoice;
  final bool counterConfirmed;
  final double? counterNet;
  final double? selectedNetPrice;

  final TextEditingController counterPriceController;

  // Mantidos por compatibilidade com a chamada atual
  final ValueChanged<String> onChangePriceChoice;
  final VoidCallback onConfirmCounter;
  final VoidCallback onCounterTextChanged;

  static const double _platformFee = 0.15; // 15%

  double? _parseCurrencyToDouble(String text) {
    final cleaned =
        text.replaceAll('R\$', '').replaceAll(RegExp(r'[^0-9,\.]'), '').trim();

    if (cleaned.isEmpty) return null;

    final normalized = cleaned.contains(',')
        ? cleaned.replaceAll('.', '').replaceAll(',', '.')
        : cleaned;

    return double.tryParse(normalized);
  }

  double _netFromGross(double gross) => gross * (1 - _platformFee);

  @override
  Widget build(BuildContext context) {
    // Se já está assigned/candidate, você pode ocultar totalmente ou mostrar “Resumo”.
    // Por enquanto: só mostra esta área ANTES do match.
    if (isAssigned || isCandidate) {
      return const SizedBox.shrink();
    }

    final gross = _parseCurrencyToDouble(counterPriceController.text);
    final net = (gross != null && gross > 0) ? _netFromGross(gross) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Valores',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3B246B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enviar proposta',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B246B),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: BrCurrencyField(
                      controller: counterPriceController,
                      labelText: 'Valor da proposta (R\$)',
                      hintText: 'R\$ 0,00',
                      onChanged: (_) => onCounterTextChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onConfirmCounter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B246B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text(
                        counterConfirmed ? 'Confirmado' : 'Confirmar',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (net != null)
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: Color(0xFF3B246B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Você receberá (após 15%): ${currencyBr.format(net)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B246B),
                        ),
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'Digite o valor para ver quanto você receberá após a taxa.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
