import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';

import 'package:renthus/screens/provider_main_page.dart';
import 'package:renthus/screens/provider_service_selection_screen.dart';

class ProviderAreaPage extends ConsumerStatefulWidget {
  const ProviderAreaPage({super.key});

  @override
  ConsumerState<ProviderAreaPage> createState() => _ProviderAreaPageState();
}

class _ProviderAreaPageState extends ConsumerState<ProviderAreaPage> {

  bool _checking = true;
  String _email = '';

  bool _hasProvider = false;
  // ignore: unused_field - usado para lógica de navegação em _checkProviderStatus
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkProviderStatus();
  }

  Future<void> _checkProviderStatus() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _email = '';
        _hasProvider = false;
        _onboardingCompleted = false;
      });
      return;
    }

    _email = user.email ?? '';

    try {
      // ✅ SOMENTE VIEW
      final me = await supabase
          .from('v_provider_me')
          .select('provider_id, onboarding_completed')
          .maybeSingle();

      final hasProvider = me != null && me['provider_id'] != null;
      final onboardingCompleted =
          (me?['onboarding_completed'] as bool?) ?? false;

      if (!mounted) return;

      setState(() {
        _hasProvider = hasProvider;
        _onboardingCompleted = onboardingCompleted;
        _checking = false;
      });

      if (hasProvider && onboardingCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _goToMain();
        });
      }
    } catch (e) {
      debugPrint('Erro _checkProviderStatus (view): $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _hasProvider = false;
        _onboardingCompleted = false;
      });
    }
  }

  void _goToMain() {
    context.goToProviderHome();
  }

  Future<void> _goToConfigServices() async {
    await context.pushProviderServiceSelection();
    _checkProviderStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Se não tem provider ainda, você pode mandar pro fluxo de cadastro (ou mostrar um aviso)
    if (!_hasProvider) {
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

    // Tela roxinha de “configurar serviços”
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Olá, $_email ',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,),
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
                onPressed: _goToConfigServices,
                icon: const Icon(Icons.build),
                label: const Text('Configurar serviços'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF3B246B),
                  elevation: 1,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
                'Depois de configurar, você entra no painel do prestador.',),
          ],
        ),
      ),
    );
  }
}
