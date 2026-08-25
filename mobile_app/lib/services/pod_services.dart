import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

typedef PodMultipartRequestFactory = http.MultipartRequest Function(
  String method,
  Uri uri,
);
typedef PodRequestSender = Future<http.StreamedResponse> Function(
  http.BaseRequest request,
);

/// Service for managing POD (Proof of Delivery) operations
class PodService extends ApiService {
  PodService({
    PodMultipartRequestFactory? multipartRequestFactory,
    PodRequestSender? requestSender,
  })  : _multipartRequestFactory = multipartRequestFactory,
        _requestSender = requestSender;

  final PodMultipartRequestFactory? _multipartRequestFactory;
  final PodRequestSender? _requestSender;

  static const int _maximumImageCount = 5;
  static const int _maximumImageSize = 5 * 1024 * 1024;
  static const Set<String> _allowedImageExtensions = {
    'jpeg',
    'png',
    'jpg',
    'gif',
    'webp',
  };

  /// Upload one order-shop POD with one to five proof images.
  Future<Map<String, dynamic>> uploadOrderShopPod({
    required int orderId,
    required int orderShopId,
    required List<String> imagePaths,
    required double latitude,
    required double longitude,
    required String remarks,
    required String status,
  }) async {
    try {
      final validationError = await _validateOrderShopPod(
        orderId: orderId,
        orderShopId: orderShopId,
        imagePaths: imagePaths,
        latitude: latitude,
        longitude: longitude,
        remarks: remarks,
        status: status,
      );
      if (validationError != null) {
        return _failure(validationError);
      }

      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return _failure('Authentication required. Please login.');
      }

      final uri = Uri.parse(ApiEndpoints.uploadProofOfDelivery);
      final request = _multipartRequestFactory?.call('POST', uri) ??
          http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.fields.addAll({
        'orderId': orderId.toString(),
        'orderShopId': orderShopId.toString(),
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'remarks': remarks,
        'status': status.toLowerCase(),
      });

      for (final imagePath in imagePaths) {
        final imageFile = File(imagePath);
        request.files.add(
          http.MultipartFile.fromBytes(
            'images[]',
            await imageFile.readAsBytes(),
            filename: _fileName(imagePath),
          ),
        );
      }

      final streamedResponse =
          await (_requestSender?.call(request) ?? request.send()).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Upload request timed out after 30 seconds');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      dynamic responseData;
      if (response.body.trim().isEmpty) {
        responseData = <String, dynamic>{};
      } else {
        try {
          responseData = jsonDecode(response.body);
        } on FormatException {
          responseData = <String, dynamic>{};
        }
      }

      final isSuccessStatus =
          response.statusCode >= 200 && response.statusCode < 300;
      final apiReportedFailure =
          responseData is Map && responseData['success'] == false;
      if (isSuccessStatus && !apiReportedFailure) {
        return {
          'success': true,
          'message': responseData is Map
              ? responseData['message'] ?? 'POD uploaded successfully'
              : 'POD uploaded successfully',
          'data': responseData is Map
              ? responseData['data'] ?? responseData
              : responseData,
        };
      }

      return _failure(
        _responseError(responseData, 'Failed to upload POD'),
        data: responseData,
      );
    } on TimeoutException catch (error) {
      return _failure('Upload timeout: ${error.toString()}');
    } catch (error) {
      return _failure('Network error: ${error.toString()}');
    }
  }

  Future<String?> _validateOrderShopPod({
    required int orderId,
    required int orderShopId,
    required List<String> imagePaths,
    required double latitude,
    required double longitude,
    required String remarks,
    required String status,
  }) async {
    if (orderId <= 0) return 'Invalid order ID.';
    if (orderShopId <= 0) return 'Invalid order-shop ID.';
    if (imagePaths.isEmpty || imagePaths.length > _maximumImageCount) {
      return 'Select between 1 and $_maximumImageCount delivery photos.';
    }
    if (latitude < -90 || latitude > 90) {
      return 'Latitude must be between -90 and 90';
    }
    if (longitude < -180 || longitude > 180) {
      return 'Longitude must be between -180 and 180';
    }
    if (remarks.length > 1000) {
      return 'Remarks must not exceed 1000 characters';
    }
    if (!{'pending', 'delivered', 'failed'}.contains(status.toLowerCase())) {
      return 'Status must be one of: pending, delivered, failed';
    }

    for (final imagePath in imagePaths) {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) return 'Image file not found';
      if (await imageFile.length() > _maximumImageSize) {
        return 'Image file size exceeds 5MB limit';
      }
      final extension = _fileName(imagePath).split('.').last.toLowerCase();
      if (!_allowedImageExtensions.contains(extension)) {
        return 'Invalid image format. Allowed: jpeg, png, jpg, gif, webp';
      }
    }
    return null;
  }

  static String _fileName(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }

  static String _responseError(dynamic responseData, String fallback) {
    if (responseData is! Map) return fallback;
    final message = responseData['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    final errors = responseData['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }
    return fallback;
  }

  static Map<String, dynamic> _failure(String message, {dynamic data}) {
    return {
      'success': false,
      'message': message,
      'data': data,
    };
  }

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
        const Duration(seconds: 30),
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
