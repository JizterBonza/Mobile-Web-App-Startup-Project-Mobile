import 'dart:convert';

import 'package:agriconnect/services/cart_services.dart';
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

  test('cart update sends a PUT request with the absolute quantity', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'Cart updated',
          'data': {'id': 12, 'quantity': 3},
        }),
        200,
      );
    });

    final result = await CartService(httpClient: client).updateCart(
      cartItemId: '12',
      quantity: 3,
    );

    expect(capturedRequest.method, 'PUT');
    expect(
      capturedRequest.url.toString(),
      'https://example.test/api/carts/12',
    );
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(capturedRequest.body), {'quantity': 3});
    expect(result, {
      'success': true,
      'message': 'Cart updated',
      'data': {'id': 12, 'quantity': 3},
    });
  });

  test('cart update preserves an API error response', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'message': 'The quantity is invalid.',
          'errors': {
            'quantity': ['The quantity must be at least 1.'],
          },
        }),
        422,
      ),
    );

    final result = await CartService(httpClient: client).updateCart(
      cartItemId: 12,
      quantity: 0,
    );

    expect(result['success'], isFalse);
    expect(result['message'], 'The quantity is invalid.');
    expect(result['data'], {
      'message': 'The quantity is invalid.',
      'errors': {
        'quantity': ['The quantity must be at least 1.'],
      },
    });
  });
}
