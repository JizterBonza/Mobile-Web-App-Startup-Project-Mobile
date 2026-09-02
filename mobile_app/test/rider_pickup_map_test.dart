import 'package:agriconnect/screens/rider/riderPickupMap.dart';
import 'package:agriconnect/screens/rider/selectedOrderPickupDetail.dart';
import 'package:agriconnect/provider/order_status_provider.dart';
import 'package:agriconnect/services/directions_service.dart';
import 'package:agriconnect/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _order({
  int orderId = 52,
  required List<Map<String, dynamic>> shops,
}) {
  return <String, dynamic>{
    'order_id': orderId,
    'order_code': '#ORD-$orderId',
    'ordered_at': '2026-09-01T08:30:00',
    'recipient_name': 'Test Customer',
    'delivery_address': 'Test Address',
    'pickup_store_count': shops.length,
    'item_count': 3,
    'active_order_shops': shops,
  };
}

Map<String, dynamic> _shop({
  required int orderShopId,
  required int shopId,
  required String status,
  dynamic latitude = 7.42,
  dynamic longitude = 125.83,
}) {
  return <String, dynamic>{
    'order_shop_id': orderShopId,
    'shop_id': shopId,
    'order_status_description': status,
    'shop': <String, dynamic>{
      'id': shopId,
      'shop_name': 'Shop $shopId',
      'shop_address': 'Address $shopId',
      'shop_lat': latitude,
      'shop_long': longitude,
    },
  };
}

class _FakeOrderService extends OrderService {
  _FakeOrderService(this.orders);

  final List<Map<String, dynamic>> orders;
  int activeCalls = 0;
  int? failActiveCall;

  @override
  Future<Map<String, dynamic>> fetchActiveDeliveries() async {
    activeCalls++;
    if (activeCalls == failActiveCall) {
      throw Exception('Temporary refresh failure');
    }
    return <String, dynamic>{'orders': orders, 'count': orders.length};
  }

  @override
  Future<Map<String, dynamic>> fetchActiveDeliveryByOrderId(int orderId) async {
    return orders.firstWhere((order) => order['order_id'] == orderId);
  }

  @override
  Future<Map<String, dynamic>> updateShopOrderStatus({
    required int orderId,
    required int shopId,
    required int statusId,
    required String notes,
  }) async {
    final index = orders.indexWhere((order) => order['order_id'] == orderId);
    if (index < 0) {
      return <String, dynamic>{'success': false, 'message': 'Missing order'};
    }
    orders[index] = markActiveOrderShopInTransit(orders[index], shopId);
    return <String, dynamic>{'success': true, 'message': 'Updated'};
  }
}

class _FakeOrderStatusProvider extends OrderStatusProvider {
  @override
  int? getOrderStatusIdByDescription(String description) => 5;
}

DirectionsRoute _route({
  required String distance,
  required String duration,
  required double offset,
}) {
  return DirectionsRoute(
    polylinePoints: <LatLng>[
      const LatLng(7.4, 125.8),
      LatLng(7.42 + offset, 125.83 + offset),
    ],
    totalDistance: distance,
    totalDuration: duration,
    bounds: LatLngBounds(
      southwest: const LatLng(7.4, 125.8),
      northeast: LatLng(7.42 + offset, 125.83 + offset),
    ),
    legs: const <RouteLeg>[],
  );
}

void main() {
  test('keeps partial orders and excludes completed or invalid statuses', () {
    final partial = _order(
      shops: <Map<String, dynamic>>[
        _shop(
          orderShopId: 101,
          shopId: 10,
          status: 'Ready-for-Delivery',
        ),
        _shop(orderShopId: 102, shopId: 11, status: 'In Transit'),
      ],
    );
    final completed = _order(
      orderId: 53,
      shops: <Map<String, dynamic>>[
        _shop(orderShopId: 103, shopId: 12, status: 'Delivered'),
      ],
    );
    final cancelled = _order(
      orderId: 54,
      shops: <Map<String, dynamic>>[
        _shop(orderShopId: 104, shopId: 13, status: 'Cancelled'),
      ],
    );

    final orders = extractPickupMapOrders(<dynamic>[
      partial,
      completed,
      cancelled,
      null,
      'invalid',
    ]);

    expect(orders, hasLength(1));
    expect(orders.single['order_id'], 52);
    expect(extractPendingPickupShops(orders.single), hasLength(1));
  });

  test('creates stable markers only for valid pending shop coordinates', () {
    final orders = <Map<String, dynamic>>[
      _order(
        shops: <Map<String, dynamic>>[
          _shop(
            orderShopId: 101,
            shopId: 10,
            status: 'Ready for Delivery',
          ),
          _shop(
            orderShopId: 102,
            shopId: 11,
            status: 'Ready for Delivery',
            latitude: 'invalid',
          ),
          _shop(orderShopId: 103, shopId: 12, status: 'In-Transit'),
        ],
      ),
    ];

    final points = extractPickupMapPoints(orders);

    expect(points, hasLength(1));
    expect(points.single.markerId, 'pickup-order-shop-101');
    expect(points.single.shopId, 10);
    expect(points.single.position, const LatLng(7.42, 125.83));
  });

  test('suggests the pickup closest to the rider', () {
    final orders = <Map<String, dynamic>>[
      _order(
        shops: <Map<String, dynamic>>[
          _shop(
            orderShopId: 101,
            shopId: 10,
            status: 'Ready for Delivery',
            latitude: 7.8,
            longitude: 126.0,
          ),
          _shop(
            orderShopId: 102,
            shopId: 11,
            status: 'Ready for Delivery',
            latitude: 7.41,
            longitude: 125.81,
          ),
        ],
      ),
    ];

    final suggested = suggestNextPickupPoint(
      const LatLng(7.4, 125.8),
      extractPickupMapPoints(orders),
    );

    expect(suggested?.shopId, 11);
  });

  testWidgets('overview renders remaining pickups using active delivery cards',
      (
    tester,
  ) async {
    final partialOrder = _order(
      shops: <Map<String, dynamic>>[
        _shop(
          orderShopId: 101,
          shopId: 10,
          status: 'Ready for Delivery',
        ),
        _shop(orderShopId: 102, shopId: 11, status: 'In Transit'),
      ],
    );
    final service = _FakeOrderService(<Map<String, dynamic>>[partialOrder]);

    await tester.pumpWidget(
      MaterialApp(home: RiderPickupMapScreen(orderService: service)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('all-pickups-map')), findsOneWidget);
    expect(find.text('1 pickup point'), findsOneWidget);
    expect(find.text('Continue Pickup'), findsOneWidget);
    final map = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('all-pickups-map')),
    );
    expect(map.markers, hasLength(1));
    expect(
      map.markers.single.markerId,
      const MarkerId('pickup-order-shop-101'),
    );
  });

  testWidgets('renders route lines without primary or alternative buttons', (
    tester,
  ) async {
    final pendingOrder = _order(
      shops: <Map<String, dynamic>>[
        _shop(
          orderShopId: 101,
          shopId: 10,
          status: 'Ready for Delivery',
        ),
      ],
    );
    final service = _FakeOrderService(<Map<String, dynamic>>[pendingOrder]);
    final routes = <DirectionsRoute>[
      _route(distance: '4.2 km', duration: '12 min', offset: 0),
      _route(distance: '4.8 km', duration: '14 min', offset: 0.01),
    ];
    var routeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: RiderPickupMapScreen(
          orderService: service,
          initialRiderLocation: const LatLng(7.4, 125.8),
          routeLoader: ({required origin, required destination}) async {
            routeCalls++;
            return routes;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(routeCalls, 1);

    final map = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('all-pickups-map')),
    );
    final primary = map.polylines.singleWhere(
      (line) => line.polylineId == const PolylineId('pickup-route-0'),
    );
    final alternative = map.polylines.singleWhere(
      (line) => line.polylineId == const PolylineId('pickup-route-1'),
    );
    expect(primary.color, const Color(0xFF1268E8));
    expect(primary.width, 6);
    expect(alternative.color, const Color(0xFF8D949E));
    expect(alternative.width, 3);
    expect(
      find.byKey(const ValueKey('pickup-route-selector')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('pickup-route-options')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('pickup-route-option-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('pickup-route-option-1')),
      findsNothing,
    );
  });

  testWidgets('pickup-only detail never switches to customer delivery mode', (
    tester,
  ) async {
    final completedOrder = _order(
      shops: <Map<String, dynamic>>[
        _shop(orderShopId: 101, shopId: 10, status: 'In Transit'),
      ],
    );
    final service = _FakeOrderService(<Map<String, dynamic>>[completedOrder]);

    await tester.pumpWidget(
      MaterialApp(
        home: SelectedOrderPickupDetailScreen(
          order: completedOrder,
          pickupOnly: true,
          orderService: service,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('selected-pickup-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-delivery-sheet')), findsNothing);
    final map = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('selected-pickup-map')),
    );
    expect(map.markers, isEmpty);
  });

  testWidgets('back keeps cached pickup points when refresh fails', (
    tester,
  ) async {
    final pendingOrder = _order(
      shops: <Map<String, dynamic>>[
        _shop(
          orderShopId: 101,
          shopId: 10,
          status: 'Ready for Delivery',
        ),
      ],
    );
    final service = _FakeOrderService(<Map<String, dynamic>>[pendingOrder])
      ..failActiveCall = 2;

    await tester.pumpWidget(
      MaterialApp(home: RiderPickupMapScreen(orderService: service)),
    );
    await tester.pump();

    tester
        .widget<ElevatedButton>(
          find.byKey(const ValueKey('active-delivery-continue-52')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-pickup-sheet')), findsOneWidget);

    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('selected-pickup-back')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('all-pickups-map')), findsOneWidget);
    expect(find.text('Continue Pickup'), findsOneWidget);
    expect(find.text('Unable to load pickup points'), findsNothing);
    expect(
      find.textContaining('Unable to refresh pickup points.'),
      findsOneWidget,
    );
  });

  testWidgets('final pickup returns to overview and removes the order', (
    tester,
  ) async {
    final pendingOrder = _order(
      shops: <Map<String, dynamic>>[
        _shop(
          orderShopId: 101,
          shopId: 10,
          status: 'Ready for Delivery',
        ),
      ],
    );
    final service = _FakeOrderService(<Map<String, dynamic>>[pendingOrder]);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderStatusProvider>.value(
        value: _FakeOrderStatusProvider(),
        child: MaterialApp(
          home: RiderPickupMapScreen(orderService: service),
        ),
      ),
    );
    await tester.pump();

    final continuePickup = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('active-delivery-continue-52')),
    );
    continuePickup.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-pickup-sheet')), findsOneWidget);

    final confirmPickup = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('selected-pickup-shop-0-confirm-pickup')),
    );
    confirmPickup.onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-pickup-yes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('all-pickups-sheet')), findsOneWidget);
    expect(find.text('No pickups available'), findsOneWidget);
    expect(find.text('All pickup points completed.'), findsOneWidget);
    final map = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('all-pickups-map')),
    );
    expect(map.markers, isEmpty);
  });
}
