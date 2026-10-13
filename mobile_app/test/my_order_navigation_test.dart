import 'package:agriconnect/provider/badge_provider.dart';
import 'package:agriconnect/provider/order_status_provider.dart';
import 'package:agriconnect/provider/orders_provider.dart';
import 'package:agriconnect/screens/common/myOrderScreen.dart';
import 'package:agriconnect/screens/common/orderDetailScreen.dart';
import 'package:agriconnect/widgets/order/order_status_navigation.dart';
import 'package:agriconnect/widgets/skeletons/app_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _statuses = {
  1: 'Pending',
  2: 'Preparing',
  3: 'Ready for Delivery',
  4: 'In Transit',
  5: 'Delivered',
  6: 'Cancelled',
  7: 'ready-for-delivery',
};

class _Orders extends OrdersProvider {
  _Orders({this.testOrders});

  final List<Map<String, dynamic>>? testOrders;
  int fetchCount = 0;
  bool loading = false;
  bool? lastUseCache;
  String? testError;

  @override
  List<Map<String, dynamic>> get orders => loading
      ? []
      : testOrders ??
          _statuses.entries
              .map((entry) => <String, dynamic>{
                    'id': entry.key.toString(),
                    'order_code': 'TEST-${entry.key}',
                    'order_status':
                        entry.key.isEven ? '${entry.key}' : entry.key,
                    'ordered_at': '2026-10-12T10:00:00+08:00',
                    'order_items': <dynamic>[],
                    'total_amount': 100,
                  })
              .toList();

  @override
  bool get isLoading => loading;

  @override
  String? get error => testError;

  @override
  Future<void> fetchOrders({String? status, bool useCache = true}) async {
    fetchCount++;
    lastUseCache = useCache;
  }

  void startLoading() {
    loading = true;
    notifyListeners();
  }

  void finishLoading({String? error}) {
    loading = false;
    testError = error;
    notifyListeners();
  }
}

Map<String, dynamic> _order(String code, dynamic status, dynamic method) => {
      'id': code,
      'order_code': code,
      'order_status': status,
      'delivery_method_id': method,
      'ordered_at': '2026-10-12T10:00:00+08:00',
      'order_items': <dynamic>[],
      'total_amount': 100,
    };

class _Statuses extends OrderStatusProvider {
  int fetchCount = 0;

  @override
  Future<void> fetchAndCacheOrderStatuses() async {
    fetchCount++;
  }

  @override
  String? getOrderStatusDescription(int statusId) => _statuses[statusId];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpOrders(
    WidgetTester tester,
    _Orders orders,
    _Statuses statuses, {
    bool bottomNav = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<OrdersProvider>.value(value: orders),
        ChangeNotifierProvider<OrderStatusProvider>.value(value: statuses),
        ChangeNotifierProvider(create: (_) => BadgeProvider()),
      ],
      child: MaterialApp(
        home: MyOrderScreen(showCustomerBottomNav: bottomNav),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> selectTab(WidgetTester tester, int index) async {
    tester
        .widget<TabBarView>(find.byType(TabBarView))
        .controller!
        .animateTo(index);
    await tester.pumpAndSettle();
  }

  for (final bottomNav in [false, true]) {
    testWidgets(
        'pickup empty state loads, refreshes and retries (bottom nav: $bottomNav)',
        (tester) async {
      final orders = _Orders();
      final statuses = _Statuses();
      await pumpOrders(tester, orders, statuses, bottomNav: bottomNav);
      final navigation = tester.widget<OrderStatusNavigation>(
        find.byType(OrderStatusNavigation),
      );
      expect(navigation.selectedIndex, 0);
      expect(navigation.items.map((item) => item.label), [
        'All',
        'Pending',
        'Preparing',
        'To Pickup',
        'To Deliver',
        'Delivered',
        'Cancelled',
      ]);
      expect(navigation.items[3].iconPath, 'assets/icons/box.svg');
      expect(find.text('No: TEST-1'), findsOneWidget);
      expect(orders.fetchCount, 1);
      expect(statuses.fetchCount, 1);
      final bottomNavigation = find.byType(BottomNavigationBar);
      expect(bottomNavigation, bottomNav ? findsOneWidget : findsNothing);

      await tester.tap(find.text('To Pickup'));
      await tester.pumpAndSettle();
      expect(find.text('No pickup orders'), findsOneWidget);
      expect(find.textContaining('No: TEST-'), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.drag(
          find.ancestor(
            of: find.text('No pickup orders'),
            matching: find.byType(SingleChildScrollView),
          ),
          const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(orders.fetchCount, 2);
      expect(orders.lastUseCache, isFalse);

      orders.startLoading();
      await tester.pump();
      expect(find.text('No pickup orders'), findsNothing);
      expect(find.byType(OrderListSkeleton), findsOneWidget);

      orders.finishLoading(error: 'Connection failed');
      await tester.pumpAndSettle();
      expect(find.text('Failed to load orders'), findsOneWidget);
      expect(find.text('No pickup orders'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(orders.fetchCount, 3);
      expect(orders.lastUseCache, isFalse);

      orders.finishLoading();
      await tester.pumpAndSettle();
      await selectTab(tester, 2);
      await tester.drag(find.byType(TabBarView), const Offset(-750, 0));
      await tester.pumpAndSettle();
      expect(find.text('No pickup orders'), findsOneWidget);
      expect(orders.fetchCount, 3);
      expect(statuses.fetchCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pickup placement and details (bottom nav: $bottomNav)',
        (tester) async {
      final orders = _Orders(testOrders: [
        _order('PICKUP', 3, 3),
        _order('DELIVERY', 3, 1),
      ]);
      await pumpOrders(tester, orders, _Statuses(), bottomNav: bottomNav);
      expect(find.text('No: PICKUP'), findsOneWidget);
      await tester.tap(find.text('To Pickup'));
      await tester.pumpAndSettle();
      expect(find.text('No: PICKUP'), findsOneWidget);
      expect(find.text('No: DELIVERY'), findsNothing);
      await selectTab(tester, 4);
      expect(find.text('No: PICKUP'), findsNothing);
      expect(find.text('No: DELIVERY'), findsOneWidget);
      await selectTab(tester, 3);
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(
          tester
              .widget<OrderDetailScreen>(find.byType(OrderDetailScreen))
              .order['order_code'],
          'PICKUP');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pickup requires both IDs and accepts numeric strings',
      (tester) async {
    final orders = _Orders(testOrders: [
      _order('STRING', '3', '3'),
      _order('NUMBER', 3.0, 3.0),
      _order('PREPARING', 2, 3),
      _order('DELIVERY', 3, 1),
      _order('MISSING-METHOD', 3, null),
      _order('MISSING-STATUS', null, 3),
      _order('INVALID-METHOD', 3, 'invalid'),
      _order('INVALID-STATUS', 'invalid', 3),
    ]);
    await pumpOrders(tester, orders, _Statuses());
    await selectTab(tester, 3);
    for (final order in orders.orders) {
      expect(
          find.text('No: ${order['order_code']}'),
          ['STRING', 'NUMBER'].contains(order['order_code'])
              ? findsOneWidget
              : findsNothing);
    }
    expect(orders.fetchCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves the original filters and ready-for-delivery alias',
      (tester) async {
    final orders = _Orders();
    final statuses = _Statuses();
    await pumpOrders(tester, orders, statuses);
    const expectedOrders = {
      1: [1],
      2: [2],
      4: [3, 4, 7],
      5: [5],
      6: [6],
    };
    for (final entry in expectedOrders.entries) {
      await selectTab(tester, entry.key);
      for (final statusId in _statuses.keys) {
        expect(
          find.text('No: TEST-$statusId'),
          entry.value.contains(statusId) ? findsOneWidget : findsNothing,
          reason: 'Filter ${entry.key}, order $statusId',
        );
      }
    }
    await selectTab(tester, 0);
    expect(find.text('No: TEST-1'), findsOneWidget);
    expect(orders.fetchCount, 1);
    expect(statuses.fetchCount, 1);
    expect(tester.takeException(), isNull);
  });
}
