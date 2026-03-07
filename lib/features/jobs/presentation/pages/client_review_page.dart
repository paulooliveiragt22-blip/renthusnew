import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/utils/comment_moderator.dart';

class ClientReviewPage extends ConsumerStatefulWidget {
  const ClientReviewPage({
    super.key,
    required this.jobId,
    required this.providerId,
    this.providerName,
  });

  final String jobId;
  final String providerId;
  final String? providerName;

  @override
  ConsumerState<ClientReviewPage> createState() => _ClientReviewPageState();
}

class _ClientReviewPageState extends ConsumerState<ClientReviewPage> {
  int _rating = 0; // 0 = nenhuma estrela selecionada ainda
  final _commentController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingReview = true;
  bool _alreadyReviewed = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyReviewed();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Verificação de duplicidade ────────────────────────────────────────────

  Future<void> _checkIfAlreadyReviewed() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isCheckingReview = false);
        return;
      }
      final res = await supabase
          .from('reviews')
          .select('id')
          .eq('job_id', widget.jobId)
          .eq('from_user', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _alreadyReviewed = res != null;
          _isCheckingReview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingReview = false);
    }
  }

  // ── Envio ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isLoading || _alreadyReviewed) return;

    if (_rating == 0) {
      _snack('Selecione uma nota de 1 a 5 estrelas.');
      return;
    }

    final commentText = _commentController.text.trim();
    final moderationError = CommentModerator.validate(commentText);
    if (moderationError != null) {
      _snack(moderationError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser;
      if (user == null) {
        _snack('Faça login novamente.');
        setState(() => _isLoading = false);
        return;
      }

      // Tenta encontrar o provider por id ou por user_id
      Map<String, dynamic>? provRow = await supabase
          .from('providers')
          .select('id, user_id')
          .eq('id', widget.providerId)
          .maybeSingle();

      provRow ??= await supabase
          .from('providers')
          .select('id, user_id')
          .eq('user_id', widget.providerId)
          .maybeSingle();

      final providersId = (provRow?['id'] as String?) ?? widget.providerId;
      final toUser     = (provRow?['user_id'] as String?) ?? widget.providerId;

      await supabase.from('reviews').insert({
        'job_id':      widget.jobId,
        'from_user':   user.id,
        'to_user':     toUser,
        'provider_id': providersId,
        'rating':      _rating,
        'comment':     commentText,
      });

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitted = true;
      });

      // Exibe sucesso por 1.8s antes de fechar
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao enviar avaliação: $e');
      if (!mounted) return;
      _snack(ErrorHandler.friendlyErrorMessage(e));
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Avaliar profissional',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isCheckingReview
          ? const Center(child: CircularProgressIndicator())
          : _submitted
              ? _buildSuccessView()
              : _alreadyReviewed
                  ? _buildAlreadyReviewedView()
                  : _buildForm(roxo),
    );
  }

  // ── Tela de sucesso ───────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF34A853),
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Avaliação enviada!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Obrigado pelo feedback. Sua opinião sobre '
              '${widget.providerName?.isNotEmpty == true ? widget.providerName! : 'o profissional'} '
              'já está no perfil dele.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (i) => Icon(
                  i < _rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: i < _rating
                      ? Colors.amber.shade700
                      : Colors.grey.shade300,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Já avaliou ────────────────────────────────────────────────────────────

  Widget _buildAlreadyReviewedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Você já avaliou este pedido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Só é permitida uma avaliação por pedido.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B246B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Formulário ────────────────────────────────────────────────────────────

  Widget _buildForm(Color roxo) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card com nome do prestador
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE9F7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF3B246B),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Avaliando',
                        style: TextStyle(
                            fontSize: 11, color: Colors.black45),
                      ),
                      Text(
                        widget.providerName?.isNotEmpty == true
                            ? widget.providerName!
                            : 'Profissional',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B246B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Estrelas
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text(
                  'Como foi o atendimento?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B246B),
                  ),
                ),
                const SizedBox(height: 20),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final starIndex = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starIndex),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            starIndex <= _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 46,
                            color: starIndex <= _rating
                                ? Colors.amber.shade700
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _rating == 0
                      ? 'Toque em uma estrela para avaliar'
                      : _ratingLabel(_rating),
                  style: TextStyle(
                    fontSize: 13,
                    color: _rating == 0
                        ? Colors.black38
                        : Colors.amber.shade800,
                    fontWeight: _rating > 0
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Comentário
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comentário (opcional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B246B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Descreva sua experiência com o serviço prestado.',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText:
                        'Ex: Profissional pontual, serviço bem feito...',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: Colors.black38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFF3B246B)),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Proibido incluir telefone, e-mail, redes sociais ou linguagem ofensiva.',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botão enviar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isLoading || _rating == 0) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: roxo,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Enviar avaliação',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Péssimo';
      case 2:
        return 'Ruim';
      case 3:
        return 'Regular';
      case 4:
        return 'Bom';
      case 5:
        return 'Excelente!';
      default:
        return '';
    }
  }
}
