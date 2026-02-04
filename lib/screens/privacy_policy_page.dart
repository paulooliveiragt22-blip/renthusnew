import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de privacidade'),
        backgroundColor: kRoxo,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Em breve.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
