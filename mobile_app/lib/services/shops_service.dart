import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../utils/url.dart';
import '../services/api_service.dart';

/// Service for managing shops/stores with API fetching
class ShopsService extends ApiService {
  /// Fetch shops from API with authentication
  Future<List<Map<String, dynamic>>> _fetchShopsFromAPI({int? limit}) async {
    String url = ApiEndpoints.getShops;
    if (limit != null) {
      url = '$url?limit=$limit';
    }

    final response = await http.get(
      Uri.parse(url),
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
        return (data['data'] as List).map((shop) {
          return {
            "id": shop['id'],
            "agrivet_id": shop['agrivet_id'],
            "zone_id": shop['zone_id'],
            "shop_name": shop['shop_name'],
            "shop_description": shop['shop_description'],
            "shop_address": shop['shop_address'],
            "shop_lat": shop['shop_lat'],
            "shop_long": shop['shop_long'],
            "contact_number": shop['contact_number'],
            "shop_logo": shop['logo_url'], // Map logo_url to shop_logo
            "shop_rating":
                shop['average_rating'], // Map average_rating to shop_rating
            "total_reviews": shop['total_reviews'] ?? 0,
            "shop_status": shop['shop_status'],
            "created_at": shop['created_at'],
          };
        }).toList();
      }
    } else {
      throw Exception('Failed to load shops: ${response.statusCode}');
    }
    return [];
  }

  /// Fetch shop details by ID from API
  Future<Map<String, dynamic>> _fetchShopByIdFromAPI(String shopId) async {
    final url = ApiEndpoints.getShopById.replaceAll('{id}', shopId);
    //print('Fetching shop from URL: $url');

    final response = await http.get(
      Uri.parse(url),
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

    //print('Shop API response status: ${response.statusCode}');
    //print('Shop API response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['success'] == true && responseData['data'] != null) {
        final shop = responseData['data'] as Map<String, dynamic>;
        final baseUrl = Url.getUrl();

        // Parse items with full image URLs
        List<Map<String, dynamic>> parsedItems = [];
        //print('Raw items from API: ${shop['items']}');
        if (shop['items'] != null && shop['items'] is List) {
          final rawItems = shop['items'] as List;
          //print('Number of raw items: ${rawItems.length}');
          parsedItems = rawItems.map<Map<String, dynamic>>((item) {
            // Convert relative image paths to full URLs
            List<String>? fullImageUrls;
            if (item['item_images'] != null && item['item_images'] is List) {
              fullImageUrls = (item['item_images'] as List).map((imagePath) {
                final path = imagePath.toString();
                // If already a full URL, use as is; otherwise prepend base URL
                if (path.startsWith('http')) {
                  return path;
                }
                return '$baseUrl$path';
              }).toList();
            }

            return {
              "id": item['id'],
              "shop_id": item['shop_id'],
              "item_name": item['item_name'],
              "item_description": item['item_description'],
              "item_price": item['item_price'],
              "item_quantity": item['item_quantity'],
              "category": item['category'],
              "item_images": fullImageUrls,
              "item_status": item['item_status'],
              "average_rating": item['average_rating'],
              "total_reviews": item['total_reviews'] ?? 0,
              "sold_count": item['sold_count'] ?? 0,
            };
          }).toList();
        }

        //print('Parsed ${parsedItems.length} items from shop response');

        final result = {
          "id": shop['id'],
          "agrivet_id": shop['agrivet_id'],
          "shop_name": shop['shop_name'],
          "shop_description": shop['shop_description'],
          "shop_address": shop['shop_address'],
          "shop_lat": shop['shop_lat'],
          "shop_long": shop['shop_long'],
          "contact_number": shop['contact_number'],
          "shop_logo": shop['logo_url'], // Map logo_url to shop_logo
          "shop_rating":
              shop['average_rating'], // Map average_rating to shop_rating
          "total_reviews": shop['total_reviews'] ?? 0,
          "shop_status": shop['shop_status'],
          "created_at": shop['created_at'],
          "items": parsedItems,
        };

        //print('Returning shop data with items: ${result['items']}');
        return result;
      }
    } else {
      throw Exception('Failed to load shop details: ${response.statusCode}');
    }
    return {};
  }

  /// Fetch shops from API
  /// Note: Caching handled by ShopsProvider
  Future<List<Map<String, dynamic>>> fetchShops({int? limit}) async {
    return await _fetchShopsFromAPI(limit: limit);
  }

  /// Fetch shop details by ID
  Future<Map<String, dynamic>> fetchShopById(String shopId) async {
    return await _fetchShopByIdFromAPI(shopId);
  }

  /// Fetch shop items by shop ID
  Future<List<Map<String, dynamic>>> fetchShopItems(String shopId) async {
    final url = ApiEndpoints.getShopItems.replaceAll('{id}', shopId);
    //print('Fetching shop items from URL: $url');

    final response = await http.get(
      Uri.parse(url),
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

    //print('Shop items API response status: ${response.statusCode}');
    //print('Shop items API response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['success'] == true && responseData['data'] != null) {
        final baseUrl = Url.getUrl();
        final rawItems = responseData['data'];

        // Handle both array of items and object with items array
        List itemsList;
        if (rawItems is List) {
          itemsList = rawItems;
        } else if (rawItems is Map && rawItems['items'] != null) {
          itemsList = rawItems['items'] as List;
        } else {
          itemsList = [];
        }

        //print('Parsing ${itemsList.length} items');

        return itemsList.map<Map<String, dynamic>>((item) {
          // Convert relative image paths to full URLs
          List<String>? fullImageUrls;
          if (item['item_images'] != null && item['item_images'] is List) {
            fullImageUrls = (item['item_images'] as List).map((imagePath) {
              final path = imagePath.toString();
              if (path.startsWith('http')) {
                return path;
              }
              return '$baseUrl$path';
            }).toList();
          }

          return {
            "id": item['id'],
            "shop_id": item['shop_id'],
            "item_name": item['item_name'],
            "item_description": item['item_description'],
            "item_price": item['item_price'],
            "item_quantity": item['item_quantity'],
            "category": item['category'],
            "item_images": fullImageUrls,
            "item_status": item['item_status'],
            "average_rating": item['average_rating'],
            "total_reviews": item['total_reviews'] ?? 0,
            "sold_count": item['sold_count'] ?? 0,
          };
        }).toList();
      }
    } else {
      throw Exception('Failed to load shop items: ${response.statusCode}');
    }
    return [];
  }

  /// Fetch shop reviews by shop ID
  Future<Map<String, dynamic>> fetchShopReviews(String shopId) async {
    final url = ApiEndpoints.getShopReviews.replaceAll('{id}', shopId);

    final response = await http.get(
      Uri.parse(url),
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

        // Parse reviews array
        List<Map<String, dynamic>> reviews = [];
        if (data['reviews'] != null && data['reviews'] is List) {
          reviews =
              (data['reviews'] as List).map<Map<String, dynamic>>((review) {
            return {
              'id': review['id'],
              'user_id': review['user_id'],
              'username': review['username'] ?? 'Anonymous',
              'rating': review['rating'] is num
                  ? (review['rating'] as num).toDouble()
                  : double.tryParse(review['rating']?.toString() ?? '0') ?? 0.0,
              'comment': review['comment'] ?? '',
              'review_images': review['review_images'],
              'item_name': review['item_name'],
              'order_id': review['order_id'],
              'created_at': review['created_at'],
              'updated_at': review['updated_at'],
            };
          }).toList();
        }

        return {
          'shop_id': data['shop_id'] ?? shopId,
          'shop_name': data['shop_name'],
          'average_rating': data['average_rating'],
          'total_reviews': data['total_reviews'] ?? reviews.length,
          'reviews': reviews,
        };
      }
    } else {
      throw Exception('Failed to load shop reviews: ${response.statusCode}');
    }
    return {};
  }

  /// Submit a review for a shop's item/order
  ///
  /// Parameters:
  /// - [shopId]: Required - The ID of the shop being reviewed
  /// - [userId]: Required - The ID of the user submitting the review
  /// - [rating]: Required - Rating value between 1 and 5
  /// - [itemId]: Optional - The ID of the item being reviewed
  /// - [orderId]: Optional - The ID of the order being reviewed
  /// - [reviewText]: Optional - Review text (max 1000 characters)
  /// - [reviewImages]: Optional - List of image URLs/paths (max 255 chars each)
  ///
  /// Returns a Map with 'success' boolean and 'message' or 'data'
  Future<Map<String, dynamic>> submitReview({
    required String shopId,
    required int userId,
    required int rating,
    int? itemId,
    int? orderId,
    String? reviewText,
    List<String>? reviewImages,
  }) async {
    try {
      final url = ApiEndpoints.submitReview.replaceAll('{id}', shopId);

      // Build request body
      final Map<String, dynamic> body = {
        'user_id': userId,
        'rating': rating,
      };

      // Add optional fields if provided
      if (itemId != null) {
        body['item_id'] = itemId;
      }
      if (orderId != null) {
        body['order_id'] = orderId;
      }
      if (reviewText != null && reviewText.isNotEmpty) {
        body['review_text'] = reviewText;
      }
      if (reviewImages != null && reviewImages.isNotEmpty) {
        body['review_images'] = reviewImages;
      }

      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${await ApiService.getToken()}',
        },
        body: jsonEncode(body),
      )
          .timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds');
        },
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Review submitted successfully',
          'data': responseData['data'],
        };
      } else if (response.statusCode == 422) {
        // Validation error
        final errors = responseData['errors'] ?? responseData['message'];
        String errorMessage = 'Validation failed';
        if (errors is Map) {
          errorMessage = errors.values.first is List
              ? errors.values.first[0]
              : errors.values.first.toString();
        } else if (errors is String) {
          errorMessage = errors;
        }
        return {
          'success': false,
          'message': errorMessage,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to submit review',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }
}
