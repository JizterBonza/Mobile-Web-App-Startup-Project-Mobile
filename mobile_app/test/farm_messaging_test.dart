import 'dart:convert';

import 'package:agriconnect/models/messageModel.dart';
import 'package:agriconnect/provider/message_provider.dart';
import 'package:agriconnect/services/message_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'TEST_URL=https://example.test');
    SharedPreferences.setMockInitialValues({'auth_token': 'farm-token'});
  });

  test('farm conversation POST sends empty JSON and parses a thread', () async {
    for (final code in [200, 201]) {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(),
            'https://example.test/api/farms/7/messages');
        expect(request.headers['authorization'], 'Bearer farm-token');
        expect(request.headers['content-type'], 'application/json');
        expect(request.body, '{}');
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'conversation': {'id': 42, 'name': 'Test Farm'},
                'farm': {'id': 7, 'name': 'Test Farm'},
                'messages': [],
              }
            }),
            code);
      });
      final result =
          await MessageService(httpClient: client).startFarmConversation(7);
      expect(result['success'], isTrue);
      final thread = result['data'] as ConversationThread;
      expect(thread.conversation.id, 42);
      expect(thread.farm?.id, 7);
      expect(thread.displayName, 'Test Farm');
      client.close();
    }
  });

  test('farm conversation POST accepts a listing ID or message body', () async {
    for (final payload in [
      {'item_id': 11},
      {'body': 'Hello farmer'},
    ]) {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/farms/7/messages');
        expect(jsonDecode(request.body), payload);
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'conversation': {'id': 42},
                'messages': [],
              }
            }),
            201);
      });
      final result =
          await MessageService(httpClient: client).startFarmConversation(
        7,
        itemId: payload['item_id'],
        body: payload['body']?.toString(),
      );
      expect(result['success'], isTrue);
      client.close();
    }
  });

  test('farm POST error does not fall back to shop conversation', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.url.path, '/api/farms/7/messages');
      return http.Response('{"message":"Farm unavailable"}', 403);
    });
    final provider =
        MessageProvider(messageService: MessageService(httpClient: client));
    final success = await provider.startOrResumeFarmConversation(
        farmId: 7, farmName: 'Test Farm');
    expect(success, isFalse);
    expect(provider.error, 'Farm unavailable');
    expect(provider.activeThread, isNull);
    expect(requests, 1);
    client.close();
    provider.dispose();
  });

  test('farm POST rejects unsuccessful and ID-less 200 responses', () async {
    for (final body in [
      '{"success":false,"message":"Not allowed"}',
      '{"success":true,"data":{"messages":[]}}',
    ]) {
      final client = MockClient((request) async => http.Response(body, 200));
      final result =
          await MessageService(httpClient: client).startFarmConversation(7);
      expect(result['success'], isFalse);
      client.close();
    }
  });

  test('provider stores a farm thread and preserves its name', () async {
    final client = MockClient((request) async => http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'conversation': {'id': 42},
            'messages': [],
          }
        }),
        201));
    final provider =
        MessageProvider(messageService: MessageService(httpClient: client));
    expect(
        await provider.startOrResumeFarmConversation(
            farmId: 7, farmName: 'Test Farm'),
        isTrue);
    expect(provider.activeThread?.conversation.id, 42);
    expect(provider.activeThread?.displayName, 'Test Farm');
    expect(provider.conversations.single.farmId, 7);
    expect(provider.conversations.single.shopName, 'Test Farm');
    client.close();
    provider.dispose();
  });

  test('inbox refresh keeps known farm metadata when list omits it', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'conversation': {
                  'id': 42,
                  'avatar_url': 'farms/logos/hill.jpg',
                },
                'messages': [],
              }
            }),
            201);
      }
      expect(request.url.path, '/api/messages');
      return http.Response(
          jsonEncode({
            'conversations': [
              {'id': 42, 'last_message': 'Hello'}
            ],
            'unread_count': 0,
          }),
          200);
    });
    final provider =
        MessageProvider(messageService: MessageService(httpClient: client));
    expect(
        await provider.startOrResumeFarmConversation(
            farmId: 7, farmName: 'Test Farm'),
        isTrue);
    expect(await provider.fetchConversations(silent: true), isTrue);
    expect(provider.conversations.single.farmId, 7);
    expect(provider.conversations.single.shopName, 'Test Farm');
    expect(provider.conversations.single.avatarUrl,
        'https://example.test/storage/farms/logos/hill.jpg');
    client.close();
    provider.dispose();
  });

  test('shop conversation still uses its existing endpoint', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/shops/9/messages');
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'conversation': {'id': 50},
              'shop': {'id': 9, 'name': 'Shop'},
              'messages': [],
            }
          }),
          201);
    });
    final result =
        await MessageService(httpClient: client).startConversation(shopId: 9);
    expect(result['success'], isTrue);
    client.close();
  });

  test('sending a picked listing uses the existing conversation endpoint',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/messages/42');
      expect(request.headers['authorization'], 'Bearer farm-token');
      expect(jsonDecode(request.body), {'item_id': 101});
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'conversation': {'id': 42},
              'farm': {'id': 7, 'name': 'Hill Farm'},
              'messages': [
                {
                  'id': 301,
                  'type': 'product',
                  'product': {'listing_id': 101, 'product_name': 'Kelso'}
                }
              ],
            }
          }),
          201);
    });
    final result = await MessageService(httpClient: client)
        .sendMessage(conversationId: 42, itemId: 101);
    expect(result['success'], isTrue);
    final thread = result['data'] as ConversationThread;
    expect(thread.farm?.id, 7);
    expect(thread.messages.single.product?.listingId, 101);
    client.close();
  });

  test('inbox model reads farm names without a shop field', () {
    final conversation = ConversationModel.fromJson({
      'id': 42,
      'farm_id': 7,
      'farm_name': 'Test Farm',
      'last_message': 'Hello',
    });
    expect(conversation.farmId, 7);
    expect(conversation.shopId, isNull);
    expect(conversation.shopName, 'Test Farm');
  });

  test('inbox model resolves farm and shop avatar URLs', () {
    final farm = ConversationModel.fromJson({
      'id': 42,
      'farm_id': 7,
      'farm_name': 'Hill Farm',
      'avatar_url': 'farms/logos/hill.jpg',
    });
    final shop = ConversationModel.fromJson({
      'id': 43,
      'shop_id': 9,
      'shop_name': 'Test Shop',
      'avatar_url': 'https://cdn.example.test/shop.png',
    });
    expect(farm.avatarUrl, 'https://example.test/storage/farms/logos/hill.jpg');
    expect(shop.avatarUrl, 'https://cdn.example.test/shop.png');
    expect(farm.copyWith(lastMessage: 'Hello').avatarUrl, farm.avatarUrl);
  });

  test('chat header resolves its avatar and prefers farm profile avatar', () {
    final thread = ConversationThread.fromJson({
      'conversation': {
        'id': 42,
        'avatar_url': 'avatars/customer.jpg',
      },
      'farm': {
        'id': 7,
        'name': 'Hill Farm',
        'avatar_url': 'farms/logos/hill.jpg',
      },
      'messages': [],
    });
    expect(thread.conversation.avatarUrl,
        'https://example.test/storage/avatars/customer.jpg');
    expect(
        thread.avatarUrl, 'https://example.test/storage/farms/logos/hill.jpg');
    final shopThread = ConversationThread.fromJson({
      'conversation': {
        'id': 43,
        'avatar_url': 'https://cdn.example.test/shop-avatar.png',
      },
      'shop': {'id': 9, 'name': 'Test Shop'},
      'messages': [],
    });
    expect(shopThread.avatarUrl, 'https://cdn.example.test/shop-avatar.png');
  });

  test('farm listing message parses as a product card', () {
    final message = MessageModel.fromJson({
      'id': 99,
      'type': 'product',
      'listing': {
        'id': 11,
        'name': 'Sample Rooster',
        'price': 2500,
        'image': '/rooster.jpg',
      },
    });
    expect(message.isProduct, isTrue);
    expect(message.product?.id, 11);
    expect(message.product?.name, 'Sample Rooster');
  });

  test('full farm thread reads listing snapshot and farm context', () {
    final thread = ConversationThread.fromJson({
      'conversation': {
        'id': 42,
        'name': 'Juan Dela Cruz',
        'avatar_url': null,
        'last_seen': 'Active now',
      },
      'messages': [
        {'id': 'date-2026-10-25', 'type': 'date', 'label': 'Today'},
        {
          'id': 301,
          'type': 'product',
          'side': 'outgoing',
          'time': '10.30 AM',
          'created_at': '2026-10-25T10:30:00+08:00',
          'sent_by': 'Staff',
          'status': 'sent',
          'body': 'Is this bird available?',
          'product': {
            'listing_id': 101,
            'product_name': 'Kelso',
            'item_price': 1500,
            'effective_price': 1500,
            'active_discount_percent': 0,
            'image_url': 'gamefowls/kelso.jpg',
            'unit_label': 'per head',
            'item_quantity': 5,
          },
        },
        {
          'id': 302,
          'type': 'text',
          'side': 'incoming',
          'time': '10.32 AM',
          'created_at': '2026-10-25T10:32:00+08:00',
          'body': 'Yes, it is available.',
        },
      ],
      'shop': null,
      'farm': {'id': 7, 'name': 'Hill Farm'},
    });

    expect(thread.shop, isNull);
    expect(thread.farm?.id, 7);
    expect(thread.displayName, 'Hill Farm');
    expect(thread.messages.first.isDate, isTrue);
    final productMessage = thread.messages[1];
    expect(productMessage.body, 'Is this bird available?');
    expect(productMessage.product?.listingId, 101);
    expect(productMessage.product?.name, 'Kelso');
    expect(productMessage.product?.price, 1500);
    expect(productMessage.product?.imageUrl, contains('gamefowls/kelso.jpg'));
  });
}
