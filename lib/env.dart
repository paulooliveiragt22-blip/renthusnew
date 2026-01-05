// Centralized environment configuration for Supabase.
// Values can be overridden via --dart-define at build time to avoid
// hardcoding credentials in source.
class Env {
  static const _defaultSupabaseUrl =
      'https://dqfejuakbtcxhymrxoqs.supabase.co';
  static const _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxZmVqdWFrYnRjeGh5bXJ4b3FzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4MjA4NjUsImV4cCI6MjA3ODM5Njg2NX0.k6dl4CLhdjPEq1DaOOnPWcY6o_Rvv64edJJqdWVPz-4';

  /// Supabase project URL. Override with `--dart-define=SUPABASE_URL=...`.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultSupabaseUrl,
  );

  /// Supabase anonymous key. Override with
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultSupabaseAnonKey,
  );
}
