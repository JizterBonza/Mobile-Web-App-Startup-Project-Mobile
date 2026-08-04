import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/api_endpoints.dart';
import 'order_status_service.dart';

class ApiService {
  // SharedPreferences key for storing auth token
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiresAtKey = 'token_expires_at';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedLoginKey = 'saved_login';
  static const String _savedLoginTypeKey = 'saved_login_type';
  static const String savedLoginTypePhone = 'phone';
  static const String savedLoginTypeUsernameOrEmail = 'username_or_email';
  static const String _userTypeKey = 'user_type';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userMobileNumberKey = 'user_mobile_number';
  static const String _userAddressKey = 'user_address';
  static const String _firstNameKey = 'first_name';
  static const String _middleNameKey = 'middle_name';
  static const String _lastNameKey = 'last_name';

  static Completer<bool>? _refreshCompleter;

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

  static String? _formatDefaultAddress(dynamic address) {
    if (address == null) return null;
    if (address is String && address.isNotEmpty) return address;
    if (address is Map) {
      return address['full_address']?.toString() ??
          address['street_address']?.toString() ??
          address['map_address']?.toString();
    }
    return null;
  }

  static DateTime? _parseExpiresAt(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toUtc();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _hasRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);
      return refreshToken != null && refreshToken.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _canRefreshSession() async {
    return (await isRememberMeEnabled()) || (await _hasRefreshToken());
  }

  static Future<bool> isRememberMeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberMeKey) ?? false;
    } catch (e) {
      print('Error reading remember me preference: $e');
      return false;
    }
  }

  static Future<String?> getSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_savedLoginKey);
    } catch (e) {
      print('Error reading saved login: $e');
      return null;
    }
  }

  static Future<String?> getSavedLoginType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedType = prefs.getString(_savedLoginTypeKey);
      if (savedType != null && savedType.isNotEmpty) return savedType;

      // Support preferences saved before login types were introduced.
      final savedLogin = prefs.getString(_savedLoginKey);
      if (savedLogin == null || savedLogin.isEmpty) return null;
      return _loginTypeFor(savedLogin);
    } catch (e) {
      print('Error reading saved login type: $e');
      return null;
    }
  }

  static String _loginTypeFor(String loginIdentifier) {
    final trimmed = loginIdentifier.trim();
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    final isPhone = !trimmed.contains('@') &&
        RegExp(r'^\d+$').hasMatch(trimmed) &&
        digitsOnly.length >= 10;
    return isPhone ? savedLoginTypePhone : savedLoginTypeUsernameOrEmail;
  }

  static Future<bool> isAccessTokenExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiresAt = _parseExpiresAt(prefs.getString(_tokenExpiresAtKey));
      if (expiresAt == null) return false;
      return DateTime.now().toUtc().isAfter(
            expiresAt.subtract(const Duration(seconds: 30)),
          );
    } catch (e) {
      print('Error checking token expiry: $e');
      return false;
    }
  }

  static Future<void> applyRememberMePreference({
    required bool rememberMe,
    String? loginIdentifier,
    String? loginType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberMeKey, rememberMe);
      if (rememberMe) {
        if (loginIdentifier != null && loginIdentifier.isNotEmpty) {
          await prefs.setString(_savedLoginKey, loginIdentifier);
          await prefs.setString(
            _savedLoginTypeKey,
            loginType ?? _loginTypeFor(loginIdentifier),
          );
        }
      } else {
        await prefs.remove(_refreshTokenKey);
        await prefs.remove(_tokenExpiresAtKey);
        await prefs.remove(_savedLoginKey);
        await prefs.remove(_savedLoginTypeKey);
      }
    } catch (e) {
      print('Error saving remember me preference: $e');
    }
  }

  /// Persists token and user fields from a login or Google auth response.
  static Future<void> saveAuthSessionFromResponse(
    Map<dynamic, dynamic> responseData, {
    bool persistRefreshToken = true,
  }) async {
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

    token = responseData['token']?.toString() ??
        responseData['access_token']?.toString() ??
        (responseData['data'] is Map
            ? (responseData['data']['token']?.toString() ??
                responseData['data']['access_token']?.toString())
            : null);

    userType = responseData['user_type']?.toString() ??
        (responseData['user'] is Map
            ? responseData['user']['user_type']?.toString()
            : null) ??
        (responseData['data'] is Map
            ? (responseData['data']['user_type']?.toString() ??
                (responseData['data']['user'] is Map
                    ? responseData['data']['user']['user_type']?.toString()
                    : null))
            : null);

    userId = responseData['user_id']?.toString() ??
        (responseData['user'] is Map
            ? responseData['user']['id']?.toString() ??
                responseData['user']['user_id']?.toString()
            : null) ??
        (responseData['data'] is Map
            ? (responseData['data']['user_id']?.toString() ??
                (responseData['data']['user'] is Map
                    ? (responseData['data']['user']['id']?.toString() ??
                        responseData['data']['user']['user_id']?.toString())
                    : null))
            : null);

    if (responseData['user'] is Map) {
      final user = responseData['user'] as Map;
      userName = user['user_credential'] is Map
          ? user['user_credential']['username']?.toString()
          : user['username']?.toString();
      userEmail = (user['user_detail'] is Map
              ? user['user_detail']['email']?.toString()
              : null) ??
          (user['user_credential'] is Map
              ? user['user_credential']['email']?.toString()
              : null) ??
          user['email']?.toString();
      userMobileNumber = (user['user_detail'] is Map
              ? user['user_detail']['mobile_number']?.toString()
              : null) ??
          (user['user_credential'] is Map
              ? user['user_credential']['mobile_number']?.toString()
              : null);
      firstName = user['user_detail'] is Map
          ? user['user_detail']['first_name']?.toString()
          : null;
      middleName = user['user_detail'] is Map
          ? user['user_detail']['middle_name']?.toString()
          : null;
      lastName = user['user_detail'] is Map
          ? user['user_detail']['last_name']?.toString()
          : null;
    }

    if (responseData['data'] is Map && responseData['data']['user'] is Map) {
      final user = responseData['data']['user'] as Map;
      userName ??= user['user_credential'] is Map
          ? user['user_credential']['username']?.toString()
          : null;
      userEmail ??= (user['user_detail'] is Map
              ? user['user_detail']['email']?.toString()
              : null) ??
          (user['user_credential'] is Map
              ? user['user_credential']['email']?.toString()
              : null);
      userMobileNumber ??= (user['user_detail'] is Map
              ? user['user_detail']['mobile_number']?.toString()
              : null) ??
          (user['user_credential'] is Map
              ? user['user_credential']['mobile_number']?.toString()
              : null);
      firstName ??= user['user_detail'] is Map
          ? user['user_detail']['first_name']?.toString()
          : null;
      middleName ??= user['user_detail'] is Map
          ? user['user_detail']['middle_name']?.toString()
          : null;
      lastName ??= user['user_detail'] is Map
          ? user['user_detail']['last_name']?.toString()
          : null;
    }

    userAddress = _formatDefaultAddress(responseData['default_address']);

    final refreshToken = responseData['refresh_token']?.toString();
    final expiresAt = responseData['expires_at']?.toString();

    if (token == null || token.isEmpty) {
      print('Auth session - Warning: Token not found in response');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      if (persistRefreshToken &&
          refreshToken != null &&
          refreshToken.isNotEmpty) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      }
      if (expiresAt != null && expiresAt.isNotEmpty) {
        await prefs.setString(_tokenExpiresAtKey, expiresAt);
      }
      if (userType != null && userType.isNotEmpty) {
        await prefs.setString(_userTypeKey, userType);
      }
      if (userId != null && userId.isNotEmpty) {
        await prefs.setString(_userIdKey, userId);
      }
      if (userName != null && userName.isNotEmpty) {
        await prefs.setString(_userNameKey, userName);
      }
      if (userEmail != null && userEmail.isNotEmpty) {
        await prefs.setString(_userEmailKey, userEmail);
      }
      if (userMobileNumber != null && userMobileNumber.isNotEmpty) {
        await prefs.setString(_userMobileNumberKey, userMobileNumber);
      }
      if (userAddress != null && userAddress.isNotEmpty) {
        await prefs.setString(_userAddressKey, userAddress);
      }
      if (firstName != null && firstName.isNotEmpty) {
        await prefs.setString(_firstNameKey, firstName);
      }
      if (middleName != null && middleName.isNotEmpty) {
        await prefs.setString(_middleNameKey, middleName);
      }
      if (lastName != null && lastName.isNotEmpty) {
        await prefs.setString(_lastNameKey, lastName);
      }
    } catch (e) {
      print('Error saving auth session to SharedPreferences: $e');
    }
  }

  /// Exchange Google id_token for a Sanctum token (POST /api/auth/google/token).
  static Future<Map<String, dynamic>> signInWithGoogleIdToken(
    String idToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.googleToken),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'id_token': idToken}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData is Map &&
          responseData['success'] == true) {
        await saveAuthSessionFromResponse(responseData);
        await applyRememberMePreference(rememberMe: true);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Login successful',
          'data': responseData,
        };
      }

      String errorMessage = 'Google sign-in failed';
      if (responseData is Map && responseData.containsKey('message')) {
        errorMessage = responseData['message'].toString();
      }

      return {
        'success': false,
        'message': errorMessage,
        'data': responseData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Exchange a refresh token for a new access token (POST /api/refresh).
  static Future<bool> refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(false);
        return false;
      }

      final response = await http.post(
        Uri.parse(ApiEndpoints.refresh),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData is Map) {
        await saveAuthSessionFromResponse(responseData);
        completer.complete(true);
        return true;
      }

      await _clearAuthSession();
      completer.complete(false);
      return false;
    } catch (e) {
      print('Error refreshing access token: $e');
      await _clearAuthSession();
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Restores an active session from a valid or refreshable token.
  static Future<Map<String, dynamic>> tryRestoreSession() async {
    try {
      final token = await getToken();
      final userType = await getUserType();

      if (token != null &&
          token.isNotEmpty &&
          userType != null &&
          userType.isNotEmpty) {
        return {
          'success': true,
          'userType': userType,
        };
      }

      if (await _canRefreshSession()) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          final refreshedUserType = await getUserType();
          if (refreshedUserType != null && refreshedUserType.isNotEmpty) {
            return {
              'success': true,
              'userType': refreshedUserType,
            };
          }
        }
      }

      return {'success': false};
    } catch (e) {
      print('Error restoring session: $e');
      return {'success': false};
    }
  }

  /// Login a user with email, username, or mobile number
  static Future<Map<String, dynamic>> login({
    required String emailOrUsername,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final uri = Uri.parse(ApiEndpoints.login);

      final trimmed = emailOrUsername.trim();
      final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
      final bool isEmail = trimmed.contains('@');
      final bool isPhone = !isEmail &&
          RegExp(r'^\d+$').hasMatch(trimmed) &&
          digitsOnly.length >= 10;

      final body = <String, dynamic>{
        if (isEmail) 'email': trimmed,
        if (!isEmail && isPhone) 'mobile_number': digitsOnly,
        if (!isEmail && !isPhone) 'username': trimmed,
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
        if (responseData is Map) {
          await saveAuthSessionFromResponse(
            responseData,
            persistRefreshToken: rememberMe,
          );
          // Apply this last so opting out also removes any refresh/expiry
          // metadata included in the successful login response.
          await applyRememberMePreference(
            rememberMe: rememberMe,
            loginIdentifier: isPhone ? digitsOnly : trimmed,
            loginType:
                isPhone ? savedLoginTypePhone : savedLoginTypeUsernameOrEmail,
          );
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

  /// Get the stored authentication token, refreshing it when expired.
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token == null || token.isEmpty) {
        if (await _canRefreshSession()) {
          final refreshed = await refreshAccessToken();
          if (refreshed) {
            return prefs.getString(_tokenKey);
          }
        }
        return null;
      }

      if (await isAccessTokenExpired()) {
        if (await _canRefreshSession()) {
          final refreshed = await refreshAccessToken();
          if (refreshed) {
            return prefs.getString(_tokenKey);
          }
        }
        return null;
      }

      return token;
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

  static Future<void> _clearAuthSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenExpiresAtKey);
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_savedLoginKey);
      await prefs.remove(_savedLoginTypeKey);
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
      print('Error clearing auth session: $e');
    }
  }

  /// Clear all user data from SharedPreferences.
  ///
  /// When Remember me is enabled the checkbox state and saved login
  /// identifier are preserved so the next login is pre-filled, while the
  /// access and refresh tokens are always cleared.
  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
      final savedLogin = prefs.getString(_savedLoginKey);
      final savedLoginType = prefs.getString(_savedLoginTypeKey);

      await prefs.clear();

      if (rememberMe) {
        await prefs.setBool(_rememberMeKey, true);
        if (savedLogin != null && savedLogin.isNotEmpty) {
          await prefs.setString(_savedLoginKey, savedLogin);
          await prefs.setString(
            _savedLoginTypeKey,
            savedLoginType ?? _loginTypeFor(savedLogin),
          );
        }
      }
    } catch (e) {
      print('Error clearing SharedPreferences: $e');
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

  /// Clear all Hive cached data
  static Future<void> _clearAllCache() async {
    try {
      try {
        if (Hive.isBoxOpen('delivery_photos')) {
          await Hive.box('delivery_photos').clear();
        }
      } catch (e) {
        print('Error clearing Hive box delivery_photos: $e');
      }

      try {
        final orderStatusService = OrderStatusService();
        await orderStatusService.clearOrderStatuses();
      } catch (e) {
        print('Error clearing Hive box order_statuses: $e');
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
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
