import 'package:agriconnect/widgets/delivery_acceptance_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> openDialog(WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await DeliveryAcceptanceConfirmationDialog.show(
                  context,
                  orderLabel: 'ORD-20313',
                  pickupStoreCount: 2,
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('matches the compact accepted-card design', (tester) async {
    await openDialog(tester);

    expect(find.text('Accept Delivery'), findsOneWidget);
    expect(
      find.text('Accept ORD-20313? You will pick up from 2 stores.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);

    final card = find.byKey(
      const ValueKey('delivery-acceptance-confirmation-card'),
    );
    expect(tester.getSize(card).width, 300);

    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, const Color(0xA6000000));
  });

  testWidgets('returns true when Accept is selected', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await DeliveryAcceptanceConfirmationDialog.show(
                  context,
                  orderLabel: 'ORD-20313',
                  pickupStoreCount: 1,
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(
      find.text('Accept ORD-20313? You will pick up from 1 store.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('delivery-acceptance-accept-button')),
    );
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('returns false when Cancel is selected', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await DeliveryAcceptanceConfirmationDialog.show(
                  context,
                  orderLabel: 'this order',
                  pickupStoreCount: 1,
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('delivery-acceptance-cancel-button')),
    );
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
