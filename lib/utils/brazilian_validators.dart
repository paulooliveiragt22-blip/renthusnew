/// Validadores brasileiros (CPF, CNPJ, telefone, CEP, etc)
class BrazilianValidators {
  /// Valida CPF
  static bool isValidCPF(String cpf) {
    // Remove caracteres não numéricos
    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');

    // CPF deve ter 11 dígitos
    if (cpf.length != 11) return false;

    // Verifica se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1*$').hasMatch(cpf)) return false;

    // Valida primeiro dígito verificador
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }
    int digit1 = 11 - (sum % 11);
    if (digit1 >= 10) digit1 = 0;
    if (digit1 != int.parse(cpf[9])) return false;

    // Valida segundo dígito verificador
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }
    int digit2 = 11 - (sum % 11);
    if (digit2 >= 10) digit2 = 0;
    if (digit2 != int.parse(cpf[10])) return false;

    return true;
  }

  /// Valida CNPJ
  static bool isValidCNPJ(String cnpj) {
    // Remove caracteres não numéricos
    cnpj = cnpj.replaceAll(RegExp(r'[^\d]'), '');

    // CNPJ deve ter 14 dígitos
    if (cnpj.length != 14) return false;

    // Verifica se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1*$').hasMatch(cnpj)) return false;

    // Valida primeiro dígito verificador
    List<int> weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(cnpj[i]) * weights1[i];
    }
    int digit1 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    if (digit1 != int.parse(cnpj[12])) return false;

    // Valida segundo dígito verificador
    List<int> weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    sum = 0;
    for (int i = 0; i < 13; i++) {
      sum += int.parse(cnpj[i]) * weights2[i];
    }
    int digit2 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    if (digit2 != int.parse(cnpj[13])) return false;

    return true;
  }

  /// Valida telefone brasileiro
  static bool isValidPhone(String phone) {
    // Remove caracteres não numéricos
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Telefone pode ter 10 ou 11 dígitos (com DDD)
    if (phone.length != 10 && phone.length != 11) return false;

    // Verifica se começa com DDD válido (11-99)
    int ddd = int.parse(phone.substring(0, 2));
    if (ddd < 11 || ddd > 99) return false;

    return true;
  }

  /// Valida CEP
  static bool isValidCEP(String cep) {
    // Remove caracteres não numéricos
    cep = cep.replaceAll(RegExp(r'[^\d]'), '');

    // CEP deve ter 8 dígitos
    return cep.length == 8;
  }

  /// Valida email
  static bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Valida se string contém apenas números
  static bool isNumeric(String str) {
    return RegExp(r'^\d+$').hasMatch(str);
  }

  /// Valida se string contém apenas letras
  static bool isAlpha(String str) {
    return RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(str);
  }

  /// Valida se string é alfanumérica
  static bool isAlphanumeric(String str) {
    return RegExp(r'^[a-zA-Z0-9À-ÿ\s]+$').hasMatch(str);
  }

  /// Valida senha forte
  /// - Mínimo 8 caracteres
  /// - Pelo menos uma letra maiúscula
  /// - Pelo menos uma letra minúscula
  /// - Pelo menos um número
  /// - Pelo menos um caractere especial
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;

    bool hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    bool hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    bool hasDigit = RegExp(r'\d').hasMatch(password);
    bool hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    return hasUppercase && hasLowercase && hasDigit && hasSpecialChar;
  }

  /// Formata CPF (000.000.000-00)
  static String formatCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    if (cpf.length != 11) return cpf;

    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9, 11)}';
  }

  /// Formata CNPJ (00.000.000/0000-00)
  static String formatCNPJ(String cnpj) {
    cnpj = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    if (cnpj.length != 14) return cnpj;

    return '${cnpj.substring(0, 2)}.${cnpj.substring(2, 5)}.${cnpj.substring(5, 8)}/${cnpj.substring(8, 12)}-${cnpj.substring(12, 14)}';
  }

  /// Formata telefone ((00) 00000-0000)
  static String formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (phone.length == 10) {
      // Telefone fixo
      return '(${phone.substring(0, 2)}) ${phone.substring(2, 6)}-${phone.substring(6, 10)}';
    } else if (phone.length == 11) {
      // Celular
      return '(${phone.substring(0, 2)}) ${phone.substring(2, 7)}-${phone.substring(7, 11)}';
    }

    return phone;
  }

  /// Formata CEP (00000-000)
  static String formatCEP(String cep) {
    cep = cep.replaceAll(RegExp(r'[^\d]'), '');
    if (cep.length != 8) return cep;

    return '${cep.substring(0, 5)}-${cep.substring(5, 8)}';
  }

  /// Remove formatação de CPF
  static String unformatCPF(String cpf) {
    return cpf.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Remove formatação de CNPJ
  static String unformatCNPJ(String cnpj) {
    return cnpj.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Remove formatação de telefone
  static String unformatPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Remove formatação de CEP
  static String unformatCEP(String cep) {
    return cep.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Valida data no formato DD/MM/YYYY
  static bool isValidDate(String date) {
    try {
      final parts = date.split('/');
      if (parts.length != 3) return false;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      if (month < 1 || month > 12) return false;
      if (day < 1 || day > 31) return false;
      if (year < 1900 || year > 2100) return false;

      // Valida dias por mês
      final daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

      // Verifica ano bissexto
      if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
        daysInMonth[1] = 29;
      }

      if (day > daysInMonth[month - 1]) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Valida se pessoa é maior de idade (18 anos)
  static bool isAdult(String birthDate) {
    try {
      final parts = birthDate.split('/');
      if (parts.length != 3) return false;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final birth = DateTime(year, month, day);
      final today = DateTime.now();
      final age = today.year - birth.year;

      if (today.month < birth.month ||
          (today.month == birth.month && today.day < birth.day)) {
        return age - 1 >= 18;
      }

      return age >= 18;
    } catch (e) {
      return false;
    }
  }

  /// Valida nome completo (mínimo 2 palavras)
  static bool isValidFullName(String name) {
    name = name.trim();
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    return words.length >= 2 && isAlpha(name);
  }

  /// Valida URL
  static bool isValidURL(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Valida valor monetário (permite números e vírgula/ponto)
  static bool isValidMoney(String value) {
    return RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(value);
  }

  /// Valida cartão de crédito (algoritmo de Luhn)
  static bool isValidCreditCard(String cardNumber) {
    cardNumber = cardNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cardNumber.length < 13 || cardNumber.length > 19) return false;

    int sum = 0;
    bool alternate = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Valida placa de veículo (padrão Mercosul)
  static bool isValidLicensePlate(String plate) {
    plate = plate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Formato antigo: ABC1234
    bool oldFormat = RegExp(r'^[A-Z]{3}\d{4}$').hasMatch(plate);

    // Formato Mercosul: ABC1D23
    bool mercosulFormat = RegExp(r'^[A-Z]{3}\d[A-Z]\d{2}$').hasMatch(plate);

    return oldFormat || mercosulFormat;
  }

  /// Valida código de segurança do cartão (CVV)
  static bool isValidCVV(String cvv) {
    return RegExp(r'^\d{3,4}$').hasMatch(cvv);
  }

  /// Valida data de validade do cartão (MM/YY)
  static bool isValidCardExpiry(String expiry) {
    try {
      final parts = expiry.split('/');
      if (parts.length != 2) return false;

      final month = int.parse(parts[0]);
      final year = int.parse('20${parts[1]}');

      if (month < 1 || month > 12) return false;

      final now = DateTime.now();
      final expiryDate = DateTime(year, month);

      return expiryDate.isAfter(now);
    } catch (e) {
      return false;
    }
  }

  /// Remove caracteres especiais perigosos (prevenir SQL injection)
  static String sanitizeInput(String input) {
    // Remover aspas, ponto-e-vírgula, etc
    // CORRIGIDO: usando triple quotes para evitar problema com aspas
    return input
        .replaceAll(RegExp(r"""['";\\]"""), '')
        .trim();
  }

  /// Limpar apenas números (útil para CPF, telefone, CEP)
  static String onlyNumbers(String input) {
    return input.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Limpar apenas letras (útil para nomes)
  static String onlyLetters(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ\s]'), '');
  }

  /// Capitalize primeira letra de cada palavra
  static String capitalize(String input) {
    if (input.isEmpty) return input;

    return input
        .split(' ')
        .map((word) =>
            word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}