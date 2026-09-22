import 'package:agriconnect/screens/rider/selectedOrderPickupDetail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  Map<String, dynamic> orderWithStatuses(List<dynamic> statuses) {
    return {
      'active_order_shops': statuses
          .map((status) => {'order_status_description': status})
          .toList(),
    };
  }

  Future<void> pumpProgress(
    WidgetTester tester,
    PickupProgress progress,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: PickupProgressBar(progress: progress),
            ),
          ),
        ),
      ),
    );
  }

  test('one in-transit shop completes Picked Up and In Transit', () {
    final progress = PickupProgress.fromOrder(
      orderWithStatuses(['In Transit']),
    );

    expect(progress.totalShops, 1);
    expect(progress.pickedUpCount, 1);
    expect(progress.pickedUpComplete, isTrue);
    expect(progress.pickupLabel, 'Picked Up');
    expect(progress.inTransitActive, isTrue);
    expect(progress.delivered, isFalse);
  });

  test('mixed ready and in-transit shops report partial pickup progress', () {
    final progress = PickupProgress.fromOrder(
      orderWithStatuses(['Ready for Pick-up', 'in_transit']),
    );

    expect(progress.totalShops, 2);
    expect(progress.pickedUpCount, 1);
    expect(progress.pickedUpComplete, isFalse);
    expect(progress.pickupLabel, '1/2');
    expect(progress.inTransitActive, isFalse);
  });

  test('two in-transit shops complete Picked Up', () {
    final progress = PickupProgress.fromOrder(
      orderWithStatuses(['in-transit', 'In Transit']),
    );

    expect(progress.pickedUpCount, 2);
    expect(progress.pickedUpComplete, isTrue);
    expect(progress.pickupLabel, 'Picked Up');
    expect(progress.inTransitActive, isTrue);
  });

  test('all delivered shops complete the final progression state', () {
    final progress = PickupProgress.fromOrder(
      orderWithStatuses(['Delivered', 'delivered']),
    );

    expect(progress.pickedUpCount, 2);
    expect(progress.pickedUpComplete, isTrue);
    expect(progress.inTransitActive, isFalse);
    expect(progress.delivered, isTrue);
  });

  test('malformed shop data is ignored safely', () {
    final progress = PickupProgress.fromOrder({
      'active_order_shops': [
        null,
        'invalid',
        {'order_status_description': null},
      ],
    });

    expect(progress.totalShops, 1);
    expect(progress.pickedUpCount, 0);
    expect(progress.pickedUpComplete, isFalse);
    expect(progress.pickupLabel, '0/1');
  });

  test('refresh fallback updates only the confirmed shop', () {
    final order = {
      'order_id': 52,
      'active_order_shops': [
        {
          'shop_id': 10,
          'order_status_description': 'Ready for Delivery',
        },
        {
          'shop_id': 11,
          'order_status_description': 'Ready for Delivery',
        },
      ],
    };

    final updated = markActiveOrderShopInTransit(order, 10);
    final shops = extractActiveOrderShops(updated);

    expect(shops[0]['order_status_description'], 'In-Transit');
    expect(shops[1]['order_status_description'], 'Ready for Delivery');
    expect(PickupProgress.fromOrder(updated).pickupLabel, '1/2');
  });

  test('extracts and validates drop-off coordinates', () {
    expect(
      extractDropOffLocation({
        'drop_off_coordinates': {
          'latitude': '7.4479123',
          'longitude': 125.8071234,
        },
      }),
      const LatLng(7.4479123, 125.8071234),
    );
    expect(
      extractDropOffLocation({
        'drop_off_coordinates': {'latitude': 100, 'longitude': 125},
      }),
      isNull,
    );
    expect(extractDropOffLocation(const {}), isNull);
  });

  testWidgets('partial pickup displays the fraction in step two', (
    tester,
  ) async {
    final progress = PickupProgress.fromOrder(
      orderWithStatuses(['Ready for Delivery', 'In Transit']),
    );
    await pumpProgress(tester, progress);

    expect(
      find.byKey(const ValueKey('pickup-step-picked-up-number')),
      findsOneWidget,
    );
    expect(find.text('1/2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pickup-step-in-transit-number')),
      findsOneWidget,
    );
  });

  testWidgets('all in-transit shops check Picked Up and In Transit', (
    tester,
  ) async {
    final progress = PickupProgress.fromOrder(
      orderWithStatuses(['In Transit', 'in-transit']),
    );
    await pumpProgress(tester, progress);

    expect(
      find.byKey(const ValueKey('pickup-step-picked-up-check')),
      findsOneWidget,
    );
    expect(find.text('Picked Up'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pickup-step-in-transit-check')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pickup-step-delivered-number')),
      findsOneWidget,
    );
  });

  testWidgets('delivered orders check every progression step', (tester) async {
    final progress = PickupProgress.fromOrder(
      orderWithStatuses(['Delivered']),
    );
    await pumpProgress(tester, progress);

    for (final step in ['accepted', 'picked-up', 'in-transit', 'delivered']) {
      expect(
        find.byKey(ValueKey('pickup-step-$step-check')),
        findsOneWidget,
      );
    }
  });

  testWidgets('No closes pickup confirmation without changing the shop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SelectedOrderPickupDetailScreen(
          order: {
            'order_id': 52,
            'order_code': '#ORD-TEST',
            'active_order_shops': [
              {
                'shop_id': 10,
                'order_status_description': 'Ready for Delivery',
                'shop': {
                  'id': 10,
                  'shop_name': 'Test Shop',
                  'shop_address': 'Test Address',
                },
              },
            ],
          },
        ),
      ),
    );
    await tester.pump();

    final confirmButton = find.byKey(
      const ValueKey('selected-pickup-shop-0-confirm-pickup'),
    );
    expect(confirmButton, findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-pickup-shop-0-issue')),
      findsNothing,
    );
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-pickup-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-pickup-no')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('confirm-pickup-dialog')), findsNothing);
    expect(find.text('Waiting'), findsOneWidget);
    expect(confirmButton, findsOneWidget);
  });

  testWidgets('all picked-up shops show customer delivery mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SelectedOrderPickupDetailScreen(
          order: {
            'order_id': 52,
            'order_code': '#ORD-TEST',
            'recipient_name': 'Chito Panilagan',
            'recipient_contact_number': '09328937283',
            'delivery_address': 'Purok 8, San Isidro, Tagum City',
            'drop_off_coordinates': {
              'latitude': 7.4479123,
              'longitude': 125.8071234,
            },
            'active_order_shops': [
              {
                'shop_id': 10,
                'order_status_description': 'In-Transit',
                'shop': {
                  'shop_name': 'First Shop',
                  'shop_lat': 7.42,
                  'shop_long': 125.83,
                },
              },
              {
                'shop_id': 11,
                'order_status_description': 'In Transit',
                'shop': {
                  'shop_name': 'Second Shop',
                  'shop_lat': 7.43,
                  'shop_long': 125.84,
                },
              },
            ],
          },
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('selected-delivery-sheet')),
      findsOneWidget,
    );
    expect(
        find.text('Items are collected - Ready for Delivery'), findsOneWidget);
    expect(find.text('Chito Panilagan'), findsOneWidget);
    expect(find.text('09328937283'), findsOneWidget);
    expect(find.text('Purok 8, San Isidro, Tagum City'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-delivery-confirm-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('selected-pickup-sheet')), findsNothing);

    final map = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('selected-pickup-map')),
    );
    expect(map.markers, hasLength(1));
    expect(
      map.markers.single.markerId,
      const MarkerId('selected-order-drop-off'),
    );
    expect(map.markers.single.position, const LatLng(7.4479123, 125.8071234));

    final confirmDelivery =
        find.byKey(const ValueKey('selected-delivery-confirm-button'));
    tester.widget<ElevatedButton>(confirmDelivery).onPressed!();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('confirm-delivery-screen')),
      findsOneWidget,
    );
    expect(find.text('ORD-TEST'), findsOneWidget);
  });

  testWidgets('delivery mode handles missing contact and coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SelectedOrderPickupDetailScreen(
          order: {
            'order_id': 52,
            'active_order_shops': [
              {
                'shop_id': 10,
                'order_status_description': 'In-Transit',
              },
            ],
            'drop_off_coordinates': {
              'latitude': 'invalid',
              'longitude': 125.8,
            },
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Customer unavailable'), findsOneWidget);
    expect(find.text('Contact unavailable'), findsOneWidget);
    expect(find.text('Address unavailable'), findsOneWidget);
    final map = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('selected-pickup-map')),
    );
    expect(map.markers, isEmpty);

    final contactButton =
        find.byKey(const ValueKey('selected-delivery-contact-button'));
    tester.widget<OutlinedButton>(contactButton).onPressed!();
    await tester.pump();
    expect(
      find.text('This customer does not have a contact number.'),
      findsOneWidget,
    );
  });
}
