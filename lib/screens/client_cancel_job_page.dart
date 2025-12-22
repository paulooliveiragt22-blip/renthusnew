import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CancelJobPage extends StatefulWidget {
  final String jobId;
  final String role; // 'client' ou 'provider'

  const CancelJobPage({
    super.key,
    required this.jobId,
    required this.role,
  });

  @override
  State<CancelJobPage> createState() => _CancelJobPageState();
}

class _CancelJobPageState extends State<CancelJobPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  String get _title =>
      widget.role == 'provider' ? 'Cancelar atendimento' : 'Cancelar pedido';

  String get _warningText {
    if (widget.role == 'provider') {
      return 'Atenção: cancelar atendimentos com frequência ou muito em cima '
          'da hora pode impactar sua reputação na plataforma e gerar '
          'punições futuras, como redução de destaque nas listagens.';
    } else {
      return 'Ao cancelar, o profissional será informado. Evite cancelar '
          'repetidamente sem necessidade para manter uma boa experiência '
          'na plataforma. Se houver pagamento, o estorno será analisado '
          'e processado conforme as regras da Renthus.';
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faça login novamente.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final reason = _reasonController.text.trim();

      await supabase.rpc(
        'cancel_job',
        params: {
          '_job_id': widget.jobId,
          '_user_id': user.id,
          '_role': widget.role,
          '_reason': reason.isEmpty ? null : reason,
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao cancelar job: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        title: Text(_title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _warningText,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            const Text(
              'Conte o motivo do cancelamento (opcional):',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'Ex: O horário não serve mais, precisei mudar a data...',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isLoading ? 'Cancelando...' : 'Confirmar cancelamento',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
