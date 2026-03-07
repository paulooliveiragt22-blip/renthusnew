import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

const _kRoxo = Color(0xFF3B246B);

class ProviderReviewsPage extends ConsumerWidget {
  const ProviderReviewsPage({
    super.key,
    required this.providerId,
    this.isOwnProfile = false,
  });

  final String providerId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnProfile ? 'Minhas Avaliações' : 'Avaliações'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F4F4),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReviews(client),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          final reviews = snap.data ?? [];
          if (reviews.isEmpty) {
            return _emptyState();
          }
          return _buildContent(reviews);
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchReviews(dynamic client) async {
    final res = await client
        .from('v_provider_public_reviews')
        .select()
        .eq('provider_id', providerId)
        .order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Ainda sem avaliações',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOwnProfile
                  ? 'Complete serviços para receber feedback!'
                  : 'Este profissional ainda não recebeu avaliações.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> reviews) {
    final totalReviews = reviews.length;
    final avgRating = reviews.fold<double>(
          0,
          (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0),
        ) /
        totalReviews;

    final dist = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      final stars = (r['rating'] as num?)?.toInt() ?? 0;
      if (stars >= 1 && stars <= 5) dist[stars] = dist[stars]! + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Column(
                    children: [
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: _kRoxo,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) {
                          return Icon(
                            i < avgRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: i < avgRating.round()
                                ? Colors.amber.shade700
                                : Colors.grey.shade300,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'baseado em $totalReviews avaliação${totalReviews > 1 ? 'ões' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [5, 4, 3, 2, 1].map((star) {
                        final count = dist[star] ?? 0;
                        final pct = totalReviews > 0
                            ? count / totalReviews
                            : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '$star★',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.amber.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${(pct * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...reviews.map(_reviewCard),
      ],
    );
  }

  Widget _reviewCard(Map<String, dynamic> r) {
    final stars = (r['rating'] as num?)?.toInt() ?? 0;
    final comment = (r['comment'] as String?)?.trim() ?? '';
    final clientName = (r['client_name'] as String?) ?? 'Cliente';
    final createdAt = r['created_at']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  clientName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                _relativeDate(createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: i < stars ? Colors.amber.shade700 : Colors.grey.shade300,
              );
            }),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _relativeDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return 'agora';
      if (diff.inHours < 24) return 'há ${diff.inHours}h';
      if (diff.inDays < 7) return 'há ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}';
      if (diff.inDays < 30) return 'há ${(diff.inDays / 7).floor()} sem';
      if (diff.inDays < 365) return 'há ${(diff.inDays / 30).floor()} meses';
      return 'há ${(diff.inDays / 365).floor()} anos';
    } catch (_) {
      return '';
    }
  }
}
