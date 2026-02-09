// lib/utils/brazilian_validators.dart

/// Validadores para dados brasileiros
/// 
/// Incluí:
/// - CPF (com dígito verificador)
/// - CNPJ (com dígito verificador)
/// - Telefone (celular e fixo)
/// - CEP
/// - Sanitização de inputs
class BrazilianValidators {
  // ========================================
  // CPF
  // ========================================

  /// Validar CPF
  /// 
  /// Uso em TextFormField:
  /// ```dart
  /// TextFormField(
  ///   validator: BrazilianValidators.validateCPF,
  /// )
  /// ```
  static String? validateCPF(String? value) {
    if (value == null || value.isEmpty) {
      return 'CPF obrigatório';
    }

    // Remover formatação
    final cpf = value.replaceAll(RegExp(r'[^\d]'), '');

    // Verificar tamanho
    if (cpf.length != 11) {
      return 'CPF deve ter 11 dígitos';
    }

    // Verificar se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return 'CPF inválido';
    }

    // Validar dígitos verificadores
    if (!_isValidCPF(cpf)) {
      return 'CPF inválido';
    }

    return null;
  }

  /// Verificar se CPF é válido (algoritmo oficial)
  static bool _isValidCPF(String cpf) {
    // Calcular primeiro dígito verificador
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }
    int digit1 = (sum * 10) % 11;
    if (digit1 == 10) digit1 = 0;

    if (digit1 != int.parse(cpf[9])) {
      return false;
    }

    // Calcular segundo dígito verificador
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }
    int digit2 = (sum * 10) % 11;
    if (digit2 == 10) digit2 = 0;

    return digit2 == int.parse(cpf[10]);
  }

  /// Formatar CPF (123.456.789-01)
  static String formatCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    if (cpf.length != 11) return cpf;

    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }

  // ========================================
  // CNPJ
  // ========================================

  /// Validar CNPJ
  static String? validateCNPJ(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Opcional
    }

    // Remover formatação
    final cnpj = value.replaceAll(RegExp(r'[^\d]'), '');

    // Verificar tamanho
    if (cnpj.length != 14) {
      return 'CNPJ deve ter 14 dígitos';
    }

    // Verificar se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) {
      return 'CNPJ inválido';
    }

    // Validar dígitos verificadores
    if (!_isValidCNPJ(cnpj)) {
      return 'CNPJ inválido';
    }

    return null;
  }

  /// Verificar se CNPJ é válido (algoritmo oficial)
  static bool _isValidCNPJ(String cnpj) {
    // Primeiro dígito verificador
    int sum = 0;
    int weight = 5;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(cnpj[i]) * weight;
      weight = weight == 2 ? 9 : weight - 1;
    }
    int digit1 = sum % 11 < 2 ? 0 : 11 - (sum % 11);

    if (digit1 != int.parse(cnpj[12])) {
      return false;
    }

    // Segundo dígito verificador
    sum = 0;
    weight = 6;
    for (int i = 0; i < 13; i++) {
      sum += int.parse(cnpj[i]) * weight;
      weight = weight == 2 ? 9 : weight - 1;
    }
    int digit2 = sum % 11 < 2 ? 0 : 11 - (sum % 11);

    return digit2 == int.parse(cnpj[13]);
  }

  /// Formatar CNPJ (12.345.678/0001-90)
  static String formatCNPJ(String cnpj) {
    cnpj = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    if (cnpj.length != 14) return cnpj;

    return '${cnpj.substring(0, 2)}.${cnpj.substring(2, 5)}.${cnpj.substring(5, 8)}/${cnpj.substring(8, 12)}-${cnpj.substring(12)}';
  }

  // ========================================
  // TELEFONE
  // ========================================

  /// Validar telefone brasileiro
  /// 
  /// Aceita:
  /// - Celular: (11) 98765-4321 (11 dígitos)
  /// - Fixo: (11) 3456-7890 (10 dígitos)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Telefone obrigatório';
    }

    // Remover formatação
    final phone = value.replaceAll(RegExp(r'[^\d]'), '');

    // Verificar tamanho
    if (phone.length != 10 && phone.length != 11) {
      return 'Telefone inválido';
    }

    // Verificar se começa com DDD válido (10-99)
    final ddd = int.tryParse(phone.substring(0, 2));
    if (ddd == null || ddd < 10 || ddd > 99) {
      return 'DDD inválido';
    }

    // Se for celular (11 dígitos), deve começar com 9
    if (phone.length == 11 && phone[2] != '9') {
      return 'Celular deve começar com 9';
    }

    return null;
  }

  /// Formatar telefone ((11) 98765-4321)
  static String formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (phone.length == 11) {
      // Celular: (11) 98765-4321
      return '(${phone.substring(0, 2)}) ${phone.substring(2, 7)}-${phone.substring(7)}';
    } else if (phone.length == 10) {
      // Fixo: (11) 3456-7890
      return '(${phone.substring(0, 2)}) ${phone.substring(2, 6)}-${phone.substring(6)}';
    }

    return phone;
  }

  // ========================================
  // CEP
  // ========================================

  /// Validar CEP
  static String? validateCEP(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Opcional
    }

    // Remover formatação
    final cep = value.replaceAll(RegExp(r'[^\d]'), '');

    // Verificar tamanho
    if (cep.length != 8) {
      return 'CEP deve ter 8 dígitos';
    }

    // Verificar se não é sequência inválida
    if (RegExp(r'^0{8}$').hasMatch(cep)) {
      return 'CEP inválido';
    }

    return null;
  }

  /// Formatar CEP (12345-678)
  static String formatCEP(String cep) {
    cep = cep.replaceAll(RegExp(r'[^\d]'), '');
    if (cep.length != 8) return cep;

    return '${cep.substring(0, 5)}-${cep.substring(5)}';
  }

  // ========================================
  // E-MAIL
  // ========================================

  /// Validar e-mail
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'E-mail obrigatório';
    }

    // Regex básico para e-mail
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'E-mail inválido';
    }

    // Verificar se é e-mail descartável (opcional)
    if (_isDisposableEmail(value)) {
      return 'E-mails temporários não são permitidos';
    }

    return null;
  }

  /// Verificar se é e-mail descartável
  static bool _isDisposableEmail(String email) {
    final domain = email.split('@').last.toLowerCase();

    const disposableDomains = [
      'tempmail.com',
      'guerrillamail.com',
      '10minutemail.com',
      'yopmail.com',
      'mailinator.com',
      'throwaway.email',
      'fakeinbox.com',
      'trashmail.com',
    ];

    return disposableDomains.contains(domain);
  }

  // ========================================
  // SENHA
  // ========================================

  /// Validar senha forte
  /// 
  /// Requisitos:
  /// - Mínimo 8 caracteres
  /// - Pelo menos uma letra maiúscula
  /// - Pelo menos uma letra minúscula
  /// - Pelo menos um número
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Senha obrigatória';
    }

    if (value.length < 8) {
      return 'Senha deve ter pelo menos 8 caracteres';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Senha deve conter pelo menos uma letra maiúscula';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Senha deve conter pelo menos uma letra minúscula';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Senha deve conter pelo menos um número';
    }

    return null;
  }

  /// Validar confirmação de senha
  static String? validatePasswordConfirmation(
    String? value,
    String password,
  ) {
    if (value == null || value.isEmpty) {
      return 'Confirme a senha';
    }

    if (value != password) {
      return 'Senhas não coincidem';
    }

    return null;
  }

  // ========================================
  // SANITIZAÇÃO
  // ========================================

  /// Remover HTML e scripts (prevenir XSS)
  static String sanitizeHtml(String input) {
    return input
        .replaceAll(RegExp(r'<script.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<.*?>'), '')
        .trim();
  }

  /// Remover caracteres especiais perigosos (prevenir SQL injection)
  static String sanitizeInput(String input) {
    // Remover aspas, ponto-e-vírgula, etc
    return input
        .replaceAll(RegExp(r'[\'";\\]'), '')
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
}