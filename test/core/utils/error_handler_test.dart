import 'package:flutter_test/flutter_test.dart';

import 'package:renthus/core/exceptions/app_exceptions.dart';

void main() {
  group('parseSupabaseException', () {
    test('jwt expired retorna AuthException', () {
      final result = parseSupabaseException(Exception('jwt expired'));
      expect(result, isA<AuthException>());
      expect(result.message, contains('Sessão expirada'));
    });

    test('permission denied retorna PermissionException', () {
      final result = parseSupabaseException(Exception('permission denied'));
      expect(result, isA<PermissionException>());
    });

    test('not found retorna NotFoundException', () {
      final result = parseSupabaseException(Exception('not found'));
      expect(result, isA<NotFoundException>());
    });

    test('network retorna NetworkException', () {
      final result = parseSupabaseException(Exception('network error'));
      expect(result, isA<NetworkException>());
    });
  });
}
