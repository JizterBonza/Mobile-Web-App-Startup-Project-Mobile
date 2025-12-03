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
  static const String _userEmailKey = 'user_email';
  static const String _userMobileNumberKey = 'user_mobile_number';
  static const String _userAddressKey = 'user_address';
  static const String _firstNameKey = 'first_name';
  static const String _middleNameKey = 'middle_name';
  static const String _lastNameKey = 'last_name';

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
        //print('Response data: $responseData');
        String? token;
        String? userType;
        String? userId;
        String? userName;
        String? userEmail;
        String? userMobileNumber;
        String? userAddress;
        String? firstName;
        String? middleName;
        String? lastName;

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
          // Extract email from user_detail (primary) or user_credential (fallback)
          userEmail = (responseData['user'] is Map &&
                      responseData['user']['user_detail'] is Map
                  ? responseData['user']['user_detail']['email']?.toString()
                  : null) ??
              responseData['user']['user_credential']?['email']?.toString() ??
              (responseData['data'] is Map
                  ? ((responseData['data']['user'] is Map &&
                              responseData['data']['user']['user_detail'] is Map
                          ? responseData['data']['user']['user_detail']['email']
                              ?.toString()
                          : null) ??
                      (responseData['data']['user_credential'] is Map
                          ? responseData['data']['user_credential']['email']
                              ?.toString()
                          : null))
                  : null);
          // Extract mobile_number from user_detail (primary) or user_credential (fallback)
          userMobileNumber = (responseData['user'] is Map &&
                      responseData['user']['user_detail'] is Map
                  ? responseData['user']['user_detail']['mobile_number']
                      ?.toString()
                  : null) ??
              responseData['user']['user_credential']?['mobile_number']
                  ?.toString() ??
              (responseData['data'] is Map
                  ? ((responseData['data']['user'] is Map &&
                              responseData['data']['user']['user_detail'] is Map
                          ? responseData['data']['user']['user_detail']
                                  ['mobile_number']
                              ?.toString()
                          : null) ??
                      (responseData['data']['user_credential'] is Map
                          ? responseData['data']['user_credential']
                                  ['mobile_number']
                              ?.toString()
                          : null))
                  : null);
          // Extract shipping_address from user_detail
          userAddress = (responseData['user'] is Map &&
                      responseData['user']['user_detail'] is Map
                  ? responseData['user']['user_detail']['shipping_address']
                      ?.toString()
                  : null) ??
              (responseData['data'] is Map
                  ? (responseData['data']['user'] is Map &&
                          responseData['data']['user']['user_detail'] is Map
                      ? responseData['data']['user']['user_detail']
                              ['shipping_address']
                          ?.toString()
                      : null)
                  : null);
          // Extract first_name from user_detail
          firstName = (responseData['user'] is Map &&
                      responseData['user']['user_detail'] is Map
                  ? responseData['user']['user_detail']['first_name']
                      ?.toString()
                  : null) ??
              (responseData['data'] is Map
                  ? (responseData['data']['user'] is Map &&
                          responseData['data']['user']['user_detail'] is Map
                      ? responseData['data']['user']['user_detail']
                              ['first_name']
                          ?.toString()
                      : null)
                  : null);
          // Extract middle_name from user_detail
          middleName = (responseData['user'] is Map &&
                      responseData['user']['user_detail'] is Map
                  ? responseData['user']['user_detail']['middle_name']
                      ?.toString()
                  : null) ??
              (responseData['data'] is Map
                  ? (responseData['data']['user'] is Map &&
                          responseData['data']['user']['user_detail'] is Map
                      ? responseData['data']['user']['user_detail']
                              ['middle_name']
                          ?.toString()
                      : null)
                  : null);
          // Extract last_name from user_detail
          lastName = (responseData['user'] is Map &&
                      responseData['user']['user_detail'] is Map
                  ? responseData['user']['user_detail']['last_name']?.toString()
                  : null) ??
              (responseData['data'] is Map
                  ? (responseData['data']['user'] is Map &&
                          responseData['data']['user']['user_detail'] is Map
                      ? responseData['data']['user']['user_detail']['last_name']
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

            // Save userEmail if found
            if (userEmail != null && userEmail.isNotEmpty) {
              await prefs.setString(_userEmailKey, userEmail);
            }

            // Save userMobileNumber if found
            if (userMobileNumber != null && userMobileNumber.isNotEmpty) {
              await prefs.setString(_userMobileNumberKey, userMobileNumber);
            }

            // Save userAddress if found
            if (userAddress != null && userAddress.isNotEmpty) {
              await prefs.setString(_userAddressKey, userAddress);
            }

            // Save firstName if found
            if (firstName != null && firstName.isNotEmpty) {
              await prefs.setString(_firstNameKey, firstName);
            }

            // Save middleName if found
            if (middleName != null && middleName.isNotEmpty) {
              await prefs.setString(_middleNameKey, middleName);
            }

            // Save lastName if found
            if (lastName != null && lastName.isNotEmpty) {
              await prefs.setString(_lastNameKey, lastName);
            }

            // print('User email: $userEmail');
            // print('User mobile number: $userMobileNumber');
            // print('User address: $userAddress');
            // print('First name: $firstName');
            // print('Middle name: $middleName');
            // print('Last name: $lastName');
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

  /// Get the stored user email
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      print('Error getting user email from SharedPreferences: $e');
      return null;
    }
  }

  /// Get the stored user mobile number
  static Future<String?> getUserMobileNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userMobileNumberKey);
    } catch (e) {
      print('Error getting user mobile number from SharedPreferences: $e');
      return null;
    }
  }

  /// Get the stored user address
  static Future<String?> getUserAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userAddressKey);
    } catch (e) {
      print('Error getting user address from SharedPreferences: $e');
      return null;
    }
  }

  /// Get the stored first name
  static Future<String?> getFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_firstNameKey);
    } catch (e) {
      print('Error getting first name from SharedPreferences: $e');
      return null;
    }
  }

  /// Get the stored middle name
  static Future<String?> getMiddleName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_middleNameKey);
    } catch (e) {
      print('Error getting middle name from SharedPreferences: $e');
      return null;
    }
  }

  /// Get the stored last name
  static Future<String?> getLastName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastNameKey);
    } catch (e) {
      print('Error getting last name from SharedPreferences: $e');
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
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userMobileNumberKey);
      await prefs.remove(_userAddressKey);
      await prefs.remove(_firstNameKey);
      await prefs.remove(_middleNameKey);
      await prefs.remove(_lastNameKey);
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

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    required String email,
    String? mobileNumber,
    String? shippingAddress,
  }) async {
    try {
      final authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
          'data': null,
        };
      }

      final uri = Uri.parse(ApiEndpoints.updateProfile);

      final body = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
      };

      // Add optional fields only if provided
      if (middleName != null && middleName.isNotEmpty) {
        body['middle_name'] = middleName;
      }
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        body['mobile_number'] = mobileNumber;
      }
      if (shippingAddress != null && shippingAddress.isNotEmpty) {
        body['shipping_address'] = shippingAddress;
      }

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Update SharedPreferences with new user data
        try {
          final prefs = await SharedPreferences.getInstance();

          if (username.isNotEmpty) {
            await prefs.setString(_userNameKey, username);
          }
          if (email.isNotEmpty) {
            await prefs.setString(_userEmailKey, email);
          }
          if (mobileNumber != null && mobileNumber.isNotEmpty) {
            await prefs.setString(_userMobileNumberKey, mobileNumber);
          }
          if (shippingAddress != null && shippingAddress.isNotEmpty) {
            await prefs.setString(_userAddressKey, shippingAddress);
          }
          if (firstName.isNotEmpty) {
            await prefs.setString(_firstNameKey, firstName);
          }
          if (middleName != null && middleName.isNotEmpty) {
            await prefs.setString(_middleNameKey, middleName);
          }
          if (lastName.isNotEmpty) {
            await prefs.setString(_lastNameKey, lastName);
          }
        } catch (e) {
          print('Error updating SharedPreferences: $e');
        }

        return {
          'success': true,
          'message': responseData['message'] ?? 'Profile updated successfully',
          'data': responseData,
        };
      } else {
        String errorMessage = 'Profile update failed';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData.containsKey('errors')) {
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

  /// Change user password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
          'data': null,
        };
      }

      final uri = Uri.parse(ApiEndpoints.changePassword);

      final body = <String, dynamic>{
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      };

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Password changed successfully',
          'data': responseData,
        };
      } else {
        String errorMessage = 'Password change failed';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData.containsKey('errors')) {
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
