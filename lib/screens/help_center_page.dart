import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:renthus/core/router/app_router.dart';

const _kRoxo = Color(0xFF3B246B);

class HelpCenterPlaceholderPage extends StatelessWidget {
  const HelpCenterPlaceholderPage({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    if (!await canLaunchUrlString(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.')),
        );
      }
      return;
    }
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Ajuda'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F4F4),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Suporte rápido ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.headset_mic_rounded,
                      size: 40, color: _kRoxo),
                  const SizedBox(height: 12),
                  const Text(
                    'Precisa de ajuda?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _kRoxo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fale com nosso suporte pelo WhatsApp',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => _openUrl(
                      context,
                      'https://wa.me/5566999999999?text=Ol%C3%A1%2C%20preciso%20de%20ajuda%20com%20o%20Renthus',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text(
                      'Abrir WhatsApp',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- FAQ ----
            const Text(
              'Perguntas frequentes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kRoxo,
              ),
            ),

            const SizedBox(height: 16),
            _categoryTitle('Sobre o Renthus'),
            const _FaqTile(
              question: 'O que é o Renthus?',
              answer:
                  'O Renthus é um app que conecta quem precisa de serviços '
                  'residenciais e comerciais a profissionais avaliados da sua '
                  'região. Você descreve o que precisa, recebe propostas com '
                  'preço e horário, e paga com segurança pelo app.',
            ),
            const _FaqTile(
              question: 'Em quais cidades o Renthus funciona?',
              answer:
                  'Atualmente estamos em Sorriso-MT e região. Estamos '
                  'expandindo para novas cidades em breve. Fique de olho nas '
                  'novidades pelo app e redes sociais.',
            ),

            const SizedBox(height: 24),
            _categoryTitle('Para Clientes'),
            const _FaqTile(
              question: 'Como solicitar um serviço?',
              answer:
                  'Na tela inicial, toque no botão + e descreva o serviço '
                  'que precisa. Adicione fotos, escolha a data e envie. '
                  'Profissionais da sua região receberão seu pedido e enviarão '
                  'propostas com preço e disponibilidade.',
            ),
            const _FaqTile(
              question: 'Como funciona o pagamento?',
              answer:
                  'Após escolher um profissional, você paga pelo app via '
                  'Pix ou cartão. O valor fica protegido até que o serviço '
                  'seja concluído. Só depois o pagamento é liberado ao '
                  'prestador.',
            ),
            const _FaqTile(
              question: 'Posso cancelar um pedido?',
              answer:
                  'Sim, acesse Meus Pedidos, toque no pedido e selecione '
                  'Cancelar. Se já houve pagamento, o estorno será processado '
                  'automaticamente conforme nossa política.',
            ),
            const _FaqTile(
              question: 'E se o profissional não aparecer?',
              answer:
                  'Abra uma reclamação pelo app em Detalhes do Pedido. '
                  'Analisaremos o caso e, se procedente, o valor será '
                  'estornado integralmente.',
            ),
            const _FaqTile(
              question: 'Como avaliar um profissional?',
              answer:
                  'Após a conclusão do serviço, uma tela de avaliação '
                  'aparecerá automaticamente. Você também pode avaliar depois '
                  'em Meus Pedidos > Detalhes > Avaliar profissional.',
            ),

            const SizedBox(height: 24),
            _categoryTitle('Para Profissionais'),
            const _FaqTile(
              question: 'Como me cadastrar como prestador?',
              answer:
                  'Na tela inicial do app, escolha "Sou Profissional" e '
                  'preencha seus dados, documentos e serviços que oferece. '
                  'Após a verificação, você começará a receber pedidos da '
                  'sua região.',
            ),
            const _FaqTile(
              question: 'Como recebo pelos serviços?',
              answer:
                  'O pagamento é processado pelo app e transferido para '
                  'sua conta bancária cadastrada. O repasse acontece após a '
                  'conclusão do serviço, descontada a taxa da plataforma.',
            ),
            const _FaqTile(
              question: 'Posso atender em outras cidades?',
              answer:
                  'Sim, na sua área de atuação você define o raio de '
                  'atendimento. Quanto maior o raio, mais pedidos você '
                  'receberá, mas considere o deslocamento.',
            ),

            const SizedBox(height: 24),
            _categoryTitle('Conta e Segurança'),
            const _FaqTile(
              question: 'Como alterar meus dados?',
              answer:
                  'Acesse Minha Conta > Editar dados pessoais. Você pode '
                  'atualizar nome, telefone, e-mail e endereço a qualquer '
                  'momento.',
            ),
            const _FaqTile(
              question: 'Como excluir minha conta?',
              answer:
                  'Em Minha Conta, role até o final e toque em Cancelar conta. '
                  'Seus dados serão removidos conforme nossa política de '
                  'privacidade. Pedidos em aberto precisam ser finalizados '
                  'antes da exclusão.',
            ),

            const SizedBox(height: 32),

            // ---- Links úteis ----
            const Text(
              'Links úteis',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kRoxo,
              ),
            ),
            const SizedBox(height: 8),
            _linkTile(
              icon: Icons.description_outlined,
              label: 'Termos de Uso',
              onTap: () => context.pushTerms(),
            ),
            _linkTile(
              icon: Icons.shield_outlined,
              label: 'Política de Privacidade',
              onTap: () => context.pushPrivacy(),
            ),
            _linkTile(
              icon: Icons.mail_outline,
              label: 'suporte@renthus.com.br',
              onTap: () => _openUrl(
                context,
                'mailto:suporte@renthus.com.br?subject=Suporte%20Renthus',
              ),
            ),

            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Horário de atendimento: segunda a sexta, 08h às 18h',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _categoryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _linkTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _kRoxo),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kRoxo,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          iconColor: _kRoxo,
          collapsedIconColor: Colors.black45,
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kRoxo,
            ),
          ),
          children: [
            Text(
              answer,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
