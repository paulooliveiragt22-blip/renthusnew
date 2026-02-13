import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:renthus/core/providers/supabase_provider.dart';
import 'client_main_page.dart';

class ClientSignUpStep2Page extends ConsumerStatefulWidget {
  const ClientSignUpStep2Page({super.key});

  @override
  ConsumerState<ClientSignUpStep2Page> createState() => _ClientSignUpStep2PageState();
}

class _ClientSignUpStep2PageState extends ConsumerState<ClientSignUpStep2Page> {

  final _formKey = GlobalKey<FormState>();

  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  bool _loading = false;
  bool _loadingCep = false;

  @override
  void dispose() {
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _buscarCep() async {
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;

    setState(() => _loadingCep = true);

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['erro'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CEP não encontrado.')),
          );
        } else {
          _streetController.text = (data['logradouro'] ?? '').toString();
          _districtController.text = (data['bairro'] ?? '').toString();
          _cityController.text = (data['localidade'] ?? '').toString();
          _stateController.text = (data['uf'] ?? '').toString();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao buscar CEP.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao buscar CEP.')),
      );
    } finally {
      if (mounted) setState(() => _loadingCep = false);
    }
  }

  Future<void> _finish() async {
    if (_loading) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      await supabase.from('clients').update({
        'address_zip_code': _cepController.text.trim(),
        'address_street': _streetController.text.trim(),
        'address_number': _numberController.text.trim(),
        'address_district': _districtController.text.trim(),
        'city': _cityController.text.trim(), // usa coluna city existente
        'address_state': _stateController.text.trim(),
      }).eq('id', user.id);

      if (!mounted) return;

      // 👉 Depois de salvar endereço, vai pra tela principal do cliente (com bottom nav)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ClientMainPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar endereço: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: const Text('Seu endereço'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Informe seu endereço',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: roxo,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // CEP
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cepController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'CEP',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            final onlyDigits =
                                value.replaceAll(RegExp(r'\D'), '');
                            if (onlyDigits.length == 8) {
                              _buscarCep();
                            }
                          },
                          validator: (v) {
                            final text =
                                v?.replaceAll(RegExp(r'\D'), '') ?? '';
                            if (text.length != 8) {
                              return 'Informe um CEP válido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loadingCep ? null : _buscarCep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: roxo,
                            foregroundColor: Colors.white,
                          ),
                          child: _loadingCep
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
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
                  const SizedBox(height: 12),

                  // Rua
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'Rua / Avenida',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Informe a rua' : null,
                  ),
                  const SizedBox(height: 12),

                  // Número
                  TextFormField(
                    controller: _numberController,
                    decoration: const InputDecoration(
                      labelText: 'Número',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Informe o número' : null,
                  ),
                  const SizedBox(height: 12),

                  // Bairro
                  TextFormField(
                    controller: _districtController,
                    decoration: const InputDecoration(
                      labelText: 'Bairro',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Informe o bairro' : null,
                  ),
                  const SizedBox(height: 12),

                  // Cidade
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Informe a cidade' : null,
                  ),
                  const SizedBox(height: 12),

                  // Estado
                  TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'Estado (UF)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Informe o estado' : null,
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _finish,
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
                          : const Text('Finalizar cadastro'),
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
