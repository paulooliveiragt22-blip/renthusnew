import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);

class CreateJobPaymentSection extends StatelessWidget {

  const CreateJobPaymentSection({
    super.key,
    required this.selectedPaymentMethod,
    required this.onSelectPaymentMethod,
  });
  final String? selectedPaymentMethod; // 'pix', 'credit_card', 'debit_card'
  final ValueChanged<String> onSelectPaymentMethod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forma de pagamento (não será cobrado nada agora)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Escolher uma forma ajuda a calcular quanto o prestador poderá receber, '
          'mas nada será cobrado neste momento.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _PaymentChip(
              label: 'Pix',
              value: 'pix',
              selected: selectedPaymentMethod == 'pix',
              onTap: () => onSelectPaymentMethod('pix'),
            ),
            _PaymentChip(
              label: 'Cartão de crédito',
              value: 'credit_card',
              selected: selectedPaymentMethod == 'credit_card',
              onTap: () => onSelectPaymentMethod('credit_card'),
            ),
            _PaymentChip(
              label: 'Cartão de débito',
              value: 'debit_card',
              selected: selectedPaymentMethod == 'debit_card',
              onTap: () => onSelectPaymentMethod('debit_card'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {

  const _PaymentChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

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
