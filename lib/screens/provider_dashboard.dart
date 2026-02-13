import 'package:flutter/material.dart';
import 'package:renthus/screens/provider_home_page.dart'; // está na mesma pasta "screens"

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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderHomePage(),
      ),
    );
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
