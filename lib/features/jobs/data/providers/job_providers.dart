import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/jobs/data/repositories/job_repository.dart';
import 'package:renthus/models/job.dart';
import 'package:renthus/repositories/job_repository.dart' as app_repo;

part 'job_providers.g.dart';

@riverpod
JobRepository jobRepository(JobRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return JobRepository(supabase);
}

/// Repositório legado (views v_provider_jobs_*) para job_details do prestador
@riverpod
app_repo.JobRepository appJobRepository(AppJobRepositoryRef ref) {
  return app_repo.JobRepository();
}

/// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
@riverpod
Future<Map<String, dynamic>?> providerJobById(
    ProviderJobByIdRef ref, String jobId) async {
  final repo = ref.read(appJobRepositoryProvider);
  return await repo.getProviderJobSmartById(jobId);
}

@riverpod
Future<List<Job>> jobsList(JobsListRef ref, {String? city, String? status}) async {
  final repository = ref.watch(jobRepositoryProvider);
  return await repository.getJobs(city: city, status: status);
}

@riverpod
Future<Job> jobById(JobByIdRef ref, String id) async {
  final repository = ref.watch(jobRepositoryProvider);
  return await repository.getJobById(id);
}

@riverpod
Stream<List<Job>> jobsStream(JobsStreamRef ref, {String? city}) {
  final repository = ref.watch(jobRepositoryProvider);
  return repository.watchJobs(city: city);
}

@riverpod
class JobActions extends _$JobActions {
  @override
  FutureOr<void> build() async {}

  Future<Job?> create(Map<String, dynamic> jobData) async {
    state = const AsyncValue.loading();
    
    return await AsyncValue.guard(() async {
      final repository = ref.read(jobRepositoryProvider);
      final job = await repository.createJob(jobData);
      ref.invalidate(jobsListProvider);
      return job;
    }).then((result) => result.value);
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    
    state = await AsyncValue.guard(() async {
      final repository = ref.read(jobRepositoryProvider);
      await repository.updateJob(id, updates);
      ref.invalidate(jobsListProvider);
      ref.invalidate(jobByIdProvider(id));
    });
  }
}
