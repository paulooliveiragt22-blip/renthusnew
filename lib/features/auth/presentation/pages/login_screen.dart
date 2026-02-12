import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/features/auth/data/providers/auth_providers.dart';
import 'package:renthus/features/auth/domain/models/login_destination.dart';
import 'package:renthus/screens/admin/admin_home_page.dart';
import 'package:renthus/screens/client_main_page.dart';
import 'package:renthus/screens/provider_main_page.dart';
import 'package:renthus/screens/role_selection_page.dart';

/// Tela de login migrada para Riverpod.
///
/// Usa authActionsProvider para login e AsyncValue para loading/error.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    await ref.read(authActionsProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF3B246B);

    // Listen para navegação após login bem-sucedido
    ref.listen(authActionsProvider, (previous, next) {
      next.whenOrNull(
        data: (destination) {
          if (destination == null || !context.mounted) return;

          ref.read(authActionsProvider.notifier).reset();

          switch (destination) {
            case LoginDestination.admin:
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AdminHomePage()),
                (route) => false,
              );
              break;
            case LoginDestination.provider:
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ProviderMainPage()),
                (route) => false,
              );
              break;
            case LoginDestination.client:
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ClientMainPage()),
                (route) => false,
              );
              break;
          }
        },
        error: (error, _) {
          if (!context.mounted) return;
          final message = error is AuthException
              ? error.message
              : 'Erro ao entrar: $error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      );
    });

    final loginAsync = ref.watch(authActionsProvider);
    final isLoading = loginAsync.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        title: const Text('Entrar'),
        elevation: 0,
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
                  const SizedBox(height: 16),
                  const Text(
                    'Bem-vindo de volta',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B246B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Acesse sua conta para acompanhar seus pedidos.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Informe seu e-mail.';
                      if (!text.contains('@') || !text.contains('.')) {
                        return 'E-mail inválido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.isEmpty) return 'Informe sua senha.';
                      return null;
                    },
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0DAA00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Entrar'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoleSelectionPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Ainda não tem conta? Criar conta',
                        style: TextStyle(
                          color: Color(0xFF3B246B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
