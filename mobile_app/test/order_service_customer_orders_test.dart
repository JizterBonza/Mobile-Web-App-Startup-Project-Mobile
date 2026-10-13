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
}
