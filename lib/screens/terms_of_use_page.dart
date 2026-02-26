import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos de uso'),
        backgroundColor: kRoxo,
        foregroundColor: Colors.white,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          'Termos de Uso - Renthus\n\n'
          '1. Aceitação\n'
          'Ao utilizar a plataforma Renthus, você concorda com estes termos.\n\n'
          '2. Uso da plataforma\n'
          'A plataforma conecta clientes e prestadores para contratação de serviços. '
          'O usuário deve fornecer informações verdadeiras e manter seus dados atualizados.\n\n'
          '3. Conduta\n'
          'Não é permitido uso fraudulento, ofensivo, discriminatório ou que viole leis vigentes.\n\n'
          '4. Pagamentos e repasses\n'
          'Pagamentos seguem as regras exibidas no app. Liberação de valores para prestadores '
          'pode respeitar janelas de segurança e análise de disputa.\n\n'
          '5. Cancelamentos e disputas\n'
          'Cancelamentos e disputas podem gerar revisão de valores, retenções temporárias ou estornos, '
          'conforme política operacional da plataforma.\n\n'
          '6. Limitação de responsabilidade\n'
          'A plataforma atua como intermediadora e pode adotar medidas para segurança, prevenção de fraude '
          'e conformidade legal.\n\n'
          '7. Alterações\n'
          'Estes termos podem ser atualizados. A versão vigente será disponibilizada no aplicativo.\n\n'
          '8. Contato\n'
          'Dúvidas: suporte@renthus.com.br',
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
      ),
    );
  }
}
