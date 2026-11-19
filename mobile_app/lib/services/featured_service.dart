import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_endpoints.dart';
import 'api_service.dart';

class FeaturedService {
  FeaturedService({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  /// GET /api/featured — returns only `data.products`.
  Future<List<Map<String, dynamic>>> fetchFeaturedProducts() async {
    final response = await _get(Uri.parse(ApiEndpoints.getFeatured));

    if (response.statusCode != 200) {
      throw Exception('Failed to load featured: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map ||
        decoded['success'] != true ||
        decoded['data'] is! Map ||
        decoded['data']['products'] is! List) {
      throw const FormatException('Invalid featured response');
    }

    return (decoded['data']['products'] as List).map((entry) {
      if (entry is! Map) {
        throw const FormatException('Invalid featured product');
      }
      return Map<String, dynamic>.from(entry);
    }).toList();
  }

  Future<http.Response> _get(Uri uri) async {
    final token = await ApiService.getToken();
    final headers = _headers(token);
    return (_httpClient?.get(uri, headers: headers) ??
            http.get(uri, headers: headers))
        .timeout(const Duration(seconds: 10));
  }

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
}
