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
    String? paymentMethod,
    required double subtotal,
    required double shippingFee,
    required double totalAmount,
    String? orderInstruction,
    required int? deliveryMethodId,
    String? voucherCode,
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
      final trimmedVoucher = voucherCode?.trim();

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
        if (trimmedVoucher != null && trimmedVoucher.isNotEmpty)
          'voucher_code': trimmedVoucher,
        // 'payment_method': paymentMethod,
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
          'checkout_url': responseData['checkout_url'],
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

  Future<Map<String, dynamic>> calculateOrder({
    required List<Map<String, dynamic>> items,
    int? shippingAddressId,
    int? deliveryMethodId,
    String? voucherCode,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Authentication required.'};
      }

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {'success': false, 'message': 'User ID not found.'};
      }

      final uri = Uri.parse(ApiEndpoints.calculateOrder);
      final trimmedVoucher = voucherCode?.trim();

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'user_id': userId,
              'items': items,
              if (shippingAddressId != null)
                'shipping_address_id': shippingAddressId,
              if (deliveryMethodId != null)
                'delivery_method_id': deliveryMethodId,
              if (trimmedVoucher != null && trimmedVoucher.isNotEmpty)
                'voucher_code': trimmedVoucher,
            }),
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Request timed out after 15 seconds');
            },
          );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        double toDouble(dynamic value) {
          if (value is num) return value.toDouble();
          return double.tryParse(value?.toString() ?? '') ?? 0.0;
        }

        int toInt(dynamic value) => (value as num?)?.toInt() ?? 0;

        final discountAmount = toDouble(
          responseData['voucher_discount_amount'],
        );

        return {
          'success': responseData['success'] ?? true,
          'subtotal': toDouble(responseData['subtotal']),
          'delivery_base_fee': toDouble(responseData['delivery_base_fee']),
          'delivery_km_fee': toDouble(responseData['delivery_km_fee']),
          'delivery_distance_km':
              toDouble(responseData['delivery_distance_km']),
          'is_reduced_base': responseData['is_reduced_base'] == true,
          'shipping_fee': toDouble(responseData['shipping_fee']),
          'heavy_surcharge': toDouble(responseData['heavy_surcharge']),
          'heavy_surcharge_units': toInt(responseData['heavy_surcharge_units']),
          'total_weight_kg': toDouble(responseData['total_weight_kg']),
          'multi_store_fee': toDouble(responseData['multi_store_fee']),
          'mov_penalty_fee': toDouble(responseData['mov_penalty_fee']),
          'total_fees': toDouble(responseData['total_fees']),
          'total_amount': toDouble(responseData['total_amount']),
          'voucher_id': responseData['voucher_id'],
          'voucher_code': responseData['voucher_code']?.toString(),
          'voucher_discount_amount': discountAmount,
          'store_count': toInt(responseData['store_count']),
          'is_pickup': responseData['is_pickup'] == true,
          'per_store': (responseData['per_store'] as List?)
                  ?.map((store) => Map<String, dynamic>.from(store as Map))
                  .toList() ??
              [],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to calculate order',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
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
            'delivery_base_fee':
                orderDetail?['delivery_base_fee']?.toString() ?? '0.00',
            'delivery_km_fee':
                orderDetail?['delivery_km_fee']?.toString() ?? '0.00',
            'delivery_distance_km':
                orderDetail?['delivery_distance_km']?.toString() ?? '0.00',
            'is_reduced_base': orderDetail?['is_reduced_base'] ?? false,
            'heavy_surcharge':
                orderDetail?['heavy_surcharge']?.toString() ?? '0.00',
            'heavy_surcharge_units': orderDetail?['heavy_surcharge_units'] ?? 0,
            'total_weight_kg':
                orderDetail?['total_weight_kg']?.toString() ?? '0.00',
            'multi_store_fee':
                orderDetail?['multi_store_fee']?.toString() ?? '0.00',
            'mov_penalty_fee':
                orderDetail?['mov_penalty_fee']?.toString() ?? '0.00',
            'total_fees': orderDetail?['total_fees']?.toString() ?? '0.00',
            'store_count': orderDetail?['store_count'] ?? 0,
            'is_pickup': orderDetail?['is_pickup'] ?? false,
            'total_amount': orderDetail?['total_amount']?.toString() ?? '0.00',
            'shipping_address':
                orderDetail?['shipping_address']?.toString() ?? '',
            'drop_location_lat': orderDetail?['drop_location_lat'],
            'drop_location_long': orderDetail?['drop_location_long'],
            'order_instruction': orderDetail?['order_instruction'],
            // 'payment_method': orderDetail?['payment_method']?.toString() ?? '',
            'payment_status':
                orderDetail?['payment_status']?.toString() ?? 'pending',
            'order_detail_created_at': orderDetail?['created_at'],
            'order_detail_updated_at': orderDetail?['updated_at'],
            'user': order['user'],
            'order_items': order['order_items'] ?? [],
            'order_shops': order['order_shops'] ?? [],
            'payment': order['payment'],
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

  /// Update order status.
  /// Sends PUT /api/orders/{id}/status with body: { status, order_id?, shop_id? }.
  /// order_id is in the URL; order_id and shop_id are also sent in the body when provided.
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? shopId,
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

      final body = <String, dynamic>{
        'status': status,
        'order_id': orderId,
      };
      if (shopId != null && shopId.isNotEmpty) {
        body['shop_id'] = shopId;
      }

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
  /// The API returns order-shop groups: each entry has an order_shop_id,
  /// a nested order object (with user/order_detail), a shop object, and items.
  /// This method flattens the response into the structure the rider screens expect.
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
        final orders = (responseData['data'] as List).map((entry) {
          final orderData = entry['order'] as Map<String, dynamic>? ?? {};
          final orderDetail =
              orderData['order_detail'] as Map<String, dynamic>?;
          final user = orderData['user'] as Map<String, dynamic>?;
          final address = orderDetail?['address'] as Map<String, dynamic>?;
          final shop = entry['shop'] as Map<String, dynamic>?;
          final items = entry['items'] as List<dynamic>? ?? [];

          return {
            'id': entry['order_id'],
            'order_shop_id': entry['order_shop_id'],
            'user_id': orderData['user_id'],
            'order_detail_id': orderData['order_detail_id'],
            'order_status': entry['order_status']?.toString() ?? 'pending',
            'rider_id': entry['rider_id'] ?? orderData['rider_id'],
            'ordered_at': orderData['ordered_at']?.toString() ?? '',
            'updated_at': orderData['updated_at']?.toString(),
            'user': user,
            'order_detail': orderDetail,
            'order_items': items,
            'shop': shop,
            'shop_id': entry['shop_id'],
            'order_id': entry['order_id'],
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
            // 'payment_method': orderDetail?['payment_method']?.toString() ?? '',
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
