import 'package:agriconnect/provider/orders_provider.dart';
import 'package:agriconnect/screens/rider/riderEarningsScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeOrdersProvider extends OrdersProvider {
  _FakeOrdersProvider({
    List<Map<String, dynamic>> orders = const [],
    String? error,
  })  : _testOrders = orders,
        _testError = error;

  final List<Map<String, dynamic>> _testOrders;
  final String? _testError;
  int fetchCount = 0;
  bool? lastUseCache;

  @override
  List<Map<String, dynamic>> get orders => _testOrders;

  @override
  String? get error => _testError;

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchRiderOrders({
    String? status,
    bool useCache = true,
  }) async {
    fetchCount++;
    lastUseCache = useCache;
  }
}

void main() {
  Future<void> pumpWallet(
    WidgetTester tester,
    _FakeOrdersProvider provider, {
    double width = 390,
    double height = 844,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrdersProvider>.value(
        value: provider,
        child: const MaterialApp(home: RiderEarningsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows all-time delivered shipping fees in the wallet',
      (tester) async {
    final provider = _FakeOrdersProvider(
      orders: [
        {
          'order_status': 'delivered',
          'order_code': '#ORD-20441',
          'ordered_at': '2026-07-10T03:51:00',
          'shipping_fee': '80.00',
        },
        {
          'order_status': 'Delivered',
          'order_code': 'ORD-20442',
          'ordered_at': '2026-07-11T14:05:00',
          'shipping_fee': 4200,
        },
        {
          'order_status': 'pending',
          'order_code': 'ORD-PENDING',
          'ordered_at': '2026-07-12T08:00:00',
          'shipping_fee': 900,
        },
      ],
    );

    await pumpWallet(tester, provider);

    expect(find.text('Wallet'), findsNWidgets(2));
    expect(find.text('Your delivery earnings.'), findsOneWidget);
    expect(find.text('₱4,280'), findsNWidgets(2));
    expect(find.text('ORD-20441'), findsOneWidget);
    expect(find.text('ORD-20442'), findsOneWidget);
    expect(find.text('ORD-PENDING'), findsNothing);
    expect(find.text('+₱80'), findsOneWidget);
    expect(find.text('+₱4,200'), findsOneWidget);
    expect(find.text('July 10, 2026 • 3:51am'), findsOneWidget);
    expect(provider.fetchCount, 1);
    expect(provider.lastUseCache, isTrue);
  });

  testWidgets('matches history proportions and disables withdrawals',
      (tester) async {
    final provider = _FakeOrdersProvider(
      orders: [
        {
          'order_status': 'delivered',
          'order_code': 'ORD-20441',
          'ordered_at': '2026-07-10T03:51:00',
          'shipping_fee': 80,
        },
      ],
    );

    await pumpWallet(tester, provider, width: 390);

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('wallet-title')),
    );
    final balanceSize = tester.getSize(
      find.byKey(const ValueKey('wallet-balance-card')),
    );
    final earningsTabSize = tester.getSize(
      find.byKey(const ValueKey('wallet-earnings-tab')),
    );
    final rowSize = tester.getSize(
      find.byKey(const ValueKey('wallet-earning-row-0')),
    );
    final withdrawButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('wallet-withdraw-button')),
    );
    final withdrawalsTab = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('wallet-withdrawals-tab')),
    );
    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );

    expect(title.style?.fontSize, 24);
    expect(balanceSize.width, 358);
    expect(earningsTabSize.height, 34);
    expect(rowSize.height, greaterThanOrEqualTo(58));
    expect(withdrawButton.onPressed, isNull);
    expect(withdrawalsTab.onPressed, isNull);
    expect(navigation.currentIndex, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows empty and error states with retry support',
      (tester) async {
    final emptyProvider = _FakeOrdersProvider();
    await pumpWallet(tester, emptyProvider);
    expect(find.text('No earnings yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final errorProvider = _FakeOrdersProvider(error: 'Connection failed');
    await pumpWallet(tester, errorProvider);
    expect(find.text('Unable to load earnings'), findsOneWidget);
    expect(find.text('Connection failed'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wallet-retry')));
    await tester.pump();
    await tester.pump();

    expect(errorProvider.fetchCount, 2);
    expect(errorProvider.lastUseCache, isFalse);
  });
}
