import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/constants.dart';
import '../../services/pod_services.dart';

typedef DeliveryCameraPicker = Future<XFile?> Function();
typedef DeliveryLocationProvider = Future<DeliveryCoordinates> Function();
typedef DeliveryPodUploader = Future<Map<String, dynamic>> Function({
  required int orderId,
  required int orderShopId,
  required List<String> imagePaths,
  required double latitude,
  required double longitude,
  required String remarks,
  required String status,
});

class DeliveryCoordinates {
  const DeliveryCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class RiderConfirmDeliveryScreen extends StatefulWidget {
  const RiderConfirmDeliveryScreen({
    super.key,
    required this.order,
    this.cameraPicker,
    this.locationProvider,
    this.podUploader,
  });

  final Map<String, dynamic> order;
  final DeliveryCameraPicker? cameraPicker;
  final DeliveryLocationProvider? locationProvider;
  final DeliveryPodUploader? podUploader;

  @override
  State<RiderConfirmDeliveryScreen> createState() =>
      _RiderConfirmDeliveryScreenState();
}

class _RiderConfirmDeliveryScreenState
    extends State<RiderConfirmDeliveryScreen> {
  static const int _maximumPhotoCount = 5;
  static const List<String> _deliveryRemarks = <String>[
    'Delivered and received by the customer',
    'Delivered to the designated drop-off area',
    // 'Delivery failed - second attempt required',
    // 'Delivery failed - return order to the store',
  ];

  final ImagePicker _imagePicker = ImagePicker();
  final PodService _podService = PodService();

  final List<XFile> _deliveryPhotos = <XFile>[];
  final Set<int> _uploadedOrderShopIds = <int>{};
  String _selectedRemark = _deliveryRemarks.first;
  bool _isOpeningCamera = false;
  bool _isSubmitting = false;
  int _uploadCurrent = 0;
  int _uploadTotal = 0;

  bool get _formLocked => _isSubmitting || _uploadedOrderShopIds.isNotEmpty;

  String get _orderCode {
    final raw = widget.order['order_code']?.toString().trim() ?? '';
    if (raw.isEmpty) return 'ORDER';
    return raw.startsWith('#') ? raw.substring(1) : raw;
  }

  String get _deliveryAddress {
    final raw = widget.order['delivery_address']?.toString().trim() ?? '';
    return raw.isEmpty ? 'Delivery address unavailable' : raw;
  }

  int? get _orderId {
    return _positiveInt(widget.order['order_id'] ?? widget.order['id']);
  }

  List<int>? get _orderShopIds {
    final rawShops = widget.order['active_order_shops'];
    if (rawShops is! List || rawShops.isEmpty) return null;

    final ids = <int>[];
    final seen = <int>{};
    for (final rawShop in rawShops) {
      if (rawShop is! Map) return null;
      final id = _positiveInt(rawShop['order_shop_id']);
      if (id == null) return null;
      if (seen.add(id)) ids.add(id);
    }
    return ids.isEmpty ? null : ids;
  }

  int? _positiveInt(dynamic value) {
    final parsed =
        value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  Future<void> _takeDeliveryPhoto({int? replaceIndex}) async {
    if (_isOpeningCamera || _formLocked) return;
    if (replaceIndex == null && _deliveryPhotos.length >= _maximumPhotoCount) {
      return;
    }
    setState(() => _isOpeningCamera = true);

    try {
      final photo = widget.cameraPicker != null
          ? await widget.cameraPicker!()
          : await _imagePicker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
            );
      if (!mounted || photo == null) return;
      setState(() {
        if (replaceIndex != null &&
            replaceIndex >= 0 &&
            replaceIndex < _deliveryPhotos.length) {
          _deliveryPhotos[replaceIndex] = photo;
        } else if (_deliveryPhotos.length < _maximumPhotoCount) {
          _deliveryPhotos.add(photo);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the camera. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningCamera = false);
    }
  }

  Future<DeliveryCoordinates> _getCurrentLocation() async {
    final injectedProvider = widget.locationProvider;
    if (injectedProvider != null) return injectedProvider();

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception(
        'Turn on location services before completing the delivery.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it in app settings.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission is required to complete the delivery.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return DeliveryCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<Map<String, dynamic>> _uploadPod({
    required int orderId,
    required int orderShopId,
    required List<String> imagePaths,
    required DeliveryCoordinates location,
  }) {
    final injectedUploader = widget.podUploader;
    if (injectedUploader != null) {
      return injectedUploader(
        orderId: orderId,
        orderShopId: orderShopId,
        imagePaths: imagePaths,
        latitude: location.latitude,
        longitude: location.longitude,
        remarks: _selectedRemark,
        status: 'delivered',
      );
    }
    return _podService.uploadOrderShopPod(
      orderId: orderId,
      orderShopId: orderShopId,
      imagePaths: imagePaths,
      latitude: location.latitude,
      longitude: location.longitude,
      remarks: _selectedRemark,
      status: 'delivered',
    );
  }

  Future<void> _completeDelivery() async {
    if (_isSubmitting) return;

    final orderId = _orderId;
    if (orderId == null) {
      _showMessage('This order has an invalid or missing order ID.');
      return;
    }
    final orderShopIds = _orderShopIds;
    if (orderShopIds == null) {
      _showMessage('This order has invalid or missing order-shop details.');
      return;
    }
    if (_deliveryPhotos.isEmpty) {
      _showMessage('Add at least one proof-of-delivery photo.');
      return;
    }

    final remainingOrderShopIds = orderShopIds
        .where((id) => !_uploadedOrderShopIds.contains(id))
        .toList();
    if (remainingOrderShopIds.isEmpty) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadTotal = orderShopIds.length;
      _uploadCurrent = _uploadedOrderShopIds.length + 1;
    });

    try {
      final location = await _getCurrentLocation();
      final imagePaths = _deliveryPhotos.map((photo) => photo.path).toList();

      for (final orderShopId in remainingOrderShopIds) {
        if (!mounted) return;
        setState(() => _uploadCurrent = _uploadedOrderShopIds.length + 1);
        final result = await _uploadPod(
          orderId: orderId,
          orderShopId: orderShopId,
          imagePaths: imagePaths,
          location: location,
        );
        if (!mounted) return;

        if (result['success'] != true) {
          final message = result['message']?.toString().trim();
          _showMessage(
            message?.isNotEmpty == true ? message! : 'Failed to upload POD.',
          );
          return;
        }
        setState(() => _uploadedOrderShopIds.add(orderShopId));
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _uploadCurrent = 0;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        key: const ValueKey('confirm-delivery-screen'),
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5F5),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            key: const ValueKey('confirm-delivery-back'),
            onPressed: _isSubmitting ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.chevron_left, color: Color(0xFF777777)),
          ),
          titleSpacing: 0,
          title: const Text(
            'Confirm Delivery',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: const ValueKey('confirm-delivery-order-card'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E2E2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _orderCode,
                            key: const ValueKey('confirm-delivery-order-code'),
                            style: const TextStyle(
                              color: AppColors.primaryGreenLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _deliveryAddress,
                            key: const ValueKey('confirm-delivery-address'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF222222),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PROOF OF DELIVERY',
                      style: TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPhotoPicker(),
                    const SizedBox(height: 16),
                    const Text(
                      'NOTES',
                      style: TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('confirm-delivery-notes'),
                      value: _selectedRemark,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF777777),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 11,
                      ),
                      items: _deliveryRemarks
                          .map(
                            (remark) => DropdownMenuItem<String>(
                              value: remark,
                              child: Text(
                                remark,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _formLocked
                          ? null
                          : (remark) {
                              if (remark == null) return;
                              setState(() => _selectedRemark = remark);
                            },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFFD7D7D7)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFFD7D7D7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGreenLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        key: const ValueKey('confirm-delivery-complete'),
                        onPressed: _isSubmitting ? null : _completeDelivery,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primaryGreenLight,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Complete Delivery',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSubmitting)
                Positioned.fill(
                  child: ColoredBox(
                    key: const ValueKey('confirm-delivery-upload-overlay'),
                    color: const Color(0x66000000),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Uploading $_uploadCurrent of $_uploadTotal',
                              key: const ValueKey(
                                'confirm-delivery-upload-progress',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF222222),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    if (_deliveryPhotos.isEmpty) {
      return GestureDetector(
        key: const ValueKey('confirm-delivery-photo-picker'),
        onTap: _takeDeliveryPhoto,
        child: CustomPaint(
          painter: const _DashedRoundedBorderPainter(
            color: Color(0xFFD5D5D5),
            radius: 7,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 88,
            child: _buildPhotoPlaceholder(),
          ),
        ),
      );
    }

    final canAddPhoto = _deliveryPhotos.length < _maximumPhotoCount;
    final itemCount = _deliveryPhotos.length + (canAddPhoto ? 1 : 0);

    return CustomPaint(
      key: const ValueKey('confirm-delivery-photo-picker'),
      painter: const _DashedRoundedBorderPainter(
        color: Color(0xFFD5D5D5),
        radius: 7,
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Delivery photos at drop off location',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${_deliveryPhotos.length}/$_maximumPhotoCount',
                  key: const ValueKey('confirm-delivery-photo-count'),
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index == _deliveryPhotos.length) {
                  return _buildAddPhotoTile();
                }
                return _buildPhotoPreview(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    if (_isOpeningCamera) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt_outlined, size: 22, color: Color(0xFF858585)),
        SizedBox(height: 7),
        Text(
          'Delivery photo at drop off location',
          style: TextStyle(color: Color(0xFF555555), fontSize: 10),
        ),
        SizedBox(height: 2),
        Text(
          'Tap to take a photo',
          style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildAddPhotoTile() {
    return Material(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: const ValueKey('confirm-delivery-add-photo'),
        onTap: _isOpeningCamera || _formLocked ? null : _takeDeliveryPhoto,
        borderRadius: BorderRadius.circular(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD7D7D7)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: _isOpeningCamera
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        color: AppColors.primaryGreenLight,
                        size: 25,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Add Photo',
                        style: TextStyle(
                          color: AppColors.primaryGreenLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(int index) {
    return Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: const Color(0xFFEAEAEA),
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('confirm-delivery-change-photo-$index'),
              onTap: _isOpeningCamera || _formLocked
                  ? null
                  : () => _takeDeliveryPhoto(replaceIndex: index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(_deliveryPhotos[index].path),
                    key: ValueKey('confirm-delivery-photo-preview-$index'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFEAEAEA),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: Color(0x99000000),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Change Photo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            key: ValueKey('confirm-delivery-remove-photo-$index'),
            tooltip: 'Remove photo ${index + 1}',
            onPressed: _formLocked
                ? null
                : () => setState(() => _deliveryPhotos.removeAt(index)),
            constraints: const BoxConstraints.tightFor(width: 22, height: 22),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xB3000000),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    const dashLength = 5.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
