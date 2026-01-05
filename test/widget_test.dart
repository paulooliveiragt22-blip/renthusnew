import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:renthus_app/main.dart';

void main() {
  testWidgets('RenthusApp exibe a tela de seleção de perfil',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RenthusApp());
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao Renthus'), findsOneWidget);
    expect(find.text('Como você quer usar o app?'), findsOneWidget);
    expect(find.text('Já tenho conta? Entrar'), findsOneWidget);
  });
}
