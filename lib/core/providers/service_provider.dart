import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/repositories/service_repository.dart';

part 'service_provider.g.dart';

@Riverpod(keepAlive: true)
ServiceRepository serviceRepository(ServiceRepositoryRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return ServiceRepository(client: supabase);
}
