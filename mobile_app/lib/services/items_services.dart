import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

/// Service for managing items/products with API fetching
class ItemsService extends ApiService {
  /// Fetch items from API with authentication
  Future<List<Map<String, dynamic>>> _fetchItemsFromAPI() async {
    final response = await http.get(
      Uri.parse(ApiEndpoints.getItemsRandom),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${await ApiService.getToken()}',
      },
    ).timeout(
      Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds');
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return (data['data'] as List).map((item) {
          return {
            "id": item['id'],
            "shop_id": item['shop_id'],
            "item_name": item['item_name'],
            "item_description": item['item_description'],
            "item_price": item['item_price'],
            "item_quantity": item['item_quantity'],
            "category": item['category'],
            "item_images": item['item_images'],
            "item_status": item['item_status'],
            "average_rating": item['average_rating'],
          };
        }).toList();
      }
    } else {
      throw Exception('Failed to load items: ${response.statusCode}');
    }
    return [];
  }

  /// Fetch item reviews from API with authentication
  Future<Map<String, dynamic>> _fetchItemReviewsFromAPI(String itemId) async {
    final response = await http.get(
      Uri.parse(ApiEndpoints.getItemReviews.replaceAll('{id}', itemId)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${await ApiService.getToken()}',
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
        final data = responseData['data'] as Map<String, dynamic>;

        // Parse reviews array and remove duplicates by ID
        List<Map<String, dynamic>> reviews = [];
        Set<dynamic> seenIds = {};
        if (data['reviews'] != null && data['reviews'] is List) {
          for (var review in data['reviews'] as List) {
            final reviewId = review['id'];
            // Skip if we've already seen this review ID
            if (seenIds.contains(reviewId)) continue;
            seenIds.add(reviewId);

            reviews.add({
              'id': review['id'],
              'user_id': review['user_id'],
              'username': review['username'] ?? '',
              'rating': review['rating'] is num
                  ? (review['rating'] as num).toDouble()
                  : double.tryParse(review['rating']?.toString() ?? '0') ?? 0.0,
              'comment': review['comment'] ?? '',
              'review_images': review['review_images'],
              'order_id': review['order_id'],
              'created_at': review['created_at'],
              'updated_at': review['updated_at'],
              'verified':
                  review['verified'] == 'true' || review['verified'] == true,
            });
          }
        }

        return {
          'id': data['id'],
          'shop_id': data['shop_id'],
          'item_name': data['item_name'],
          'item_description': data['item_description'],
          'item_price': data['item_price'],
          'item_quantity': data['item_quantity'],
          'category': data['category'],
          'item_images': data['item_images'],
          'item_status': data['item_status'],
          'average_rating': data['average_rating'],
          'total_reviews': reviews.length,
          'sold_count': data['sold_count'] ?? 0,
          'reviews': reviews,
        };
      }
    } else {
      throw Exception('Failed to load item reviews: ${response.statusCode}');
    }
    return {};
  }

  /// Fetch items from API
  /// Note: Caching handled by ItemsProvider
  Future<List<Map<String, dynamic>>> fetchItems() async {
    return await _fetchItemsFromAPI();
  }

  /// Fetch item reviews from API
  /// Returns item details with reviews array
  Future<Map<String, dynamic>> fetchItemReviews(String itemId) async {
    return await _fetchItemReviewsFromAPI(itemId);
  }
}
