import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_service.dart';

class ServiceRepository {
  ServiceRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;

  Future<List<HomeService>> fetchHomeServices() async {
    final response = await _db
        .from('renthus_home_services')
        .select()
        .eq('is_active', true)
        .order('order_index', ascending: true);

    return (response as List).map((row) => HomeService.fromMap(row)).toList();
  }
}
