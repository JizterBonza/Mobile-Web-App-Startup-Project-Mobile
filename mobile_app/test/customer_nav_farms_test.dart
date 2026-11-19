import 'package:agriconnect/provider/badge_provider.dart';
import 'package:agriconnect/screens/common/myOrderScreen.dart';
import 'package:agriconnect/screens/common/notificationScreen.dart';
import 'package:agriconnect/screens/customer/favoriteScreen.dart';
import 'package:agriconnect/screens/customer/klasrumScreen.dart';
import 'package:agriconnect/screens/customer/partnerFarmsScreen.dart';
import 'package:agriconnect/utils/customer_nav.dart';
import 'package:agriconnect/widgets/login_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

Future<_Routes> _pumpNav(WidgetTester tester,
    {int currentIndex = CustomerNavIndex.home, bool isGuest = false}) async {
  final routes = _Routes();
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => BadgeProvider(),
    child: MaterialApp(
      navigatorObservers: [routes],
      home: Builder(
        builder: (context) => Scaffold(
          bottomNavigationBar: buildCustomerBottomNavigationBar(
            context: context,
            currentIndex: currentIndex,
            isGuest: isGuest,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return routes;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows Farms with chicken SVG and hides Favorites',
      (tester) async {
    await _pumpNav(tester, currentIndex: CustomerNavIndex.farms);
    final nav =
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(nav.items.map((item) => item.label),
        ['Home', 'Farms', 'Klasrum', 'Orders', 'Notifs']);
    expect(nav.currentIndex, 1);
    expect(find.text('Favorite'), findsNothing);
    final icons = tester.widgetList<SvgPicture>(find.descendant(
      of: find.byWidget(nav.items[1].activeIcon),
      matching: find.byType(SvgPicture),
    ));
    expect(icons, isNotEmpty);
    expect((icons.first.bytesLoader as SvgAssetLoader).assetName,
        'assets/icons/chicken.svg');
  });

  testWidgets('hidden Favorites destination safely selects Home',
      (tester) async {
    await _pumpNav(tester, currentIndex: CustomerNavIndex.favorites);
    expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0);
    expect(tester.takeException(), isNull);
  });

  for (final destination in [
    (1, PartnerFarmsScreen),
    (2, KlasrumScreen),
    (3, MyOrderScreen),
    (4, NotificationScreen),
  ]) {
    testWidgets('visible tab ${destination.$1} routes to ${destination.$2}',
        (tester) async {
      final routes = await _pumpNav(tester);
      final nav =
          tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      nav.onTap!(destination.$1);
      final route = routes.pushed.last as PageRouteBuilder;
      final context = tester.element(find.byType(BottomNavigationBar));
      final screen = route.pageBuilder(context, const AlwaysStoppedAnimation(1),
          const AlwaysStoppedAnimation(1));
      expect(screen.runtimeType, destination.$2);
      // Inspect routing without mounting unrelated destination dependencies.
      Navigator.of(context).removeRoute(route);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('Favorites route is preserved', (tester) async {
    final routes = await _pumpNav(tester);
    final context = tester.element(find.byType(BottomNavigationBar));
    handleCustomerNavTap(context,
        targetIndex: CustomerNavIndex.favorites,
        currentIndex: CustomerNavIndex.home,
        isGuest: false);
    final route = routes.pushed.last as PageRouteBuilder;
    expect(
        route.pageBuilder(context, const AlwaysStoppedAnimation(1),
            const AlwaysStoppedAnimation(1)),
        isA<FavoriteScreen>());
    Navigator.of(context).removeRoute(route);
    await tester.pumpAndSettle();
  });

  testWidgets('guest selecting Farms sees login and stays on Home',
      (tester) async {
    await _pumpNav(tester, isGuest: true);
    await tester.tap(find.text('Farms'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginDialog), findsOneWidget);
    expect(find.byType(PartnerFarmsScreen), findsNothing);
  });

  testWidgets('reselecting Farms does not navigate', (tester) async {
    final routes = await _pumpNav(tester, currentIndex: CustomerNavIndex.farms);
    final before = routes.pushed.length;
    await tester.tap(find.text('Farms'));
    await tester.pumpAndSettle();
    expect(routes.pushed.length, before);
  });

  testWidgets('Home returns from a secondary customer route', (tester) async {
    await _pumpNav(tester);
    final context = tester.element(find.byType(BottomNavigationBar));
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        body: const Text('Secondary destination'),
        bottomNavigationBar: buildCustomerBottomNavigationBar(
          context: context,
          currentIndex: CustomerNavIndex.farms,
          isGuest: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Secondary destination'), findsNothing);
  });
}
