import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/features/auth/data/providers/auth_providers.dart';

const _kRoxo = Color(0xFF3B246B);

String _formatCpfView(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 11) return digits;
  return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.'
      '${digits.substring(6, 9)}-${digits.substring(9, 11)}';
}

class ProviderBankDataViewPage extends ConsumerStatefulWidget {
  const ProviderBankDataViewPage({super.key});

  @override
  ConsumerState<ProviderBankDataViewPage> createState() =>
      _ProviderBankDataViewPageState();
}

class _ProviderBankDataViewPageState
    extends ConsumerState<ProviderBankDataViewPage> {
  Map<String, dynamic>? _bankData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(providerRepositoryProvider);
      final data = await repo.getProviderBankData();
      if (!mounted) return;
      setState(() {
        _bankData = data ?? {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
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

    final data = _bankData ?? {};
    final cpf = _formatCpfView(data['cpf']?.toString());
    final holder = (data['bank_holder_name'] as String?) ?? '';
    final bankCode = (data['bank_code']?.toString() ?? '');
    final agency = (data['bank_branch_number'] as String?) ?? '';
    final agencyDigit = (data['bank_branch_check_digit'] as String?) ?? '';
    final account = (data['bank_account_number'] as String?) ?? '';
    final accountDigit = (data['bank_account_check_digit'] as String?) ?? '';
    final accountType = (data['bank_account_type'] as String?) ?? '';

    String _accountTypeLabel(String raw) {
      switch (raw) {
        case 'savings':
          return 'Poupança';
        case 'checking':
        default:
          return 'Conta corrente';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados bancários'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Titularidade',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kRoxo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabelValue(label: 'CPF', value: cpf),
                  const SizedBox(height: 8),
                  _LabelValue(label: 'Titular da conta', value: holder),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conta bancária',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kRoxo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabelValue(label: 'Banco', value: bankCode),
                  const SizedBox(height: 8),
                  _LabelValue(
                    label: 'Agência',
                    value: agencyDigit.isNotEmpty
                        ? '$agency-$agencyDigit'
                        : agency,
                  ),
                  const SizedBox(height: 8),
                  _LabelValue(
                    label: 'Conta',
                    value: accountDigit.isNotEmpty
                        ? '$account-$accountDigit'
                        : account,
                  ),
                  const SizedBox(height: 8),
                  _LabelValue(
                    label: 'Tipo de conta',
                    value: _accountTypeLabel(accountType),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final changed =
                      await router.push<bool>(AppRoutes.providerBankDataEdit);
                  if (!mounted) return;
                  if (changed == true) {
                    await _load();
                    Navigator.of(context).pop(true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRoxo,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar dados bancários'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

