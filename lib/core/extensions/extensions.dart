import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Extension para DateTime
extension DateTimeX on DateTime {
  /// Formata para dd/MM/yyyy
  String toDateString() {
    return DateFormat('dd/MM/yyyy').format(this);
  }

  /// Formata para dd/MM/yyyy HH:mm
  String toDateTimeString() {
    return DateFormat('dd/MM/yyyy HH:mm').format(this);
  }

  /// Formata para HH:mm
  String toTimeString() {
    return DateFormat('HH:mm').format(this);
  }

  /// Retorna string relativa (Há 5 minutos, Ontem, etc)
  String toRelativeString() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'Agora mesmo';
    }

    if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} min';
    }

    if (difference.inHours < 24) {
      return 'Há ${difference.inHours}h';
    }

    if (difference.inDays == 1) {
      return 'Ontem';
    }

    if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    }

    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Há $weeks ${weeks == 1 ? "semana" : "semanas"}';
    }

    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Há $months ${months == 1 ? "mês" : "meses"}';
    }

    final years = (difference.inDays / 365).floor();
    return 'Há $years ${years == 1 ? "ano" : "anos"}';
  }

  /// Verifica se é hoje
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Verifica se é ontem
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && 
           month == yesterday.month && 
           day == yesterday.day;
  }
}

/// Extension para String
extension StringX on String {
  /// Capitaliza primeira letra
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  /// Capitaliza todas as palavras
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty ? word : word.capitalize())
        .join(' ');
  }

  /// Remove acentos
  String removeAccents() {
    const withAccents = 'áàãâäéèêëíìîïóòõôöúùûüçñÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

    var result = this;
    for (var i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result;
  }

  /// Máscara de CPF
  String toCpfMask() {
    final numbers = replaceAll(RegExp(r'[^\d]'), '');
    if (numbers.length != 11) return this;
    return '${numbers.substring(0, 3)}.${numbers.substring(3, 6)}.${numbers.substring(6, 9)}-${numbers.substring(9, 11)}';
  }

  /// Máscara de CNPJ
  String toCnpjMask() {
    final numbers = replaceAll(RegExp(r'[^\d]'), '');
    if (numbers.length != 14) return this;
    return '${numbers.substring(0, 2)}.${numbers.substring(2, 5)}.${numbers.substring(5, 8)}/${numbers.substring(8, 12)}-${numbers.substring(12, 14)}';
  }

  /// Máscara de telefone
  String toPhoneMask() {
    final numbers = replaceAll(RegExp(r'[^\d]'), '');
    if (numbers.length < 10) return this;
    if (numbers.length == 10) {
      return '(${numbers.substring(0, 2)}) ${numbers.substring(2, 6)}-${numbers.substring(6, 10)}';
    }
    return '(${numbers.substring(0, 2)}) ${numbers.substring(2, 7)}-${numbers.substring(7, 11)}';
  }

  /// Máscara de CEP
  String toCepMask() {
    final numbers = replaceAll(RegExp(r'[^\d]'), '');
    if (numbers.length != 8) return this;
    return '${numbers.substring(0, 5)}-${numbers.substring(5, 8)}';
  }

  /// Remove máscara (deixa só números)
  String get onlyNumbers {
    return replaceAll(RegExp(r'[^\d]'), '');
  }
}

/// Extension para int (valores monetários)
extension IntX on int {
  /// Formata como moeda brasileira
  String toCurrency() {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    return formatter.format(this / 100);
  }
}

/// Extension para double (valores monetários)
extension DoubleX on double {
  /// Formata como moeda brasileira
  String toCurrency() {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    return formatter.format(this);
  }
}

/// Extension para BuildContext
extension BuildContextX on BuildContext {
  /// Tamanho da tela
  Size get screenSize => MediaQuery.sizeOf(this);
  
  /// Largura da tela
  double get screenWidth => screenSize.width;
  
  /// Altura da tela
  double get screenHeight => screenSize.height;
  
  /// Padding do sistema (safe area)
  EdgeInsets get systemPadding => MediaQuery.paddingOf(this);
  
  /// Theme
  ThemeData get theme => Theme.of(this);
  
  /// TextTheme
  TextTheme get textTheme => theme.textTheme;
  
  /// ColorScheme
  ColorScheme get colorScheme => theme.colorScheme;
  
  /// É dark mode?
  bool get isDarkMode => theme.brightness == Brightness.dark;
  
  /// Mostra SnackBar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// Esconde teclado
  void hideKeyboard() {
    FocusScope.of(this).unfocus();
  }
}

/// Extension para List
extension ListX<T> on List<T> {
  /// Separa elementos com um separador
  List<T> separated(T separator) {
    if (isEmpty) return [];
    
    final result = <T>[];
    for (var i = 0; i < length; i++) {
      result.add(this[i]);
      if (i < length - 1) {
        result.add(separator);
      }
    }
    return result;
  }
}
