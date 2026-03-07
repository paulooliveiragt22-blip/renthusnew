// Config local para testes unitários puros (sem Supabase / plugins).
// Sobrescreve o flutter_test_config.dart da pasta raiz de test/.
Future<void> testExecutable(Future<void> Function() testMain) async {
  await testMain();
}
