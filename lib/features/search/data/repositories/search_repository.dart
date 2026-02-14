import 'package:supabase_flutter/supabase_flutter.dart';

class SearchRepository {
  SearchRepository(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> searchServices({
    String? query,
    String? categoryId,
    int from = 0,
    int to = 14,
  }) async {
    var q = _client.from('services_catalog').select();
    if (query != null && query.isNotEmpty) {
      q = q.ilike('name', '%$query%');
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.eq('category_id', categoryId);
    }
    final res = await q.order('created_at', ascending: false).range(from, to);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> createBooking({
    required String serviceId,
    required String providerId,
    required String clientId,
  }) async {
    await _client.from('bookings').insert({
      'service_id': serviceId,
      'provider_id': providerId,
      'client_id': clientId,
      'status': 'pending',
      'scheduled_at': DateTime.now().toIso8601String(),
    });
  }
}
