import 'dart:async';

import 'package:agriconnect/provider/badge_provider.dart';
import 'package:agriconnect/screens/customer/farmDetailsScreen.dart';
import 'package:agriconnect/screens/customer/partnerFarmsScreen.dart';
import 'package:agriconnect/services/farms_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Farms extends FarmsService {
  List<Map<String, dynamic>> farms = [];
  Future<List<Map<String, dynamic>>> Function()? loader;
  int calls = 0;
  final openedIds = <dynamic>[];

  @override
  Future<List<Map<String, dynamic>>> fetchFarms() async {
    calls++;
    return loader == null ? farms : await loader!();
  }

  @override
  Future<Map<String, dynamic>> fetchFarmWithListings(dynamic id) async {
    openedIds.add(id);
    return {'id': id, 'name': 'Farm $id', 'listings': <dynamic>[]};
  }
}

Future<void> _pumpFarms(WidgetTester tester, _Farms service) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => BadgeProvider(),
    child: MaterialApp(home: PartnerFarmsScreen(farmsService: service)),
  ));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'auth_token': 'test'}));

  testWidgets('loads and lists every farm in API order with Farms selected',
      (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    final service = _Farms()..loader = () => pending.future;
    await _pumpFarms(tester, service);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(List.generate(
        9,
        (index) => {
              'id': 9 - index,
              'name': 'Partner ${9 - index}',
              'city': 'Davao City',
              'province': 'Davao del Sur',
            }));
    await tester.pumpAndSettle();
    expect(find.text('Partner Gamefarms'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.getTopLeft(find.text('Partner 9')).dy,
        lessThan(tester.getTopLeft(find.text('Partner 8')).dy));
    expect(find.text('Davao City, Davao del Sur'), findsWidgets);
    expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        1);
    await tester.scrollUntilVisible(find.text('Partner 1'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Partner 1'), findsOneWidget);
    expect(service.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty results can refresh by button and pull gesture',
      (tester) async {
    final service = _Farms();
    await _pumpFarms(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('No partner farms available'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    service.farms = [
      {'id': 1, 'name': 'New Partner'}
    ];
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(service.calls, 3);
    expect(find.text('New Partner'), findsOneWidget);
  });

  testWidgets('fetch failure offers retry and recovers', (tester) async {
    final service = _Farms()..loader = () async => throw Exception('offline');
    await _pumpFarms(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('Failed to load partner farms'), findsOneWidget);
    service.loader = null;
    service.farms = [
      {'id': 3, 'name': 'Recovered Farm'}
    ];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered Farm'), findsOneWidget);
    expect(find.text('Failed to load partner farms'), findsNothing);
    expect(service.calls, 2);
  });

  testWidgets(
      'refresh failure retains cards and successful refresh replaces them',
      (tester) async {
    final service = _Farms()
      ..farms = [
        {'id': 1, 'name': 'Existing Farm'}
      ];
    await _pumpFarms(tester, service);
    await tester.pumpAndSettle();
    service.loader = () async => throw Exception('offline');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Existing Farm'), findsOneWidget);
    expect(find.text('Failed to refresh partner farms'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    service.loader = null;
    service.farms = [
      {'id': 2, 'name': 'Replacement Farm'}
    ];
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Replacement Farm'), findsOneWidget);
    expect(find.text('Existing Farm'), findsNothing);
    expect(service.calls, 3);
  });

  testWidgets('opens the selected farm and Back restores the list',
      (tester) async {
    final service = _Farms()
      ..farms = [
        {'id': 42, 'name': 'Chosen Farm'},
        {'name': 'Unavailable Farm'}
      ];
    await _pumpFarms(tester, service);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unavailable Farm'));
    await tester.pumpAndSettle();
    expect(find.byType(FarmDetailsScreen), findsNothing);
    await tester.tap(find.text('Chosen Farm'));
    await tester.pumpAndSettle();
    final details =
        tester.widget<FarmDetailsScreen>(find.byType(FarmDetailsScreen));
    expect(details.farmId, 42);
    expect(details.farmName, 'Chosen Farm');
    expect(service.openedIds, [42]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chosen Farm'), findsOneWidget);
    expect(service.calls, 1);
  });

  testWidgets('long text and missing or broken images fit narrow cards',
      (tester) async {
    final longName = List.filled(20, 'Partner Farm').join(' ');
    final longAddress = List.filled(20, 'Long Road').join(' ');
    final service = _Farms()
      ..farms = [
        {'id': 1, 'name': longName, 'address': longAddress},
        {'id': 2, 'name': '', 'cover_url': 'https://example.test/missing.jpg'},
      ];
    await _pumpFarms(tester, service);
    await tester.pumpAndSettle();
    expect(find.text(longName), findsOneWidget);
    expect(find.text(longAddress), findsOneWidget);
    expect(find.text('Unnamed Farm'), findsOneWidget);
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images.where((image) => image.image is AssetImage).length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing a fetch after leaving the screen is safe',
      (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    final service = _Farms()..loader = () => pending.future;
    await _pumpFarms(tester, service);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
