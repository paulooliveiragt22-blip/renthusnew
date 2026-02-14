import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/auth/auth.dart';
import 'package:renthus/features/client/client.dart';
import 'package:renthus/features/provider/provider.dart';

class RoleSelectionPage extends ConsumerWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const roxo = Color(0xFF3B246B);
    const laranja = Color(0xFFFF6600);
    const roxoClaro = Color(0xFFE8DFFC);
    final supabase = ref.read(supabaseProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bem-vindo ao Renthus',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Como você quer usar o app?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B246B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escolha se você quer contratar serviços ou trabalhar como prestador de serviços.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                _RoleCard(
                  icon: Icons.search,
                  title: 'Quero contratar serviços',
                  description:
                      'Encontre profissionais para limpeza, manutenção, fretes e muito mais.',
                  backgroundColor: roxoClaro,
                  iconColor: roxo,
                  textColor: roxo,
                  onTap: () async {
                    if (supabase.auth.currentUser != null) {
                      try {
                        await supabase.rpc('client_ensure_profile');
                      } catch (e) {
                        debugPrint('client_ensure_profile error: $e');
                      }
                    }
                    if (!context.mounted) return;
                    context.goToClientSignupStep1();
                  },
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.handyman,
                  title: 'Quero ser prestador de serviços',
                  description:
                      'Cadastre-se como prestador para receber pedidos e aumentar seu faturamento.',
                  backgroundColor: laranja,
                  iconColor: Colors.white,
                  textColor: Colors.white,
                  onTap: () async {
                    if (supabase.auth.currentUser != null) {
                      try {
                        await supabase.rpc('provider_ensure_profile');
                      } catch (e) {
                        debugPrint('provider_ensure_profile error: $e');
                      }
                    }
                    if (!context.mounted) return;
                    context.goToProviderSignupStep1();
                  },
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.black12),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => context.goToLogin(),
                    child: const Text(
                      'Já tenho conta? Entrar',
                      style: TextStyle(
                        color: Color(0xFF3B246B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _RoleCard extends StatelessWidget {

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: textColor.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textColor.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
