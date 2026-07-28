import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

class CartService extends ApiService {
  // Fetch items on carts from API
  Future<List<Map<String, dynamic>>> _fetchCartItemsFromAPI(
      String itemId) async {
    final token = await ApiService.getToken();
    final response = await http.get(
      Uri.parse(ApiEndpoints.getCart.replaceAll('{id}', itemId)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(
      Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds');
      },
    );

    List<Map<String, dynamic>> cartItems = [];

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final datas = responseData['data'] as List;
        for (var data in datas) {
          cartItems.add({
            "id": data['id'],
            "user_id": data['user_id'],
            "item_id": data['item_id'],
            "shop_id": data['item']['shop_id'],
            "shop_name": data['item']['shop_name'],
            "quantity": data['quantity'],
            "price_snapshot": data['price_snapshot'],
            "discounted_price": data['discounted_price'],
            "discount_status": data['discount_status'],
            "discount_details": data['discount_details'],
            "status": data['status'],
            "added_at": data['created_at'],
            "item_name": data['item']['item_name'],
            "item_price": data['item']['item_price'],
            "item_quantity": data['item']['item_quantity'],
          });
        }

        return cartItems;
      } else {
        throw Exception('Failed to load cart items: ${response.statusCode}');
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchCartItemsFromAPI(
      String itemId) async {
    return await _fetchCartItemsFromAPI(itemId);
  }

  // Add item to cart via API
  Future<Map<String, dynamic>> addToCart({
    required String userId,
    required String itemId,
    required double price,
    required int quantity,
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

      final uri = Uri.parse(ApiEndpoints.addToCart);

      final body = {
        'user_id': userId,
        'item_id': itemId,
        'price': price,
        'quantity': quantity,
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
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Item added to cart',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to add item to cart';
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

  // Remove item from cart via API
  Future<Map<String, dynamic>> removeCartItem(String cartItemId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final uri =
          Uri.parse(ApiEndpoints.deleteCart.replaceAll('{id}', cartItemId));

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
          'message': responseData['message'] ?? 'Item removed from cart',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to remove item from cart';
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

  // Remove all items from cart via API (batch delete)
  Future<Map<String, dynamic>> clearAllCartItems(
      List<String> cartItemIds) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      if (cartItemIds.isEmpty) {
        return {
          'success': true,
          'message': 'Cart is already empty',
          'data': null,
        };
      }

      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      // Delete all items one by one
      for (String cartItemId in cartItemIds) {
        try {
          final uri =
              Uri.parse(ApiEndpoints.deleteCart.replaceAll('{id}', cartItemId));

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

          if (response.statusCode >= 200 && response.statusCode < 300) {
            successCount++;
          } else {
            failCount++;
            final responseData = jsonDecode(response.body);
            if (responseData is Map && responseData.containsKey('message')) {
              errors.add(responseData['message'].toString());
            }
          }
        } catch (e) {
          failCount++;
          errors.add('Failed to delete item $cartItemId: ${e.toString()}');
        }
      }

      if (failCount == 0) {
        return {
          'success': true,
          'message': 'All items removed from cart',
          'data': {'deleted_count': successCount},
        };
      } else if (successCount > 0) {
        return {
          'success': true,
          'message': '$successCount item(s) removed, $failCount item(s) failed',
          'data': {
            'deleted_count': successCount,
            'failed_count': failCount,
            'errors': errors,
          },
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to remove items from cart',
          'data': {
            'deleted_count': 0,
            'failed_count': failCount,
            'errors': errors,
          },
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

  // ===== CartScreen V2 Methods =====
  // Fetches cart items preserving full nested structure (zone, shop info)
  // for CartScreenV2 zone-based grouping.
  // Sample API response:
  // {
  //   "success": true,
  //   "data": [
  //     {
  //       "id": 1, "user_id": 42, "item_id": 10, "quantity": 2,
  //       "price_snapshot": "120.00",
  //       "discounted_price": 96,
  //       "discount_status": "active",
  //       "discount_details": {
  //         "original_price": "120.00",
  //         "actual_discount": "24.00",
  //         "discounted_price": "96.00",
  //         "discount_percent": "20.00",
  //         "discount_type": "timed",
  //         "discount_expires_at": "2026-07-01T00:00:00.000000Z"
  //       },
  //       "item": {
  //         "id": 10, "shop_id": 3, "item_name": "...",
  //         "item_price": "120.00", "item_quantity": 100,
  //         "shop": {
  //           "id": 3, "shop_name": "...",
  //           "zone": { "id": 1, "name": "...", "is_cod": true }
  //         }
  //       }
  //     }
  //   ],
  //   "count": 1
  // }
  Future<List<Map<String, dynamic>>> fetchCartItemsForV2(
      String userId) async {
    final token = await ApiService.getToken();
    final response = await http.get(
      Uri.parse(ApiEndpoints.getCart.replaceAll('{id}', userId)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
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
        return List<Map<String, dynamic>>.from(responseData['data']);
      } else {
        throw Exception('Failed to load cart items: ${response.statusCode}');
      }
    }
    return [];
  }
}
