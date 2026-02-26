import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';

const _kRoxo = Color(0xFF3B246B);

class AdminVerificationsTab extends ConsumerStatefulWidget {
  const AdminVerificationsTab({super.key});

  @override
  ConsumerState<AdminVerificationsTab> createState() =>
      _AdminVerificationsTabState();
}

class _AdminVerificationsTabState
    extends ConsumerState<AdminVerificationsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _pending = [];
  String _filter = 'documents_submitted';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final data = await supabase
          .from('providers')
          .select(
            'id, user_id, full_name, cpf, phone, address_city, '
            'address_state, verification_status, document_front_url, '
            'document_back_url, selfie_document_url, document_type, '
            'mother_name, birthdate, professional_occupation, '
            'bank_code, bank_branch_number, bank_account_number, '
            'bank_account_type, bank_holder_name, created_at',
          )
          .eq('verification_status', _filter)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _pending = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _filterChip('Aguardando', 'documents_submitted'),
              const SizedBox(width: 8),
              _filterChip('Rejeitados', 'rejected'),
              const SizedBox(width: 8),
              _filterChip('Pendentes', 'pending'),
              const SizedBox(width: 8),
              _filterChip('Suspensos', 'suspended'),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _pending.isEmpty && !_loading
              ? const Center(
                  child: Text(
                    'Nenhuma verificação neste filtro.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _ProviderVerificationCard(
                        provider: _pending[i],
                        onAction: _load,
                      ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String status) {
    final active = _filter == status;
    return FilterChip(
      label: Text(label),
      selected: active,
      selectedColor: _kRoxo.withOpacity(0.15),
      checkmarkColor: _kRoxo,
      onSelected: (_) {
        setState(() => _filter = status);
        _load();
      },
    );
  }
}

class _ProviderVerificationCard extends ConsumerStatefulWidget {
  const _ProviderVerificationCard({
    required this.provider,
    required this.onAction,
  });
  final Map<String, dynamic> provider;
  final VoidCallback onAction;

  @override
  ConsumerState<_ProviderVerificationCard> createState() =>
      _ProviderVerificationCardState();
}

class _ProviderVerificationCardState
    extends ConsumerState<_ProviderVerificationCard> {
  bool _acting = false;

  String get _name =>
      (widget.provider['full_name'] as String?)?.trim().isNotEmpty == true
          ? widget.provider['full_name'] as String
          : 'Prestador';

  String get _cpf => (widget.provider['cpf'] as String?) ?? '—';
  String get _city =>
      '${widget.provider['address_city'] ?? '?'}-${widget.provider['address_state'] ?? '?'}';

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final providerId = widget.provider['id'] as String;

      await supabase.from('providers').update({
        'verification_status': 'documents_approved',
      }).eq('id', providerId);

      await supabase.from('provider_verification_log').insert({
        'provider_id': providerId,
        'old_status': widget.provider['verification_status'],
        'new_status': 'documents_approved',
        'reason': 'Documentos aprovados pelo admin',
      });

      // Call edge function to create Pagar.me recipient
      try {
        await supabase.functions.invoke(
          'create-pagarme-recipient',
          body: {'provider_id': providerId},
        );
      } catch (_) {
        // Recipient creation can be retried later
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prestador aprovado!')),
      );
      widget.onAction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Motivo da rejeição'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Descreva o motivo...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Rejeitar'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _acting = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final providerId = widget.provider['id'] as String;

      await supabase.from('providers').update({
        'verification_status': 'rejected',
        'document_rejected_reason': reason,
      }).eq('id', providerId);

      await supabase.from('provider_verification_log').insert({
        'provider_id': providerId,
        'old_status': widget.provider['verification_status'],
        'new_status': 'rejected',
        'reason': reason,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prestador rejeitado.')),
      );
      widget.onAction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _viewDocuments() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          _ProviderDocumentsPage(provider: widget.provider),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _kRoxo.withOpacity(0.1),
                  child: Text(
                    _name[0].toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: _kRoxo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('CPF: $_cpf • $_city',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _viewDocuments,
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Ver documentos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRoxo,
                    side: const BorderSide(color: _kRoxo),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const Spacer(),
                if (_acting)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  TextButton(
                    onPressed: _reject,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Rejeitar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0DAA00),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Aprovar'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderDocumentsPage extends StatelessWidget {
  const _ProviderDocumentsPage({required this.provider});
  final Map<String, dynamic> provider;

  @override
  Widget build(BuildContext context) {
    final name = (provider['full_name'] as String?) ?? 'Prestador';
    final frontUrl = provider['document_front_url'] as String?;
    final backUrl = provider['document_back_url'] as String?;
    final selfieUrl = provider['selfie_document_url'] as String?;
    final docType = (provider['document_type'] as String?) ?? '—';
    final cpf = (provider['cpf'] as String?) ?? '—';
    final motherName = (provider['mother_name'] as String?) ?? '—';
    final birthdate = (provider['birthdate'] as String?) ?? '—';
    final occupation =
        (provider['professional_occupation'] as String?) ?? '—';
    final bankCode = (provider['bank_code'] as String?) ?? '—';
    final bankBranch =
        (provider['bank_branch_number'] as String?) ?? '—';
    final bankAccount =
        (provider['bank_account_number'] as String?) ?? '—';
    final bankType = (provider['bank_account_type'] as String?) ?? '—';
    final holderName =
        (provider['bank_holder_name'] as String?) ?? '—';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
        title: Text('Docs: $name'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Dados pessoais'),
            _infoRow('CPF', cpf),
            _infoRow('Nome da mãe', motherName),
            _infoRow('Nascimento', birthdate),
            _infoRow('Profissão', occupation),
            const SizedBox(height: 20),
            _sectionTitle('Dados bancários'),
            _infoRow('Titular', holderName),
            _infoRow('Banco', bankCode),
            _infoRow('Agência', bankBranch),
            _infoRow('Conta', bankAccount),
            _infoRow('Tipo', bankType == 'checking' ? 'Corrente' : 'Poupança'),
            const SizedBox(height: 20),
            _sectionTitle('Documentos ($docType)'),
            const SizedBox(height: 8),
            _docImage(context, 'Frente do documento', frontUrl),
            const SizedBox(height: 12),
            _docImage(context, 'Verso do documento', backUrl),
            const SizedBox(height: 12),
            _docImage(context, 'Selfie com documento', selfieUrl),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _kRoxo)),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 120,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _docImage(
      BuildContext context, String label, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (url != null && url.isNotEmpty)
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                    backgroundColor: Colors.black, title: Text(label)),
                backgroundColor: Colors.black,
                body: Center(
                  child: InteractiveViewer(
                    child: Image.network(url),
                  ),
                ),
              ),
            )),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey.shade200,
                  child: const Center(child: Text('Erro ao carregar')),
                ),
              ),
            ),
          )
        else
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('Não enviado',
                  style: TextStyle(color: Colors.black38)),
            ),
          ),
      ],
    );
  }
}
