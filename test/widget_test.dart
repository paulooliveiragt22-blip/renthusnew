// Teste básico do Renthus app.
//
// Verifica que o app inicia e a tela de seleção de papel é exibida.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/main.dart';

void main() {
  testWidgets('App carrega e exibe tela de boas-vindas',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RenthusApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao Renthus'), findsOneWidget);
    expect(find.text('Como você quer usar o app?'), findsOneWidget);
  });
}
