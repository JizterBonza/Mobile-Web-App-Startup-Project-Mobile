import 'dart:async';
import 'dart:io';

import 'package:agriconnect/models/messageModel.dart';
import 'package:agriconnect/provider/message_provider.dart';
import 'package:agriconnect/screens/customer/InquiryChat.dart';
import 'package:agriconnect/screens/customer/conversationScreen.dart';
import 'package:agriconnect/screens/customer/farmGamefowlMessagePickerScreen.dart';
import 'package:agriconnect/screens/customer/messageProductPickerScreen.dart';
import 'package:agriconnect/services/farms_service.dart';
import 'package:agriconnect/widgets/gamefowl_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FarmListings extends FarmsService {
  int calls = 0;
  Future<Map<String, dynamic>> Function()? response;

  @override
  Future<Map<String, dynamic>> fetchFarmWithListings(dynamic id) {
    expect(id, 7);
    calls++;
    return response?.call() ?? Future.value(_farmData());
  }

  @override
  Future<Map<String, dynamic>> fetchFarmGamefowlListing(dynamic id) async => {
        'id': 101,
        'name': 'Kelso',
        'price': 1500,
        'gamefowl': {
          'class': {'name': 'Gamefowl'},
          'age_type': {'name': 'Adult'},
          'sex': 'Male',
        },
      };
}

Map<String, dynamic> _farmData() => {
      'id': 7,
      'name': 'Hill Farm',
      'listings': [
        {
          'id': 101,
          'name': 'Kelso',
          'status': 'active',
          'stock': '3',
          'price': 1500,
          'gamefowl': {
            'class': {'name': 'Gamefowl'},
            'age_type': {'name': 'Adult'},
            'sex': 'Male',
            'bloodline': {'name': 'Golden Boy Sweater'},
          },
        },
        {
          'id': 102,
          'name': 'Plain bird',
          'status': 'active',
          'stock': 1,
          'price': null,
          'gamefowl': null,
        },
        {'id': 103, 'name': 'Sold out', 'status': 'active', 'stock': 0},
        {'id': 104, 'name': 'Hidden', 'status': 'inactive', 'stock': 3},
        {'id': 105, 'name': 'Unknown stock', 'status': 'active'},
      ],
    };

class _Provider extends MessageProvider {
  _Provider({required this.farm});

  final bool farm;
  int sendCalls = 0;
  dynamic sentItemId;
  String? sentBody;
  dynamic sentConversationId;
  Completer<bool>? sendGate;
  bool sendResult = true;
  int refreshCalls = 0;
  String? _error;
  late ConversationThread thread = _thread(farm: farm);

  @override
  ConversationThread? get activeThread => thread;

  @override
  String? get error => _error;

  @override
  Future<bool> loadConversation(dynamic conversationId) async => true;

  @override
  Future<void> startLiveUpdates() async {}

  @override
  void clearActiveThread({bool notify = true}) {}

  @override
  Future<bool> sendMessage({
    required dynamic conversationId,
    String? body,
    List<File> attachments = const [],
    dynamic itemId,
  }) async {
    sendCalls++;
    sentItemId = itemId;
    sentBody = body;
    sentConversationId = conversationId;
    final success = sendGate == null ? sendResult : await sendGate!.future;
    if (success) {
      thread = thread.copyWith(messages: [
        ...thread.messages,
        MessageModel.fromJson({
          'id': 301,
          'type': 'product',
          'side': 'outgoing',
          'product': {
            'listing_id': itemId,
            'product_name': 'Kelso',
            'item_price': 1500,
          },
        }),
      ]);
      notifyListeners();
    } else {
      _error = 'Message unavailable';
    }
    return success;
  }

  @override
  Future<bool> refreshActiveThread() async {
    refreshCalls++;
    return true;
  }
}

ConversationThread _thread({required bool farm}) =>
    ConversationThread.fromJson({
      'conversation': {'id': 42, 'name': 'Chat'},
      'farm': farm ? {'id': 7, 'name': 'Hill Farm'} : null,
      'shop': farm ? null : {'id': 9, 'name': 'Test Shop'},
      'messages': [],
    });

void main() {
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> showPicker(
      WidgetTester tester, _Provider provider, _FarmListings listings) async {
    phoneSize(tester);
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FarmGamefowlMessagePickerScreen(
                    farmId: 7,
                    conversationId: 42,
                    farmsService: listings,
                  ),
                ),
              ),
              child: const Text('Open picker'),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows active in-stock listings and searches name or bloodline',
      (tester) async {
    final provider = _Provider(farm: true);
    final listings = _FarmListings();
    await showPicker(tester, provider, listings);
    expect(find.text('Kelso'), findsOneWidget);
    expect(find.text('Plain bird'), findsOneWidget);
    expect(find.text('Gamefowl | Adult | Male'), findsOneWidget);
    expect(find.text('\u20B11500.00'), findsOneWidget);
    expect(find.text('Price unavailable'), findsOneWidget);
    expect(find.text('3 in stock'), findsOneWidget);
    expect(find.byType(GamefowlIcon), findsNWidgets(2));
    expect(find.byIcon(Icons.pets), findsNothing);
    expect(find.text('Sold out'), findsNothing);
    expect(find.text('Hidden'), findsNothing);
    expect(find.text('Unknown stock'), findsNothing);

    await tester.enterText(find.byType(TextField), 'sweater');
    await tester.pump();
    expect(find.text('Kelso'), findsOneWidget);
    expect(find.text('Plain bird'), findsNothing);
    await tester.enterText(find.byType(TextField), 'plain');
    await tester.pump();
    expect(find.text('Plain bird'), findsOneWidget);
    expect(find.text('Kelso'), findsNothing);
    expect(listings.calls, 1);
  });

  testWidgets('loading failure offers Retry', (tester) async {
    final provider = _Provider(farm: true);
    final listings = _FarmListings();
    final pending = Completer<Map<String, dynamic>>();
    listings.response =
        () => listings.calls == 1 ? pending.future : Future.value(_farmData());
    phoneSize(tester);
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: FarmGamefowlMessagePickerScreen(
          farmId: 7,
          conversationId: 42,
          farmsService: listings,
        ),
      ),
    ));
    expect(find.text('Kelso'), findsNothing);
    pending.completeError(Exception('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to load gamefowl listings'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Kelso'), findsOneWidget);
    expect(listings.calls, 2);
  });

  testWidgets('send uses listing ID once and returns to chat', (tester) async {
    final provider = _Provider(farm: true)..sendGate = Completer<bool>();
    final listings = _FarmListings();
    await showPicker(tester, provider, listings);
    await tester.tap(find.text('Send').first);
    await tester.pump();
    await tester.tap(find.text('Send').last);
    await tester.pump();
    expect(provider.sendCalls, 1);
    expect(provider.sentConversationId, 42);
    expect(provider.sentItemId, 101);
    expect(provider.sentBody, isNull);
    provider.sendGate!.complete(true);
    await tester.pumpAndSettle();
    expect(provider.refreshCalls, 1);
    expect(find.byType(FarmGamefowlMessagePickerScreen), findsNothing);
  });

  testWidgets('failed send stays in picker and shows error', (tester) async {
    final provider = _Provider(farm: true)..sendResult = false;
    await showPicker(tester, provider, _FarmListings());
    await tester.tap(find.text('Send').first);
    await tester.pumpAndSettle();
    expect(find.byType(FarmGamefowlMessagePickerScreen), findsOneWidget);
    expect(find.text('Message unavailable'), findsOneWidget);
    expect(provider.refreshCalls, 0);
  });

  for (final inquiry in [false, true]) {
    testWidgets(
        '${inquiry ? 'InquiryChat' : 'ConversationScreen'} opens farm picker and displays sent card',
        (tester) async {
      phoneSize(tester);
      final provider = _Provider(farm: true);
      final listings = _FarmListings();
      await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
        value: provider,
        child: MaterialApp(
          home: inquiry
              ? InquiryChat(conversationId: 42, farmsService: listings)
              : ConversationScreen(conversationId: 42, farmsService: listings),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      expect(find.text('Gamefowl'), findsOneWidget);
      expect(find.byType(GamefowlIcon), findsOneWidget);
      expect(find.text('Products'), findsNothing);
      await tester.tap(find.text('Gamefowl'));
      await tester.pumpAndSettle();
      expect(find.byType(FarmGamefowlMessagePickerScreen), findsOneWidget);
      await tester.tap(find.text('Send').first);
      await tester.pumpAndSettle();
      expect(find.byType(FarmGamefowlMessagePickerScreen), findsNothing);
      expect(find.text('Kelso'), findsOneWidget);
      expect(provider.sentItemId, 101);
    });
  }

  testWidgets('shop chat keeps its Products picker', (tester) async {
    phoneSize(tester);
    final provider = _Provider(farm: false);
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: const MaterialApp(
          home: ConversationScreen(conversationId: 42, shopId: 9)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Gamefowl'), findsNothing);
    await tester.tap(find.text('Products'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MessageProductPickerScreen), findsOneWidget);
  });
}
