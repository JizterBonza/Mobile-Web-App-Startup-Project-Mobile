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
            "quantity": data['quantity'],
            "price_snapshot": data['price_snapshot'],
            "status": data['status'],
            "added_at": data['added_at'],
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
}
