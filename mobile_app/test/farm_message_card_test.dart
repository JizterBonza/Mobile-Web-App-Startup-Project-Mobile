import 'dart:async';

import 'package:agriconnect/models/messageModel.dart';
import 'package:agriconnect/provider/message_provider.dart';
import 'package:agriconnect/screens/customer/InquiryChat.dart';
import 'package:agriconnect/screens/customer/conversationScreen.dart';
import 'package:agriconnect/screens/customer/farmGamefowlListingDetailScreen.dart';
import 'package:agriconnect/services/farms_service.dart';
import 'package:agriconnect/widgets/farm_gamefowl_message_card.dart';
import 'package:agriconnect/widgets/conversation_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Listings extends FarmsService {
  int calls = 0;
  bool fail = false;

  @override
  Future<Map<String, dynamic>> fetchFarmGamefowlListing(dynamic id) async {
    calls++;
    expect(id, 101);
    if (fail) throw Exception('Listing unavailable');
    return {
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
}

class _ThreadProvider extends MessageProvider {
  _ThreadProvider(this.thread, {this.inboxAvatar});

  final ConversationThread thread;
  final String? inboxAvatar;
  int loads = 0;

  @override
  ConversationThread? get activeThread => thread;

  @override
  List<ConversationModel> get conversations => inboxAvatar == null
      ? const []
      : [
          ConversationModel(
            id: 42,
            shopId: thread.shop?.id,
            farmId: thread.farm?.id,
            shopName: thread.displayName,
            avatarUrl: inboxAvatar,
            lastMessage: '',
          ),
        ];

  @override
  Future<bool> loadConversation(dynamic conversationId) async {
    expect(conversationId, 42);
    loads++;
    return true;
  }

  @override
  Future<void> startLiveUpdates() async {}

  @override
  void clearActiveThread({bool notify = true}) {}
}

ConversationThread _thread({
  required bool farm,
  int messageCount = 1,
  String? avatarUrl,
}) {
  final product = farm
      ? {
          'listing_id': 101,
          'product_name': 'Kelso',
          'item_price': 1500,
        }
      : {
          'item_id': 101,
          'item_name': 'Shop Rooster',
          'item_price': 1500,
        };
  return ConversationThread.fromJson({
    'conversation': {'id': 42, 'name': 'Chat', 'avatar_url': avatarUrl},
    'shop': farm ? null : {'id': 9, 'name': 'Test Shop'},
    'farm': farm ? {'id': 7, 'name': 'Hill Farm'} : null,
    'messages': [
      for (var index = 0; index < messageCount; index++)
        {
          'id': 301 + index,
          'type': 'product',
          'side': 'outgoing',
          'body': 'Is this bird available?',
          'product': product,
        },
    ],
  });
}

void main() {
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('both chat screens use the thread avatar in their header',
      (tester) async {
    phoneSize(tester);
    for (final farm in [true, false]) {
      for (final inquiry in [true, false]) {
        final provider = _ThreadProvider(_thread(
          farm: farm,
          messageCount: 0,
          avatarUrl: 'https://example.test/avatar.png',
        ));
        await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
          value: provider,
          child: MaterialApp(
            home: inquiry
                ? InquiryChat(conversationId: 42, farmsService: _Listings())
                : ConversationScreen(
                    conversationId: 42, farmsService: _Listings()),
          ),
        ));
        await tester.pumpAndSettle();
        final avatar =
            tester.widget<ConversationAvatar>(find.byType(ConversationAvatar));
        expect(avatar.avatarUrl, 'https://example.test/avatar.png');
        expect(avatar.isFarm, farm);
        expect(avatar.size, 40);
      }
    }
  });

  testWidgets('chat headers reuse inbox avatar when thread avatar is null',
      (tester) async {
    phoneSize(tester);
    for (final farm in [true, false]) {
      for (final inquiry in [true, false]) {
        final provider = _ThreadProvider(
          _thread(farm: farm, messageCount: 0),
          inboxAvatar: 'https://example.test/inbox-avatar.png',
        );
        await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
          value: provider,
          child: MaterialApp(
            home: inquiry
                ? InquiryChat(conversationId: 42, farmsService: _Listings())
                : ConversationScreen(
                    conversationId: 42, farmsService: _Listings()),
          ),
        ));
        await tester.pumpAndSettle();
        final avatar =
            tester.widget<ConversationAvatar>(find.byType(ConversationAvatar));
        expect(avatar.avatarUrl, 'https://example.test/inbox-avatar.png');
      }
    }
  });

  testWidgets('farm snapshot is visible before listing details arrive',
      (tester) async {
    final detail = Completer<Map<String, dynamic>>();
    final product = MessageProductSnapshot.fromJson({
      'listing_id': 101,
      'product_name': 'Kelso',
      'item_price': 1500,
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: FarmGamefowlMessageCard(
            product: product,
            body: 'Is this bird available?',
            listingFuture: detail.future,
          ),
        ),
      ),
    ));
    expect(find.text('Kelso'), findsOneWidget);
    expect(find.text('\u20B11500.00'), findsOneWidget);
    expect(find.text('Is this bird available?'), findsOneWidget);
    expect(find.text('Gamefowl | Adult | Male'), findsNothing);

    detail.complete({
      'name': 'Renamed listing',
      'price': 2000,
      'gamefowl': {
        'class': {'name': 'Gamefowl'},
        'age_type': {'name': 'Adult'},
        'sex': 'Male',
      },
    });
    await tester.pump();
    expect(find.text('Kelso'), findsOneWidget);
    expect(find.text('\u20B11500.00'), findsOneWidget);
    expect(find.text('Gamefowl | Adult | Male'), findsOneWidget);
  });

  testWidgets('farm card enriches the snapshot and opens listing details',
      (tester) async {
    phoneSize(tester);
    final listings = _Listings();
    final provider = _ThreadProvider(_thread(farm: true, messageCount: 2));
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: ConversationScreen(conversationId: 42, farmsService: listings),
      ),
    ));
    await tester.pumpAndSettle();
    expect(provider.loads, 1);
    expect(find.byType(FarmGamefowlMessageCard), findsNWidgets(2));
    expect(find.text('Kelso'), findsNWidgets(2));
    expect(find.text('Gamefowl | Adult | Male'), findsNWidgets(2));
    expect(find.text('\u20B11500.00'), findsNWidgets(2));
    expect(find.text('Is this bird available?'), findsNWidgets(2));
    expect(find.text('Buy'), findsNothing);
    expect(listings.calls, 1);

    await tester.tap(find.byType(FarmGamefowlMessageCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(FarmGamefowlListingDetailScreen), findsOneWidget);
  });

  testWidgets('InquiryChat recognizes farm metadata when reopened by ID',
      (tester) async {
    phoneSize(tester);
    final listings = _Listings();
    final provider = _ThreadProvider(_thread(farm: true));
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: InquiryChat(conversationId: 42, farmsService: listings),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Hill Farm'), findsOneWidget);
    expect(find.byType(FarmGamefowlMessageCard), findsOneWidget);
    expect(find.text('Gamefowl | Adult | Male'), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
    expect(listings.calls, 1);
  });

  testWidgets('failed detail request retains farm message snapshot',
      (tester) async {
    phoneSize(tester);
    final listings = _Listings()..fail = true;
    final provider = _ThreadProvider(_thread(farm: true));
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: ConversationScreen(conversationId: 42, farmsService: listings),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Kelso'), findsOneWidget);
    expect(find.text('\u20B11500.00'), findsOneWidget);
    expect(find.text('Is this bird available?'), findsOneWidget);
    expect(find.byType(FarmGamefowlMessageCard), findsOneWidget);
    expect(find.text('Gamefowl | Adult | Male'), findsNothing);
  });

  testWidgets('shop conversation keeps its existing Buy card', (tester) async {
    phoneSize(tester);
    final listings = _Listings();
    final provider = _ThreadProvider(_thread(farm: false));
    await tester.pumpWidget(ChangeNotifierProvider<MessageProvider>.value(
      value: provider,
      child: MaterialApp(
        home: ConversationScreen(conversationId: 42, farmsService: listings),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Shop Rooster'), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget);
    expect(find.byType(FarmGamefowlMessageCard), findsNothing);
    expect(listings.calls, 0);
  });
}
