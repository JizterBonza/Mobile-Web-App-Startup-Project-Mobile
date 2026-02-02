import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

/// Service for managing orders
class OrderService extends ApiService {
  /// Create a new order
  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> items,
    required String shippingAddress,
    required int? shippingAddressId,
    required String paymentMethod,
    required double subtotal,
    required double shippingFee,
    required double totalAmount,
    String? orderInstruction,
    required int? deliveryMethodId,
  }) async {
    try {
      print('shippingAddressId: $shippingAddressId');
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found. Please login again.',
          'data': null,
        };
      }

      final uri = Uri.parse(ApiEndpoints.createOrder);

      final body = {
        'user_id': userId,
        'items': items,
        'subtotal': subtotal,
        'shipping_fee': shippingFee,
        'total_amount': totalAmount,
        'shipping_address': shippingAddress,
        'shipping_address_id': shippingAddressId,
        'order_instruction': orderInstruction ?? '',
        'delivery_method_id': deliveryMethodId,
        'payment_method': paymentMethod,
      };

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      )
          .timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Order created successfully',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to create order';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData.containsKey('errors')) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first.toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': responseData,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Fetch orders for current user
  /// Flattens nested API response structure
  Future<Map<String, dynamic>> fetchOrders({
    String? status,
  }) async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final userId = await ApiService.getUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('User ID not found. Please login again.');
    }

    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      ApiEndpoints.getOrdersByUserId.replaceAll('{user_id}', userId),
    ).replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

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

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['success'] == true && responseData['data'] != null) {
        final orders = (responseData['data'] as List).map((order) {
          final orderDetail = order['order_detail'] as Map<String, dynamic>?;

          return {
            'id': order['id'],
            'user_id': order['user_id'],
            'order_detail_id': order['order_detail_id'],
            'order_status': order['order_status']?.toString() ?? 'Pending',
            'ordered_at': order['ordered_at']?.toString() ?? '',
            'updated_at': order['updated_at']?.toString(),
            'order_code': orderDetail?['order_code']?.toString() ?? '',
            'subtotal': orderDetail?['subtotal']?.toString() ?? '0.00',
            'shipping_fee': orderDetail?['shipping_fee']?.toString() ?? '0.00',
            'total_amount': orderDetail?['total_amount']?.toString() ?? '0.00',
            'shipping_address':
                orderDetail?['shipping_address']?.toString() ?? '',
            'drop_location_lat': orderDetail?['drop_location_lat'],
            'drop_location_long': orderDetail?['drop_location_long'],
            'order_instruction': orderDetail?['order_instruction'],
            'payment_method': orderDetail?['payment_method']?.toString() ?? '',
            'payment_status':
                orderDetail?['payment_status']?.toString() ?? 'pending',
            'order_detail_created_at': orderDetail?['created_at'],
            'order_detail_updated_at': orderDetail?['updated_at'],
            'user': order['user'],
            'order_items': order['order_items'] ?? [],
            'order_id': order['id'],
          };
        }).toList();

        return {
          'orders': orders,
          'count': responseData['count'] ?? orders.length,
        };
      }
    } else {
      throw Exception('Failed to load orders: ${response.statusCode}');
    }

    return {
      'orders': [],
      'count': 0,
    };
  }

  /// Get a single order by ID
  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final uri = Uri.parse(
        ApiEndpoints.getOrderById.replaceAll('{id}', orderId),
      );

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
        return {
          'success': true,
          'message': responseData['message'] ?? 'Order retrieved successfully',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to retrieve order';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': responseData,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Update order status
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final uri = Uri.parse(
        ApiEndpoints.updateOrderStatus.replaceAll('{id}', orderId),
      );

      final body = {
        'status': status,
      };

      final response = await http
          .put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      )
          .timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message':
              responseData['message'] ?? 'Order status updated successfully',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to update order status';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData.containsKey('errors')) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first.toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': responseData,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Cancel an order
  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final uri = Uri.parse(
        ApiEndpoints.cancelOrder.replaceAll('{id}', orderId),
      );

      final response = await http.delete(
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Order cancelled successfully',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to cancel order';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData.containsKey('errors')) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first.toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': responseData,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Get order history for current user
  Future<Map<String, dynamic>> getOrderHistory({
    int? limit,
    int? offset,
  }) async {
    return await fetchOrders();
  }

  /// Fetch orders assigned to a specific rider
  /// Uses the getOrdersByRiderId endpoint
  /// Preserves the original nested API structure for map screens
  Future<Map<String, dynamic>> fetchOrdersByRiderId({
    String? status,
  }) async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final riderId = await ApiService.getUserId();
    if (riderId == null || riderId.isEmpty) {
      throw Exception('Rider ID not found. Please login again.');
    }

    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      ApiEndpoints.getOrdersByRiderId.replaceAll('{rider_id}', riderId),
    ).replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

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

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['success'] == true && responseData['data'] != null) {
        // Preserve the original nested structure from API
        // This includes: order_detail, order_detail.address, user, order_items
        final orders = (responseData['data'] as List).map((order) {
          final orderDetail = order['order_detail'] as Map<String, dynamic>?;
          final user = order['user'] as Map<String, dynamic>?;
          final address = orderDetail?['address'] as Map<String, dynamic>?;

          // Return the original structure with some flattened fields for backward compatibility
          return {
            // Original nested structure preserved
            'id': order['id'],
            'user_id': order['user_id'],
            'order_detail_id': order['order_detail_id'],
            'order_status': order['order_status']?.toString() ?? 'pending',
            'rider_id': order['rider_id'],
            'ordered_at': order['ordered_at']?.toString() ?? '',
            'updated_at': order['updated_at']?.toString(),
            'user': user,
            'order_detail': orderDetail,
            'order_items': order['order_items'] ?? [],

            // Flattened fields for backward compatibility with existing code
            'order_id': order['id'],
            'order_code': orderDetail?['order_code']?.toString() ?? '',
            'subtotal': orderDetail?['subtotal']?.toString() ?? '0.00',
            'shipping_fee': orderDetail?['shipping_fee']?.toString() ?? '0.00',
            'total_amount': orderDetail?['total_amount']?.toString() ?? '0.00',
            'shipping_address':
                orderDetail?['shipping_address']?.toString() ?? '',
            'address_id': orderDetail?['address_id'],
            'drop_location_lat':
                address?['latitude'] ?? orderDetail?['drop_location_lat'],
            'drop_location_long':
                address?['longitude'] ?? orderDetail?['drop_location_long'],
            'recipient_name': address?['recipient_name']?.toString() ?? '',
            'recipient_contact': address?['contact_number']?.toString() ?? '',
            'order_instruction': orderDetail?['order_instruction'],
            'delivery_method_id': orderDetail?['delivery_method_id'],
            'payment_method': orderDetail?['payment_method']?.toString() ?? '',
            'payment_status':
                orderDetail?['payment_status']?.toString() ?? 'pending',
            'order_detail_created_at': orderDetail?['created_at'],
            'order_detail_updated_at': orderDetail?['updated_at'],
            'address': address,
          };
        }).toList();

        return {
          'orders': orders,
          'count': responseData['count'] ?? orders.length,
        };
      }
    } else {
      throw Exception('Failed to load rider orders: ${response.statusCode}');
    }

    return {
      'orders': [],
      'count': 0,
    };
  }

  /// Fetch delivery methods
  Future<Map<String, dynamic>> fetchDeliveryMethods() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final uri = Uri.parse(ApiEndpoints.getDeliveryMethods);

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

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'message': 'Delivery methods retrieved successfully',
          'data': responseData['data'] ?? [],
        };
      } else {
        String errorMessage = 'Failed to retrieve delivery methods';
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
}
