import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_endpoints.dart';

class ApiService {
  // SharedPreferences key for storing auth token
  static const String _tokenKey = 'auth_token';

  /// Register a new user
  ///
  /// Returns a Map with 'success' (bool) and 'message' (String) or 'data' (Map)
  /// Throws an exception if the request fails
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

  /// Login a user
  ///
  /// [emailOrUsername] can be either an email address or username
  /// Returns a Map with 'success' (bool), 'message' (String), and 'data' (Map) containing token/user info
  /// Throws an exception if the request fails
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
        if (responseData is Map) {
          token = responseData['token']?.toString() ??
              responseData['access_token']?.toString() ??
              (responseData['data'] is Map
                  ? (responseData['data']['token']?.toString() ??
                      responseData['data']['access_token']?.toString())
                  : null);
        }

        // Save token to SharedPreferences if found
        if (token != null && token.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_tokenKey, token);
          } catch (e) {
            // Log error but don't fail the login if token saving fails
            print('Error saving token to SharedPreferences: $e');
          }
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
  ///
  /// Returns the token if found, null otherwise
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('Error getting token from SharedPreferences: $e');
      return null;
    }
  }

  /// Clear the stored authentication token
  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (e) {
      print('Error clearing token from SharedPreferences: $e');
    }
  }

  /// Logout a user
  ///
  /// [token] is the authentication token for the logged-in user (optional, will use stored token if not provided)
  /// Returns a Map with 'success' (bool) and 'message' (String)
  /// Throws an exception if the request fails
  static Future<Map<String, dynamic>> logout({
    String? token,
  }) async {
    try {
      // Use provided token or get from SharedPreferences
      final authToken = token ?? await getToken();

      if (authToken == null || authToken.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found',
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Clear token from SharedPreferences on successful logout
        await clearToken();

        return {
          'success': true,
          'message': responseData['message'] ?? 'Logout successful',
          'data': responseData,
        };
      } else {
        // Handle errors
        String errorMessage = 'Logout failed';
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
}
