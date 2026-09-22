import 'package:agriconnect/widgets/incoming_delivery_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> order({
    int id = 105,
    String code = 'ORD-20313',
    dynamic rate,
    int pickupCount = 2,
    int itemCount = 3,
  }) {
    return {
      'order_id': id,
      'order_code': code,
      'ordered_at': '2026-07-10T11:51:00+08:00',
      'recipient_name': 'Chito Panilagan',
      'delivery_address': 'Purok 8, San Isidro, Tagum City',
      'pickup_store_count': pickupCount,
      'item_count': itemCount,
      if (rate != null) 'rate': rate,
      'available_order_shops': const [],
    };
  }

  Future<void> pumpSection(
    WidgetTester tester, {
    required List<Map<String, dynamic>> orders,
    int? count,
    double width = 390,
    ValueChanged<Map<String, dynamic>>? onAccept,
    Set<String> acceptingOrderIds = const {},
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: IncomingDeliverySection(
              orders: orders,
              count: count ?? orders.length,
              onAccept: onAccept,
              acceptingOrderIds: acceptingOrderIds,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders mockup content in a horizontal blue card list',
      (tester) async {
    await pumpSection(
      tester,
      orders: [
        order(),
        order(id: 106, code: 'ORD-20314', pickupCount: 1, itemCount: 1),
      ],
      count: 2,
    );

    expect(find.text('Incoming Delivery'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('ORD-20313'), findsOneWidget);
    expect(find.text('July 10, 2026 • 11:51am'), findsNWidgets(2));
    expect(find.text('Chito Panilagan'), findsNWidgets(2));
    expect(find.text('Purok 8, San Isidro, Tagum City'), findsNWidgets(2));
    expect(find.text('2 pickup stores • 3 items'), findsOneWidget);
    expect(find.text('1 pickup store • 1 item'), findsOneWidget);
    expect(find.text('New'), findsNWidgets(2));
    expect(find.text('Accept'), findsNWidgets(2));

    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('incoming-delivery-list')),
    );
    expect(list.scrollDirection, Axis.horizontal);

    final firstCard = tester.widget<Container>(
      find.byKey(const ValueKey('incoming-delivery-card-105')),
    );
    final decoration = firstCard.decoration! as BoxDecoration;
    expect(decoration.border, isA<Border>());
    expect((decoration.border! as Border).top.color, const Color(0xFF66B5FF));

    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('incoming-delivery-accept-105')),
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF0A8CFF),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('incoming-delivery-card-105')))
          .width,
      lessThan(358),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides rate when absent and accepts with no callback',
      (tester) async {
    await pumpSection(tester, orders: [order()]);

    expect(find.text('Rate'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('incoming-delivery-accept-105')),
    );
    await tester.pump();

    expect(find.byType(IncomingDeliverySection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('passes the selected order to the accept callback',
      (tester) async {
    final expectedOrder = order();
    Map<String, dynamic>? acceptedOrder;
    await pumpSection(
      tester,
      orders: [expectedOrder],
      onAccept: (value) => acceptedOrder = value,
    );

    await tester.tap(
      find.byKey(const ValueKey('incoming-delivery-accept-105')),
    );
    await tester.pump();

    expect(acceptedOrder, same(expectedOrder));
  });

  testWidgets('disables and shows a spinner for an accepting order',
      (tester) async {
    await pumpSection(
      tester,
      orders: [order()],
      acceptingOrderIds: const {'105'},
    );

    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('incoming-delivery-accept-105')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.byKey(const ValueKey('incoming-delivery-accept-spinner')),
      findsOneWidget,
    );
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('formats numeric and numeric-string rates', (tester) async {
    await pumpSection(
      tester,
      orders: [
        order(rate: 80),
        order(id: 106, code: 'ORD-20314', rate: '95.50'),
      ],
    );

    expect(find.text('Rate'), findsNWidgets(2));
    expect(find.text('₱80'), findsOneWidget);
    expect(find.text('₱95.50'), findsOneWidget);
  });

  testWidgets('renders nothing for an empty order list', (tester) async {
    await pumpSection(tester, orders: const [], count: 0);

    expect(find.text('Incoming Delivery'), findsNothing);
    expect(
      find.byKey(const ValueKey('incoming-delivery-section')),
      findsNothing,
    );
  });

  testWidgets('handles narrow widths and malformed optional fields',
      (tester) async {
    final malformed = order()
      ..['ordered_at'] = 'Unknown delivery date'
      ..['pickup_store_count'] = 'bad'
      ..['item_count'] = null
      ..['rate'] = 'not-a-number';

    await pumpSection(tester, orders: [malformed], count: -1, width: 320);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Unknown delivery date'), findsOneWidget);
    expect(find.text('0 pickup stores • 0 items'), findsOneWidget);
    expect(find.text('Rate'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes a leading hash from the displayed order code', (
    tester,
  ) async {
    final incomingOrder = order()..['order_code'] = '#ORD-20313';
    await pumpSection(tester, orders: [incomingOrder]);

    expect(find.text('ORD-20313'), findsOneWidget);
    expect(find.text('#ORD-20313'), findsNothing);
  });
}
