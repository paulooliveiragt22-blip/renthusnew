import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/utils/brazilian_validators.dart';

class ClientSignUpStep1Page extends ConsumerStatefulWidget {
  const ClientSignUpStep1Page({super.key});

  @override
  ConsumerState<ClientSignUpStep1Page> createState() => _ClientSignUpStep1PageState();
}

class _ClientSignUpStep1PageState extends ConsumerState<ClientSignUpStep1Page> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
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
    _cpfController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final form = _formKey.currentState;
    if (form == null) return;

    if (!form.validate()) {
      return;
    }

    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final cpf = _cpfController.text.replaceAll(RegExp(r'\D'), '');
    final password = _passwordController.text;

    setState(() {
      _loading = true;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      // 1) Criar usuário no Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user ?? supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Não foi possível criar sua conta. Tente novamente em instantes.',
        );
      }

      // 2) Criar/atualizar registro na tabela clients via RPC (SECURITY DEFINER)
      // Passa p_user_id explicitamente pois auth.uid() pode ser null logo após
      // signUp quando email confirmation está habilitado no Supabase (sem sessão).
      await supabase.rpc('rpc_client_ensure_me', params: {
        'p_full_name': fullName,
        'p_phone': phone,
        'p_user_id': user.id,
        'p_cpf': cpf,
      });

      if (!mounted) return;

      // 3) Aguardar confirmação de e-mail antes de prosseguir
      context.pushEmailConfirmation(email, AppRoutes.clientSignupStep2, password);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e, st) {
      debugPrint('❌ [ClientSignUp] Erro ao criar conta: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar conta: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
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
        title: const Text('Criar conta de Cliente'),
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
                    'Informe seus dados para contratar serviços com segurança.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  // Nome completo
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Informe seu nome completo.';
                      }
                      if (text.split(' ').length < 2) {
                        return 'Informe nome e sobrenome.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // E-mail
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

                  // Telefone
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

                  // CPF
                  TextFormField(
                    controller: _cpfController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CpfInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CPF',
                      hintText: '000.000.000-00',
                      border: OutlineInputBorder(),
                      helperText: 'Necessário para pagamentos via PIX',
                    ),
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                      if (digits.isEmpty) return 'Informe seu CPF.';
                      if (!BrazilianValidators.isValidCPF(digits)) {
                        return 'CPF inválido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Senha
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Criar senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 12),

                  // Confirmar senha
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword =
                                !_obscureConfirmPassword;
                          });
                        },
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
                    'Você poderá ver, criar e acompanhar seus pedidos direto pelo app.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.goToLogin(),
                      child: const Text('Já tenho conta? Entrar'),
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

/// Formata CPF automaticamente: 000.000.000-00
class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
