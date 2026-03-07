import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailConfirmationPage extends StatefulWidget {
  const EmailConfirmationPage({
    super.key,
    required this.email,
    required this.nextRoute,
    required this.password,
  });

  final String email;
  final String nextRoute;
  final String password;

  @override
  State<EmailConfirmationPage> createState() => _EmailConfirmationPageState();
}

class _EmailConfirmationPageState extends State<EmailConfirmationPage> {
  bool _loading = false;

  Future<void> _handleContinue() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: widget.email,
        password: widget.password,
      );
      if (!mounted) return;
      final confirmed = response.user?.emailConfirmedAt != null;
      if (!confirmed) {
        throw Exception('E-mail ainda não confirmado.');
      }
      context.go(widget.nextRoute);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_authErrorMessage(e.message)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'E-mail ainda não confirmado. Verifique sua caixa de entrada e clique no link antes de continuar.',
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ));
      setState(() => _loading = false);
    }
  }

  String _authErrorMessage(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('email not confirmed')) {
      return 'E-mail ainda não confirmado. Clique no link enviado para ${widget.email} e tente novamente.';
    }
    if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
      return 'Credenciais inválidas. Tente novamente.';
    }
    return 'E-mail ainda não confirmado. Verifique sua caixa de entrada e clique no link antes de continuar.';
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: const Text('Confirmação de e-mail'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.mark_email_unread_outlined, size: 80, color: roxo),
            const SizedBox(height: 24),
            const Text(
              'Verifique seu e-mail',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: roxo,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enviamos um link de confirmação para:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Clique no link do e-mail para ativar sua conta e depois toque em continuar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: roxo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Já confirmei, continuar'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
