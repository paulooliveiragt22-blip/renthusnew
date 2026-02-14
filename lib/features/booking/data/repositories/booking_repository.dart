import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRepository {
  BookingRepository(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>?> loadBooking(String bookingId) async {
    final res = await _client
        .from('bookings')
        .select('*, services_catalog(name), disputes(status)')
        .eq('id', bookingId)
        .maybeSingle();
    return res != null ? Map<String, dynamic>.from(res as Map) : null;
  }

  Future<void> openDispute({
    required String bookingId,
    required String userId,
    required String reason,
  }) async {
    await _client.from('disputes').insert({
      'booking_id': bookingId,
      'opened_by': userId,
      'reason': reason,
    });
  }
}
