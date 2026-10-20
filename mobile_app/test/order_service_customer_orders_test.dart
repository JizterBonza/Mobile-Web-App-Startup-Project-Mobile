import 'dart:convert';

import 'package:agriconnect/services/order_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.testLoad(
        fileInput:
            'TEST_URL=https://example.test\nSTAGING_URL=https://example.test');
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_id': '3',
    });
  });

  test('customer orders retain delivery method with nested fallback', () async {
    final responseOrders = [
      {
        'id': 50,
        'order_status': 3,
        'delivery_method_id': 3,
        'order_detail': {'delivery_method_id': 1},
      },
      {
        'id': 51,
        'order_status': '3',
        'delivery_method_id': '3',
      },
      {
        'id': 52,
        'order_status': 3,
        'order_detail': {'delivery_method_id': 3},
      },
      {
        'id': 53,
        'order_status': 3,
        'delivery_method_id': null,
        'order_detail': {'delivery_method_id': 3},
      },
      {'id': 54, 'order_status': 3},
    ];
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://example.test/api/orders/user/3');
      expect(request.headers['authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode({'success': true, 'data': responseOrders, 'count': 5}),
        200,
      );
    });
    addTearDown(client.close);

    final result = await OrderService(httpClient: client).fetchOrders();
    final orders = result['orders'] as List;
    expect(orders.map((order) => order['delivery_method_id']),
        [3, '3', 3, 3, null]);
    expect(orders.map((order) => order['order_status']),
        ['3', '3', '3', '3', '3']);
    expect(result['count'], 5);
  });

  test('order creation sends cart row IDs only on items', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://example.test/api/orders/create');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.containsKey('cart_id'), isFalse);
      expect((body['items'] as List).single['cart_id'], 42);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'id': 88}
        }),
        200,
      );
    });
    addTearDown(client.close);

    final result = await OrderService(httpClient: client).createOrder(
      items: [
        {
          'cart_id': 42,
          'item_id': '9',
          'shop_id': '3',
          'quantity': 1,
          'price_at_purchase': 20.0
        },
      ],
      shippingAddress: 'Test address',
      shippingAddressId: 1,
      subtotal: 20,
      shippingFee: 0,
      totalAmount: 20,
      deliveryMethodId: 1,
    );
    expect(result['success'], isTrue);
  });
}
