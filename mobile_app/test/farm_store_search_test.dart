import 'package:agriconnect/screens/customer/farmDetailsScreen.dart';
import 'package:agriconnect/screens/customer/farmGamefowlListingDetailScreen.dart';
import 'package:agriconnect/services/farms_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchFarmsService extends FarmsService {
  int calls = 0;
  final openedIds = <dynamic>[];

  @override
  Future<Map<String, dynamic>> fetchFarmGamefowlListing(dynamic id) async {
    openedIds.add(id);
    return {'id': id, 'name': 'Opened bird', 'price': 5000};
  }

  @override
  Future<Map<String, dynamic>> fetchFarmWithListings(dynamic id) async {
    calls++;
    return {
      'id': id,
      'name': 'Search Farm',
      'listings': [
        {
          'id': 1,
          'name': 'Golden Rooster',
          'price': 5000,
          'gamefowl': {
            'description': 'Healthy show bird',
            'bloodline': {'name': 'Sweater'},
            'class': {'name': 'Pure'},
            'age_type': {'name': 'Adult'},
            'sex': 'Male',
          },
        },
        {'id': 2, 'name': 'White Hen', 'price': 3000, 'gamefowl': null},
      ],
    };
  }
}

Future<_SearchFarmsService> _showStore(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = _SearchFarmsService();
  await tester.pumpWidget(MaterialApp(
    home: FarmDetailsScreen(farmId: 1, farmsService: service),
  ));
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('typing suggests locally without filtering and opens a listing',
      (tester) async {
    final service = await _showStore(tester);
    await tester.enterText(find.byType(TextField), 'sweater golden');
    await tester.pumpAndSettle();
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('White Hen'), findsOneWidget);
    expect(find.byKey(const ValueKey('search-suggestion-product-1')),
        findsOneWidget);
    expect(service.calls, 1);
    await tester.tap(find.byKey(const ValueKey('search-suggestion-product-1')));
    await tester.pumpAndSettle();
    expect(find.byType(FarmGamefowlListingDetailScreen), findsOneWidget);
    expect(service.openedIds, [1]);
    expect(find.byKey(const ValueKey('search-suggestions-dropdown')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters locally by name and nested gamefowl traits',
      (tester) async {
    final service = await _showStore(tester);
    expect(find.text('2 items'), findsOneWidget);

    for (final query in [
      '  GOLDEN  ',
      'sweater',
      'pure',
      'adult',
      'male',
      'show bird',
      'sweater   golden',
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Golden Rooster'), findsOneWidget);
      expect(find.text('White Hen'), findsNothing);
      expect(find.text('1 item'), findsOneWidget);
    }

    await tester.enterText(find.byType(TextField), 'hen');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('White Hen'), findsOneWidget);
    expect(find.text('Golden Rooster'), findsNothing);
    expect(service.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows no matches and restores all listings when cleared',
      (tester) async {
    await _showStore(tester);
    await tester.enterText(find.byType(TextField), 'unavailable breed');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No matching gamefowl'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('No gamefowl available'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.text('Golden Rooster'), findsOneWidget);
    expect(find.text('White Hen'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text('2 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching from Reviews returns to Gamefowl results',
      (tester) async {
    await _showStore(tester);
    await tester.tap(find.text('Reviews'));
    await tester.pump();
    expect(find.text('No reviews yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'golden');
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Golden Rooster'), findsOneWidget);
    expect(find.text('No reviews yet'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);

    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.takeException(), isNull);
  });
}
