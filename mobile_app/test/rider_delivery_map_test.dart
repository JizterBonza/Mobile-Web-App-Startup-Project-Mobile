import 'package:agriconnect/screens/rider/riderDeliveryMap.dart';
import 'package:agriconnect/services/directions_service.dart';
import 'package:agriconnect/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Map<String, dynamic> _deliveryOrder({
  int orderId = 52,
  List<String> statuses = const <String>['In Transit'],
  dynamic latitude = 7.42,
  dynamic longitude = 125.83,
}) {
  return <String, dynamic>{
    'order_id': orderId,
    'order_code': '#ORD-$orderId',
    'ordered_at': '2026-09-01T08:30:00',
    'recipient_name': 'Customer $orderId',
    'recipient_contact_number': '09123456789',
    'delivery_address': 'Delivery Address $orderId',
    'pickup_store_count': statuses.length,
    'item_count': 3,
    'drop_off_coordinates': <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    },
    'active_order_shops': statuses
        .asMap()
        .entries
        .map(
          (entry) => <String, dynamic>{
            'order_shop_id': orderId * 10 + entry.key,
            'shop_id': entry.key + 1,
            'order_status_description': entry.value,
          },
        )
        .toList(),
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
}

DirectionsRoute _route() {
  return DirectionsRoute(
    polylinePoints: const <LatLng>[
      LatLng(7.4, 125.8),
      LatLng(7.42, 125.83),
      LatLng(7.44, 125.85),
    ],
    totalDistance: '8.4 km',
    totalDuration: '24 min',
    bounds: LatLngBounds(
      southwest: const LatLng(7.4, 125.8),
      northeast: const LatLng(7.44, 125.85),
    ),
    legs: const <RouteLeg>[],
  );
}

void main() {
  test('includes only active orders that are ready for customer delivery', () {
    final inTransit = _deliveryOrder();
    final partiallyDelivered = _deliveryOrder(
      orderId: 53,
      statuses: const <String>['Delivered', 'in-transit'],
    );
    final stillForPickup = _deliveryOrder(
      orderId: 54,
      statuses: const <String>['Ready for Delivery', 'In Transit'],
    );
    final delivered = _deliveryOrder(
      orderId: 55,
      statuses: const <String>['Delivered', 'Delivered'],
    );
    final malformed = _deliveryOrder(
      orderId: 56,
      statuses: const <String>['Unknown'],
    );

    final orders = extractDeliveryMapOrders(<dynamic>[
      inTransit,
      partiallyDelivered,
      stillForPickup,
      delivered,
      malformed,
      inTransit,
      null,
      'invalid',
    ]);

    expect(orders.map((order) => order['order_id']), <int>[52, 53]);
  });

  test('creates stable drop-off markers and skips invalid coordinates', () {
    final points = extractDeliveryMapPoints(<Map<String, dynamic>>[
      _deliveryOrder(),
      _deliveryOrder(orderId: 53, latitude: 'invalid'),
    ]);

    expect(points, hasLength(1));
    expect(points.single.markerId, 'delivery-order-52');
    expect(points.single.position, const LatLng(7.42, 125.83));
  });

  testWidgets('renders all in-transit orders with Active Delivery cards', (
    tester,
  ) async {
    final orders = <Map<String, dynamic>>[
      _deliveryOrder(),
      _deliveryOrder(orderId: 53, latitude: 'invalid'),
      _deliveryOrder(
        orderId: 54,
        statuses: const <String>['Ready for Delivery'],
      ),
    ];
    final service = _FakeOrderService(orders);

    await tester.pumpWidget(
      MaterialApp(home: RiderDeliveryMapScreen(orderService: service)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('all-deliveries-map')), findsOneWidget);
    expect(find.text('2 deliveries'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delivery-map-refresh')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('delivery-map-fit-all')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('delivery-map-route')), findsOneWidget);
    expect(find.text('Route'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.my_location), findsNothing);
    expect(find.text('Customer drop-off'), findsOneWidget);
    expect(find.text('You'), findsNothing);

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.initialChildSize, 0.38);
    expect(sheet.minChildSize, 0.18);
    expect(sheet.maxChildSize, 0.86);
    expect(
      find.byKey(const ValueKey('active-delivery-card-54')),
      findsNothing,
    );

    final map = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('all-deliveries-map')),
    );
    expect(map.markers, hasLength(1));
    expect(
      map.markers.single.markerId,
      const MarkerId('delivery-order-52'),
    );

    await tester.drag(
      find.byKey(const ValueKey('delivery-map-sheet')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue Delivery'), findsNWidgets(2));
    expect(find.text('In Transit'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('active-delivery-card-53')),
      findsOneWidget,
    );
  });

  testWidgets('card opens the existing in-transit Active Delivery detail', (
    tester,
  ) async {
    final order = _deliveryOrder();
    final service = _FakeOrderService(<Map<String, dynamic>>[order]);

    await tester.pumpWidget(
      MaterialApp(home: RiderDeliveryMapScreen(orderService: service)),
    );
    await tester.pump();

    tester
        .widget<ElevatedButton>(
          find.byKey(const ValueKey('active-delivery-continue-52')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('selected-delivery-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-delivery-confirm-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('selected-pickup-sheet')), findsNothing);
  });

  testWidgets('return keeps cached delivery points when refresh fails', (
    tester,
  ) async {
    final order = _deliveryOrder();
    final service = _FakeOrderService(<Map<String, dynamic>>[order])
      ..failActiveCall = 2;

    await tester.pumpWidget(
      MaterialApp(home: RiderDeliveryMapScreen(orderService: service)),
    );
    await tester.pump();

    tester
        .widget<ElevatedButton>(
          find.byKey(const ValueKey('active-delivery-continue-52')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('selected-pickup-back')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('all-deliveries-map')), findsOneWidget);
    expect(find.text('Continue Delivery'), findsOneWidget);
    expect(find.text('Unable to load delivery points'), findsNothing);
    expect(
      find.textContaining('Unable to refresh delivery points.'),
      findsOneWidget,
    );
  });

  testWidgets('automatically routes through every valid customer drop-off', (
    tester,
  ) async {
    final orders = <Map<String, dynamic>>[
      _deliveryOrder(),
      _deliveryOrder(
        orderId: 53,
        latitude: 7.44,
        longitude: 125.85,
      ),
    ];
    final service = _FakeOrderService(orders);
    var routeCalls = 0;
    List<LatLng>? routedDropOffs;

    await tester.pumpWidget(
      MaterialApp(
        home: RiderDeliveryMapScreen(
          orderService: service,
          initialRiderLocation: const LatLng(7.4, 125.8),
          routeLoader: ({
            required riderLocation,
            required dropOffLocations,
          }) async {
            routeCalls++;
            routedDropOffs = dropOffLocations;
            return _route();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(routeCalls, 1);
    expect(routedDropOffs, hasLength(2));
    final map = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('all-deliveries-map')),
    );
    final route = map.polylines.single;
    expect(route.polylineId, const PolylineId('all-deliveries-route'));
    expect(route.color, const Color(0xFF1268E8));
    expect(route.width, 6);
    expect(find.text('Hide route'), findsOneWidget);
    expect(find.text('Customer drop-off'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.textContaining('8.4 km'), findsNothing);
    expect(find.textContaining('24 min'), findsNothing);
    expect(
      find.byKey(const ValueKey('delivery-map-route-summary')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('delivery-map-route')));
    await tester.pump();
    expect(find.text('Route'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delivery-map-route-summary')),
      findsNothing,
    );
    final hiddenRouteMap = tester.widget<GoogleMap>(
      find.byKey(const ValueKey('all-deliveries-map')),
    );
    expect(hiddenRouteMap.polylines, isEmpty);
  });
}
