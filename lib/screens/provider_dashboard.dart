import 'package:flutter/material.dart';
import 'package:renthus/core/router/app_router.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  @override
  void initState() {
    super.initState();
    // Assim que essa tela abrir, já redireciona para a Home do Prestador
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToHome();
    });
  }

  void _goToHome() {
    context.goToProviderHome();
  }

  @override
  Widget build(BuildContext context) {
    // Tela só de carregamento enquanto redireciona
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
