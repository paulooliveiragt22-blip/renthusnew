import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  final double? offeredPrice;
  final String priceText;
  final String netIfAcceptText;

  final double? lastQuotePrice;
  final double? quoteNet;
  final bool hasQuote;

  final String priceChoice;
  final TextEditingController counterPriceController;
  final bool counterConfirmed;
  final double? counterNet;

  final double? selectedNetPrice;

  final ValueChanged<String> onChangePriceChoice;
  final VoidCallback onConfirmCounter;
  final VoidCallback onCounterTextChanged;

  @override
  Widget build(BuildContext context) {
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
        _buildValuesCard(context),
      ],
    );
  }

  Widget _buildValuesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _valueLine('Valor ofertado pelo cliente', priceText),
          const SizedBox(height: 6),
          _valueLine(
            'Você receberá (se aceitar este valor)',
            netIfAcceptText,
            highlight: offeredPrice != null && offeredPrice! > 0,
          ),
          const SizedBox(height: 4),
          const Text(
            'O valor líquido já considera taxas do app.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),

          // Última contraproposta
          if (hasQuote && lastQuotePrice != null) ...[
            const SizedBox(height: 10),
            _valueLine(
              'Sua última contraproposta',
              currencyBr.format(lastQuotePrice),
            ),
            if (quoteNet != null) ...[
              const SizedBox(height: 2),
              _valueLine(
                'Valor que você receberia',
                currencyBr.format(quoteNet),
              ),
            ],
          ],

          // Área de definição de valor (somente antes do match)
          if (!isAssigned && !isCandidate) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Defina o valor que você aceita para este serviço:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 4),
            RadioListTile<String>(
              value: 'accept',
              groupValue: priceChoice,
              onChanged: (offeredPrice == null || offeredPrice! <= 0)
                  ? null
                  : (v) {
                      if (v == null) return;
                      onChangePriceChoice(v);
                    },
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Aceitar valor ofertado pelo cliente',
                style: TextStyle(fontSize: 13),
              ),
            ),
            RadioListTile<String>(
              value: 'counter',
              groupValue: priceChoice,
              onChanged: (v) {
                if (v == null) return;
                onChangePriceChoice(v);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enviar contraproposta',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (priceChoice == 'counter') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: counterPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor da contraproposta (R\$)',
                        hintText: 'Ex: 350,00',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => onCounterTextChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: onConfirmCounter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B246B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Se você não aceitar o valor do cliente, é obrigatório informar uma contraproposta.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              if (counterNet != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Você receberá após taxas do app: ${currencyBr.format(counterNet)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B246B),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8),
            if (priceChoice == 'accept' && selectedNetPrice != null)
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
                      'Você receberá após taxa do app: '
                      '${currencyBr.format(selectedNetPrice)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B246B),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _valueLine(String label, String value, {bool highlight = false}) {
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
