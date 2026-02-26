import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kRoxo = Color(0xFF3B246B);

/// Dialog reutilizável que pede a senha atual do usuário.
/// Retorna `true` se a senha foi confirmada, `false`/`null` se cancelou.
///
/// Uso:
/// ```dart
/// final confirmed = await showPasswordConfirmDialog(context, supabase);
/// if (confirmed != true) return;
/// // prosseguir com a ação sensível
/// ```
Future<bool?> showPasswordConfirmDialog(
  BuildContext context,
  SupabaseClient supabase,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PasswordConfirmDialog(supabase: supabase),
  );
}

class _PasswordConfirmDialog extends StatefulWidget {
  const _PasswordConfirmDialog({required this.supabase});
  final SupabaseClient supabase;

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final password = _controller.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Digite sua senha');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = widget.supabase.auth.currentUser?.email;
      if (email == null) {
        setState(() {
          _error = 'Sessão expirada. Faça login novamente.';
          _loading = false;
        });
        return;
      }

      await widget.supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        final msg = e.message.toLowerCase();
        _error = (msg.contains('invalid') ||
                msg.contains('wrong') ||
                msg.contains('credentials'))
            ? 'Senha incorreta. Tente novamente.'
            : 'Erro ao verificar senha. Tente novamente.';
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Erro ao verificar. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: _kRoxo, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Confirme sua identidade',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Para sua segurança, digite sua senha atual para continuar.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Senha atual',
              labelStyle: const TextStyle(fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: Colors.black45,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: _kRoxo),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}
