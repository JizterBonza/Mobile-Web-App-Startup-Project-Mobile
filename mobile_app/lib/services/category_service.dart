import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';
import 'package:flutter/material.dart';

class CategoryService extends ApiService {
  // Map of category names to icons
  static final Map<String, IconData> categoryIcons = {
    'Seeds': Icons.eco,
    'Fertilizer': Icons.science,
    'Tools': Icons.build,
    'Equipment': Icons.agriculture,
    'Plants': Icons.grass,
    'Pesticides': Icons.pest_control,
  };

  /// Fetch categories from API
  Future<List<Map<String, dynamic>>> _fetchCategoriesFromAPI() async {
    final response = await http.get(
      Uri.parse(ApiEndpoints.getCategories),
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
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true && data['data'] != null) {
        return (data['data'] as List).map((category) {
          String categoryName = category['category_name'];
          return {
            'id': category['id'],
            'name': categoryName,
            'icon': categoryIcons[categoryName] ?? Icons.broken_image,
            'description': category['category_description'],
            'image_url': category['category_image_url'],
            'status': category['status'],
          };
        }).toList();
      }
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }

    return [];
  }

  /// Fetch categories from API
  /// Note: Caching is now handled by CategoryProvider
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    return await _fetchCategoriesFromAPI();
  }
}
