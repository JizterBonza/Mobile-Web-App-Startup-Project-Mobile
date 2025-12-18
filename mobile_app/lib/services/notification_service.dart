import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';
import '../models/notificationModel.dart';

/// Service for managing notifications
class NotificationService extends ApiService {
  /// Fetch all notifications with pagination
  Future<Map<String, dynamic>> fetchNotifications({
    int page = 1,
    int perPage = 20,
    String? type,
    String? category,
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

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found. Please login again.',
          'data': null,
        };
      }

      final queryParams = <String, String>{
        'user_id': userId,
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final uri = Uri.parse(ApiEndpoints.getNotifications).replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final paginatedResponse =
            NotificationPaginatedResponse.fromJson(responseData);

        return {
          'success': true,
          'message': 'Notifications fetched successfully',
          'data': paginatedResponse,
        };
      } else {
        final responseData = jsonDecode(response.body);
        String errorMessage = 'Failed to fetch notifications';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': null,
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

  /// Fetch notifications by category
  Future<Map<String, dynamic>> fetchNotificationsByCategory({
    required String category,
    int page = 1,
    int perPage = 20,
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

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found. Please login again.',
          'data': null,
        };
      }

      final queryParams = <String, String>{
        'user_id': userId,
        'category': category,
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      final uri = Uri.parse(ApiEndpoints.getNotificationsByCategory).replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final paginatedResponse =
            NotificationPaginatedResponse.fromJson(responseData);

        return {
          'success': true,
          'message': 'Notifications fetched successfully',
          'data': paginatedResponse,
        };
      } else {
        final responseData = jsonDecode(response.body);
        String errorMessage = 'Failed to fetch notifications';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': null,
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

  /// Get unread notification count
  Future<Map<String, dynamic>> getUnreadCount() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found. Please login again.',
          'data': null,
        };
      }

      final queryParams = <String, String>{
        'user_id': userId,
      };

      final uri = Uri.parse(ApiEndpoints.getUnreadNotificationCount).replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Unread count fetched successfully',
          'data': responseData['count'] ?? responseData['unread_count'] ?? 0,
        };
      } else {
        final responseData = jsonDecode(response.body);
        String errorMessage = 'Failed to fetch unread count';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': 0,
      };
    }
  }

  /// Mark a single notification as read
  Future<Map<String, dynamic>> markAsRead(int notificationId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found. Please login again.',
          'data': null,
        };
      }

      final uri = Uri.parse(
        ApiEndpoints.markNotificationAsRead
            .replaceAll('{id}', notificationId.toString()),
      );

      final body = {
        'user_id': userId,
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
          'message': responseData['message'] ?? 'Notification marked as read',
          'data': responseData['data'],
        };
      } else {
        String errorMessage = 'Failed to mark notification as read';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': null,
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

  /// Mark all notifications as read
  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found. Please login again.',
          'data': null,
        };
      }

      final uri = Uri.parse(ApiEndpoints.markAllNotificationsAsRead);

      final body = {
        'user_id': userId,
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
          'message':
              responseData['message'] ?? 'All notifications marked as read',
          'data': responseData['data'],
        };
      } else {
        String errorMessage = 'Failed to mark all notifications as read';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': null,
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

  /// Delete a single notification
  Future<Map<String, dynamic>> deleteNotification(int notificationId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found. Please login again.',
          'data': null,
        };
      }

      final queryParams = <String, String>{
        'user_id': userId,
      };

      final uri = Uri.parse(
        ApiEndpoints.deleteNotification
            .replaceAll('{id}', notificationId.toString()),
      ).replace(queryParameters: queryParams);

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
          'message': responseData['message'] ?? 'Notification deleted',
          'data': responseData['data'],
        };
      } else {
        String errorMessage = 'Failed to delete notification';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': null,
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

  /// Clear all read notifications
  Future<Map<String, dynamic>> clearReadNotifications() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'data': null,
        };
      }

      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found. Please login again.',
          'data': null,
        };
      }

      final queryParams = <String, String>{
        'user_id': userId,
      };

      final uri = Uri.parse(ApiEndpoints.clearReadNotifications).replace(
        queryParameters: queryParams,
      );

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
          'message': responseData['message'] ?? 'Read notifications cleared',
          'data': responseData['data'],
        };
      } else {
        String errorMessage = 'Failed to clear read notifications';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': null,
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
}
