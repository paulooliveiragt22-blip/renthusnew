// lib/screens/provider_address_step3_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'provider_service_selection_screen.dart';

class ProviderAddressStep3Page extends StatefulWidget {
  const ProviderAddressStep3Page({super.key});

  @override
  State<ProviderAddressStep3Page> createState() =>
      _ProviderAddressStep3PageState();
}

class _ProviderAddressStep3PageState extends State<ProviderAddressStep3Page> {
  final _formKey = GlobalKey<FormState>();

  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  bool _loadingCep = false;
  bool _saving = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _buscarCep() async {
    final rawCep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (rawCep.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CEP inválido. Use 8 dígitos.')),
      );
      return;
    }

    setState(() => _loadingCep = true);

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$rawCep/json/');
      final resp = await http.get(url);

      if (resp.statusCode != 200) {
        throw Exception('Erro ao consultar CEP (${resp.statusCode})');
      }

      final data = jsonDecode(resp.body);
      if (data is Map && data['erro'] == true) {
        throw Exception('CEP não encontrado.');
      }

      setState(() {
        _streetController.text = (data['logradouro'] ?? '').toString();
        _districtController.text = (data['bairro'] ?? '').toString();
        _cityController.text = (data['localidade'] ?? '').toString();
        _stateController.text = (data['uf'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar CEP: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingCep = false);
    }
  }

  Future<void> _salvarEndereco() async {
    if (_saving) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return;
    }

    setState(() => _saving = true);

    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    final street = _streetController.text.trim();
    final number = _numberController.text.trim();
    final complement = _complementController.text.trim();
    final district = _districtController.text.trim();
    final city = _cityController.text.trim();
    final uf = _stateController.text.trim().toUpperCase();

    try {
      // ✅ SEM tabela crua: usa RPC
      await _supabase.rpc('rpc_provider_update_address', params: {
        'p_cep': cep,
        'p_address_street': street,
        'p_address_number': number,
        'p_address_complement': complement.isEmpty ? null : complement,
        'p_address_district': district,
        'p_city': city,
        'p_state': uf,
        'p_mark_onboarding_completed': true,
      });

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ProviderServiceSelectionScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar endereço: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: const Text('Endereço de atendimento'),
      ),
      backgroundColor: const Color(0xFFF2F2F2),
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
                    'Use o endereço principal de atendimento.\n'
                    'Você poderá editar depois na Minha Conta.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
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
                          validator: (value) {
                            final v =
                                (value ?? '').replaceAll(RegExp(r'\D'), '');
                            if (v.length != 8) {
                              return 'Informe um CEP válido com 8 dígitos.';
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'Rua / Logradouro',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _numberController,
                    decoration: const InputDecoration(
                      labelText: 'Número',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _complementController,
                    decoration: const InputDecoration(
                      labelText: 'Complemento (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _districtController,
                    decoration: const InputDecoration(
                      labelText: 'Bairro',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stateController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      labelText: 'UF',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final txt = (v ?? '').trim();
                      if (txt.length != 2) return 'UF com 2 letras.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '2/2',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _salvarEndereco,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0DAA00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Salvar endereço e continuar'),
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
