import 'dart:async';

import 'package:agriconnect/screens/customer/farmDetailsScreen.dart';
import 'package:agriconnect/services/farms_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFarmsService extends FarmsService {
  _FakeFarmsService(this.responses, {this.detailResponses = const []});

  final List<Future<Map<String, dynamic>> Function()> responses;
  final List<Future<Map<String, dynamic>> Function()> detailResponses;
  int calls = 0;
  int detailCalls = 0;
  dynamic lastId;
  dynamic lastListingId;

  @override
  Future<Map<String, dynamic>> fetchFarmWithListings(dynamic id) {
    lastId = id;
    return responses[calls++]();
  }

  @override
  Future<Map<String, dynamic>> fetchFarmGamefowlListing(dynamic id) {
    lastListingId = id;
    return detailResponses[detailCalls++]();
  }
}

void main() {
  testWidgets('shows loading, then farm details with nullable fields omitted',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final completer = Completer<Map<String, dynamic>>();
    final service = _FakeFarmsService([() => completer.future]);
    await tester.pumpWidget(MaterialApp(
      home:
          FarmDetailsScreen(farmId: 1, farmName: 'Farm', farmsService: service),
    ));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(service.lastId, 1);

    completer.complete({
      'id': 1,
      'name': 'Test Farm',
      'owner_name': 'Test Farmer',
      'description': null,
      'address': 'Sample Road',
      'city': 'Tagum',
      'province': 'Davao del Norte',
      'contact_number': '09123452678',
      'email': 'test@gmail.com',
      'operating_hours': '08:00 - 18:00',
      'status': 'active',
      'listings': [],
    });
    await tester.pump();

    expect(find.text('Test Farm'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Test Farmer'), findsOneWidget);
    expect(find.text('test@gmail.com / 09123452678'), findsOneWidget);
    expect(find.text('Sample Road'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Search in farm'), findsOneWidget);
    expect(find.text('About Farm'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Gamefowl'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Best Seller'), findsOneWidget);
    expect(find.text('No gamefowl available'), findsOneWidget);
    expect(find.text('View All'), findsNothing);

    await tester.tap(find.text('One way / Pure'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('One way / Pure')).style?.fontWeight,
      FontWeight.w600,
    );

    await tester.tap(find.text('Reviews'));
    await tester.pump();
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('No gamefowl available'), findsNothing);
  });

  testWidgets('shows error and Retry reloads the farm', (tester) async {
    final service = _FakeFarmsService([
      () async => throw Exception('offline'),
      () async => {'id': 2, 'name': 'Recovered Farm', 'listings': []},
    ]);
    await tester.pumpWidget(MaterialApp(
      home: FarmDetailsScreen(farmId: 2, farmsService: service),
    ));
    await tester.pump();

    expect(find.text('Failed to load farm'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.text('Recovered Farm'), findsOneWidget);
    expect(service.calls, 2);
  });

  testWidgets('pull to refresh reloads the visible farm', (tester) async {
    final service = _FakeFarmsService([
      () async => {
            'id': 3,
            'name': 'First Farm',
            'listings': [
              {
                'id': 10,
                'name': 'First Rooster',
                'price': 2500,
                'selling_unit': 'per head'
              }
            ]
          },
      () async => {
            'id': 3,
            'name': 'Updated Farm',
            'listings': [
              {
                'id': 11,
                'name': 'New Rooster',
                'price': 3000,
                'selling_unit': 'per head'
              }
            ]
          },
    ]);
    await tester.pumpWidget(MaterialApp(
      home: FarmDetailsScreen(farmId: 3, farmsService: service),
    ));
    await tester.pump();
    expect(find.text('First Farm'), findsOneWidget);
    expect(find.text('First Rooster'), findsOneWidget);
    expect(find.text('₱2500.00'), findsOneWidget);
    expect(find.text('/per head'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 350));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Updated Farm'), findsOneWidget);
    expect(find.text('New Rooster'), findsOneWidget);
    expect(find.text('First Rooster'), findsNothing);
    expect(service.calls, 2);
  });

  testWidgets(
      'shows listings under every visual type chip and keeps reviews empty',
      (tester) async {
    final service = _FakeFarmsService([
      () async => {
            'id': 7,
            'name': 'Hill Farm',
            'listings': [
              {
                'id': 1,
                'name': 'Sample Rooster',
                'price': 2500,
                'selling_unit': 'per head',
                'gamefowl': {
                  'class': {'name': 'Gamefowl'}
                },
              },
              {'id': 2, 'name': 'Second Rooster', 'price': 3000}
            ],
          },
    ]);
    await tester.pumpWidget(MaterialApp(
      home: FarmDetailsScreen(farmId: 7, farmsService: service),
    ));
    await tester.pump();

    expect(service.lastId, 7);
    expect(find.text('Sample Rooster'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('No gamefowl available'), findsNothing);
    await tester.tap(find.text('One way / Pure'));
    await tester.pump();
    expect(find.text('Sample Rooster'), findsOneWidget);
    await tester.tap(find.text('Reviews'));
    await tester.pump();
    expect(find.text('No reviews yet'), findsOneWidget);
  });

  testWidgets('card opens listing detail and renders the API fields',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final detail = Completer<Map<String, dynamic>>();
    final service = _FakeFarmsService(
      [
        () async => {
              'id': 7,
              'name': 'Test Farm',
              'listings': [
                {'id': 11, 'name': 'Card Rooster', 'price': 2500}
              ],
            }
      ],
      detailResponses: [() => detail.future],
    );
    await tester.pumpWidget(MaterialApp(
      home: FarmDetailsScreen(farmId: 7, farmsService: service),
    ));
    await tester.pump();
    await tester.tap(find.text('Card Rooster'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(service.lastListingId, 11);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    detail.complete({
      'id': 11,
      'name': 'Sample Gamefowl Rooster',
      'price': 2500,
      'selling_unit': 'per head',
      'images': [],
      'gamefowl': {
        'description': 'Sample product for testing.',
        'sex': 'Male',
        'hatch_date': null,
        'bloodline': {'name': 'Golden Boy Sweater'},
        'age_type': {'name': 'Adult'},
        'class': {'name': 'Gamefowl'},
      },
      'farm': {
        'name': 'Test Farm',
        'city': 'Tagum',
        'province': 'Davao del Norte',
      },
    });
    await tester.pump();
    expect(find.text('Sample Gamefowl Rooster'), findsOneWidget);
    expect(find.text('₱2500.00'), findsOneWidget);
    expect(find.text(' /per head'), findsOneWidget);
    expect(find.text('Golden Boy Sweater | Adult | Male'), findsOneWidget);
    expect(find.text('Hatch Date: —'), findsOneWidget);
    expect(find.text('Class: Gamefowl'), findsOneWidget);
    expect(find.text('Sample product for testing.'), findsOneWidget);
    expect(find.text('Add to Crate'), findsOneWidget);
    expect(find.text('Order Request'), findsOneWidget);
    expect(find.text('Inquire'), findsOneWidget);
  });

  testWidgets('listing detail retries after a failed request', (tester) async {
    final service = _FakeFarmsService(
      [
        () async => {
              'id': 7,
              'name': 'Test Farm',
              'listings': [
                {'id': 11, 'name': 'Card Rooster'}
              ],
            }
      ],
      detailResponses: [
        () async => throw Exception('offline'),
        () async => {'id': 11, 'name': 'Recovered Rooster'},
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: FarmDetailsScreen(farmId: 7, farmsService: service),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('Card Rooster'));
    await tester.pump();
    await tester.tap(find.text('Card Rooster'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Failed to load gamefowl listing'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Recovered Rooster'), findsOneWidget);
    expect(service.detailCalls, 2);
  });
}
