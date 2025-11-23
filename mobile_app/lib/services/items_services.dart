import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

/// Service for managing items/products with API fetching
/// Note: Caching is now handled by ItemsProvider
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

  /// Fetch items from API
  /// Note: Caching is now handled by ItemsProvider
  Future<List<Map<String, dynamic>>> fetchItems() async {
    return await _fetchItemsFromAPI();
  }
}
