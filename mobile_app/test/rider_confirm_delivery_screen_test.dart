import 'dart:async';

import 'package:agriconnect/screens/rider/riderConfirmDeliveryScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  const order = <String, dynamic>{
    'order_id': 52,
    'order_code': '#ORD-20451',
    'delivery_address': 'Purok 8, San Isidro, Tagum City',
  };
  const deliveryOrder = <String, dynamic>{
    'order_id': 100,
    'order_code': '#ORD-20451',
    'delivery_address': 'Purok 8, San Isidro, Tagum City',
    'active_order_shops': [
      {'order_shop_id': 501},
      {'order_shop_id': 502},
    ],
  };

  Future<void> openDeliveryForm(
    WidgetTester tester, {
    required RiderConfirmDeliveryScreen screen,
    ValueChanged<bool?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open-confirm-delivery'),
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(builder: (_) => screen),
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-confirm-delivery')));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the confirm delivery form from order data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RiderConfirmDeliveryScreen(order: order),
      ),
    );

    expect(find.text('Confirm Delivery'), findsOneWidget);
    expect(find.text('ORD-20451'), findsOneWidget);
    expect(find.text('Purok 8, San Isidro, Tagum City'), findsOneWidget);
    expect(find.text('PROOF OF DELIVERY'), findsOneWidget);
    expect(find.text('Tap to take a photo'), findsOneWidget);
    expect(
      find.text('Delivered and received by the customer'),
      findsOneWidget,
    );
    expect(find.text('Complete Delivery'), findsOneWidget);
  });

  testWidgets('remarks dropdown selects an available delivery result', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RiderConfirmDeliveryScreen(order: order),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-notes')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Delivered to the designated drop-off area').last,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Delivered to the designated drop-off area'),
      findsOneWidget,
    );
  });

  testWidgets('requires a proof photo before resolving location', (
    tester,
  ) async {
    var locationCalls = 0;
    var uploadCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderConfirmDeliveryScreen(
          order: deliveryOrder,
          locationProvider: () async {
            locationCalls++;
            return const DeliveryCoordinates(latitude: 7, longitude: 125);
          },
          podUploader: ({
            required orderId,
            required orderShopId,
            required imagePaths,
            required latitude,
            required longitude,
            required remarks,
            required status,
          }) async {
            uploadCalls++;
            return <String, dynamic>{'success': true};
          },
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.pump();

    expect(
        find.text('Add at least one proof-of-delivery photo.'), findsOneWidget);
    expect(locationCalls, 0);
    expect(uploadCalls, 0);
  });

  testWidgets('uploads every order-shop and returns success', (tester) async {
    final uploadedShopIds = <int>[];
    final receivedStatuses = <String>[];
    bool? navigationResult;

    await openDeliveryForm(
      tester,
      onResult: (result) => navigationResult = result,
      screen: RiderConfirmDeliveryScreen(
        order: deliveryOrder,
        cameraPicker: () async => XFile('assets/images/store_sample.png'),
        locationProvider: () async =>
            const DeliveryCoordinates(latitude: 7.4479, longitude: 125.8071),
        podUploader: ({
          required orderId,
          required orderShopId,
          required imagePaths,
          required latitude,
          required longitude,
          required remarks,
          required status,
        }) async {
          expect(orderId, 100);
          expect(imagePaths, hasLength(1));
          expect(latitude, 7.4479);
          expect(longitude, 125.8071);
          expect(remarks, 'Delivered and received by the customer');
          uploadedShopIds.add(orderShopId);
          receivedStatuses.add(status);
          return <String, dynamic>{'success': true};
        },
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-photo-picker')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.pumpAndSettle();

    expect(uploadedShopIds, <int>[501, 502]);
    expect(receivedStatuses, everyElement('delivered'));
    expect(navigationResult, isTrue);
    expect(find.byKey(const ValueKey('confirm-delivery-screen')), findsNothing);
  });

  testWidgets('partial failure retries only remaining order-shops', (
    tester,
  ) async {
    final uploadAttempts = <int>[];
    var secondShopAttempts = 0;
    bool? navigationResult;

    await openDeliveryForm(
      tester,
      onResult: (result) => navigationResult = result,
      screen: RiderConfirmDeliveryScreen(
        order: deliveryOrder,
        cameraPicker: () async => XFile('assets/images/store_sample.png'),
        locationProvider: () async =>
            const DeliveryCoordinates(latitude: 7, longitude: 125),
        podUploader: ({
          required orderId,
          required orderShopId,
          required imagePaths,
          required latitude,
          required longitude,
          required remarks,
          required status,
        }) async {
          uploadAttempts.add(orderShopId);
          if (orderShopId == 502 && secondShopAttempts++ == 0) {
            return <String, dynamic>{
              'success': false,
              'message': 'Temporary upload failure',
            };
          }
          return <String, dynamic>{'success': true};
        },
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-photo-picker')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.pumpAndSettle();

    expect(uploadAttempts, <int>[501, 502]);
    expect(find.text('Temporary upload failure'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('confirm-delivery-screen')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.pumpAndSettle();

    expect(uploadAttempts, <int>[501, 502, 502]);
    expect(navigationResult, isTrue);
  });

  testWidgets('location failure keeps the completed form on screen', (
    tester,
  ) async {
    var uploadCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderConfirmDeliveryScreen(
          order: deliveryOrder,
          cameraPicker: () async => XFile('assets/images/store_sample.png'),
          locationProvider: () async =>
              throw Exception('Turn on location services.'),
          podUploader: ({
            required orderId,
            required orderShopId,
            required imagePaths,
            required latitude,
            required longitude,
            required remarks,
            required status,
          }) async {
            uploadCalls++;
            return <String, dynamic>{'success': true};
          },
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-photo-picker')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turn on location services.'), findsOneWidget);
    expect(uploadCalls, 0);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('duplicate completion taps start only one upload',
      (tester) async {
    final uploadCompleter = Completer<Map<String, dynamic>>();
    var uploadCalls = 0;
    bool? navigationResult;

    await openDeliveryForm(
      tester,
      onResult: (result) => navigationResult = result,
      screen: RiderConfirmDeliveryScreen(
        order: const <String, dynamic>{
          'order_id': 100,
          'active_order_shops': [
            {'order_shop_id': 501},
          ],
        },
        cameraPicker: () async => XFile('assets/images/store_sample.png'),
        locationProvider: () async =>
            const DeliveryCoordinates(latitude: 7, longitude: 125),
        podUploader: ({
          required orderId,
          required orderShopId,
          required imagePaths,
          required latitude,
          required longitude,
          required remarks,
          required status,
        }) {
          uploadCalls++;
          return uploadCompleter.future;
        },
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-photo-picker')),
    );
    await tester.pumpAndSettle();
    final completeButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('confirm-delivery-complete')),
    );
    completeButton.onPressed!();
    completeButton.onPressed!();
    await tester.pump();

    expect(uploadCalls, 1);
    expect(find.text('Uploading 1 of 1'), findsOneWidget);

    uploadCompleter.complete(<String, dynamic>{'success': true});
    await tester.pumpAndSettle();
    expect(navigationResult, isTrue);
  });

  testWidgets('supports up to five photos and hides add at the limit', (
    tester,
  ) async {
    var calls = 0;
    Future<XFile?> cameraPicker() async {
      calls++;
      return XFile('assets/images/store_sample.png');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: RiderConfirmDeliveryScreen(
          order: order,
          cameraPicker: cameraPicker,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-photo-picker')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('confirm-delivery-photo-preview-0')),
      findsOneWidget,
    );
    expect(find.text('Change Photo'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-delivery-add-photo')),
      findsOneWidget,
    );

    for (var index = 1; index < 5; index++) {
      await tester.tap(
        find.byKey(const ValueKey('confirm-delivery-add-photo')),
      );
      await tester.pumpAndSettle();
    }

    expect(calls, 5);
    expect(find.text('5/5'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-delivery-photo-preview-4')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('confirm-delivery-add-photo')),
      findsNothing,
    );
  });

  testWidgets('camera cancellation keeps existing photos', (tester) async {
    var calls = 0;
    Future<XFile?> cameraPicker() async {
      calls++;
      if (calls == 1) return XFile('assets/images/store_sample.png');
      return null;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: RiderConfirmDeliveryScreen(
          order: order,
          cameraPicker: cameraPicker,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-photo-picker')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-add-photo')),
    );
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('1/5'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-delivery-photo-preview-0')),
      findsOneWidget,
    );
  });

  testWidgets('camera errors show a non-blocking message', (tester) async {
    Future<XFile?> cameraPicker() async => throw Exception('camera error');

    await tester.pumpWidget(
      MaterialApp(
        home: RiderConfirmDeliveryScreen(
          order: order,
          cameraPicker: cameraPicker,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-delivery-photo-picker')),
    );
    await tester.pump();

    expect(
      find.text('Unable to open the camera. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Tap to take a photo'), findsOneWidget);
  });
}
