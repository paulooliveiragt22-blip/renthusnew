import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/admin/data/repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseProvider));
});

final adminAlertsProvider = FutureProvider<AdminAlerts>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.loadAlerts();
});
