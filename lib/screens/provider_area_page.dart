import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';


class ProviderAreaPage extends ConsumerWidget {
  const ProviderAreaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(providerMeFullProvider);
    final user = ref.watch(supabaseProvider).auth.currentUser;

    return meAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Área do Prestador'),
          backgroundColor: const Color(0xFF3B246B),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(ErrorHandler.friendlyErrorMessage(e)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(providerMeFullProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      data: (me) {
        final email = user?.email ?? '';
        final hasProvider = me != null && me['provider_id'] != null;
        final onboardingCompleted =
            (me?['onboarding_completed'] as bool?) ?? false;

        if (!hasProvider) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Área do Prestador'),
              backgroundColor: const Color(0xFF3B246B),
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Seu cadastro de prestador ainda não foi encontrado.\n'
                  'Volte e finalize o cadastro como Prestador.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (hasProvider && onboardingCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.goToProviderHome();
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Área do Prestador'),
            backgroundColor: const Color(0xFF3B246B),
            foregroundColor: Colors.white,
          ),
          backgroundColor: const Color(0xFFF7ECFF),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Área do Prestador',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Olá, $email ',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('👋', style: TextStyle(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aqui você configura os serviços que presta.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await context.pushProviderServiceSelection();
                      ref.invalidate(providerMeFullProvider);
                    },
                    icon: const Icon(Icons.build),
                    label: const Text('Configurar serviços'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3B246B),
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Depois de configurar, você entra no painel do prestador.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
