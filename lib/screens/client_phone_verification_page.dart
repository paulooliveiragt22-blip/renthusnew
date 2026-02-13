import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/screens/client_signup_step2_page.dart';

class ClientPhoneVerificationPage extends ConsumerStatefulWidget {

  const ClientPhoneVerificationPage({
    super.key,
    required this.phone,
  });
  final String phone;

  @override
  ConsumerState<ClientPhoneVerificationPage> createState() =>
      _ClientPhoneVerificationPageState();
}

class _ClientPhoneVerificationPageState
    extends ConsumerState<ClientPhoneVerificationPage> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_loading) return;

    // 🔐 Aqui depois você pluga a lógica real de verificação via SMS (Twilio/Supabase)
    // Por enquanto, só simula sucesso e vai para o endereço.

    setState(() => _loading = true);

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ClientSignUpStep2Page(),
      ),
    );

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: const Text('Verificar celular'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Confirme seu número',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: roxo,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enviamos um código por SMS/WhatsApp para:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: roxo,
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Código de verificação',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyCode,
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
                        : const Text('Confirmar código'),
                  ),
                ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    // TODO: reenviar código (Twilio) depois
                  },
                  child: const Text('Não recebeu o código? Reenviar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
