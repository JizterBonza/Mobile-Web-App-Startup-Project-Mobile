import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

/// Service for managing orders.
class OrderService extends ApiService {
  OrderService({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  /// Decode an API response safely.
  dynamic _decodeResponseBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};

    try {
      return jsonDecode(body);
    } on FormatException {
      return <String, dynamic>{'raw_response': body};
    }
  }

  /// Convert backend validation errors into readable messages.
  String _formatValidationErrors(dynamic errors) {
    if (errors is Map) {
      final messages = <String>[];
      errors.forEach((key, value) {
        final formatted = _formatValidationValue(value);
        if (formatted.isNotEmpty) messages.add('$key: $formatted');
      });
      return messages.join('\n');
    }

    if (errors is List) {
      return errors
          .map(_formatValidationValue)
          .where((message) => message.isNotEmpty)
          .join('\n');
    }

    return errors?.toString() ?? '';
  }

  String _formatValidationValue(dynamic value) {
    if (value is List) {
      return value
          .map(_formatValidationValue)
          .where((message) => message.isNotEmpty)
          .join(', ');
    }

    if (value is Map) {
      return value.entries.map((entry) {
        final message = _formatValidationValue(entry.value);
        return message.isEmpty ? '' : '${entry.key}: $message';
      }).where((message) => message.isNotEmpty).join(', ');
    }

    return value?.toString() ?? '';
  }

  /// Extract the most useful error message from an API response.
  String _extractErrorMessage(
    dynamic responseData, {
    required String fallback,
  }) {
    if (responseData is Map) {
      final formattedErrors =
          _formatValidationErrors(responseData['errors']);
      if (formattedErrors.isNotEmpty) return formattedErrors;

      final message = responseData['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;

      final error = responseData['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return error;

      final rawResponse = responseData['raw_response']?.toString().trim();
      if (rawResponse != null && rawResponse.isNotEmpty) {
        return '$fallback: $rawResponse';
      }
    }

    return fallback;
  }

  int? _positiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// Resolve the cart ID from the explicit argument first, then from item
  /// maps that actually contain a cart_id/cartId field. Never use a product
  /// ID or cart-item ID as a substitute for the cart ID.
  int? _resolveCartId({
    int? cartId,
    required List<Map<String, dynamic>> items,
  }) {
    final explicitId = _positiveInt(cartId);
    if (explicitId != null) return explicitId;

    for (final item in items) {
      final candidate = _positiveInt(item['cart_id'] ?? item['cartId']);
      if (candidate != null) return candidate;
    }
    return null;
  }

  /// Create a new order.
  ///
  /// Pass [cartId] when creating an order from the user's cart. If the
  /// cart ID is also present as `cart_id` or `cartId` in an item map, it
  /// can be resolved from there. Product IDs are never treated as cart IDs.
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
    int? cartId,
  }) async {
    try {
      print('========== CREATE ORDER ==========');
      print('Shipping address ID: $shippingAddressId');
      print('Delivery method ID: $deliveryMethodId');
      print('Payment method supplied: ${paymentMethod != null}');
      print('Item count: ${items.length}');

      if (items.isEmpty) {
        return {
          'success': false,
          'message': 'Your cart is empty. Add an item before checkout.',
          'data': null,
        };
      }

      if (shippingAddressId == null || shippingAddressId <= 0) {
        return {
          'success': false,
          'message': 'Please select a valid shipping address.',
          'data': null,
        };
      }

      if (deliveryMethodId == null || deliveryMethodId <= 0) {
        return {
          'success': false,
          'message': 'Please select a valid delivery method.',
          'data': null,
        };
      }

      final resolvedCartId = _resolveCartId(cartId: cartId, items: items);
      if (resolvedCartId == null) {
        return {
          'success': false,
          'message': 'Cart ID is missing or invalid. Pass the actual cart ID '
              'to createOrder(cartId: ...) before submitting checkout.',
          'data': null,
        };
      }

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
      final trimmedPaymentMethod = paymentMethod?.trim();

      final body = <String, dynamic>{
        'user_id': userId,
        'cart_id': resolvedCartId,
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
        if (trimmedPaymentMethod != null && trimmedPaymentMethod.isNotEmpty)
          'payment_method': trimmedPaymentMethod,
      };

      print('CREATE ORDER URL: $uri');
      print('CREATE ORDER REQUEST BODY: ${jsonEncode(body)}');

      final request = _httpClient?.post ?? http.post;
      final response = await request(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds.');
        },
      );

      final responseData = _decodeResponseBody(response.body);
      print('CREATE ORDER STATUS: ${response.statusCode}');
      print('CREATE ORDER RESPONSE: ${response.body}');

      final isSuccessfulStatus =
          response.statusCode >= 200 && response.statusCode < 300;
      final apiReportedFailure =
          responseData is Map && responseData['success'] == false;

      if (isSuccessfulStatus && !apiReportedFailure) {
        final data = responseData is Map
            ? responseData['data'] ?? responseData
            : responseData;
        final checkoutUrl =
            responseData is Map ? responseData['checkout_url'] : null;
        final message = responseData is Map
            ? responseData['message']?.toString() ??
                'Order created successfully.'
            : 'Order created successfully.';

        print('CREATE ORDER SUCCESS: $message');
        print('CREATE ORDER CHECKOUT URL: $checkoutUrl');

        return {
          'success': true,
          'message': message,
          'data': data,
          'checkout_url': checkoutUrl,
        };
      }

      final errorMessage = _extractErrorMessage(
        responseData,
        fallback: 'Failed to create order (HTTP ${response.statusCode}).',
      );
      print('CREATE ORDER ERRORS: $errorMessage');

      return {
        'success': false,
        'message': errorMessage,
        'data': responseData,
        'status_code': response.statusCode,
      };
    } on TimeoutException catch (e) {
      print('CREATE ORDER TIMEOUT: $e');
      return {
        'success': false,
        'message': 'The order request timed out. Please try again.',
        'data': null,
      };
    } catch (e, stackTrace) {
      print('CREATE ORDER EXCEPTION: $e');
      print('CREATE ORDER STACK TRACE: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to create order: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Calculate order totals before checkout.
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
      final request = _httpClient?.post ?? http.post;

      final response = await request(
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
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds.');
        },
      );

      final responseData = _decodeResponseBody(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData is Map &&
          responseData['success'] != false) {
        double toDouble(dynamic value) {
          if (value is num) return value.toDouble();
          return double.tryParse(value?.toString() ?? '') ?? 0.0;
        }

        int toInt(dynamic value) {
          if (value is num) return value.toInt();
          return int.tryParse(value?.toString() ?? '') ?? 0;
        }

        final rawPerStore = responseData['per_store'];
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
          'heavy_surcharge_units':
              toInt(responseData['heavy_surcharge_units']),
          'total_weight_kg': toDouble(responseData['total_weight_kg']),
          'multi_store_fee': toDouble(responseData['multi_store_fee']),
          'mov_penalty_fee': toDouble(responseData['mov_penalty_fee']),
          'total_fees': toDouble(responseData['total_fees']),
          'total_amount': toDouble(responseData['total_amount']),
          'voucher_id': responseData['voucher_id'],
          'voucher_code': responseData['voucher_code']?.toString(),
          'voucher_discount_amount':
              toDouble(responseData['voucher_discount_amount']),
          'store_count': toInt(responseData['store_count']),
          'is_pickup': responseData['is_pickup'] == true,
          'per_store': rawPerStore is List
              ? rawPerStore
                  .whereType<Map>()
                  .map((store) => Map<String, dynamic>.from(store))
                  .toList()
              : <Map<String, dynamic>>[],
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          responseData,
          fallback:
              'Failed to calculate order (HTTP ${response.statusCode}).',
        ),
        'data': responseData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to calculate order: ${e.toString()}',
      };
    }
  }

  /// Fetch orders for the current user.
  Future<Map<String, dynamic>> fetchOrders({String? status}) async {
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
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final request = _httpClient?.get ?? http.get;
    final response = await request(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds.');
      },
    );

    final responseData = _decodeResponseBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        responseData,
        fallback: 'Failed to load orders: ${response.statusCode}',
      ));
    }

    if (responseData is Map &&
        responseData['success'] == true &&
        responseData['data'] is List) {
      final orders = (responseData['data'] as List).map((raw) {
        final order = Map<String, dynamic>.from(raw as Map);
        final detailRaw = order['order_detail'];
        final orderDetail =
            detailRaw is Map ? Map<String, dynamic>.from(detailRaw) : null;

        return <String, dynamic>{
          'id': order['id'],
          'user_id': order['user_id'],
          'order_detail_id': order['order_detail_id'],
          'order_status': order['order_status']?.toString() ?? 'Pending',
          'delivery_method_id':
              order['delivery_method_id'] ?? orderDetail?['delivery_method_id'],
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
          'total_amount':
              orderDetail?['total_amount']?.toString() ?? '0.00',
          'shipping_address':
              orderDetail?['shipping_address']?.toString() ?? '',
          'drop_location_lat': orderDetail?['drop_location_lat'],
          'drop_location_long': orderDetail?['drop_location_long'],
          'order_instruction': orderDetail?['order_instruction'],
          'payment_status':
              orderDetail?['payment_status']?.toString() ?? 'pending',
          'voucher_discount_amount':
              orderDetail?['voucher_discount_amount']?.toString() ?? '0.00',
          'order_detail_created_at': orderDetail?['created_at'],
          'order_detail_updated_at': orderDetail?['updated_at'],
          'user': order['user'],
          'order_items': order['order_items'] ?? [],
          'order_shops': order['order_shops'] ?? [],
          'payment': order['payment'],
          'order_id': order['id'],
        };
      }).toList();

      return {'orders': orders, 'count': responseData['count'] ?? orders.length};
    }

    return {'orders': <Map<String, dynamic>>[], 'count': 0};
  }

  /// Get a single order by ID.
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
      final request = _httpClient?.get ?? http.get;
      final response = await request(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds.');
        },
      );

      final responseData = _decodeResponseBody(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !(responseData is Map && responseData['success'] == false)) {
        return {
          'success': true,
          'message': responseData is Map
              ? responseData['message'] ?? 'Order retrieved successfully.'
              : 'Order retrieved successfully.',
          'data': responseData is Map
              ? responseData['data'] ?? responseData
              : responseData,
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          responseData,
          fallback: 'Failed to retrieve order (HTTP ${response.statusCode}).',
        ),
        'data': responseData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to retrieve order: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Update order status.
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
      final body = <String, dynamic>{'status': status, 'order_id': orderId};
      if (shopId != null && shopId.isNotEmpty) body['shop_id'] = shopId;

      final request = _httpClient?.put ?? http.put;
      final response = await request(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds.');
        },
      );

      final responseData = _decodeResponseBody(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !(responseData is Map && responseData['success'] == false)) {
        return {
          'success': true,
          'message': responseData is Map
              ? responseData['message'] ?? 'Order status updated successfully.'
              : 'Order status updated successfully.',
          'data': responseData is Map
              ? responseData['data'] ?? responseData
              : responseData,
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          responseData,
          fallback:
              'Failed to update order status (HTTP ${response.statusCode}).',
        ),
        'data': responseData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update order status: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Update one shop within an order using the rider pickup payload.
  Future<Map<String, dynamic>> updateShopOrderStatus({
    required int orderId,
    required int shopId,
    required int statusId,
    required String notes,
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
        ApiEndpoints.updateOrderStatus.replaceAll('{id}', orderId.toString()),
      );
      final request = _httpClient?.put ?? http.put;
      final response = await request(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'shop_id': shopId,
          'status': statusId,
          'notes': notes,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds.');
        },
      );

      final responseData = _decodeResponseBody(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !(responseData is Map && responseData['success'] == false)) {
        return {
          'success': true,
          'message': responseData is Map
              ? responseData['message'] ?? 'Order picked up successfully.'
              : 'Order picked up successfully.',
          'data': responseData is Map
              ? responseData['data'] ?? responseData
              : responseData,
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          responseData,
          fallback: 'Failed to confirm pickup (HTTP ${response.statusCode}).',
        ),
        'data': responseData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to confirm pickup: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Cancel an order.
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
      final request = _httpClient?.delete ?? http.delete;
      final response = await request(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds.');
        },
      );

      final responseData = _decodeResponseBody(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !(responseData is Map && responseData['success'] == false)) {
        return {
          'success': true,
          'message': responseData is Map
              ? responseData['message'] ?? 'Order cancelled successfully.'
              : 'Order cancelled successfully.',
          'data': responseData is Map
              ? responseData['data'] ?? responseData
              : responseData,
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          responseData,
          fallback: 'Failed to cancel order (HTTP ${response.statusCode}).',
        ),
        'data': responseData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to cancel order: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Get order history for the current user.
  Future<Map<String, dynamic>> getOrderHistory({
    int? limit,
    int? offset,
  }) async {
    return fetchOrders();
  }

  /// Fetch orders available for a rider to accept.
  Future<Map<String, dynamic>> fetchReadyForDeliveryOrders() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final request = _httpClient?.get ?? http.get;
    final response = await request(
      Uri.parse(ApiEndpoints.readyForDelivery),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds.');
      },
    );

    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback:
            'Failed to load ready-for-delivery orders: ${response.statusCode}',
      ));
    }
    if (decoded is! Map || decoded['success'] != true) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load ready-for-delivery orders.',
      ));
    }

    final rawData = decoded['data'];
    final orders = rawData is List
        ? rawData.whereType<Map>()
            .map((order) => Map<String, dynamic>.from(order)).toList()
        : <Map<String, dynamic>>[];
    final rawCount = decoded['count'];
    final count = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '') ?? orders.length;

    return {'orders': orders, 'count': count};
  }

  /// Fetch orders currently active for the authenticated rider.
  Future<Map<String, dynamic>> fetchActiveDeliveries() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final request = _httpClient?.get ?? http.get;
    final response = await request(
      Uri.parse(ApiEndpoints.activeDeliveries),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds.');
      },
    );

    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load active deliveries: ${response.statusCode}',
      ));
    }
    if (decoded is! Map || decoded['success'] != true) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load active deliveries.',
      ));
    }

    final rawData = decoded['data'];
    final orders = rawData is List
        ? rawData.whereType<Map>()
            .map((order) => Map<String, dynamic>.from(order)).toList()
        : <Map<String, dynamic>>[];
    final rawCount = decoded['count'];
    final parsedCount = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '');
    final count = parsedCount != null && parsedCount >= orders.length
        ? parsedCount
        : orders.length;

    return {'orders': orders, 'count': count};
  }

  /// Fetch the authenticated rider's delivery history for one month.
  Future<Map<String, dynamic>> fetchRiderDeliveryHistory({
    required int month,
    required int year,
    required String status,
  }) async {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12.');
    }

    final normalizedStatus = status.trim().toLowerCase();
    const supportedStatuses = {'all', 'delivered', 'failed'};
    if (!supportedStatuses.contains(normalizedStatus)) {
      throw ArgumentError.value(
        status,
        'status',
        'Must be all, delivered, or failed.',
      );
    }

    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final uri = Uri.parse(ApiEndpoints.riderDeliveries).replace(
      queryParameters: {
        'month': month.toString(),
        'year': year.toString(),
        'status': normalizedStatus,
      },
    );
    final request = _httpClient?.get ?? http.get;
    final response = await request(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds.');
      },
    );

    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load delivery history: ${response.statusCode}',
      ));
    }
    if (decoded is! Map || decoded['success'] != true) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load delivery history.',
      ));
    }

    final rawData = decoded['data'];
    if (rawData is! List) {
      throw Exception('Invalid delivery-history data.');
    }
    final deliveries = rawData.whereType<Map>()
        .map((delivery) => Map<String, dynamic>.from(delivery)).toList();
    final rawCount = decoded['count'];
    final count = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '') ?? deliveries.length;
    final rawFilters = decoded['filters'];

    return {
      'deliveries': deliveries,
      'count': count,
      'filters': rawFilters is Map
          ? Map<String, dynamic>.from(rawFilters)
          : {
              'month': month,
              'year': year,
              'status': normalizedStatus,
            },
    };
  }

  /// Fetch one completed or failed delivery for the authenticated rider.
  Future<Map<String, dynamic>> fetchRiderDeliveryHistoryDetail(
    int orderId,
  ) async {
    if (orderId <= 0) {
      throw ArgumentError.value(orderId, 'orderId', 'Must be positive.');
    }

    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final request = _httpClient?.get ?? http.get;
    final response = await request(
      Uri.parse(ApiEndpoints.riderDeliveryByOrderId(orderId)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds.');
      },
    );

    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load delivery details: ${response.statusCode}',
      ));
    }
    if (decoded is! Map || decoded['success'] != true) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load delivery details.',
      ));
    }

    final rawData = decoded['data'];
    if (rawData is! Map) throw Exception('Invalid delivery-detail data.');
    return Map<String, dynamic>.from(rawData);
  }

  /// Fetch one active delivery for the authenticated rider.
  Future<Map<String, dynamic>> fetchActiveDeliveryByOrderId(
    int orderId,
  ) async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final request = _httpClient?.get ?? http.get;
    final response = await request(
      Uri.parse(ApiEndpoints.activeDeliveryByOrderId(orderId)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds.');
      },
    );

    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load active delivery: ${response.statusCode}',
      ));
    }
    if (decoded is! Map || decoded['success'] != true) {
      throw Exception(_extractErrorMessage(
        decoded,
        fallback: 'Failed to load active delivery.',
      ));
    }

    final rawData = decoded['data'];
    if (rawData is! Map) throw Exception('Invalid active-delivery data.');
    return Map<String, dynamic>.from(rawData);
  }

  /// Accept all available shops for a ready-for-delivery order.
  Future<Map<String, dynamic>> acceptReadyForDeliveryOrder({
    required String orderId,
    required List<int> orderShopIds,
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
      if (orderShopIds.isEmpty) {
        return {
          'success': false,
          'message': 'No pickup shops are available for this order.',
          'data': null,
        };
      }

      final uri = Uri.parse(
        ApiEndpoints.acceptReadyForDeliveryOrder.replaceAll(
          '{orderId}',
          orderId,
        ),
      );
      final request = _httpClient?.post ?? http.post;
      final response = await request(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'order_shop_ids': orderShopIds}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds.');
        },
      );

      final responseData = _decodeResponseBody(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !(responseData is Map && responseData['success'] == false)) {
        return {
          'success': true,
          'message': responseData is Map
              ? responseData['message'] ?? 'Delivery accepted successfully.'
              : 'Delivery accepted successfully.',
          'data': responseData is Map
              ? responseData['data'] ?? responseData
              : responseData,
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          responseData,
          fallback: 'Failed to accept delivery (HTTP ${response.statusCode}).',
        ),
        'data': responseData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to accept delivery: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Fetch orders assigned to a specific rider.
  Future<Map<String, dynamic>> fetchOrdersByRiderId({String? status}) async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final riderId = await ApiService.getUserId();
    if (riderId == null || riderId.isEmpty) {
      throw Exception('Rider ID not found. Please login again.');
    }

    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse(
      ApiEndpoints.getOrdersByRiderId.replaceAll('{rider_id}', riderId),
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final request = _httpClient?.get ?? http.get;
    final response = await request(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds.');
      },
    );

    final responseData = _decodeResponseBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        responseData,
        fallback: 'Failed to load rider orders: ${response.statusCode}',
      ));
    }

    if (responseData is Map &&
        responseData['success'] == true &&
        responseData['data'] is List) {
      final orders = (responseData['data'] as List).map((entry) {
        final entryMap = Map<String, dynamic>.from(entry as Map);
        final orderData = entryMap['order'] is Map
            ? Map<String, dynamic>.from(entryMap['order'] as Map)
            : <String, dynamic>{};
        final orderDetail = orderData['order_detail'] is Map
            ? Map<String, dynamic>.from(orderData['order_detail'] as Map)
            : null;
        final user = orderData['user'] is Map
            ? Map<String, dynamic>.from(orderData['user'] as Map)
            : null;
        final address = orderDetail?['address'] is Map
            ? Map<String, dynamic>.from(orderDetail!['address'] as Map)
            : null;
        final shop = entryMap['shop'] is Map
            ? Map<String, dynamic>.from(entryMap['shop'] as Map)
            : null;
        final items = entryMap['items'] is List
            ? entryMap['items'] as List
            : <dynamic>[];

        return <String, dynamic>{
          'id': entryMap['order_id'],
          'order_shop_id': entryMap['order_shop_id'],
          'user_id': orderData['user_id'],
          'order_detail_id': orderData['order_detail_id'],
          'order_status': entryMap['order_status']?.toString() ?? 'pending',
          'rider_id': entryMap['rider_id'] ?? orderData['rider_id'],
          'ordered_at': orderData['ordered_at']?.toString() ?? '',
          'updated_at': orderData['updated_at']?.toString(),
          'user': user,
          'order_detail': orderDetail,
          'order_items': items,
          'shop': shop,
          'shop_id': entryMap['shop_id'],
          'order_id': entryMap['order_id'],
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
          'payment_status':
              orderDetail?['payment_status']?.toString() ?? 'pending',
          'order_detail_created_at': orderDetail?['created_at'],
          'order_detail_updated_at': orderDetail?['updated_at'],
          'address': address,
        };
      }).toList();

      return {'orders': orders, 'count': responseData['count'] ?? orders.length};
    }
    return {'orders': <Map<String, dynamic>>[], 'count': 0};
  }

  /// Check whether every shop can deliver to the supplied coordinates.
  Future<Map<String, dynamic>> checkZoneCoverage({
    required double latitude,
    required double longitude,
    required List<int> shopIds,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'all_inside_zone': false,
        };
      }

      final uniqueShopIds = shopIds.toSet().toList(growable: false);
      if (uniqueShopIds.isEmpty) {
        return {
          'success': false,
          'message': 'No valid shops were provided for the coverage check.',
          'all_inside_zone': false,
        };
      }

      final request = _httpClient?.post ?? http.post;
      final response = await request(
        Uri.parse(ApiEndpoints.checkZoneCoverage),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'shop_ids': uniqueShopIds,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds.');
        },
      );

      final decoded = _decodeResponseBody(response.body);
      if (decoded is! Map) {
        return {
          'success': false,
          'message': 'Invalid zone coverage response.',
          'all_inside_zone': false,
        };
      }

      final allInsideZone = decoded['all_inside_zone'];
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true &&
          allInsideZone is bool) {
        return {
          'success': true,
          'message': decoded['message']?.toString(),
          'all_inside_zone': allInsideZone,
          'coordinates': decoded['coordinates'],
          'shops': decoded['shops'] is List ? decoded['shops'] : const [],
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          decoded,
          fallback: 'Failed to verify delivery zone coverage.',
        ),
        'all_inside_zone': false,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to check delivery zone: ${e.toString()}',
        'all_inside_zone': false,
      };
    }
  }

  /// Fetch delivery methods.
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

      final request = _httpClient?.get ?? http.get;
      final response = await request(
        Uri.parse(ApiEndpoints.getDeliveryMethods),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds.');
        },
      );

      final responseData = _decodeResponseBody(response.body);
      if (response.statusCode == 200 &&
          responseData is Map &&
          responseData['success'] == true) {
        return {
          'success': true,
          'message': 'Delivery methods retrieved successfully.',
          'data': responseData['data'] ?? [],
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          responseData,
          fallback:
              'Failed to retrieve delivery methods (HTTP ${response.statusCode}).',
        ),
        'data': [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to retrieve delivery methods: ${e.toString()}',
        'data': [],
      };
    }
  }
}
