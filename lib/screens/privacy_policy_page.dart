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
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          'Política de Privacidade - Renthus\n\n'
          '1. Dados coletados\n'
          'Coletamos dados de cadastro, contato, uso da plataforma e informações necessárias '
          'para intermediação de serviços e pagamentos.\n\n'
          '2. Finalidade\n'
          'Os dados são utilizados para autenticação, operação do app, prevenção de fraude, '
          'atendimento e cumprimento de obrigações legais.\n\n'
          '3. Compartilhamento\n'
          'Dados podem ser compartilhados com parceiros de pagamento, infraestrutura e suporte, '
          'sempre no limite necessário para execução do serviço.\n\n'
          '4. Segurança\n'
          'Adotamos medidas técnicas e administrativas para proteger os dados contra acesso indevido.\n\n'
          '5. Retenção\n'
          'Dados podem ser mantidos pelo tempo necessário para obrigações legais, auditoria e segurança.\n\n'
          '6. Direitos do titular\n'
          'Você pode solicitar atualização de dados, revisão de informações e esclarecimentos sobre tratamento.\n\n'
          '7. Contato\n'
          'Para solicitações relacionadas a privacidade: suporte@renthus.com.br',
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
      ),
    );
  }
}
