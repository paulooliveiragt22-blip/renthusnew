import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env pode não existir em CI
  }

  final url = dotenv.env['SUPABASE_URL'] ?? 'https://test.supabase.co';
  final key = dotenv.env['SUPABASE_ANON_KEY'] ?? 'test-anon-key';

  await Supabase.initialize(url: url, anonKey: key);

  await testMain();
}
