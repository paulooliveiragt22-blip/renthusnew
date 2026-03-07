import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/widgets/password_confirm_dialog.dart';
import 'package:renthus/features/auth/data/providers/auth_providers.dart';

const _kRoxo = Color(0xFF3B246B);
const _kBanks = <String, String>{
  '001': 'Banco do Brasil',
  '033': 'Santander',
  '104': 'Caixa Econômica',
  '237': 'Bradesco',
  '341': 'Itaú Unibanco',
  '260': 'Nubank',
  '077': 'Banco Inter',
  '336': 'C6 Bank',
  '290': 'PagBank',
  '380': 'PicPay',
  '403': 'Cora',
};

/// Formata CPF para exibição (xxx.xxx.xxx-xx).
String _formatCpf(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 11) return digits;
  return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.'
      '${digits.substring(6, 9)}-${digits.substring(9, 11)}';
}

/// Tela para alterar dados bancários do prestador.
class ProviderBankDataPage extends ConsumerStatefulWidget {
  const ProviderBankDataPage({super.key});

  @override
  ConsumerState<ProviderBankDataPage> createState() =>
      _ProviderBankDataPageState();
}

class _ProviderBankDataPageState extends ConsumerState<ProviderBankDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _holderController = TextEditingController();
  final _agencyController = TextEditingController();
  final _agencyDigitController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountDigitController = TextEditingController();

  Map<String, dynamic>? _bankData;
  bool _loading = true;
  bool _saving = false;
  String? _selectedBank;
  String _accountType = 'checking';
  String? _cpfDisplay;

  @override
  void initState() {
    super.initState();
    _loadBankData();
  }

  @override
  void dispose() {
    _holderController.dispose();
    _agencyController.dispose();
    _agencyDigitController.dispose();
    _accountNumberController.dispose();
    _accountDigitController.dispose();
    super.dispose();
  }

  Future<void> _loadBankData() async {
    final repo = ref.read(providerRepositoryProvider);
    try {
      final data = await repo.getProviderBankData();
      if (!mounted) return;
      setState(() {
        _bankData = data;
        _loading = false;
        _cpfDisplay = _formatCpf(data?['cpf']?.toString());
        _holderController.text = (data?['bank_holder_name'] as String?)?.trim() ?? '';
        _selectedBank = data?['bank_code']?.toString();
        _agencyController.text = (data?['bank_branch_number'] as String?)?.trim() ?? '';
        _agencyDigitController.text =
            (data?['bank_branch_check_digit'] as String?)?.trim() ?? '';
        _accountNumberController.text =
            (data?['bank_account_number'] as String?)?.trim() ?? '';
        _accountDigitController.text =
            (data?['bank_account_check_digit'] as String?)?.trim() ?? '';
        final type = data?['bank_account_type'] as String?;
        _accountType = (type == 'savings') ? 'savings' : 'checking';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final supabase = ref.read(supabaseProvider);
    final confirmed = await showPasswordConfirmDialog(context, supabase);
    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      await supabase.rpc('submit_provider_bank_data', params: {
        'p_bank_code': _selectedBank,
        'p_bank_branch_number': _agencyController.text.trim(),
        'p_bank_branch_check_digit': _agencyDigitController.text.trim(),
        'p_bank_account_number': _accountNumberController.text.trim(),
        'p_bank_account_check_digit': _accountDigitController.text.trim(),
        'p_bank_account_type': _accountType,
        'p_bank_holder_name': _holderController.text.trim(),
      });

      final recipientId = _bankData?['pagarme_recipient_id'] as String?;
      final providerId = _bankData?['id']?.toString();

      // c) Se tem recipient, atualizar no Pagar.me
      if (recipientId != null &&
          recipientId.isNotEmpty &&
          providerId != null &&
          providerId.isNotEmpty) {
        await supabase.functions.invoke(
          'update-pagarme-bank-account',
          body: {'provider_id': providerId},
        );
        // Ignoramos erro 403/network da Edge; o banco já foi atualizado
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados bancários atualizados com sucesso!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dados bancários'),
          backgroundColor: _kRoxo,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados bancários'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // CPF somente leitura
              TextFormField(
                initialValue: _cpfDisplay,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'CPF',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.lock_outline, color: _kRoxo),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'O CPF não pode ser alterado pois está vinculado ao seu cadastro financeiro.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _holderController,
                decoration: const InputDecoration(
                  labelText: 'Titular da conta',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: _kBanks.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text('${e.key} – ${e.value}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedBank = v),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Selecione o banco' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _agencyController,
                      decoration: const InputDecoration(
                        labelText: 'Agência',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      validator: (v) => (v == null || v.length < 4)
                          ? 'Mínimo 4 dígitos'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _agencyDigitController,
                      decoration: const InputDecoration(
                        labelText: 'Dígito agência',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Conta',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo obrigatório'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _accountDigitController,
                      decoration: const InputDecoration(
                        labelText: 'Dígito conta',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Corrente'),
                    selected: _accountType == 'checking',
                    selectedColor: _kRoxo.withOpacity(0.15),
                    onSelected: (_) =>
                        setState(() => _accountType = 'checking'),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('Poupança'),
                    selected: _accountType == 'savings',
                    selectedColor: _kRoxo.withOpacity(0.15),
                    onSelected: (_) =>
                        setState(() => _accountType = 'savings'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRoxo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Salvar alterações',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
