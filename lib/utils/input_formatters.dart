// lib/utils/input_formatters.dart
import 'package:flutter/services.dart';

/// Formatadores de input para campos brasileiros
///
/// Uso:
/// ```dart
/// TextFormField(
///   inputFormatters: [CPFFormatter()],
///   keyboardType: TextInputType.number,
/// )
/// ```

// ========================================
// CPF FORMATTER (###.###.###-##)
// ========================================
class CPFFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Limitar a 11 dígitos
    final digitsOnly = text.substring(0, text.length > 11 ? 11 : text.length);

    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 3 || i == 6) {
        formatted += '.';
      } else if (i == 9) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ========================================
// CNPJ FORMATTER (##.###.###/####-##)
// ========================================
class CNPJFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final digitsOnly = text.substring(0, text.length > 14 ? 14 : text.length);

    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2 || i == 5) {
        formatted += '.';
      } else if (i == 8) {
        formatted += '/';
      } else if (i == 12) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ========================================
// PHONE FORMATTER ((##) #####-####)
// ========================================
class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final digitsOnly = text.substring(0, text.length > 11 ? 11 : text.length);

    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 0) {
        formatted += '(';
      } else if (i == 2) {
        formatted += ') ';
      } else if ((digitsOnly.length == 11 && i == 7) ||
          (digitsOnly.length == 10 && i == 6)) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ========================================
// CEP FORMATTER (#####-###)
// ========================================
class CEPFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final digitsOnly = text.substring(0, text.length > 8 ? 8 : text.length);

    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 5) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ========================================
// CURRENCY FORMATTER (R$ #.###,##)
// ========================================
class CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remover tudo exceto dígitos
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Converter para double (centavos)
    final intValue = int.parse(digitsOnly);
    final doubleValue = intValue / 100;

    // Formatar como moeda brasileira
    final formatted = 'R\$ ${_formatCurrency(doubleValue)}';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    // Adicionar separadores de milhar
    String formatted = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formatted = '.$formatted';
      }
      formatted = integerPart[i] + formatted;
      count++;
    }

    return '$formatted,$decimalPart';
  }
}

// ========================================
// UPPERCASE FORMATTER
// ========================================
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// ========================================
// LOWERCASE FORMATTER
// ========================================
class LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}

// ========================================
// EXEMPLO DE USO
// ========================================

/// Widget de exemplo mostrando como usar os formatadores
/// 
/// ```dart
/// import 'package:renthus_app/utils/input_formatters.dart';
/// import 'package:renthus_app/utils/brazilian_validators.dart';
/// 
/// class ExampleForm extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Form(
///       child: Column(
///         children: [
///           // CPF
///           TextFormField(
///             decoration: InputDecoration(labelText: 'CPF'),
///             keyboardType: TextInputType.number,
///             inputFormatters: [CPFFormatter()],
///             validator: BrazilianValidators.validateCPF,
///           ),
///           
///           // CNPJ
///           TextFormField(
///             decoration: InputDecoration(labelText: 'CNPJ'),
///             keyboardType: TextInputType.number,
///             inputFormatters: [CNPJFormatter()],
///             validator: BrazilianValidators.validateCNPJ,
///           ),
///           
///           // Telefone
///           TextFormField(
///             decoration: InputDecoration(labelText: 'Telefone'),
///             keyboardType: TextInputType.phone,
///             inputFormatters: [PhoneFormatter()],
///             validator: BrazilianValidators.validatePhone,
///           ),
///           
///           // CEP
///           TextFormField(
///             decoration: InputDecoration(labelText: 'CEP'),
///             keyboardType: TextInputType.number,
///             inputFormatters: [CEPFormatter()],
///             validator: BrazilianValidators.validateCEP,
///           ),
///           
///           // Valor em Reais
///           TextFormField(
///             decoration: InputDecoration(labelText: 'Valor'),
///             keyboardType: TextInputType.number,
///             inputFormatters: [CurrencyFormatter()],
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```