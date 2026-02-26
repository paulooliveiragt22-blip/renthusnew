import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/router/app_router.dart';

const _kRoxo = Color(0xFF3B246B);

class ProviderPublicProfilePage extends ConsumerStatefulWidget {
  const ProviderPublicProfilePage({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<ProviderPublicProfilePage> createState() =>
      _ProviderPublicProfilePageState();
}

class _ProviderPublicProfilePageState
    extends ConsumerState<ProviderPublicProfilePage> {
  bool _isFavorite = false;
  bool _loadingFav = false;
  bool _isClient = false;

  @override
  void initState() {
    super.initState();
    _checkIfClient();
  }

  Future<void> _checkIfClient() async {
    final client = ref.read(supabaseProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final row = await client
          .from('clients')
          .select('id')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) {
        setState(() => _isClient = true);
        _checkFavorite();
      }
    } catch (_) {}
  }

  Future<void> _checkFavorite() async {
    final client = ref.read(supabaseProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final row = await client
          .from('client_favorites')
          .select('id')
          .eq('client_id', uid)
          .eq('provider_id', widget.providerId)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _isFavorite = row != null);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_loadingFav) return;
    setState(() => _loadingFav = true);
    try {
      final client = ref.read(supabaseProvider);
      final result = await client.rpc('toggle_favorite_provider', params: {
        'p_provider_id': widget.providerId,
      });
      if (!mounted) return;
      setState(() {
        _isFavorite = result == true;
        _loadingFav = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite
              ? 'Profissional salvo nos favoritos'
              : 'Profissional removido dos favoritos'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFav = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_isClient)
            IconButton(
              onPressed: _loadingFav ? null : _toggleFavorite,
              icon: _loadingFav
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorite ? Colors.red.shade400 : Colors.white,
                    ),
              tooltip:
                  _isFavorite ? 'Remover dos salvos' : 'Salvar profissional',
            ),
        ],
      ),
      body: FutureBuilder<_ProfileData>(
        future: _fetchProfile(client, widget.providerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snap.error?.toString() ?? 'Perfil não encontrado.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _Body(data: snap.data!, providerId: widget.providerId);
        },
      ),
    );
  }
}

Future<_ProfileData> _fetchProfile(dynamic client, String providerId) async {
  final profileRes = await client
      .from('v_provider_public_profile')
      .select()
      .eq('provider_id', providerId)
      .maybeSingle();

  if (profileRes == null) throw Exception('Prestador não encontrado.');

  final reviewsRes = await client
      .from('v_provider_public_reviews')
      .select()
      .eq('provider_id', providerId)
      .order('created_at', ascending: false)
      .limit(10);

  return _ProfileData(
    profile: Map<String, dynamic>.from(profileRes),
    reviews: (reviewsRes as List).cast<Map<String, dynamic>>(),
  );
}

class _ProfileData {
  const _ProfileData({required this.profile, required this.reviews});
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> reviews;
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.providerId});
  final _ProfileData data;
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    final name = (p['name'] as String?) ?? 'Profissional';
    final avatarUrl = p['avatar_url'] as String?;
    final bio = (p['bio'] as String?)?.trim() ?? '';
    final rating = (p['rating'] as num?)?.toDouble();
    final city = p['city'] as String?;
    final state = p['state'] as String?;
    final completedJobs = (p['completed_jobs_count'] as num?)?.toInt() ?? 0;
    final memberSince = p['member_since']?.toString();

    final services = _parseServices(p['services']);
    final reviews = data.reviews;

    final locationText = [
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
    ].join(' - ');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context, name, avatarUrl, locationText),

          const SizedBox(height: 20),

          // Stats
          _buildStats(rating, completedJobs, memberSince),

          // Bio
          if (bio.isNotEmpty) ...[
            _sectionTitle('Sobre'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                bio,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // Services
          if (services.isNotEmpty) ...[
            _sectionTitle('Serviços oferecidos'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: services.map((s) {
                  return Chip(
                    label: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kRoxo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF3EEFF),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ),
          ],

          // Reviews
          _sectionTitle(
            'Avaliações recentes',
            trailing: reviews.isNotEmpty
                ? GestureDetector(
                    onTap: () => context.pushProviderReviews(providerId),
                    child: const Text(
                      '(ver todas)',
                      style: TextStyle(
                        fontSize: 12,
                        color: _kRoxo,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
          ),
          if (reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Ainda sem avaliações',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            )
          else
            ...reviews.take(5).map(_buildReviewCard),

          // Footer
          const SizedBox(height: 28),
          Center(
            child: Text(
              _memberSinceText(memberSince),
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String name,
    String? avatarUrl,
    String locationText,
  ) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kRoxo, Color(0xFF2A1850)],
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: Column(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color(0xFFEDE7F6),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _kRoxo,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              if (locationText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  locationText,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 280, width: double.infinity),
      ],
    );
  }

  Widget _buildStats(double? rating, int completedJobs, String? memberSince) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              '⭐ ${rating != null && rating > 0 ? rating.toStringAsFixed(1) : '-'}',
              'Avaliação',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              '$completedJobs',
              'Serviços',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              _timeSinceMember(memberSince),
              'No Renthus',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E1EC)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kRoxo,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kRoxo,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> r) {
    final stars = (r['rating'] as num?)?.toInt() ?? 0;
    final comment = (r['comment'] as String?)?.trim() ?? '';
    final clientName = (r['client_name'] as String?) ?? 'Cliente';
    final createdAt = r['created_at']?.toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (i) {
                  return Icon(
                    i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: i < stars ? Colors.amber.shade700 : Colors.grey.shade300,
                  );
                }),
                const Spacer(),
                Text(
                  _relativeDate(createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              clientName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
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
      ),
    );
  }

  List<String> _parseServices(dynamic json) {
    if (json == null) return [];
    final list = (json is List) ? json : [];
    return list
        .map((e) => (e is Map ? e['service_name']?.toString() : null))
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toList();
  }

  String _timeSinceMember(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      final months = (diff.inDays / 30).floor();
      if (months < 1) return '< 1 mês';
      if (months < 12) return '$months ${months == 1 ? 'mês' : 'meses'}';
      final years = (months / 12).floor();
      final rem = months % 12;
      if (rem == 0) return '$years ${years == 1 ? 'ano' : 'anos'}';
      return '${years}a ${rem}m';
    } catch (_) {
      return '-';
    }
  }

  String _memberSinceText(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final month = DateFormat.MMMM('pt_BR').format(dt);
      return 'Membro desde $month/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _relativeDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return 'agora';
      if (diff.inHours < 24) return 'há ${diff.inHours}h';
      if (diff.inDays < 7) return 'há ${diff.inDays}d';
      if (diff.inDays < 30) return 'há ${(diff.inDays / 7).floor()} sem';
      if (diff.inDays < 365) return 'há ${(diff.inDays / 30).floor()} meses';
      return 'há ${(diff.inDays / 365).floor()} anos';
    } catch (_) {
      return '';
    }
  }
}
