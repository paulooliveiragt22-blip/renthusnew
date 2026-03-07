import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/shared_preferences_provider.dart';
import 'package:renthus/core/services/job_draft_service.dart';

/// Serviço de rascunhos de pedidos incompletos (home do cliente).
final jobDraftServiceProvider = FutureProvider<JobDraftService>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return JobDraftService(prefs);
});
