import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_gate_page.dart';

class ProviderConfirmEmailPage extends StatefulWidget {
  final String email;
  final String password;
  final String fullName;
  final String phone;

  const ProviderConfirmEmailPage({
    super.key,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  @override
  State<ProviderConfirmEmailPage> createState() =>
      _ProviderConfirmEmailPageState();
}

class _ProviderConfirmEmailPageState extends State<ProviderConfirmEmailPage> {
  final _supabase = Supabase.instance.client;

  bool _loadingResend = false;
  bool _loadingConfirm = false;

  Future<void> _resend() async {
    if (_loadingResend) return;
    setState(() => _loadingResend = true);

    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de confirmação reenviado.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reenviar e-mail: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingResend = false);
    }
  }

  Future<void> _alreadyConfirmed() async {
    if (_loadingConfirm) return;
    setState(() => _loadingConfirm = true);

    try {
      // 1) Login (depois de confirmar e-mail)
      await _supabase.auth.signInWithPassword(
        email: widget.email,
        password: widget.password,
      );

      // ✅ Garante sessão antes de qualquer RPC baseada em auth.uid()
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('Sessão não foi estabelecida. Tente novamente.');
      }
      debugPrint(
          'PROVIDER confirm session=${_supabase.auth.currentSession != null} uid=${_supabase.auth.currentUser?.id}');

      // 2) Define role + garante provider/profile (idempotente)
      // Use sua RPC oficial (pelo seu RoleSelection: provider_ensure_profile)
      await _supabase.rpc('provider_ensure_profile');

      if (!mounted) return;

      // 3) Volta pro Gate decidir o próximo passo
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGatePage()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível continuar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingConfirm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: const Text('Confirmar e-mail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Confirme seu e-mail para continuar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: roxo,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviamos um link de confirmação para:\n${widget.email}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loadingResend ? null : _resend,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: roxo,
                      side: const BorderSide(color: roxo),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    child: _loadingResend
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reenviar e-mail'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadingConfirm ? null : _alreadyConfirmed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0DAA00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    child: _loadingConfirm
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Já confirmei'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Se não encontrar o e-mail, verifique o spam ou aguarde alguns minutos.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
