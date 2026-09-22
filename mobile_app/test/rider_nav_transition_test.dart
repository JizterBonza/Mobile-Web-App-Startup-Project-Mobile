import 'package:agriconnect/provider/orders_provider.dart';
import 'package:agriconnect/screens/rider/riderAllDeliveriesScreen.dart';
import 'package:agriconnect/services/order_service.dart';
import 'package:agriconnect/utils/rider_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeOrdersProvider extends OrdersProvider {
  @override
  List<Map<String, dynamic>> get orders => const [];

  @override
  String? get error => null;

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchRiderOrders({String? status, bool useCache = true}) async {}
}

class _FakeOrderService extends OrderService {
  @override
  Future<Map<String, dynamic>> fetchActiveDeliveries() async =>
      {'orders': <Map<String, dynamic>>[], 'count': 0};

  @override
  Future<Map<String, dynamic>> fetchReadyForDeliveryOrders() async =>
      {'orders': <Map<String, dynamic>>[], 'count': 0};
}

class _RouteLog extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;
  int replacements = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes++;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      replacements++;
}

void main() {
  setUp(riderDashboardTab.reset);

  Future<_RouteLog> pumpDeliveriesOverDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final log = _RouteLog();
    await tester.pumpWidget(
      ChangeNotifierProvider<OrdersProvider>.value(
        value: _FakeOrdersProvider(),
        child: MaterialApp(
          navigatorObservers: [log],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    riderFadeRoute(
                      RiderAllDeliveriesScreen(
                        orderService: _FakeOrderService(),
                      ),
                    ),
                  ),
                  child: const Text('open deliveries'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open deliveries'));
    await tester.pumpAndSettle();
    expect(find.text('All Delivery'), findsOneWidget);
    return log;
  }

  testWidgets('only one nav bar renders while switching to the wallet tab',
      (tester) async {
    await pumpDeliveriesOverDashboard(tester);

    await tester.tap(find.text('Wallet'));
    await tester.pump();

    // Mid-flight the Hero keeps a single nav bar on screen instead of
    // cross-fading the outgoing and incoming bars.
    for (var elapsed = 0; elapsed < 150; elapsed += 30) {
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    }

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-title')), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('sibling tabs swap in a single transition', (tester) async {
    final log = await pumpDeliveriesOverDashboard(tester);
    final pushesBefore = log.pushes;

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    // The dashboard underneath is never popped back to and re-pushed, so it
    // cannot flash between the two tabs.
    expect(log.replacements, 1);
    expect(log.pops, 0);
    expect(log.pushes, pushesBefore);
  });

  testWidgets('dashboard tabs are requested through the shared controller',
      (tester) async {
    final log = await pumpDeliveriesOverDashboard(tester);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(riderDashboardTab.index, RiderNavIndex.history);
    expect(log.pops, 1);
    expect(find.text('open deliveries'), findsOneWidget);
  });

  testWidgets('tapping the current tab does nothing', (tester) async {
    final log = await pumpDeliveriesOverDashboard(tester);

    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle();

    expect(log.pops, 0);
    expect(log.replacements, 0);
    expect(find.text('All Delivery'), findsOneWidget);
  });
}
