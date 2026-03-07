import 'package:supabase_flutter/supabase_flutter.dart';

/// Busca de tipos de serviço (v_service_types_search, v_service_types_public)
class ServiceTypesRepository {
  ServiceTypesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  /// Busca por texto em name/description e tokens em name.
  /// Retorna map name -> id e name -> category_id.
  Future<Map<String, Map<String, String>>> searchServiceTypes(String text) async {
    final lowerText = text.toLowerCase().trim();
    if (lowerText.isEmpty) return {};

    final tokens = lowerText
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 3)
        .toSet()
        .toList();

    if (tokens.length > 4) tokens.removeRange(4, tokens.length);
    if (tokens.any((t) => t.startsWith('foto')) && !tokens.contains('foto')) {
      tokens.add('foto');
    }

    final List<String> conditions = [];
    conditions.add('name.ilike.%$text%');
    conditions.add('description.ilike.%$text%');
    for (final token in tokens) {
      conditions.add('name.ilike.%$token%');
    }
    final orFilter = conditions.join(',');

    try {
      final subRes = await _client
          .from('v_service_types_search')
          .select('id, name, category_id')
          .or(orFilter)
          .limit(12);

      final Map<String, String> mapSub = {};
      final Map<String, String> mapCat = {};

      for (final row in subRes as List<dynamic>) {
        final data = row as Map<String, dynamic>;
        final id = data['id'] as String?;
        final name = data['name'] as String?;
        final categoryId = data['category_id'] as String?;
        if (id == null || name == null || categoryId == null) continue;
        mapSub[name] = id;
        mapCat[name] = categoryId;
      }

      if (mapSub.isEmpty) {
        final fallback = await _client
            .from('v_service_types_public')
            .select('id, name, category_id')
            .eq('is_active', true)
            .order('name')
            .limit(10);

        for (final row in fallback as List<dynamic>) {
          final data = row as Map<String, dynamic>;
          final id = data['id'] as String?;
          final name = data['name'] as String?;
          final categoryId = data['category_id'] as String?;
          if (id == null || name == null || categoryId == null) continue;
          mapSub[name] = id;
          mapCat[name] = categoryId;
        }
      }

      return {'byName': mapSub, 'byCategory': mapCat};
    } catch (_) {
      return {};
    }
  }
}
