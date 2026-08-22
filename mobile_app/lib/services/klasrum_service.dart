import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../utils/media_url.dart';
import '../services/api_service.dart';

class KlasrumService extends ApiService {
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

  Map<String, dynamic> _mapContent(dynamic raw) {
    final item = Map<String, dynamic>.from(raw as Map);
    final category = item['category'];
    String categoryName = '';
    dynamic categoryId = item['category_id'];
    if (category is Map) {
      categoryName = category['name']?.toString() ?? '';
      categoryId ??= category['id'];
    }

    final heading = item['heading'];
    final caption = item['caption'];

    return {
      'id': item['id'],
      'title': item['title']?.toString() ?? '',
      'description': item['description']?.toString() ?? '',
      'heading': heading == null || heading.toString() == 'null'
          ? ''
          : heading.toString(),
      'category_id': categoryId,
      'category_name': categoryName,
      'cover_url': resolveMediaUrl(item['cover_url']?.toString()),
      'published_at': item['published_at']?.toString(),
      'body': item['body']?.toString(),
      'caption': caption == null || caption.toString() == 'null'
          ? ''
          : caption.toString(),
      'media_url': resolveMediaUrl(item['media_url']?.toString()),
      'media_type': item['media_type']?.toString(),
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

    final response = await http
        .get(
          uri,
          headers: await _headers(),
        )
        .timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out after 10 seconds');
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return (data['data'] as List).map(_mapContent).toList();
      }
    } else {
      throw Exception('Failed to load Klasrum contents: ${response.statusCode}');
    }
    return [];
  }

  /// GET /api/klasrum/categories
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await http
        .get(
          Uri.parse(ApiEndpoints.getKlasrumCategories),
          headers: await _headers(),
        )
        .timeout(
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
}
