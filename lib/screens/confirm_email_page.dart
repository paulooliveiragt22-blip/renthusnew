import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/onboarding_repository.dart';
import 'signup_step1_page.dart'; // SignupRole
import 'signup_step2_unified_page.dart';

class ConfirmEmailPage extends StatefulWidget {
  final String email;
  final String password;
  final SignupRole role;

  const ConfirmEmailPage({
    super.key,
    required this.email,
    required this.password,
    required this.role,
  });

  @override
  State<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends State<ConfirmEmailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _onboardingRepo = OnboardingRepository();

  bool _loadingResend = false;
  bool _loadingConfirm = false;

  Future<void> _resend() async {
    if (_loadingResend) return;
    setState(() => _loadingResend = true);

    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,

        // ✅ DEEP LINK: abre o app ao clicar no e-mail
        emailRedirectTo: 'renthus://auth-callback',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de confirmação reenviado.')),
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erro ao reenviar e-mail: $e');
    } finally {
      if (mounted) setState(() => _loadingResend = false);
    }
  }

  Future<void> _alreadyConfirmed() async {
    if (_loadingConfirm) return;
    setState(() => _loadingConfirm = true);

    try {
      // Login (Auth apenas)
      await _supabase.auth.signInWithPassword(
        email: widget.email,
        password: widget.password,
      );

      // Onboarding (fail-safe): status email_confirmed
      await _onboardingRepo.upsert(
        status: 'email_confirmed',
      );

      if (!mounted) return;

      // Vai para o Step2 unificado (role pré-selecionada)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SignupStep2UnifiedPage(initialRole: widget.role),
        ),
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Não foi possível continuar: $e');
    } finally {
      if (mounted) setState(() => _loadingConfirm = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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
