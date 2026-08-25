import 'package:agriconnect/widgets/active_deliveries_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> order({
    int id = 105,
    dynamic rate,
    dynamic pickupCount = 2,
    dynamic itemCount = 7,
    String? statusLabel = 'In Progress',
    dynamic status = 'in_progress',
    dynamic activeOrderShops,
  }) {
    return {
      'order_id': id,
      'order_code': 'ORD-20451',
      'ordered_at': '2026-07-10T11:51:00+08:00',
      'status': status,
      'status_label': statusLabel,
      'recipient_name': 'Maria Santos',
      'delivery_address': 'Purok 21, Madaum, Tagum City',
      'pickup_store_count': pickupCount,
      'item_count': itemCount,
      if (rate != null) 'rate': rate,
      'active_order_shops': activeOrderShops ??
          [
            {
              'order_shop_id': 42,
              'shop_id': 7,
              'order_status_description': 'Ready for Delivery',
              'shop': {'shop_name': 'Agrify Main Shop'},
              'items': [
                {
                  'quantity': 3,
                  'item': {
                    'item_name': 'Animal Feed',
                    'item_images': 'items/feed-front.jpg',
                  },
                },
              ],
            },
          ],
    };
  }

  Future<void> pumpSection(
    WidgetTester tester, {
    required List<Map<String, dynamic>> orders,
    int count = 0,
    bool isLoading = false,
    String? error,
    VoidCallback? onRetry,
    ValueChanged<Map<String, dynamic>>? onContinue,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ActiveDeliveriesSection(
              orders: orders,
              count: count,
              isLoading: isLoading,
              error: error,
              onRetry: onRetry,
              onContinue: onContinue,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the horizontal active-delivery mockup', (tester) async {
    await pumpSection(
      tester,
      orders: [order(), order(id: 106)],
      count: 3,
    );

    expect(find.text('Active Delivery'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('ORD-20451'), findsNWidgets(2));
    expect(find.text('July 10, 2026 • 11:51am'), findsNWidgets(2));
    expect(find.text('Ready for Delivery'), findsNWidgets(2));
    expect(find.text('Maria Santos'), findsNWidgets(2));
    expect(find.text('Purok 21, Madaum, Tagum City'), findsNWidgets(2));
    expect(find.text('2 pickup stores • 7 items'), findsNWidgets(2));
    expect(find.text('Continue Delivery'), findsNWidgets(2));

    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('active-delivery-list')),
    );
    expect(list.scrollDirection, Axis.horizontal);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('active-delivery-card-105')))
          .width,
      lessThan(358),
    );
  });

  testWidgets('keeps Continue Delivery orange but disabled', (tester) async {
    var continued = false;
    await pumpSection(
      tester,
      orders: [order()],
      onContinue: null,
    );

    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('active-delivery-continue-105')),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.disabled}),
      const Color(0xFFF0A000),
    );

    await tester.tap(
      find.byKey(const ValueKey('active-delivery-continue-105')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(continued, isFalse);
  });

  testWidgets('enables Continue Delivery and returns the tapped order', (
    tester,
  ) async {
    Map<String, dynamic>? continuedOrder;
    final activeOrder = order();
    await pumpSection(
      tester,
      orders: [activeOrder],
      onContinue: (value) => continuedOrder = value,
    );

    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('active-delivery-continue-105')),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey('active-delivery-continue-105')),
    );
    await tester.pump();

    expect(identical(continuedOrder, activeOrder), isTrue);
  });

  testWidgets('hides absent rates and formats numeric rates', (tester) async {
    await pumpSection(tester, orders: [order()]);
    expect(
      find.byKey(const ValueKey('active-delivery-rate-105')),
      findsNothing,
    );
    expect(find.text('Rate'), findsNothing);

    await pumpSection(tester, orders: [order(rate: '80.00')]);
    expect(
      find.byKey(const ValueKey('active-delivery-rate-105')),
      findsOneWidget,
    );
    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('₱80'), findsOneWidget);
  });

  testWidgets('shows loading, empty, and retryable error states', (
    tester,
  ) async {
    await pumpSection(tester, orders: [], isLoading: true);
    expect(
      find.byKey(const ValueKey('active-delivery-loading')),
      findsOneWidget,
    );

    await pumpSection(tester, orders: []);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('No active deliveries'), findsOneWidget);

    var retried = false;
    await pumpSection(
      tester,
      orders: [],
      error: 'Unable to load active deliveries.',
      onRetry: () => retried = true,
    );
    expect(find.text('Unable to load active deliveries.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('active-delivery-retry')));
    expect(retried, isTrue);
  });

  testWidgets('handles fallback status, singular counts, and narrow widths', (
    tester,
  ) async {
    await pumpSection(
      tester,
      width: 320,
      orders: [
        order(
          statusLabel: '',
          activeOrderShops: const [],
          pickupCount: '1',
          itemCount: 1,
          rate: 'not-a-number',
        ),
      ],
    );

    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('1 pickup store • 1 item'), findsOneWidget);
    expect(find.text('Rate'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the first shop status and handles malformed shop data', (
    tester,
  ) async {
    await pumpSection(
      tester,
      orders: [
        order(
          activeOrderShops: const [
            {'order_status_description': 'Ready for Delivery'},
            {'order_status_description': 'In Transit'},
          ],
        ),
      ],
    );

    expect(find.text('Ready for Delivery'), findsOneWidget);
    expect(find.text('In Transit'), findsNothing);

    await pumpSection(
      tester,
      orders: [
        order(
          id: 106,
          activeOrderShops: 'invalid',
          statusLabel: 'Assigned',
        ),
      ],
    );

    expect(find.text('Assigned'), findsOneWidget);

    await pumpSection(
      tester,
      orders: [
        order(
          id: 107,
          activeOrderShops: const [],
          statusLabel: '',
          status: '',
        ),
      ],
    );

    expect(find.text('In Progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
