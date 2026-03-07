import 'package:flutter/material.dart';

class ProviderPartnersPage extends StatelessWidget {
  const ProviderPartnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // por enquanto, parceiros mockados (fixos)
    final partners = <PartnerStore>[
      const PartnerStore(
        name: 'Casa do Construtor',
        description: 'Aluguel de ferramentas com condição especial.',
        category: 'Ferramentas e Construção',
      ),
      const PartnerStore(
        name: 'Limpeza Y',
        description: 'Produtos de limpeza com entrega rápida.',
        category: 'Limpeza e Higiene',
      ),
      const PartnerStore(
        name: 'Loja Elétrica Z',
        description: 'Materiais elétricos para manutenção e reparo.',
        category: 'Elétrica',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoBanner(),
                  const SizedBox(height: 16),
                  ...partners.map((p) => _PartnerCard(store: p)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- HEADER ----------
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF3B246B),
      ),
      child: const Text(
        'Lojas Parceiras',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------- BANNER DE EXPLICAÇÃO ----------
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B246B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.store_mall_directory,
            color: Colors.white,
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aqui você encontra lojas parceiras para comprar materiais, '
              'produtos de limpeza e outros itens com condições especiais '
              'para prestadores Renthus.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- MODEL ----------
class PartnerStore {

  const PartnerStore({
    required this.name,
    required this.description,
    required this.category,
  });
  final String name;
  final String description;
  final String category;
}

// ---------- CARD DO PARCEIRO ----------
class _PartnerCard extends StatelessWidget {

  const _PartnerCard({required this.store});
  final PartnerStore store;

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(store.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF3B246B),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  store.category,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  store.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              // aqui no futuro: abrir chat com a loja ou página de detalhes
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Em breve você poderá falar com ${store.name} pelo app.',),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B246B),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            icon: const Icon(
              Icons.chat_bubble_outline,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Contato',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
