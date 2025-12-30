import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/onboarding_repository.dart';
import 'confirm_email_page.dart';
import 'login_screen.dart';

enum SignupRole { client, provider }

class SignupStep1Page extends StatefulWidget {
  final SignupRole role;

  const SignupStep1Page({
    super.key,
    required this.role,
  });

  @override
  State<SignupStep1Page> createState() => _SignupStep1PageState();
}

class _SignupStep1PageState extends State<SignupStep1Page> {
  final _supabase = Supabase.instance.client;
  final _onboardingRepo = OnboardingRepository();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _roleAsString(SignupRole role) =>
      role == SignupRole.client ? 'client' : 'provider';

  Future<void> _redirectToLoginWithEmailPrefilled(String email) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Este e-mail já possui cadastro. Faça login para entrar.'),
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(prefilledEmail: email),
      ),
    );
  }

  Future<void> _submit() async {
    if (_loading) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final intendedRole = _roleAsString(widget.role);

    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,

        // ✅ DEEP LINK: abre o app ao clicar no e-mail
        emailRedirectTo: 'renthus://auth-callback',

        data: {
          'full_name': fullName,
          'phone': phone,
          'intended_role': intendedRole,
        },
      );

      // Onboarding (fail-safe)
      await _onboardingRepo.upsert(
        status: 'started',
        intendedRole: intendedRole,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConfirmEmailPage(
            email: email,
            password: password,
            role: widget.role,
          ),
        ),
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();

      if (msg.contains('user already registered') ||
          msg.contains('already registered') ||
          msg.contains('already') && msg.contains('registered') ||
          msg.contains('email') && msg.contains('already')) {
        await _redirectToLoginWithEmailPrefilled(email);
        return;
      }

      _showError(e.message);
    } catch (e) {
      _showError('Erro ao criar conta: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);
    final isClient = widget.role == SignupRole.client;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: Text(
            isClient ? 'Criar conta de Cliente' : 'Criar conta de Prestador'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Bem-vindo ao Renthus Service',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: roxo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isClient
                        ? 'Crie sua conta para contratar serviços.'
                        : 'Crie sua conta para prestar serviços.',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  // Nome
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Informe seu nome.';
                      if (!t.contains(' ')) return 'Informe nome e sobrenome.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Informe o e-mail.';
                      if (!t.contains('@')) return 'E-mail inválido.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone / WhatsApp',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o telefone.'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Criar senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Senha mínima de 6 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'As senhas não conferem.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0DAA00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Criar conta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
