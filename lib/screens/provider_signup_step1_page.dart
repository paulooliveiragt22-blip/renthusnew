import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/screens/provider_phone_verification_page.dart';
import 'package:renthus/screens/login_screen.dart';

class ProviderSignUpStep1Page extends ConsumerStatefulWidget {
  const ProviderSignUpStep1Page({super.key});

  @override
  ConsumerState<ProviderSignUpStep1Page> createState() =>
      _ProviderSignUpStep1PageState();
}

class _ProviderSignUpStep1PageState extends ConsumerState<ProviderSignUpStep1Page> {

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    setState(() => _loading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      // 1) Criar usuário no Supabase Auth (com metadata)
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
        },
      );

      final user = response.user ?? supabase.auth.currentUser;
      if (user == null) {
        throw Exception(
          'Não foi possível criar sua conta. Verifique se o e-mail precisa de confirmação e tente novamente.',
        );
      }

      // 2) Garantir registro em CLIENTS via RPC (SEM tabela crua no app)
      // Crie no banco: rpc_client_ensure_me(p_full_name text, p_phone text)
      await supabase.rpc('rpc_client_ensure_me', params: {
        'p_full_name': fullName,
        'p_phone': phone,
      },);

      // 3) Garantir registro em PROVIDERS via RPC (SEM tabela crua no app)
      // Crie no banco: rpc_provider_ensure_me(p_full_name text, p_phone text)
      await supabase.rpc('rpc_provider_ensure_me', params: {
        'p_full_name': fullName,
        'p_phone': phone,
      },);

      if (!mounted) return;

      // 4) Próxima etapa: verificação de telefone
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProviderPhoneVerificationPage(phone: phone),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar conta: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe seu e-mail.';
    if (!text.contains('@') || !text.contains('.')) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe seu telefone/WhatsApp.';
    if (text.replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Informe um telefone válido com DDD.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Crie uma senha.';
    if (text.length < 6) return 'A senha deve ter pelo menos 6 caracteres.';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Confirme a senha.';
    if (text != _passwordController.text) return 'As senhas não conferem.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta de Prestador'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
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
                  const Text(
                    'Bem-vindo ao Renthus Service',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B246B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Informe seus dados para começar a atender serviços.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Informe seu nome completo.';
                      if (text.split(' ').length < 2) {
                        return 'Informe nome e sobrenome.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone / WhatsApp',
                      hintText: '(66) 9 9999-9999',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Criar senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,),
                      ),
                    ),
                    validator: _validateConfirmPassword,
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
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
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
                  const SizedBox(height: 12),
                  const Text(
                    'Na próxima etapa, vamos confirmar seu telefone e depois completar seu endereço.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen(),),
                        );
                      },
                      child: const Text('Já tem conta? Entrar'),
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
