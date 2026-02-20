import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

/// Service for managing POD (Proof of Delivery) operations
class PodService extends ApiService {
  /// Upload Proof of Delivery
  ///
  /// Required parameters:
  /// - orderId: The order ID (must exist in order_details table)
  /// - imagePath: Path to the image file
  /// - latitude: Latitude coordinate (-90 to 90)
  /// - longitude: Longitude coordinate (-180 to 180)
  ///
  /// Optional parameters:
  /// - remarks: Additional remarks (max 1000 characters)
  /// - status: Delivery status ('pending', 'delivered', or 'failed')
  Future<Map<String, dynamic>> uploadPod({
    required String orderId,
    required String imagePath,
    required double latitude,
    required double longitude,
    String? remarks,
    String? status,
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

      // Validate latitude
      if (latitude < -90 || latitude > 90) {
        return {
          'success': false,
          'message': 'Latitude must be between -90 and 90',
          'data': null,
        };
      }

      // Validate longitude
      if (longitude < -180 || longitude > 180) {
        return {
          'success': false,
          'message': 'Longitude must be between -180 and 180',
          'data': null,
        };
      }

      // Check if file exists
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return {
          'success': false,
          'message': 'Image file not found',
          'data': null,
        };
      }

      // Check file size (5MB = 5 * 1024 * 1024 bytes)
      final fileSize = await imageFile.length();
      const maxSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxSize) {
        return {
          'success': false,
          'message': 'Image file size exceeds 5MB limit',
          'data': null,
        };
      }

      // Validate file extension
      final extension = imagePath.split('.').last.toLowerCase();
      const allowedExtensions = ['jpeg', 'png', 'jpg', 'gif', 'webp'];
      if (!allowedExtensions.contains(extension)) {
        return {
          'success': false,
          'message': 'Invalid image format. Allowed: jpeg, png, jpg, gif, webp',
          'data': null,
        };
      }

      // Validate remarks length if provided
      if (remarks != null && remarks.length > 1000) {
        return {
          'success': false,
          'message': 'Remarks must not exceed 1000 characters',
          'data': null,
        };
      }

      // Validate status if provided
      if (status != null &&
          !['pending', 'delivered', 'failed'].contains(status.toLowerCase())) {
        return {
          'success': false,
          'message': 'Status must be one of: pending, delivered, failed',
          'data': null,
        };
      }

      // Create multipart request
      final uri = Uri.parse(ApiEndpoints.uploadProofOfDelivery);
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      // Add fields
      request.fields['orderId'] = orderId;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      if (remarks != null && remarks.isNotEmpty) {
        request.fields['remarks'] = remarks;
      }

      if (status != null && status.isNotEmpty) {
        request.fields['status'] = status.toLowerCase();
      }

      // Add image file
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: imagePath.split('/').last,
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Upload request timed out after 30 seconds');
        },
      );

      // Get response
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'POD uploaded successfully',
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to upload POD';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            errorMessage = responseData['message'].toString();
          } else if (responseData.containsKey('errors')) {
            final errors = responseData['errors'];
            if (errors is Map) {
              errorMessage = errors.values.first is List
                  ? errors.values.first[0]
                  : errors.values.first.toString();
            } else {
              errorMessage = errors.toString();
            }
          }
        }

        return {
          'success': false,
          'message': errorMessage,
          'data': responseData,
        };
      }
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'message': 'Upload timeout: ${e.toString()}',
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
}
