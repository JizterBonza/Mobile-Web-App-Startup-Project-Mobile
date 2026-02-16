import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/constants.dart';
import '../../models/delivery_photo_model.dart';
import '../../services/order_service.dart';

class DeliveryPhotoPreviewScreen extends StatefulWidget {
  final XFile imageFile;
  final Map<String, dynamic> order;
  final String orderId;

  const DeliveryPhotoPreviewScreen({
    super.key,
    required this.imageFile,
    required this.order,
    required this.orderId,
  });

  @override
  State<DeliveryPhotoPreviewScreen> createState() =>
      _DeliveryPhotoPreviewScreenState();
}

class _DeliveryPhotoPreviewScreenState
    extends State<DeliveryPhotoPreviewScreen> {
  final OrderService _orderService = OrderService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Preview Photo',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Image Preview
            Expanded(
              child: Center(
                child: Image.file(
                  File(widget.imageFile.path),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Action Buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Retake Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _retakePhoto,
                      icon: Icon(Icons.camera_alt),
                      label: Text('Retake'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white70),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  // Confirm Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _confirmAndSave,
                      icon: _isProcessing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.check),
                      label: Text(_isProcessing ? 'Saving...' : 'Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusDelivered,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retakePhoto() async {
    Navigator.of(context).pop(false); // Return false to indicate retake
  }

  Future<void> _confirmAndSave() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Step 1: Get current location
      Position? position;
      String? address;

      print('=== DELIVERY PHOTO DEBUG: Starting location retrieval ===');
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );

        print('DEBUG: Location retrieved successfully');
        print('DEBUG: Latitude: ${position.latitude}');
        print('DEBUG: Longitude: ${position.longitude}');
        print('DEBUG: Accuracy: ${position.accuracy} meters');
        print('DEBUG: Timestamp: ${position.timestamp}');

        // Get address from coordinates
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks[0];
            address =
                '${place.street}, ${place.locality}, ${place.administrativeArea}';
            print('DEBUG: Address resolved: $address');
            print('DEBUG: Street: ${place.street}');
            print('DEBUG: Locality: ${place.locality}');
            print('DEBUG: Administrative Area: ${place.administrativeArea}');
            print('DEBUG: Country: ${place.country}');
          } else {
            print('DEBUG: No address found for coordinates');
          }
        } catch (e) {
          print('DEBUG: Error getting address: $e');
        }
      } catch (e) {
        print('DEBUG: Error getting location: $e');
        _showError('Error getting location: ${e.toString()}');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Step 2: Save image to permanent storage
      String savedImagePath;
      print('=== DELIVERY PHOTO DEBUG: Saving image to storage ===');
      try {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String deliveryPhotosDir = '${appDocDir.path}/delivery_photos';
        print('DEBUG: App documents directory: ${appDocDir.path}');
        print('DEBUG: Delivery photos directory: $deliveryPhotosDir');

        final Directory dir = Directory(deliveryPhotosDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
          print('DEBUG: Created delivery photos directory');
        } else {
          print('DEBUG: Delivery photos directory already exists');
        }

        final String fileName =
            'delivery_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File savedImage = File('${dir.path}/$fileName');
        print('DEBUG: Original image path: ${widget.imageFile.path}');
        print('DEBUG: Target file name: $fileName');
        print('DEBUG: Target file path: ${savedImage.path}');

        await File(widget.imageFile.path).copy(savedImage.path);
        savedImagePath = savedImage.path;

        print('DEBUG: Image saved successfully to: $savedImagePath');
        print('DEBUG: File exists: ${await savedImage.exists()}');
        if (await savedImage.exists()) {
          final fileSize = await savedImage.length();
          print(
              'DEBUG: File size: ${fileSize} bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)');
        }
      } catch (e) {
        print('DEBUG: Error saving image: $e');
        _showError('Error saving image: ${e.toString()}');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Step 3: Save to Hive
      print('=== DELIVERY PHOTO DEBUG: Saving to Hive ===');
      try {
        final now = DateTime.now();
        final deliveryPhoto = DeliveryPhotoModel(
          orderId: widget.orderId,
          imagePath: savedImagePath,
          timestamp: now,
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
        );

        print('DEBUG: Delivery Photo Model created:');
        print('DEBUG:   - Order ID: ${deliveryPhoto.orderId}');
        print('DEBUG:   - Image Path: ${deliveryPhoto.imagePath}');
        print(
            'DEBUG:   - Timestamp: ${deliveryPhoto.timestamp.toIso8601String()}');
        print('DEBUG:   - Latitude: ${deliveryPhoto.latitude}');
        print('DEBUG:   - Longitude: ${deliveryPhoto.longitude}');
        print('DEBUG:   - Address: ${deliveryPhoto.address ?? "N/A"}');

        final box = Hive.box('delivery_photos');
        print('DEBUG: Hive box opened: delivery_photos');
        print('DEBUG: Current box length before add: ${box.length}');

        final dataToSave = {
          'orderId': deliveryPhoto.orderId,
          'imagePath': deliveryPhoto.imagePath,
          'timestamp': deliveryPhoto.timestamp.toIso8601String(),
          'latitude': deliveryPhoto.latitude,
          'longitude': deliveryPhoto.longitude,
          'address': deliveryPhoto.address,
        };

        print('DEBUG: Data to save to Hive:');
        dataToSave.forEach((key, value) {
          print('DEBUG:   $key: $value');
        });

        final key = await box.add(dataToSave);
        print('DEBUG: Data saved to Hive with key: $key');
        print('DEBUG: Box length after add: ${box.length}');

        // Print all saved delivery photos for debugging
        print('DEBUG: All delivery photos in Hive:');
        for (int i = 0; i < box.length; i++) {
          final savedData = box.getAt(i);
          print('DEBUG:   [$i] $savedData');
        }

        print('DEBUG: Delivery photo saved successfully to Hive');
        print(
            'DEBUG: Order ${widget.orderId} at ${position.latitude}, ${position.longitude}');
      } catch (e) {
        print('DEBUG: Error saving to Hive: $e');
        print('DEBUG: Error stack trace: ${StackTrace.current}');
        _showWarning('Error saving delivery photo: ${e.toString()}');
        // Continue with delivery even if Hive save fails
      }

      // Step 4: Mark order as delivered
      print('=== DELIVERY PHOTO DEBUG: Updating order status ===');
      print('DEBUG: Order ID: ${widget.orderId}');
      print('DEBUG: New status: delivered');

      final result = await _orderService.updateOrderStatus(
        orderId: widget.orderId,
        status: 'delivered',
      );

      print('DEBUG: Order status update result:');
      print('DEBUG:   - Success: ${result['success']}');
      print('DEBUG:   - Message: ${result['message'] ?? "N/A"}');
      print('DEBUG:   - Full result: $result');

      if (result['success'] == true) {
        print('DEBUG: Order marked as delivered successfully');
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order marked as delivered'),
              backgroundColor: AppColors.statusDelivered,
            ),
          );
        }
      } else {
        print('DEBUG: Failed to update order status');
        _showError(result['message'] ?? 'Failed to update order');
        setState(() {
          _isProcessing = false;
        });
      }

      print('=== DELIVERY PHOTO DEBUG: Process completed ===');
    } catch (e) {
      _showError('Error: ${e.toString()}');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWarning(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
