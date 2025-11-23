import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_endpoints.dart';

class ApiService {
  // SharedPreferences key for storing auth token
  static const String _tokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';

  /// Register a new user
  static Future<Map<String, dynamic>> register({
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    required String email,
    required String mobileNumber,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(ApiEndpoints.register);

      final body = {
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
        'mobile_number': mobileNumber,
        'password': password,
        'password_confirmation': password,
      };

      // Add middle name only if provided
      if (middleName != null && middleName.isNotEmpty) {
        body['middle_name'] = middleName;
      }

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Registration successful',
          'data': responseData,
        };
      } else {
        // Handle validation errors or other errors
        String errorMessage = 'Registration failed';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData.containsKey('errors')) {
          // Handle validation errors
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first.toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': responseData,
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

  /// Login a user with email or username
  static Future<Map<String, dynamic>> login({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(ApiEndpoints.login);

      // Determine if the input is an email or username
      final bool isEmail = emailOrUsername.contains('@');

      final body = <String, dynamic>{
        if (isEmail) 'email': emailOrUsername,
        if (!isEmail) 'username': emailOrUsername,
        'password': password,
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Extract and save token to SharedPreferences
        String? token;
        String? userType;
        String? userId;
        String? userName;
        if (responseData is Map) {
          // Extract token from various possible locations
          token = responseData['token']?.toString() ??
              responseData['access_token']?.toString() ??
              (responseData['data'] is Map
                  ? (responseData['data']['token']?.toString() ??
                      responseData['data']['access_token']?.toString())
                  : null);

          // Extract user_type from various possible locations
          // Based on actual response: data['user']['user_type']
          userType = responseData['user_type']?.toString() ??
              (responseData['user'] is Map
                  ? responseData['user']['user_type']?.toString()
                  : null) ??
              (responseData['data'] is Map
                  ? (responseData['data']['user_type']?.toString() ??
                      (responseData['data']['user'] is Map
                          ? responseData['data']['user']['user_type']
                              ?.toString()
                          : null))
                  : null);

          // Extract user_id from various possible locations
          userId = responseData['user_id']?.toString() ??
              (responseData['user'] is Map
                  ? responseData['user']['id']?.toString() ??
                      responseData['user']['user_id']?.toString()
                  : null) ??
              (responseData['data'] is Map
                  ? (responseData['data']['user_id']?.toString() ??
                      (responseData['data']['user'] is Map
                          ? (responseData['data']['user']['id']?.toString() ??
                              responseData['data']['user']['user_id']
                                  ?.toString())
                          : null))
                  : null);
          userName =
              responseData['user']['user_credential']['username']?.toString() ??
                  (responseData['data'] is Map
                      ? (responseData['data']['user_credential'] is Map
                          ? responseData['data']['user_credential']['username']
                              ?.toString()
                          : null)
                      : null);
        }

        // Save token to SharedPreferences if found
        if (token != null && token.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_tokenKey, token);

            // Save userType if found
            if (userType != null && userType.isNotEmpty) {
              await prefs.setString(_userTypeKey, userType);
            }

            // Save userId if found
            if (userId != null && userId.isNotEmpty) {
              await prefs.setString(_userIdKey, userId);
            }

            // Save userName if found
            if (userName != null && userName.isNotEmpty) {
              await prefs.setString(_userNameKey, userName);
            }
          } catch (e) {
            // Log error but don't fail the login if token saving fails
            print('Error saving token to SharedPreferences: $e');
          }
        } else {
          print('Login - Warning: Token not found in response');
        }

        return {
          'success': true,
          'message': responseData['message'] ?? 'Login successful',
          'data': responseData,
        };
      } else {
        // Handle validation errors or other errors
        String errorMessage = 'Login failed';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData.containsKey('errors')) {
          // Handle validation errors
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first.toString();
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': responseData,
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

  /// Get the stored authentication token
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('Error getting token from SharedPreferences: $e');
      return null;
    }
  }

  /// Get the stored user type
  static Future<String?> getUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userTypeKey);
    } catch (e) {
      print('Error getting user type from SharedPreferences: $e');
      return null;
    }
  }

  /// Get the stored user ID
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      print('Error getting user ID from SharedPreferences: $e');
      return null;
    }
  }

  /// Get the stored user name
  static Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userNameKey);
    } catch (e) {
      print('Error getting user name from SharedPreferences: $e');
      return null;
    }
  }

  /// Clear the stored authentication token, user type, and user ID
  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userTypeKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userNameKey);
    } catch (e) {
      print('Error clearing token from SharedPreferences: $e');
    }
  }

  /// Logout a user
  static Future<Map<String, dynamic>> logout({
    String? token,
  }) async {
    try {
      // Use provided token or get from SharedPreferences
      final authToken = token ?? await getToken();

      if (authToken == null || authToken.isEmpty) {
        // Clear any remaining data
        await clearToken();
        await _clearAllCache();
        return {
          'success': true,
          'message': 'Logged out successfully (no active session found)',
          'data': null,
        };
      }

      final uri = Uri.parse(ApiEndpoints.logout);

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      final responseData = jsonDecode(response.body);

      // Always clear token and cache from SharedPreferences, regardless of API response
      await clearToken();
      await _clearAllCache();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Logout successful',
          'data': responseData,
        };
      } else {
        String errorMessage =
            'Logout failed on server, but local session cleared';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData.containsKey('errors')) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first.toString();
        }

        return {
          'success': true,
          'message': errorMessage,
          'data': responseData,
        };
      }
    } catch (e) {
      await clearToken();
      await _clearAllCache();
      return {
        'success': true,
        'message': 'Logged out locally (network error: ${e.toString()})',
        'data': null,
      };
    }
  }

  /// Clear all cached data
  static Future<void> _clearAllCache() async {
    // Cache clearing is now handled by Providers
    // Providers will automatically clear their cache when needed
  }
}
