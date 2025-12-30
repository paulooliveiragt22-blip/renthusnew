import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingRepository {
  final SupabaseClient _client;

  OnboardingRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Plataforma em texto para métricas (web/android/ios/macos/windows/linux/unknown)
  String _platformString() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
      default:
        return 'unknown';
    }
  }

  /// Chama a RPC de onboarding de forma idempotente e FAIL-SAFE:
  /// - nunca lança erro para a UI (swallow exceptions)
  /// - pode ser chamada várias vezes
  Future<void> upsert({
    required String
        status, // started | email_confirmed | step2_started | completed
    String? intendedRole, // client | provider
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
    String? referrer,
    String? platform,
  }) async {
    try {
      final payload = <String, dynamic>{
        // Assumindo que a RPC aceita esses nomes exatamente como colunas/campos.
        // Se no seu SQL você usou prefixos (ex: p_status), me diga que eu ajusto.
        'status': status,
        'intended_role': intendedRole,
        'utm_source': utmSource,
        'utm_medium': utmMedium,
        'utm_campaign': utmCampaign,
        'referrer': referrer,
        'platform': platform ?? _platformString(),
      };

      // Remove chaves null pra não sobrescrever valores existentes à toa
      payload.removeWhere((key, value) => value == null);

      await _client.rpc('rpc_onboarding_upsert', params: payload);
    } catch (_) {
      // Fail-safe: não quebra o app por causa de métricas
      // (se quiser, aqui dá pra adicionar log/analytics no futuro)
    }
  }
}
