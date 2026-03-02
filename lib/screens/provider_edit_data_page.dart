import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/widgets/password_confirm_dialog.dart';
import 'package:renthus/features/auth/data/providers/auth_providers.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';

const _kRoxo = Color(0xFF3B246B);

class ProviderEditDataPage extends ConsumerStatefulWidget {
  const ProviderEditDataPage({super.key});

  @override
  ConsumerState<ProviderEditDataPage> createState() =>
      _ProviderEditDataPageState();
}

class _ProviderEditDataPageState extends ConsumerState<ProviderEditDataPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _currentEmailCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  final _confirmEmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _searchingCep = false;
  String _currentEmail = '';
  String _originalPhone = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _cpfCtrl.dispose();
    _currentEmailCtrl.dispose();
    _newEmailCtrl.dispose();
    _confirmEmailCtrl.dispose();
    _phoneCtrl.dispose();
    _cepCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _districtCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _complementCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final res = await supabase
          .from('providers')
          .select(
            'full_name, cpf, phone, '
            'address_cep, address_street, address_number, '
            'address_district, address_city, address_state, address_complement',
          )
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      _currentEmail = user.email ?? '';
      _currentEmailCtrl.text = _currentEmail;
      _fullNameCtrl.text = (res?['full_name'] ?? '').toString();
      _cpfCtrl.text = (res?['cpf'] ?? '').toString();
      _originalPhone = (res?['phone'] ?? '').toString().trim();
      _phoneCtrl.text = _originalPhone;
      _cepCtrl.text = (res?['address_cep'] ?? '').toString();
      _streetCtrl.text = (res?['address_street'] ?? '').toString();
      _numberCtrl.text = (res?['address_number'] ?? '').toString();
      _districtCtrl.text = (res?['address_district'] ?? '').toString();
      _cityCtrl.text = (res?['address_city'] ?? '').toString();
      _stateCtrl.text = (res?['address_state'] ?? '').toString();
      _complementCtrl.text = (res?['address_complement'] ?? '').toString();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    }
  }

  bool _isEmailValid(String value) {
    final v = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  Future<void> _searchCep() async {
    if (_searchingCep) return;
    final cep = _cepCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cep.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um CEP válido (8 dígitos).')),
      );
      return;
    }

    setState(() => _searchingCep = true);
    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();
      final body = await response.transform(const Utf8Decoder()).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['erro'] == true) {
        throw Exception('CEP não encontrado');
      }

      if (!mounted) return;
      setState(() {
        _streetCtrl.text = (data['logradouro'] ?? '').toString();
        _districtCtrl.text = (data['bairro'] ?? '').toString();
        _cityCtrl.text = (data['localidade'] ?? '').toString();
        _stateCtrl.text = (data['uf'] ?? '').toString();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao buscar CEP. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _searchingCep = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    final newPhone = _phoneCtrl.text.trim();
    if (newPhone != _originalPhone) {
      final supabase = ref.read(supabaseProvider);
      final confirmed = await showPasswordConfirmDialog(context, supabase);
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      final providerRepo = ref.read(providerRepositoryProvider);

      await providerRepo.updateMe(
        phone: newPhone,
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        cep: _cepCtrl.text.trim(),
        addressStreet: _streetCtrl.text.trim(),
        addressNumber: _numberCtrl.text.trim(),
        addressDistrict: _districtCtrl.text.trim(),
        addressComplement: _complementCtrl.text.trim(),
      );

      ref.invalidate(providerMeForAccountProvider);
      ref.invalidate(providerMeFullProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados atualizados com sucesso.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar dados'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Dados não editáveis',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kRoxo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameCtrl,
                      readOnly: true,
                      style: const TextStyle(color: Colors.black54),
                      decoration: InputDecoration(
                        labelText: 'Nome completo',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Tooltip(
                          message: 'Para alterar seu nome, entre em contato com o suporte.',
                          child: Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Para alterar seu nome, entre em contato com o suporte Renthus.',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _cpfCtrl,
                      readOnly: true,
                      style: const TextStyle(color: Colors.black54),
                      decoration: InputDecoration(
                        labelText: 'CPF/CNPJ',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Tooltip(
                          message: 'O CPF está vinculado ao seu cadastro financeiro e não pode ser alterado.',
                          child: Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'O CPF está vinculado ao seu cadastro financeiro e não pode ser alterado.',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Contato',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kRoxo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _readonlyField(
                            label: 'E-mail atual',
                            controller: _currentEmailCtrl,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _showChangeEmailDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kRoxo,
                            ),
                            child: const Text('Alterar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('Celular'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Endereço',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kRoxo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cepCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('CEP'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _searchingCep ? null : _searchCep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kRoxo,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            child: _searchingCep
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Buscar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _streetCtrl,
                      decoration: _inputDecoration('Rua'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _numberCtrl,
                            decoration: _inputDecoration('Número'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _districtCtrl,
                            decoration: _inputDecoration('Bairro'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityCtrl,
                            decoration: _inputDecoration('Cidade'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            controller: _stateCtrl,
                            decoration: _inputDecoration('UF'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _complementCtrl,
                      decoration: _inputDecoration('Complemento (opcional)'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kRoxo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Salvar alterações'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _showChangeEmailDialog() async {
    if (_currentEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível identificar seu e-mail atual.'),
        ),
      );
      return;
    }

    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate() || saving) return;

              final newEmail = newEmailController.text.trim();
              final password = passwordController.text;

              setState(() => saving = true);
              try {
                final supabase = ref.read(supabaseProvider);

                // a) Verificar senha atual
                await supabase.auth.signInWithPassword(
                  email: _currentEmail,
                  password: password,
                );

                // b) Solicitar alteração de e-mail no auth
                await supabase.auth
                    .updateUser(UserAttributes(email: newEmail));

                if (!mounted) return;

                Navigator.of(dialogContext).pop();

                setState(() {
                  _currentEmail = newEmail;
                  _currentEmailCtrl.text = newEmail;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enviamos um e-mail de confirmação para $newEmail. '
                      'Clique no link para concluir a alteração.',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                final message = e is AuthException
                    ? 'Senha incorreta. Tente novamente.'
                    : ErrorHandler.friendlyErrorMessage(e);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              } finally {
                if (mounted) {
                  setState(() => saving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Alterar e-mail'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Novo e-mail',
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Informe o novo e-mail.';
                        if (!_isEmailValid(v)) return 'Novo e-mail inválido.';
                        if (v == _currentEmail) {
                          return 'Informe um e-mail diferente do atual.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha atual',
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Informe sua senha atual.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRoxo,
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar alteração'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _readonlyField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      enabled: false,
      decoration: _inputDecoration(label),
    );
  }
}
