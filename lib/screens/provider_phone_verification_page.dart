import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'provider_address_step3_page.dart';

class ProviderPhoneVerificationPage extends ConsumerStatefulWidget {
  final String phone;

  const ProviderPhoneVerificationPage({
    super.key,
    required this.phone,
  });

  @override
  ConsumerState<ProviderPhoneVerificationPage> createState() =>
      _ProviderPhoneVerificationPageState();
}

class _ProviderPhoneVerificationPageState
    extends ConsumerState<ProviderPhoneVerificationPage> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirmCode() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Usuário não autenticado.");
      }

      // MVP: não valida SMS de verdade
      // ✅ Só marca como verificado via RPC (sem tabela crua no app)
      await supabase.rpc('rpc_provider_mark_phone_verified');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ProviderAddressStep3Page(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao confirmar código: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar telefone'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviamos um código (simulação) para:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No MVP, não vamos validar SMS de verdade.\n'
                  'Você pode digitar qualquer código para continuar.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Código recebido',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _confirmCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Confirmar código e continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
