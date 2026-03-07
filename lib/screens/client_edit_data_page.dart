import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/features/auth/data/providers/auth_providers.dart';

const _kRoxo = Color(0xFF3B246B);

class ClientEditDataPage extends ConsumerStatefulWidget {
  const ClientEditDataPage({super.key});

  @override
  ConsumerState<ClientEditDataPage> createState() => _ClientEditDataPageState();
}

class _ClientEditDataPageState extends ConsumerState<ClientEditDataPage> {
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

  bool _loading = true;
  bool _saving = false;
  bool _searchingCep = false;
  bool _cpfAlreadySet = false; // CPF é imutável após o primeiro set
  String _currentEmail = '';

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

      final row = await supabase
          .from('clients')
          .select(
            'full_name, cpf, phone, address_zip_code, address_street, '
            'address_number, address_district, city, address_state',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      _currentEmail = user.email ?? '';
      _currentEmailCtrl.text = _currentEmail;
      _fullNameCtrl.text = (row?['full_name'] ?? '').toString();
      final cpfVal = (row?['cpf'] ?? '').toString();
      _cpfCtrl.text = cpfVal;
      _cpfAlreadySet = cpfVal.isNotEmpty;
      _phoneCtrl.text = (row?['phone'] ?? '').toString();
      _cepCtrl.text = (row?['address_zip_code'] ?? '').toString();
      _streetCtrl.text = (row?['address_street'] ?? '').toString();
      _numberCtrl.text = (row?['address_number'] ?? '').toString();
      _districtCtrl.text = (row?['address_district'] ?? '').toString();
      _cityCtrl.text = (row?['city'] ?? '').toString();
      _stateCtrl.text = (row?['address_state'] ?? '').toString();
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

    setState(() => _saving = true);
    try {
      final repo = ref.read(clientRepositoryProvider);

      // Salvar CPF se ainda não estava cadastrado
      if (!_cpfAlreadySet) {
        final cpfDigits = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
        if (cpfDigits.isNotEmpty) {
          await repo.setCpf(cpfDigits);
        }
      }

      await repo.updateMe(
        city: _cityCtrl.text.trim(),
        addressZipCode: _cepCtrl.text.trim(),
        addressStreet: _streetCtrl.text.trim(),
        addressNumber: _numberCtrl.text.trim(),
        addressDistrict: _districtCtrl.text.trim(),
        addressState: _stateCtrl.text.trim(),
      );

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
                    _fieldBox(
                      child: TextFormField(
                        controller: _fullNameCtrl,
                        readOnly: true,
                        style: const TextStyle(color: Colors.black54),
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          suffixIcon: Tooltip(
                            message:
                                'Para alterar seu nome, entre em contato com o suporte.',
                            child: Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: Colors.black38,
                            ),
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
                    _fieldBox(
                      child: _cpfAlreadySet
                          ? _readonlyField(
                              label: 'CPF',
                              controller: _cpfCtrl,
                            )
                          : TextFormField(
                              controller: _cpfCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _CpfEditFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'CPF',
                                hintText: '000.000.000-00',
                                border: InputBorder.none,
                                helperText: 'Necessário para pagamentos via PIX',
                              ),
                              validator: (v) {
                                final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                if (d.isEmpty) return null; // opcional na edição
                                if (d.length != 11) return 'CPF inválido.';
                                return null;
                              },
                            ),
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
                          child: _fieldBox(
                            child: _readonlyField(
                              label: 'E-mail atual',
                              controller: _currentEmailCtrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _showChangeEmailDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kRoxo,
                              side: BorderSide(color: Colors.grey.shade300),
                              backgroundColor: Colors.white,
                            ),
                            child: const Text('Alterar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _fieldBox(
                            child: _readonlyField(
                              label: 'Celular',
                              controller: _phoneCtrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _showChangePhoneDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kRoxo,
                              side: BorderSide(color: Colors.grey.shade300),
                              backgroundColor: Colors.white,
                            ),
                            child: const Text('Alterar'),
                          ),
                        ),
                      ],
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
                          child: _fieldBox(
                            child: TextFormField(
                              controller: _cepCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('CEP'),
                            ),
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
                    _fieldBox(
                      child: TextFormField(
                        controller: _streetCtrl,
                        decoration: _inputDecoration('Rua'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _fieldBox(
                            child: TextFormField(
                              controller: _numberCtrl,
                              decoration: _inputDecoration('Número'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _fieldBox(
                            child: TextFormField(
                              controller: _districtCtrl,
                              decoration: _inputDecoration('Bairro'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _fieldBox(
                            child: TextFormField(
                              controller: _cityCtrl,
                              decoration: _inputDecoration('Cidade'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 90,
                          child: _fieldBox(
                            child: TextFormField(
                              controller: _stateCtrl,
                              decoration: _inputDecoration('UF'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kRoxo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Salvar alterações'),
                        ),
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
      filled: true,
      fillColor: Colors.white,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  /// Retângulo branco sem borda com sombra cinza (estilo client_profile).
  Widget _fieldBox({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
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

  Future<void> _showChangePhoneDialog() async {
    final newPhoneController = TextEditingController(text: _phoneCtrl.text);
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

              final newPhone = newPhoneController.text.trim();
              final password = passwordController.text;

              setState(() => saving = true);
              try {
                final supabase = ref.read(supabaseProvider);

                await supabase.auth.signInWithPassword(
                  email: _currentEmail,
                  password: password,
                );

                await supabase.rpc(
                  'update_client_phone',
                  params: {'p_new_phone': newPhone},
                );

                if (!mounted) return;

                Navigator.of(dialogContext).pop();
                _phoneCtrl.text = newPhone;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Telefone atualizado com sucesso.'),
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
              title: const Text('Alterar celular'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: newPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Novo celular (DDD + número)',
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Informe o novo celular.';
                        if (v.length < 10) return 'Celular inválido.';
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
      style: const TextStyle(color: Colors.black54),
      decoration: _inputDecoration(label),
    );
  }
}

class _CpfEditFormatter extends TextInputFormatter {
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
