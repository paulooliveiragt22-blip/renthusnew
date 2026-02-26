import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/screens/provider_public_profile_page.dart';

const _kRoxo = Color(0xFF3B246B);

class ClientFavoritesPage extends ConsumerStatefulWidget {
  const ClientFavoritesPage({super.key});

  @override
  ConsumerState<ClientFavoritesPage> createState() =>
      _ClientFavoritesPageState();
}

class _ClientFavoritesPageState extends ConsumerState<ClientFavoritesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(supabaseProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      final res = await client
          .from('client_favorites')
          .select('''
            provider_id,
            created_at,
            v_provider_public_profile!inner (
              name,
              avatar_url,
              rating,
              city,
              services
            )
          ''')
          .eq('client_id', uid)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _favorites = (res as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar favoritos: $e');
      if (!mounted) return;

      // Fallback: direct query if the join doesn't work
      try {
        final client = ref.read(supabaseProvider);
        final uid = client.auth.currentUser?.id;
        if (uid == null) return;

        final favRows = await client
            .from('client_favorites')
            .select('provider_id, created_at')
            .eq('client_id', uid)
            .order('created_at', ascending: false);

        final favList = (favRows as List).cast<Map<String, dynamic>>();
        if (favList.isEmpty) {
          setState(() {
            _favorites = [];
            _loading = false;
          });
          return;
        }

        final providerIds =
            favList.map((f) => f['provider_id'] as String).toList();
        final profiles = await client
            .from('v_provider_public_profile')
            .select('provider_id, name, avatar_url, rating, city, services')
            .inFilter('provider_id', providerIds);

        final profileMap = <String, Map<String, dynamic>>{};
        for (final p in (profiles as List).cast<Map<String, dynamic>>()) {
          profileMap[p['provider_id'] as String] = p;
        }

        final merged = favList.map((f) {
          final pid = f['provider_id'] as String;
          return {
            'provider_id': pid,
            'created_at': f['created_at'],
            ...?profileMap[pid],
          };
        }).toList();

        if (!mounted) return;
        setState(() {
          _favorites = merged;
          _loading = false;
        });
      } catch (e2) {
        debugPrint('Erro fallback favoritos: $e2');
        if (!mounted) return;
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _removeFavorite(String providerId, int index) async {
    final client = ref.read(supabaseProvider);
    try {
      await client.rpc('toggle_favorite_provider', params: {
        'p_provider_id': providerId,
      });
      if (!mounted) return;
      setState(() => _favorites.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profissional removido dos salvos')),
      );
    } catch (e) {
      debugPrint('Erro ao remover favorito: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    }
  }

  void _openProfile(String providerId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderPublicProfilePage(providerId: providerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profissionais salvos'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F4F4),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _favorites.isEmpty
                ? _emptyState()
                : _buildList(),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Nenhum profissional salvo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Salve profissionais que você gostou\npara encontrá-los depois',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final f = _favorites[index];
        final providerId = f['provider_id']?.toString() ?? '';

        final profile = f['v_provider_public_profile'];
        final bool hasJoin = profile is Map;

        final name =
            (hasJoin ? profile['name'] : f['name']) as String? ?? 'Profissional';
        final avatarUrl =
            (hasJoin ? profile['avatar_url'] : f['avatar_url']) as String?;
        final rating =
            (hasJoin ? profile['rating'] : f['rating']) as num? ?? 0;
        final city = (hasJoin ? profile['city'] : f['city']) as String? ?? '';

        final rawServices = hasJoin ? profile['services'] : f['services'];
        String mainService = '';
        if (rawServices is List && rawServices.isNotEmpty) {
          final first = rawServices.first;
          if (first is Map) {
            mainService = (first['service_name'] as String?) ?? '';
          } else if (first is String) {
            mainService = first;
          }
        }

        return GestureDetector(
          onTap: () => _openProfile(providerId),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _kRoxo.withOpacity(0.1),
                  backgroundImage:
                      avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            color: _kRoxo,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (rating > 0) ...[
                            Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber.shade700),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (city.isNotEmpty)
                            Flexible(
                              child: Text(
                                city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (mainService.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EEFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            mainService,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _kRoxo,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removeFavorite(providerId, index),
                  icon: Icon(Icons.favorite_rounded, color: Colors.red.shade400),
                  tooltip: 'Remover dos salvos',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
