import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/addressModel.dart';
import '../utils/api_endpoints.dart';
import 'api_service.dart';

/// Service class for handling address-related API operations
class AddressService {
  // SharedPreferences key for storing addresses locally
  static const String _addressesKey = 'user_addresses';

  /// Fetch addresses from API for a user
  Future<List<AddressModel>> fetchAddresses() async {
    try {
      final token = await ApiService.getToken();
      final userId = await ApiService.getUserId();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      final uri =
          Uri.parse('${ApiEndpoints.baseUrl}/api/addresses/user/$userId');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        List<dynamic> addressesJson = [];

        if (responseData is List) {
          addressesJson = responseData;
        } else if (responseData is Map) {
          addressesJson =
              responseData['data'] ?? responseData['addresses'] ?? [];
        }

        final addresses = addressesJson
            .map((json) => AddressModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Cache addresses locally
        await _cacheAddresses(addresses);

        return addresses;
      } else {
        throw Exception('Failed to fetch addresses: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching addresses: $e');
      // Try to return cached addresses on error
      return await getCachedAddresses();
    }
  }

  /// Add a new address
  Future<Map<String, dynamic>> addAddress(AddressModel address) async {
    try {
      final token = await ApiService.getToken();
      final userId = await ApiService.getUserId();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required',
          'data': null,
        };
      }

      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID not found',
          'data': null,
        };
      }

      final uri = Uri.parse('${ApiEndpoints.baseUrl}/api/addresses');

      final body = {
        'user_id': userId,
        ...address.toJson(),
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Address added successfully',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to add address',
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

  /// Update an existing address
  Future<Map<String, dynamic>> updateAddress(AddressModel address) async {
    try {
      final token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required',
          'data': null,
        };
      }

      if (address.id == null) {
        return {
          'success': false,
          'message': 'Address ID is required',
          'data': null,
        };
      }

      final uri =
          Uri.parse('${ApiEndpoints.baseUrl}/api/addresses/${address.id}');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(address.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Address updated successfully',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update address',
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

  /// Delete an address
  Future<Map<String, dynamic>> deleteAddress(int addressId) async {
    try {
      final token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required',
          'data': null,
        };
      }

      final uri = Uri.parse('${ApiEndpoints.baseUrl}/api/addresses/$addressId');

      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData =
            response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return {
          'success': true,
          'message': responseData['message'] ?? 'Address deleted successfully',
          'data': null,
        };
      } else {
        final responseData =
            response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to delete address',
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

  /// Set an address as the default
  Future<Map<String, dynamic>> setDefaultAddress(int addressId) async {
    try {
      final token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required',
          'data': null,
        };
      }

      final uri = Uri.parse(
          '${ApiEndpoints.baseUrl}/api/addresses/$addressId/set-default');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Default address updated',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to set default address',
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

  /// Cache addresses locally
  Future<void> _cacheAddresses(List<AddressModel> addresses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesJson = addresses.map((a) => a.toJson()).toList();
      await prefs.setString(_addressesKey, jsonEncode(addressesJson));
    } catch (e) {
      print('Error caching addresses: $e');
    }
  }

  /// Get cached addresses
  Future<List<AddressModel>> getCachedAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesString = prefs.getString(_addressesKey);

      if (addressesString == null || addressesString.isEmpty) {
        return [];
      }

      final List<dynamic> addressesJson = jsonDecode(addressesString);
      return addressesJson
          .map((json) => AddressModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting cached addresses: $e');
      return [];
    }
  }

  /// Clear cached addresses
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_addressesKey);
    } catch (e) {
      print('Error clearing address cache: $e');
    }
  }
}
