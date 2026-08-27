import 'dart:async';

import 'package:agriconnect/screens/rider/riderAllDeliveriesScreen.dart';
import 'package:agriconnect/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOrderService extends OrderService {
  Map<String, dynamic> activeResult = {
    'orders': <Map<String, dynamic>>[],
    'count': 0
  };
  Map<String, dynamic> incomingResult = {
    'orders': <Map<String, dynamic>>[],
    'count': 0
  };
  Object? activeError;
  Object? incomingError;
  Completer<Map<String, dynamic>>? activeCompleter;
  Completer<Map<String, dynamic>>? incomingCompleter;
  Completer<Map<String, dynamic>>? acceptCompleter;
  int activeCalls = 0;
  int incomingCalls = 0;
  int acceptCalls = 0;
  String? acceptedOrderId;
  List<int>? acceptedOrderShopIds;

  @override
  Future<Map<String, dynamic>> fetchActiveDeliveries() async {
    activeCalls++;
    final completer = activeCompleter;
    if (completer != null) return completer.future;
    final error = activeError;
    if (error != null) throw error;
    return activeResult;
  }

  @override
  Future<Map<String, dynamic>> fetchReadyForDeliveryOrders() async {
    incomingCalls++;
    final completer = incomingCompleter;
    if (completer != null) return completer.future;
    final error = incomingError;
    if (error != null) throw error;
    return incomingResult;
  }

  @override
  Future<Map<String, dynamic>> acceptReadyForDeliveryOrder({
    required String orderId,
    required List<int> orderShopIds,
  }) async {
    acceptCalls++;
    acceptedOrderId = orderId;
    acceptedOrderShopIds = List<int>.from(orderShopIds);
    return acceptCompleter?.future ??
        {'success': true, 'message': 'Delivery accepted.'};
  }
}

Map<String, dynamic> _activeOrder({int id = 105}) {
  return {
    'order_id': id,
    'order_code': 'ORD-20451',
    'ordered_at': '2026-07-10T11:51:00+08:00',
    'status_label': 'In Progress',
    'recipient_name': 'Maria Santos',
    'delivery_address': 'Purok 21, Madaum, Tagum City',
    'pickup_store_count': 3,
    'item_count': 7,
    'rate': 80,
    'active_order_shops': const [],
  };
}

Map<String, dynamic> _incomingOrder({int id = 203}) {
  return {
    'order_id': id,
    'order_code': 'ORD-20313',
    'ordered_at': '2026-07-10T11:51:00+08:00',
    'recipient_name': 'Chito Panilagan',
    'delivery_address': 'Purok 8, San Isidro, Tagum City',
    'pickup_store_count': 2,
    'item_count': 2,
    'rate': 80,
    'available_order_shops': const [
      {'order_shop_id': 41},
      {'order_shop_id': 42},
    ],
  };
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeOrderService service,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: RiderAllDeliveriesScreen(orderService: service),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('loads both counts and defaults to the active vertical list', (
    tester,
  ) async {
    final service = _FakeOrderService()
      ..activeResult = {
        'orders': [_activeOrder(), _activeOrder(id: 106)],
        'count': 4,
      }
      ..incomingResult = {
        'orders': [_incomingOrder()],
        'count': 3,
      };

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();

    expect(find.text('All Delivery'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('all-delivery-title')),
      findsOneWidget,
    );
    expect(service.activeCalls, 1);
    expect(service.incomingCalls, 1);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('active-delivery-tab-count')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('active-delivery-tab-count')),
          )
          .height,
      18,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('incoming-delivery-tab-count')),
          )
          .height,
      18,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('incoming-delivery-tab-count')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active-delivery-screen-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('incoming-delivery-screen-list')),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('active-delivery-card-105')))
          .width,
      358,
    );
    final activeCard = tester.widget<Container>(
      find.byKey(const ValueKey('active-delivery-card-105')),
    );
    expect(activeCard.padding, const EdgeInsets.all(18));
    expect(
      tester.widget<Text>(find.text('ORD-20451').first).style?.fontSize,
      16,
    );
    expect(find.text('All Deliveries'), findsNothing);
  });

  testWidgets('switches to the full-width blue incoming list', (tester) async {
    final service = _FakeOrderService()
      ..activeResult = {
        'orders': [_activeOrder()],
        'count': 1,
      }
      ..incomingResult = {
        'orders': [_incomingOrder()],
        'count': 1,
      };

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('incoming-delivery-tab')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('incoming-delivery-screen-list')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('incoming-delivery-card-203')))
          .width,
      358,
    );
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('keeps loading and error retry states independent',
      (tester) async {
    final incomingCompleter = Completer<Map<String, dynamic>>();
    final service = _FakeOrderService()
      ..activeError = Exception('Active delivery request failed.')
      ..incomingCompleter = incomingCompleter;

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('active-delivery-screen-error')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('incoming-delivery-tab')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('incoming-delivery-screen-loading')),
      findsOneWidget,
    );

    incomingCompleter
        .complete({'orders': <Map<String, dynamic>>[], 'count': 0});
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('incoming-delivery-screen-empty')),
      findsOneWidget,
    );

    service.activeError = null;
    service.activeResult = {
      'orders': [_activeOrder()],
      'count': 1,
    };
    await tester.tap(find.byKey(const ValueKey('active-delivery-tab')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('active-delivery-screen-retry')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ORD-20451'), findsOneWidget);
    expect(service.activeCalls, 2);
  });

  testWidgets('pull to refresh reloads both APIs', (tester) async {
    final service = _FakeOrderService()
      ..activeResult = {
        'orders': [_activeOrder()],
        'count': 1,
      }
      ..incomingResult = {
        'orders': [_incomingOrder()],
        'count': 1,
      };

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('active-delivery-screen-list')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();

    expect(service.activeCalls, 2);
    expect(service.incomingCalls, 2);
  });

  testWidgets('Continue passes the selected order and refreshes on return', (
    tester,
  ) async {
    final selectedOrder = _activeOrder();
    final service = _FakeOrderService()
      ..activeResult = {
        'orders': [selectedOrder],
        'count': 1,
      };

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('active-delivery-continue-105')),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final selectedOrderCode = find.byKey(
      const ValueKey('selected-pickup-order-code'),
      skipOffstage: false,
    );
    expect(selectedOrderCode, findsOneWidget);
    expect(tester.widget<Text>(selectedOrderCode).data, 'ORD-20451');

    Navigator.of(tester.element(selectedOrderCode)).pop(false);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(service.activeCalls, 2);
    expect(service.incomingCalls, 2);
  });

  testWidgets(
      'Accept confirms once, sends shop IDs, shows progress, and refreshes', (
    tester,
  ) async {
    final acceptCompleter = Completer<Map<String, dynamic>>();
    final service = _FakeOrderService()
      ..incomingResult = {
        'orders': [_incomingOrder()],
        'count': 1,
      }
      ..acceptCompleter = acceptCompleter;

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('incoming-delivery-tab')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('incoming-delivery-accept-203')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accept ORD-20313? You will pick up from 2 stores.'),
        findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('delivery-acceptance-accept-button')),
    );
    await tester.pump();

    expect(service.acceptCalls, 1);
    expect(service.acceptedOrderId, '203');
    expect(service.acceptedOrderShopIds, [41, 42]);
    expect(
      find.byKey(const ValueKey('incoming-delivery-accept-spinner')),
      findsOneWidget,
    );
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('incoming-delivery-accept-203')),
    );
    expect(button.onPressed, isNull);

    acceptCompleter.complete({'success': true});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Delivery Accepted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(service.acceptCalls, 1);
    expect(service.activeCalls, 2);
    expect(service.incomingCalls, 2);
  });
}
