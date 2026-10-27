import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_endpoints.dart';
import '../utils/media_url.dart';
import 'api_service.dart';

class FarmsService {
  FarmsService({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  Future<List<Map<String, dynamic>>> fetchFarms() async {
    final response = await _get(Uri.parse(ApiEndpoints.getFarms));

    if (response.statusCode != 200) {
      throw Exception('Failed to load farms: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map ||
        decoded['success'] != true ||
        decoded['data'] is! List) {
      throw const FormatException('Invalid farms response');
    }

    return (decoded['data'] as List).map((entry) {
      if (entry is! Map) {
        throw const FormatException('Invalid farm entry');
      }
      return _mapFarm(entry);
    }).toList();
  }

  Future<Map<String, dynamic>> fetchFarmById(dynamic id) async {
    final path = ApiEndpoints.getFarmById.replaceAll(
      '{id}',
      Uri.encodeComponent(id.toString()),
    );
    final response = await _get(Uri.parse(path));

    if (response.statusCode != 200) {
      throw Exception('Failed to load farm: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map ||
        decoded['success'] != true ||
        decoded['data'] is! Map) {
      throw const FormatException('Invalid farm response');
    }

    return _mapFarm(decoded['data'] as Map);
  }

  Future<Map<String, dynamic>> fetchFarmWithListings(dynamic id) async {
    final path = ApiEndpoints.getFarmListings.replaceAll(
      '{id}',
      Uri.encodeComponent(id.toString()),
    );
    final response = await _get(Uri.parse(path));

    if (response.statusCode != 200) {
      throw Exception('Failed to load farm listings: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map ||
        decoded['success'] != true ||
        decoded['data'] is! Map ||
        decoded['data']['listings'] is! List) {
      throw const FormatException('Invalid farm listings response');
    }

    final farm = _mapFarm(decoded['data'] as Map);
    farm['listings'] = (decoded['data']['listings'] as List).map((entry) {
      if (entry is! Map) {
        throw const FormatException('Invalid farm listing');
      }
      return _mapListing(entry);
    }).toList();
    return farm;
  }

  Future<Map<String, dynamic>> fetchFarmGamefowlListing(dynamic id) async {
    final path = ApiEndpoints.getFarmGamefowlListing.replaceAll(
      '{id}',
      Uri.encodeComponent(id.toString()),
    );
    final response = await _get(Uri.parse(path));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load gamefowl listing: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map ||
        decoded['success'] != true ||
        decoded['data'] is! Map ||
        decoded['data']['id'] == null) {
      throw const FormatException('Invalid gamefowl listing response');
    }

    return _mapListing(decoded['data'] as Map);
  }

  Future<http.Response> _get(Uri uri) async {
    final token = await ApiService.getToken();
    final headers = _headers(token);
    return (_httpClient?.get(uri, headers: headers) ??
            http.get(uri, headers: headers))
        .timeout(const Duration(seconds: 10));
  }

  Map<String, dynamic> _mapFarm(Map entry) {
    final farm = Map<String, dynamic>.from(entry);
    for (final key in ['cover_url', 'banner_url', 'logo_url']) {
      farm[key] = resolveShopMediaUrl(farm[key]);
    }
    return farm;
  }

  Map<String, dynamic> _mapListing(Map entry) {
    final listing = Map<String, dynamic>.from(entry);
    listing['image'] = resolveMediaUrl(listing['image']?.toString());
    if (listing['images'] is List) {
      listing['images'] = (listing['images'] as List)
          .map((image) => resolveMediaUrl(image?.toString()))
          .toList();
    }
    if (listing['gamefowl'] is Map) {
      final gamefowl = Map<String, dynamic>.from(listing['gamefowl'] as Map);
      if (gamefowl['images'] is List) {
        gamefowl['images'] = (gamefowl['images'] as List)
            .map((image) => resolveMediaUrl(image?.toString()))
            .toList();
      }
      listing['gamefowl'] = gamefowl;
    }
    if (listing['farm'] is Map) {
      listing['farm'] = _mapFarm(listing['farm'] as Map);
    }
    return listing;
  }

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
}
