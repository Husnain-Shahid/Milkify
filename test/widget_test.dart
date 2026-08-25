import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milkify/models/customer_model.dart';
import 'package:milkify/widgets/customer_tile.dart';

void main() {
  testWidgets('CustomerTile displays customer details and handles taps', (WidgetTester tester) async {
    final customer = Customer(
      id: 1,
      name: 'Ahmed Raza',
      phone: '03009876543',
      address: 'Gulberg III, Lahore',
      milkQuantity: 2.0,
      pricePerLiter: 210.0,
      time: 'Morning',
      createdAt: '2026-08-01T00:00:00.000',
    );

    bool tapped = false;
    bool billTapped = false;
    bool editTapped = false;
    bool deleteTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerTile(
            customer: customer,
            onTap: () => tapped = true,
            onBillTap: () => billTapped = true,
            onEdit: () => editTapped = true,
            onDelete: () => deleteTapped = true,
          ),
        ),
      ),
    );

    // Verify customer info displayed
    expect(find.text('Ahmed Raza'), findsOneWidget);
    expect(find.text('2.0 L/day'), findsOneWidget);
    expect(find.text('Rs 210/L'), findsOneWidget);
    expect(find.text('03009876543'), findsOneWidget);
    expect(find.text('Gulberg III, Lahore'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);

    // Tap main tile
    await tester.tap(find.text('Ahmed Raza'));
    expect(tapped, true);

    // Tap bill icon
    await tester.tap(find.byIcon(Icons.receipt_long));
    expect(billTapped, true);

    // Open popup menu and tap edit
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Customer'));
    await tester.pumpAndSettle();
    expect(editTapped, true);

    // Open popup menu and tap delete
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Customer'));
    await tester.pumpAndSettle();
    expect(deleteTapped, true);
  });
}