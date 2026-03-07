/// Valida comentários de avaliações.
///
/// Detecta:
///  - Palavras ofensivas em português
///  - Números de telefone (formato brasileiro)
///  - Endereços de e-mail
///  - Links, URLs e referências a redes sociais
///  - Handles (@usuario)
class CommentModerator {
  // ── Padrões de contato ────────────────────────────────────────────────────

  /// Número de telefone brasileiro com DDD (ex: (11) 99999-9999, 11 9 9999-9999)
  static final _phoneRegex = RegExp(
    r'(\+?55[\s\-]?)?'
    r'(\(?\d{2}\)?[\s\-]?)'
    r'\d{4,5}[\s\-]?\d{4}',
    caseSensitive: false,
  );

  /// Sequência de 9+ dígitos consecutivos (após remover separadores)
  static final _rawDigitsRegex = RegExp(r'\d{9,}');

  /// E-mail
  static final _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  /// URLs, domínios de redes sociais, WhatsApp
  static final _urlRegex = RegExp(
    r'(https?://|www\.|instagram\.com|facebook\.com|tiktok\.com|'
    r'twitter\.com|x\.com|t\.me|wa\.me|whatsapp|zap\s*zap|linkedin\.com|'
    r'youtube\.com|youtu\.be|snapchat\.com)',
    caseSensitive: false,
  );

  /// Handle de rede social (@usuario com 2+ caracteres)
  static final _handleRegex = RegExp(r'(?<![a-zA-Z0-9])@[a-zA-Z0-9_]{2,}');

  // ── Palavras ofensivas ────────────────────────────────────────────────────

  static const _offensive = [
    'puta', 'puto', 'fdp', 'viado', 'viadinho', 'buceta',
    'merda', 'bosta', 'caralho', 'porra', 'cuzão', 'cuzao',
    'vagabundo', 'vagabunda', 'imbecil', 'idiota', 'babaca',
    'desgraça', 'desgraca', 'lixo', 'escroto', 'canalha',
    'ladrão', 'ladrao', 'golpista', 'bandido', 'estelionatario',
    'retardado', 'mongol', 'otário', 'otario', 'safado', 'safada',
    'arrombado', 'arrombada', 'corno', 'corna', 'prostituta',
  ];

  // ── API pública ───────────────────────────────────────────────────────────

  /// Retorna `null` se o comentário for aceitável, ou a mensagem de erro.
  static String? validate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null; // comentário é opcional

    final lower = trimmed.toLowerCase();

    // 1. Palavras ofensivas (verifica como palavra isolada)
    for (final word in _offensive) {
      if (_containsWord(lower, word)) {
        return 'Comentário com linguagem inadequada. Por favor, revise o texto.';
      }
    }

    // 2. Número de telefone (formatado)
    if (_phoneRegex.hasMatch(trimmed)) {
      return 'Comentários não podem conter números de telefone.';
    }

    // 2b. Sequência longa de dígitos (phone sem formatação)
    final digitsOnly = trimmed.replaceAll(RegExp(r'[\s\-\(\)\+\.]'), '');
    if (_rawDigitsRegex.hasMatch(digitsOnly)) {
      return 'Comentários não podem conter números de telefone.';
    }

    // 3. E-mail
    if (_emailRegex.hasMatch(trimmed)) {
      return 'Comentários não podem conter endereços de e-mail.';
    }

    // 4. Links e redes sociais
    if (_urlRegex.hasMatch(lower)) {
      return 'Comentários não podem conter links ou referências a redes sociais.';
    }

    // 5. Handles (@usuario)
    if (_handleRegex.hasMatch(trimmed)) {
      return 'Comentários não podem conter @menções ou handles de redes sociais.';
    }

    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Verifica se [word] aparece como palavra separada em [text].
  static bool _containsWord(String text, String word) {
    // Permite que a palavra apareça entre espaços/pontuação ou nas bordas
    final pattern = RegExp(
      r'(^|[\s,\.!?\(\[\{"\-])' +
          RegExp.escape(word) +
          r'($|[\s,\.!?\)\]\}"\-])',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }
}
