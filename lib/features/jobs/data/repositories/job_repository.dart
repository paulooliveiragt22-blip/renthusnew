import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:renthus/core/exceptions/app_exceptions.dart';
import 'package:renthus/models/job.dart';

class JobRepository {
  const JobRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<Job>> getJobs({String? city, String? status}) async {
    try {
      var query = _supabase.from('jobs').select();
      if (city != null) query = query.eq('city', city);
      if (status != null) query = query.eq('status', status);
      
      final data = await query.order('created_at', ascending: false);
      return data.map((e) => Job.fromMap(e)).toList();
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<Job> getJobById(String id) async {
    try {
      final data = await _supabase.from('jobs').select().eq('id', id).single();
      return Job.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<Job> createJob(Map<String, dynamic> jobData) async {
    try {
      final data = await _supabase.from('jobs').insert(jobData).select().single();
      return Job.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Future<Job> updateJob(String id, Map<String, dynamic> updates) async {
    try {
      final data = await _supabase.from('jobs').update(updates).eq('id', id).select().single();
      return Job.fromMap(data);
    } catch (e) {
      throw parseSupabaseException(e);
    }
  }

  Stream<List<Job>> watchJobs({String? city}) {
    var query = _supabase.from('jobs').stream(primaryKey: ['id']);
    if (city != null) query = query.eq('city', city);
    return query.map((data) => data.map((e) => Job.fromMap(e)).toList());
  }
}
