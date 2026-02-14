import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceRepository {
  ServiceRepository(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>?> loadService(String serviceId) async {
    final res = await _client
        .from('services_catalog')
        .select()
        .eq('id', serviceId)
        .maybeSingle();
    return res != null ? Map<String, dynamic>.from(res as Map) : null;
  }
}
