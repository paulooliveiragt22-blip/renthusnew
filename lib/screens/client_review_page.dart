import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientReviewPage extends StatefulWidget {
  final String jobId;
  final String providerId;

  const ClientReviewPage({
    super.key,
    required this.jobId,
    required this.providerId,
  });

  @override
  State<ClientReviewPage> createState() => _ClientReviewPageState();
}

class _ClientReviewPageState extends State<ClientReviewPage> {
  final supabase = Supabase.instance.client;
  double _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

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

      await supabase.from('reviews').insert({
        'job_id': widget.jobId,
        'client_id': user.id,
        'provider_id': widget.providerId,
        'rating': _rating.round(),
        'comment': _commentController.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao enviar avaliação: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar avaliação: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        title: const Text('Avaliar profissional'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como foi o atendimento?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _rating,
              min: 1,
              max: 5,
              divisions: 4,
              label: _rating.toStringAsFixed(1),
              onChanged: (v) => setState(() => _rating = v),
            ),
            const SizedBox(height: 8),
            const Text('Deixe um comentário (opcional):'),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B246B),
                ),
                child: Text(_isLoading ? 'Enviando...' : 'Enviar avaliação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
