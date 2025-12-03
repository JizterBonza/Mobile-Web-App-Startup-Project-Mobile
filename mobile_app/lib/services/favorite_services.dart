import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

class FavoriteService extends ApiService {
  // Fetch favorites from API
  Future<List<Map<String, dynamic>>> _fetchFavoritesFromAPI(
      String userId) async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login.');
    }

    final response = await http.get(
      Uri.parse(ApiEndpoints.getFavoritesByUserId.replaceAll('{id}', userId)),
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

    List<Map<String, dynamic>> favorites = [];

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final datas = responseData['data'] as List;
        for (var data in datas) {
          final item = data['item'] as Map<String, dynamic>;

          // Parse price from string to double
          final itemPrice = item['item_price'] is num
              ? (item['item_price'] as num).toDouble()
              : double.tryParse(item['item_price']?.toString() ?? '0') ?? 0.0;

          // Parse rating from string to double
          final averageRating = item['average_rating'] is num
              ? (item['average_rating'] as num).toDouble()
              : double.tryParse(item['average_rating']?.toString() ?? '0') ??
                  0.0;

          // Determine if item is in stock
          final itemStatus = item['item_status']?.toString() ?? '';
          final inStock = itemStatus.toLowerCase() == 'active';

          favorites.add({
            // Favorite record fields
            "id": data['id'],
            "user_id": data['user_id'],
            "item_id": data['item_id'],
            "added_at": data['created_at'],
            "updated_at": data['updated_at'],

            // Item fields
            "item_name": item['item_name'],
            "item_price": item['item_price'],
            "item_quantity": item['item_quantity'],
            "item_description": item['item_description'],
            "category": item['category'],
            "item_images": item['item_images'],
            "item_status": item['item_status'],
            "average_rating": item['average_rating'],
            "total_reviews": item['total_reviews'] ?? 0,
            "sold_count": item['sold_count'] ?? 0,
            "shop_id": item['shop_id'],

            // Additional fields for UI compatibility
            "name": item['item_name'],
            "price": itemPrice,
            "rating": averageRating,
            "inStock": inStock,
            "vendor":
                '', // Vendor info not in response, can be added if available
          });
        }

        return favorites;
      } else {
        throw Exception('Failed to load favorites: ${response.statusCode}');
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchFavoritesFromAPI(
      String userId) async {
    return await _fetchFavoritesFromAPI(userId);
  }

  // Add item to favorites via API
  Future<Map<String, dynamic>> addToFavorites({
    required String userId,
    required String itemId,
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

      final uri = Uri.parse(ApiEndpoints.addToFavorites);

      final body = {
        'user_id': userId,
        'item_id': itemId,
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
          'message': responseData['message'] ?? 'Item added to favorites',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to add item to favorites';
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

  // Remove item from favorites via API
  Future<Map<String, dynamic>> removeFromFavorites(String favoriteId) async {
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
          ApiEndpoints.removeFromFavorites.replaceAll('{id}', favoriteId));

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
          'message': responseData['message'] ?? 'Item removed from favorites',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to remove item from favorites';
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

  // Check if an item is in favorites
  Future<bool> isItemFavorite(String userId, String itemId) async {
    try {
      final favorites = await fetchFavoritesFromAPI(userId);
      return favorites.any(
          (favorite) => favorite['item_id'].toString() == itemId.toString());
    } catch (e) {
      return false;
    }
  }
}
