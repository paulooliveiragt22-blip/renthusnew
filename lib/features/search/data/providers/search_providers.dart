import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/features/search/data/repositories/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(supabaseProvider));
});
