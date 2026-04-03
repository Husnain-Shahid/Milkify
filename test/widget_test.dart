import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkify/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(MilkApp());

    // Example check: verify HomeScreen loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}