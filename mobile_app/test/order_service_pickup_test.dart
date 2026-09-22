import 'dart:convert';

import 'package:agriconnect/services/order_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'TEST_URL=https://example.test');
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
  });

  test('pickup update sends the exact shop status payload', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({'success': true, 'message': 'Updated'}),
        200,
      );
    });
    final service = OrderService(httpClient: client);

    final result = await service.updateShopOrderStatus(
      orderId: 52,
      shopId: 10,
      statusId: 5,
      notes: 'Order picked up.',
    );

    expect(result['success'], isTrue);
    expect(capturedRequest.method, 'PUT');
    expect(
      capturedRequest.url.toString(),
      'https://example.test/api/orders/52/status',
    );
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(
      jsonDecode(capturedRequest.body),
      {
        'shop_id': 10,
        'status': 5,
        'notes': 'Order picked up.',
      },
    );
  });

  test('active delivery detail returns the response data map', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'order_id': 52,
            'recipient_contact_number': '0912384756',
            'drop_off_coordinates': {
              'latitude': 7.3775118,
              'longitude': 125.8198915,
            },
            'active_order_shops': [
              {
                'shop_id': 10,
                'order_status_description': 'In-Transit',
              },
            ],
          },
        }),
        200,
      );
    });
    final service = OrderService(httpClient: client);

    final order = await service.fetchActiveDeliveryByOrderId(52);

    expect(capturedRequest.method, 'GET');
    expect(
      capturedRequest.url.toString(),
      'https://example.test/api/rider/active-deliveries/52',
    );
    expect(order['order_id'], 52);
    expect(order['recipient_contact_number'], '0912384756');
    expect(order['drop_off_coordinates']['latitude'], 7.3775118);
    expect(
      (order['active_order_shops'] as List).first['shop_id'],
      10,
    );
  });

  test('active delivery detail rejects malformed data', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'success': true, 'data': []}),
        200,
      ),
    );
    final service = OrderService(httpClient: client);

    expect(
      () => service.fetchActiveDeliveryByOrderId(52),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Invalid active-delivery data'),
        ),
      ),
    );
  });
}
