// lib/widgets/br_currency_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// InputFormatter que deixa sempre no formato "R$ 0,00"
class BrCurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _fmt = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Mantém só dígitos
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final value = double.parse(digits) / 100.0;
    final newText = _fmt.format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

/// Campo de texto já pronto para valores em R$
///
/// Exemplo de uso:
/// BrCurrencyField(
///   controller: _counterPriceController,
///   labelText: 'Valor da contraproposta (R\$)',
///   onChanged: (text) { ... },
/// )
class BrCurrencyField extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  const BrCurrencyField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        BrCurrencyInputFormatter(), // 🔹 sem const aqui
      ],
      decoration: InputDecoration(
        labelText: labelText ?? 'Valor (R\$)',
        hintText: hintText ?? 'R\$ 0,00',
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
