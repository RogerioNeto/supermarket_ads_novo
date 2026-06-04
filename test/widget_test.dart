// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_ads/main.dart';

void main() {
  testWidgets('App smoke test - Verifica se o título aparece', (WidgetTester tester) async {
    // Constrói o app dentro de um MaterialApp para teste
    await tester.pumpWidget(const MaterialApp(home: SupermarketProApp(storeId: 'loja-teste')));

    // Verifica se o título da rádio está presente na tela
    expect(find.text('Supermarket Ads'), findsOneWidget);
  });
}
