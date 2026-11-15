import 'dart:async';

import 'package:agriconnect/provider/badge_provider.dart';
import 'package:agriconnect/provider/category_provider.dart';
import 'package:agriconnect/provider/items_provider.dart';
import 'package:agriconnect/screens/customer/productDetailScreen.dart';
import 'package:agriconnect/services/items_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Details extends ItemsService {
  final requests = <Completer<Map<String, dynamic>>>[];
  @override
  Future<Map<String, dynamic>> fetchItemReviews(String itemId) {
    expect(itemId, '42');
    final response = Completer<Map<String, dynamic>>();
    requests.add(response);
    return response.future;
  }
}

class _Categories extends CategoryProvider {
  @override
  List<Map<String, dynamic>> get categories => [
        {'id': 1, 'name': 'Feeds'}
      ];
}

const _summary = {
  'id': 42,
  'item_name': 'Kelso Gamefowl Feed',
  'item_price': 850
};
const _details = {
  'id': 42,
  'item_name': 'Full Feed Details',
  'item_description': 'Full description',
  'item_price': '1000.10',
  'item_quantity': 4,
  'category': 1,
  'reviews': <dynamic>[]
};

Future<_Details> _show(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = _Details();
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ItemsProvider>(
            create: (_) => ItemsProvider(itemsService: service)),
        ChangeNotifierProvider<CategoryProvider>(create: (_) => _Categories()),
        ChangeNotifierProvider<BadgeProvider>(create: (_) => BadgeProvider()),
      ],
      child: const MaterialApp(
          home: ProductDetailScreen(
              productId: 42, productData: _summary, loadFullDetails: true))));
  await tester.pump();
  return service;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('search summaries hydrate full fields before enabling purchases',
      (tester) async {
    final service = await _show(tester);
    expect(find.text('Kelso Gamefowl Feed'), findsOneWidget);
    expect(find.text('Loading product details...'), findsOneWidget);
    expect(find.text('Add to Crate'), findsNothing);
    expect(find.text('Gamefowl is available to view only'), findsNothing);
    service.requests.single.complete(Map.of(_details));
    await tester.pumpAndSettle();
    expect(find.text('Full Feed Details'), findsOneWidget);
    expect(find.text('Kelso Gamefowl Feed'), findsNothing);
    expect(find.text('₱1,000.10'), findsOneWidget);
    expect(find.text('Loading product details...'), findsNothing);
    final add = find
        .ancestor(of: find.text('Add to Crate'), matching: find.byType(InkWell))
        .first;
    expect(tester.widget<InkWell>(add).onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'detail failure preserves summary and retry enables purchases only after success',
      (tester) async {
    final service = await _show(tester);
    service.requests.first.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Kelso Gamefowl Feed'), findsOneWidget);
    expect(find.text('Could not load product details'), findsOneWidget);
    expect(find.text('Add to Crate'), findsNothing);
    await tester.tap(find.text('Retry product details'));
    await tester.pump();
    expect(service.requests, hasLength(2));
    expect(find.text('Loading product details...'), findsOneWidget);
    service.requests.last.complete(Map.of(_details));
    await tester.pumpAndSettle();
    expect(find.text('Add to Crate'), findsOneWidget);
    expect(find.text('Retry product details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing or wrong full details never enable purchase',
      (tester) async {
    final service = await _show(tester);
    service.requests.first.complete({});
    await tester.pumpAndSettle();
    expect(find.text('Retry product details'), findsOneWidget);
    await tester.tap(find.text('Retry product details'));
    await tester.pump();
    service.requests.last.complete({..._details, 'id': 99});
    await tester.pumpAndSettle();
    expect(find.text('Add to Crate'), findsNothing);
    expect(find.text('Retry product details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'leaving before detail loading completes causes no notifications after disposal',
      (tester) async {
    final service = await _show(tester);
    await tester.pumpWidget(const SizedBox());
    service.requests.single.complete(Map.of(_details));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
