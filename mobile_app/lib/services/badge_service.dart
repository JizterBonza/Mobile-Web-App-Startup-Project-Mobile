import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import 'api_service.dart';

/// Service for fetching cart and notification badge counts.
class BadgeService {
  /// GET /api/badges
  /// Expected: `{ "success": true, "cart_count": 3, "unread_notifications": 5 }`
  Future<Map<String, dynamic>> fetchBadges() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final uri = Uri.parse(ApiEndpoints.getBadges);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final cartCount = _parseCount(responseData['cart_count']);
        final unreadNotifications =
            _parseCount(responseData['unread_notifications']);

        return {
          'success': responseData['success'] == true ||
              responseData['success'] == null,
          'message': 'Badges fetched successfully',
          'data': {
            'cart_count': cartCount,
            'unread_notifications': unreadNotifications,
          },
        };
      }

      String errorMessage = 'Failed to fetch badges';
      try {
        final responseData = jsonDecode(response.body);
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }
      } catch (_) {}

      return {
        'success': false,
        'message': errorMessage,
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  int _parseCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
