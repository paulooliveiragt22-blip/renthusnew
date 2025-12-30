import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_gate_page.dart';

class ClientSignUpStep2Page extends StatefulWidget {
  const ClientSignUpStep2Page({super.key});

  @override
  State<ClientSignUpStep2Page> createState() => _ClientSignUpStep2PageState();
}

class _ClientSignUpStep2PageState extends State<ClientSignUpStep2Page> {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  // ---------------- CEP ----------------

  Future<void> _buscarCep() async {
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;

    setState(() => _loadingCep = true);

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar CEP');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['erro'] == true) {
        throw Exception('CEP não encontrado');
      }

      _streetController.text = (data['logradouro'] ?? '').toString();
      _districtController.text = (data['bairro'] ?? '').toString();
      _cityController.text = (data['localidade'] ?? '').toString();
      _stateController.text = (data['uf'] ?? '').toString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar CEP: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingCep = false);
    }
  }

  // ---------------- FINALIZAR ----------------

  Future<void> _finish() async {
    if (_loading) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _supabase.rpc(
        'rpc_client_step2',
        params: {
          'p_city': _cityController.text.trim(),
          'p_address_zip_code': _cepController.text.trim(),
          'p_address_street': _streetController.text.trim(),
          'p_address_number': _numberController.text.trim(),
          'p_address_district': _districtController.text.trim(),
          'p_address_state': _stateController.text.trim(),
        },
      );

      if (!mounted) return;

      // ✅ Volta para o Gate (única fonte de navegação)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGatePage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao finalizar cadastro: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: const Text('Endereço'),
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
                            final digits = value.replaceAll(RegExp(r'\D'), '');
                            if (digits.length == 8) _buscarCep();
                          },
                          validator: (v) {
                            final text = v?.replaceAll(RegExp(r'\D'), '') ?? '';
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

                  _field(_streetController, 'Rua / Avenida'),
                  _field(_numberController, 'Número'),
                  _field(_districtController, 'Bairro'),
                  _field(_cityController, 'Cidade'),
                  _field(_stateController, 'Estado (UF)', maxLength: 2),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0DAA00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
      ),
    );
  }
}
