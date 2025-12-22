import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/br_currency_field.dart';

const kRoxo = Color(0xFF3B246B);

class CreateJobPricingSection extends StatelessWidget {
  final String? selectedPricingModel; // 'daily' ou 'quote'
  final ValueChanged<String> onSelectPricingModel;

  // Diárias
  final int dailyQuantity;
  final VoidCallback onIncrementDaily;
  final VoidCallback onDecrementDaily;

  // Valores
  final TextEditingController budgetController;
  final double? dailyTotal;
  final double? quoteTotal;

  // Callback de máscara / cálculo
  final ValueChanged<String> onBudgetChanged;

  const CreateJobPricingSection({
    super.key,
    required this.selectedPricingModel,
    required this.onSelectPricingModel,
    required this.dailyQuantity,
    required this.onIncrementDaily,
    required this.onDecrementDaily,
    required this.budgetController,
    required this.dailyTotal,
    required this.quoteTotal,
    required this.onBudgetChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + ícone de explicação
        Row(
          children: [
            const Expanded(
              child: Text(
                'Como você quer contratar?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, size: 18, color: kRoxo),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Como funciona'),
                    content: const Text(
                      '• Por diária: você informa quantas diárias precisa. '
                      'O prestador combina o valor por dia e o total é calculado automaticamente.\n\n'
                      '• Preciso de um orçamento: você descreve o serviço e os prestadores '
                      'enviam propostas com valor total para o serviço completo.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Entendi'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Chips de seleção
        Wrap(
          spacing: 8,
          children: [
            _PricingChip(
              label: 'Por diária',
              value: 'daily',
              selected: selectedPricingModel == 'daily',
              onTap: () => onSelectPricingModel('daily'),
            ),
            _PricingChip(
              label: 'Preciso de um orçamento',
              value: 'quote',
              selected: selectedPricingModel == 'quote',
              onTap: () => onSelectPricingModel('quote'),
            ),
          ],
        ),

        // Caso seja diária
        if (selectedPricingModel == 'daily') ...[
          const SizedBox(height: 12),
          const Text(
            'Quantas diárias você precisa?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: dailyQuantity > 1 ? onDecrementDaily : null,
              ),
              Text(
                '$dailyQuantity',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onIncrementDaily,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Valor por diária (R$) com máscara BR
          BrCurrencyField(
            controller: budgetController,
            labelText: 'Valor por diária (R\$)',
            onChanged: onBudgetChanged,
          ),

          const SizedBox(height: 8),

          if (dailyTotal != null)
            Text(
              'Total estimado: ${NumberFormat.currency(locale: "pt_BR", symbol: "R\$").format(dailyTotal)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kRoxo,
              ),
            ),
        ],

        // Caso seja orçamento
        if (selectedPricingModel == 'quote') ...[
          const SizedBox(height: 12),
          BrCurrencyField(
            controller: budgetController,
            labelText: 'Quanto você pretende pagar? (R\$)',
            onChanged: onBudgetChanged,
          ),
          const SizedBox(height: 8),
          if (quoteTotal != null)
            Text(
              'Total do orçamento (referência): ${NumberFormat.currency(locale: "pt_BR", symbol: "R\$").format(quoteTotal)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kRoxo,
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'Os prestadores verão esse valor como referência e poderão enviar propostas próximas a ele.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}

class _PricingChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PricingChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: kRoxo,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) => onTap(),
    );
  }
}
