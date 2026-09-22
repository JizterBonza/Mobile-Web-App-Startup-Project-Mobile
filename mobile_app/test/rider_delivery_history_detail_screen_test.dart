import 'package:agriconnect/screens/rider/riderDeliveryHistoryDetailScreen.dart';
import 'package:agriconnect/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOrderService extends OrderService {
  @override
  Future<Map<String, dynamic>> fetchRiderDeliveryHistoryDetail(
    int orderId,
  ) async {
    return {
      'order_id': orderId,
      'order_code': 'ORD-20451',
      'ordered_at': '2026-07-10T03:51:00Z',
      'status': {'key': 'delivered', 'label': 'Delivered'},
      'customer_delivery': {
        'customer_name': 'Maria Santos',
        'contact_number': '09157782211',
        'drop_off_address': 'Purok 21, Madaum, Tagum City',
      },
      'pickup_stores': [
        {
          'name': 'PMC Agrivet Supply',
          'address': 'Pioneer Avenue, Tagum City',
          'picked_up_at': '2026-07-08T09:00:00Z',
        },
      ],
      'timeline': [
        {
          'key': 'received',
          'label': 'Received',
          'occurred_at': '2026-07-07T07:00:00Z',
          'completed': true,
        },
        {
          'key': 'delivered',
          'label': 'Delivered',
          'occurred_at': '2026-07-10T07:00:00Z',
          'completed': true,
        },
      ],
      'proof_of_delivery': {
        'groups': [
          {
            'remarks': 'Delivered successfully.',
            'images': [
              {
                'display_name': 'Image1.jpg',
                'image_url': 'https://example.test/proof/Image1.jpg',
              },
            ],
          },
        ],
      },
    };
  }
}

void main() {
  testWidgets('renders full rider delivery history details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderDeliveryHistoryDetailScreen(
          orderId: 123,
          orderService: _FakeOrderService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ORD-20451'), findsOneWidget);
    expect(find.text('Customer Delivery'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Pickup Stores'), findsOneWidget);
    expect(find.text('PMC Agrivet Supply'), findsOneWidget);
    expect(find.text('Timelines'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Proof of Delivery'),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Proof of Delivery'), findsOneWidget);
    expect(find.text('Image1.jpg'), findsOneWidget);
    expect(find.text('Delivered successfully.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delivery-proof-image-0')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('delivery-proof-image-preview')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('delivery-proof-image-close')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('delivery-proof-image-preview')),
      findsNothing,
    );
  });
}
