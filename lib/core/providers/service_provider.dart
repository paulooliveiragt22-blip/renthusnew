import 'package:renthus/models/home_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/repositories/service_repository.dart';

part 'service_provider.g.dart';

@Riverpod(keepAlive: true)
ServiceRepository serviceRepository(ServiceRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return ServiceRepository(client: supabase);
}

@Riverpod(keepAlive: true)
Future<List<HomeService>> homeServices(HomeServicesRef ref) async {
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.fetchHomeServices();
}
