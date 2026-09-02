import 'package:agriconnect/widgets/rider_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows only pickup and delivery dashboard actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderQuickActions(
            onPickupMap: () {},
            onDeliveryMap: () {},
          ),
        ),
      ),
    );

    expect(find.text('For Pickup'), findsOneWidget);
    expect(find.text('For Delivery'), findsOneWidget);
    expect(find.text('All Deliveries'), findsNothing);
    expect(find.text('Earnings'), findsNothing);
    expect(find.byIcon(Icons.store_mall_directory_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delivery_dining), findsOneWidget);
  });
}
