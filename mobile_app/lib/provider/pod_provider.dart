import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/pod_services.dart';

/// Provider for managing POD (Proof of Delivery) uploads
class PodProvider with ChangeNotifier {
  final PodService _podService = PodService();

  bool _isUploading = false;
  int _uploadProgress = 0;
  int _totalToUpload = 0;

  bool get isUploading => _isUploading;
  int get uploadProgress => _uploadProgress;
  int get totalToUpload => _totalToUpload;

  /// Upload all pending POD photos from Hive
  Future<Map<String, dynamic>> uploadAllPendingPods() async {
    if (_isUploading) {
      return {
        'success': false,
        'message': 'Upload already in progress',
        'data': null,
      };
    }

    _isUploading = true;
    _uploadProgress = 0;
    _totalToUpload = 0;
    notifyListeners();

    try {
      final box = Hive.box('delivery_photos');
      final List<Map<String, dynamic>> pendingPhotos = [];

      // Get all pending photos from Hive
      for (int i = 0; i < box.length; i++) {
        final photoData = box.getAt(i);
        if (photoData is Map) {
          final status = photoData['status']?.toString() ?? 'pending';
          // Check if status is 'pending' or if status field doesn't exist (legacy data)
          if (status == 'pending' || !photoData.containsKey('status')) {
            pendingPhotos.add({
              'index': i,
              'data': photoData,
            });
          }
        }
      }

      _totalToUpload = pendingPhotos.length;
      notifyListeners();

      if (pendingPhotos.isEmpty) {
        _isUploading = false;
        notifyListeners();
        return {
          'success': true,
          'message': 'No pending photos to upload',
          'data': {
            'successCount': 0,
            'total': 0,
          },
        };
      }

      int successCount = 0;
      int failureCount = 0;

      // Upload each pending photo
      for (final photoEntry in pendingPhotos) {
        final index = photoEntry['index'] as int;
        final photoData = photoEntry['data'] as Map;

        try {
          final orderId = photoData['orderId']?.toString();
          final imagePath = photoData['imagePath']?.toString();
          final latitude = photoData['latitude'];
          final longitude = photoData['longitude'];
          final remarks = photoData['remarks']?.toString();

          if (orderId == null || imagePath == null) {
            print('POD UPLOAD: Skipping invalid photo data at index $index');
            failureCount++;
            continue;
          }

          // Check if file exists
          final imageFile = File(imagePath);
          if (!await imageFile.exists()) {
            print('POD UPLOAD: Image file not found: $imagePath');
            // Mark as failed in Hive
            photoData['status'] = 'failed';
            await box.putAt(index, photoData);
            failureCount++;
            continue;
          }

          // Convert latitude and longitude to double
          double? lat;
          double? lon;

          if (latitude is num) {
            lat = latitude.toDouble();
          } else if (latitude is String) {
            lat = double.tryParse(latitude);
          }

          if (longitude is num) {
            lon = longitude.toDouble();
          } else if (longitude is String) {
            lon = double.tryParse(longitude);
          }

          if (lat == null || lon == null) {
            print('POD UPLOAD: Invalid coordinates for order $orderId');
            photoData['status'] = 'failed';
            await box.putAt(index, photoData);
            failureCount++;
            continue;
          }

          // Upload POD
          final result = await _podService.uploadPod(
            orderId: orderId,
            imagePath: imagePath,
            latitude: lat,
            longitude: lon,
            remarks: remarks,
            status: 'delivered',
          );

          if (result['success'] == true) {
            // Mark as uploaded in Hive
            photoData['status'] = 'uploaded';
            await box.putAt(index, photoData);
            successCount++;
            print('POD UPLOAD: Successfully uploaded POD for order $orderId');
          } else {
            // Mark as failed in Hive
            photoData['status'] = 'failed';
            await box.putAt(index, photoData);
            failureCount++;
            print(
                'POD UPLOAD: Failed to upload POD for order $orderId: ${result['message']}');
          }
        } catch (e) {
          print('POD UPLOAD: Error uploading photo at index $index: $e');
          // Mark as failed in Hive
          try {
            photoData['status'] = 'failed';
            await box.putAt(index, photoData);
          } catch (e) {
            print('POD UPLOAD: Error updating Hive status: $e');
          }
          failureCount++;
        }

        _uploadProgress++;
        notifyListeners();
      }

      _isUploading = false;
      notifyListeners();

      final message = successCount == _totalToUpload
          ? 'All photos uploaded successfully'
          : '$successCount of $_totalToUpload photos uploaded successfully';

      return {
        'success': successCount > 0,
        'message': message,
        'data': {
          'successCount': successCount,
          'failureCount': failureCount,
          'total': _totalToUpload,
        },
      };
    } catch (e) {
      _isUploading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Error during upload: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Get count of pending POD photos
  int getPendingCount() {
    try {
      final box = Hive.box('delivery_photos');
      int count = 0;
      for (int i = 0; i < box.length; i++) {
        final photoData = box.getAt(i);
        if (photoData is Map) {
          final status = photoData['status']?.toString() ?? 'pending';
          if (status == 'pending' || !photoData.containsKey('status')) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      print('Error getting pending count: $e');
      return 0;
    }
  }
}
