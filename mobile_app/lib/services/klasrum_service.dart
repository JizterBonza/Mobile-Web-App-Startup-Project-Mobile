import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/klasrum_content.dart';
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

class KlasrumService extends ApiService {
  KlasrumService({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  Future<http.Response> _get(Uri uri, Map<String, String> headers) {
    return _httpClient?.get(uri, headers: headers) ??
        http.get(uri, headers: headers);
  }

  Future<Map<String, String>> _headers() async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${await ApiService.getToken()}',
    };
  }

  Map<String, dynamic> _mapCategory(dynamic raw) {
    final category = Map<String, dynamic>.from(raw as Map);
    return {
      'id': category['id'],
      'name': category['name']?.toString() ?? '',
    };
  }

  Future<List<Map<String, dynamic>>> _getContentList(
    String baseUrl, {
    dynamic categoryId,
    String? search,
  }) async {
    final query = <String, String>{};
    if (categoryId != null) {
      query['category_id'] = categoryId.toString();
    }
    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) {
      query['search'] = trimmedSearch;
    }

    final uri = Uri.parse(baseUrl).replace(
      queryParameters: query.isEmpty ? null : query,
    );

    final response = await _get(uri, await _headers()).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds');
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return (data['data'] as List).map(mapKlasrumContent).toList();
      }
    } else {
      throw Exception(
          'Failed to load Klasrum contents: ${response.statusCode}');
    }
    return [];
  }

  /// GET /api/klasrum/categories
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await _get(
      Uri.parse(ApiEndpoints.getKlasrumCategories),
      await _headers(),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds');
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return (data['data'] as List).map(_mapCategory).toList();
      }
    } else {
      throw Exception(
          'Failed to load Klasrum categories: ${response.statusCode}');
    }
    return [];
  }

  /// GET /api/klasrum — featured / summary list (no filters).
  Future<List<Map<String, dynamic>>> fetchFeatured() async {
    return _getContentList(ApiEndpoints.getKlasrum);
  }

  /// GET /api/klasrum/contents?category_id=&search=
  Future<List<Map<String, dynamic>>> fetchContents({
    dynamic categoryId,
    String? search,
  }) async {
    return _getContentList(
      ApiEndpoints.getKlasrumContents,
      categoryId: categoryId,
      search: search,
    );
  }

  /// GET /api/klasrum/{id} returns one full article.
  Future<Map<String, dynamic>> fetchArticle(dynamic id) async {
    final response = await _get(
      Uri.parse(ApiEndpoints.getKlasrumArticle(id)),
      await _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to load Klasrum article: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true || data['data'] is! Map) {
      throw const FormatException('Invalid Klasrum article response');
    }
    return mapKlasrumContent(data['data']);
  }
}
