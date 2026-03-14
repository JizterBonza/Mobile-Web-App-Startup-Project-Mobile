import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

/// Service for managing payment methods
class PaymentService extends ApiService {
  /// Fetch payment methods from API
  Future<Map<String, dynamic>> fetchPaymentMethods() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final uri = Uri.parse(ApiEndpoints.getPaymentMethods);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Handle both direct array response and wrapped response
        List<dynamic> paymentMethods = [];

        if (responseData is List) {
          paymentMethods = responseData;
        } else if (responseData is Map && responseData['success'] == true) {
          paymentMethods = responseData['data'] ?? [];
        } else if (responseData is Map && responseData['data'] != null) {
          paymentMethods =
              responseData['data'] is List ? responseData['data'] : [];
        }

        return {
          'success': true,
          'message': 'Payment methods retrieved successfully',
          'data': paymentMethods,
        };
      } else {
        String errorMessage = 'Failed to retrieve payment methods';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': [],
      };
    }
  }

  /// Initiate payment checkout for an existing order.
  /// Returns a checkout URL that can be loaded in a WebView.
  /// Sample response: { "success": true, "checkout_url": "https://..." }
  Future<Map<String, dynamic>> initiateCheckout({
    required String orderId,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
        };
      }

      final uri = Uri.parse(
        ApiEndpoints.paymentCheckoutUrl.replaceAll('{orderId}', orderId),
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Checkout initiated',
          'checkout_url': responseData['checkout_url'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message']?.toString() ??
              'Failed to initiate payment',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Returns a map of payment method ID (as string) -> display name.
  /// Use this to show payment method name instead of ID on order details.
  static Future<Map<String, String>> getPaymentMethodNames() async {
    final service = PaymentService();
    final result = await service.fetchPaymentMethods();
    final map = <String, String>{};
    if (result['success'] == true && result['data'] != null) {
      for (final method in result['data'] as List) {
        final id = method['id']?.toString();
        final name = method['name']?.toString();
        if (id != null && name != null && name.isNotEmpty) {
          map[id] = name;
        }
      }
    }
    return map;
  }
}
