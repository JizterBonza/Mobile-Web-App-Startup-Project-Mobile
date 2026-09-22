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

  test('fetches rider delivery history with the selected filters', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'order_id': 22,
              'order_code': '#ORD-6SFZSEIFLA',
              'ordered_at': '2026-03-14T08:27:42.000000Z',
              'status': {'key': 'delivered', 'label': 'Delivered'},
              'recipient_name': 'Ginx',
              'delivery_address': '9RG9+XXH, Tagum, Davao Region',
              'pickup_store_count': 2,
              'item_count': 6,
            },
          ],
          'count': 1,
          'filters': {'month': 9, 'year': 2026, 'status': 'all'},
        }),
        200,
      );
    });

    final result = await OrderService(
      httpClient: client,
    ).fetchRiderDeliveryHistory(
      month: 9,
      year: 2026,
      status: 'all',
    );

    expect(capturedRequest.method, 'GET');
    expect(
      capturedRequest.url.toString(),
      'https://example.test/api/rider/deliveries?month=9&year=2026&status=all',
    );
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(result['count'], 1);
    expect(result['filters'], {'month': 9, 'year': 2026, 'status': 'all'});

    final deliveries = result['deliveries'] as List<Map<String, dynamic>>;
    expect(deliveries, hasLength(1));
    expect(deliveries.single['order_id'], 22);
    expect(deliveries.single['status'], {
      'key': 'delivered',
      'label': 'Delivered',
    });
  });

  test('rejects an unsupported delivery history status before requesting',
      () async {
    var requestCount = 0;
    final service = OrderService(
      httpClient: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      service.fetchRiderDeliveryHistory(
        month: 9,
        year: 2026,
        status: 'pending',
      ),
      throwsArgumentError,
    );
    expect(requestCount, 0);
  });

  test('fetches a single rider delivery detail by order ID', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'order_id': 123,
            'order_code': 'ORD-20451',
            'ordered_at': '2026-07-10T03:51:00Z',
            'status': {'key': 'delivered', 'label': 'Delivered'},
            'customer_delivery': {
              'customer_name': 'Maria Santos',
              'contact_number': '09157782211',
              'drop_off_address': 'Purok 21, Madaum, Tagum City',
            },
            'pickup_stores': [
              {
                'order_shop_id': 10,
                'shop_id': 4,
                'name': 'PMC Agrivet Supply',
              },
            ],
            'timeline': [
              {
                'key': 'delivered',
                'label': 'Delivered',
                'completed': true,
              },
            ],
            'proof_of_delivery': {
              'groups': [],
            },
          },
        }),
        200,
      );
    });

    final detail = await OrderService(
      httpClient: client,
    ).fetchRiderDeliveryHistoryDetail(123);

    expect(capturedRequest.method, 'GET');
    expect(
      capturedRequest.url.toString(),
      'https://example.test/api/rider/deliveries/123',
    );
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(detail['order_id'], 123);
    expect(detail['customer_delivery']['customer_name'], 'Maria Santos');
    expect(detail['pickup_stores'], hasLength(1));
  });
}
