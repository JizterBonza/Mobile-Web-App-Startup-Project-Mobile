import 'dart:async';
import 'dart:io';

import 'package:agriconnect/models/messageModel.dart';
import 'package:agriconnect/provider/message_provider.dart';
import 'package:agriconnect/screens/customer/InquiryChat.dart';
import 'package:agriconnect/screens/customer/farmDetailsScreen.dart';
import 'package:agriconnect/screens/customer/farmGamefowlListingDetailScreen.dart';
import 'package:agriconnect/services/farms_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FarmService extends FarmsService {
  @override
  Future<Map<String, dynamic>> fetchFarmWithListings(dynamic id) async => {
        'id': 7,
        'name': 'Test Farm',
        'listings': [],
      };

  @override
  Future<Map<String, dynamic>> fetchFarmGamefowlListing(dynamic id) async => {
        'id': 11,
        'farm_id': 7,
        'name': 'Sample Rooster',
        'price': 2500,
        'images': [],
        'farm': {'id': 7, 'name': 'Test Farm'},
        'gamefowl': {
          'sex': 'Male',
          'class': {'name': 'Gamefowl'},
          'age_type': {'name': 'Adult'},
        },
      };
}

class _MessageProvider extends MessageProvider {
  final start = Completer<bool>();
  int startCalls = 0;
  int loadCalls = 0;
  final sentBodies = <String>[];
  final sentItemIds = <dynamic>[];
  bool _started = false;

  @override
  ConversationThread? get activeThread => _started
      ? ConversationThread(
          conversation:
              ConversationHeader(id: 42, name: 'Test Farm', lastSeen: ''),
          messages: const [],
          farm: MessageShopInfo(id: 7, shopName: 'Test Farm'),
        )
      : null;

  @override
  String? get error => 'Farm unavailable';

  @override
  Future<bool> startOrResumeFarmConversation({
    required dynamic farmId,
    String? farmName,
    String? body,
    List<File> attachments = const [],
    dynamic itemId,
  }) async {
    expect(farmId, 7);
    expect(farmName, 'Test Farm');
    startCalls++;
    if (itemId != null) sentItemIds.add(itemId);
    final success = await start.future;
    _started = success;
    return success;
  }

  @override
  Future<bool> loadConversation(dynamic conversationId) async {
    expect(conversationId, 42);
    loadCalls++;
    return true;
  }

  @override
  Future<void> startLiveUpdates() async {}

  @override
  Future<bool> sendMessage({
    required dynamic conversationId,
    String? body,
    List<File> attachments = const [],
    dynamic itemId,
  }) async {
    expect(conversationId, 42);
    if (body != null) sentBodies.add(body);
    return true;
  }

  @override
  Future<bool> refreshActiveThread() async => true;

  @override
  void clearActiveThread({bool notify = true}) {}
}

void main() {
  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('farm Chat waits for POST then opens without a message',
      (tester) async {
    setPhoneSize(tester);
    final provider = _MessageProvider();
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: FarmDetailsScreen(farmId: 7, farmsService: _FarmService()),
      ),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('Chat'));
    await tester.pump();
    await tester.tap(find.text('Chat'));
    await tester.pump();
    expect(provider.startCalls, 1);
    expect(find.byType(InquiryChat), findsNothing);
    await tester.tap(find.text('Chat'));
    await tester.pump();
    expect(provider.startCalls, 1);
    provider.start.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(InquiryChat), findsOneWidget);
    expect(provider.loadCalls, 1);
    expect(provider.sentBodies, isEmpty);
    expect(provider.sentItemIds, isEmpty);
  });

  testWidgets('failed farm Chat POST leaves the user on Farm Details',
      (tester) async {
    setPhoneSize(tester);
    final provider = _MessageProvider();
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: FarmDetailsScreen(farmId: 7, farmsService: _FarmService()),
      ),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('Chat'));
    await tester.pump();
    await tester.tap(find.text('Chat'));
    provider.start.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(FarmDetailsScreen), findsOneWidget);
    expect(find.byType(InquiryChat), findsNothing);
    expect(find.text('Farm unavailable'), findsOneWidget);
  });

  testWidgets('Inquire sends the listing ID in the farm POST', (tester) async {
    setPhoneSize(tester);
    final provider = _MessageProvider();
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: FarmGamefowlListingDetailScreen(
            listingId: 11, farmsService: _FarmService()),
      ),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('Inquire'));
    await tester.pump();
    await tester.tap(find.text('Inquire'));
    await tester.pump();
    expect(provider.startCalls, 1);
    expect(provider.sentBodies, isEmpty);
    expect(provider.sentItemIds, [11]);
    expect(find.byType(InquiryChat), findsNothing);
    await tester.tap(find.text('Inquire'));
    await tester.pump();
    expect(provider.startCalls, 1);
    provider.start.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(InquiryChat), findsOneWidget);
    expect(provider.startCalls, 1);
    expect(provider.sentItemIds, [11]);
    expect(provider.sentBodies, isEmpty);
  });

  testWidgets('failed Inquire POST does not open chat or send a card',
      (tester) async {
    setPhoneSize(tester);
    final provider = _MessageProvider();
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: FarmGamefowlListingDetailScreen(
            listingId: 11, farmsService: _FarmService()),
      ),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('Inquire'));
    await tester.pump();
    await tester.tap(find.text('Inquire'));
    provider.start.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(FarmGamefowlListingDetailScreen), findsOneWidget);
    expect(find.byType(InquiryChat), findsNothing);
    expect(provider.sentBodies, isEmpty);
  });
}
