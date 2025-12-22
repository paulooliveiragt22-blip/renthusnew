// lib/screens/sign_in.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  final AuthService _auth = AuthService();

  Future<void> _submit() async {
    setState(() => _loading = true);
    final email = _email.text.trim();
    final pass = _pass.text;

    try {
      final res = await _auth.signIn(email, pass);
      final session = res.session ?? _auth.client.auth.currentSession;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha no login.')));
        setState(() => _loading = false);
        return;
      }

      // obter profile e redirecionar conforme role
      final profile = await _auth.getProfile(session.user?.id);
      final role = profile?['role'] as String?;
      if (context.mounted) {
        if (role == 'provider') {
          Navigator.pushReplacementNamed(context, '/home'); // você pode direcionar para onboarding provider
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de autenticação: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const CircularProgressIndicator() : const Text('Entrar')),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pushNamed(context, '/sign_up'), child: const Text('Criar conta')),
          ],
        ),
      ),
    );
  }
}
