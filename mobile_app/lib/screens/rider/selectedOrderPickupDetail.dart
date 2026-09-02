import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/constants.dart';
import '../../provider/order_status_provider.dart';
import '../../services/directions_service.dart';
import '../../services/order_service.dart';
import '../../utils/media_url.dart';
import '../../utils/status_utils.dart';
import 'riderConfirmDeliveryScreen.dart';

class PickupProgress {
  const PickupProgress({
    required this.totalShops,
    required this.pickedUpCount,
    required this.pickedUpComplete,
    required this.inTransitActive,
    required this.delivered,
  });

  factory PickupProgress.fromOrder(Map<String, dynamic> order) {
    final shops = extractActiveOrderShops(order);
    final statuses = shops
        .map((shop) => normalizeOrderStatus(
              shop['order_status_description']?.toString() ?? '',
            ))
        .toList();
    final pickedUpCount = statuses.where(_hasReachedPickup).length;
    final allInTransit = statuses.isNotEmpty &&
        statuses
            .every((status) => status == 'in transit' || status == 'delivered');
    final allDelivered = statuses.isNotEmpty &&
        statuses.every((status) => status == 'delivered');

    return PickupProgress(
      totalShops: shops.length,
      pickedUpCount: pickedUpCount,
      pickedUpComplete: allInTransit,
      inTransitActive: allInTransit && !allDelivered,
      delivered: allDelivered,
    );
  }

  final int totalShops;
  final int pickedUpCount;
  final bool pickedUpComplete;
  final bool inTransitActive;
  final bool delivered;

  String get pickupLabel =>
      pickedUpComplete ? 'Picked Up' : '$pickedUpCount/$totalShops';

  static bool _hasReachedPickup(String status) {
    return status == 'picked up' ||
        status == 'in transit' ||
        status == 'delivered';
  }
}

List<Map<String, dynamic>> extractActiveOrderShops(
  Map<String, dynamic> order,
) {
  final rawShops = order['active_order_shops'];
  if (rawShops is! List) return <Map<String, dynamic>>[];

  return rawShops
      .whereType<Map>()
      .map((shop) => Map<String, dynamic>.from(shop))
      .toList();
}

bool isPendingPickupShop(Map<String, dynamic> shop) {
  return isReadyForDeliveryStatus(
    shop['order_status_description']?.toString() ?? '',
  );
}

List<Map<String, dynamic>> extractPendingPickupShops(
  Map<String, dynamic> order,
) {
  return extractActiveOrderShops(order).where(isPendingPickupShop).toList();
}

Map<String, dynamic> markActiveOrderShopInTransit(
  Map<String, dynamic> order,
  int shopId,
) {
  final updatedOrder = Map<String, dynamic>.from(order);
  final rawShops = order['active_order_shops'];
  if (rawShops is! List) return updatedOrder;

  updatedOrder['active_order_shops'] = rawShops.map((rawShop) {
    if (rawShop is! Map) return rawShop;
    final shop = Map<String, dynamic>.from(rawShop);
    final currentShopId = shop['shop_id'] is num
        ? (shop['shop_id'] as num).toInt()
        : int.tryParse(shop['shop_id']?.toString() ?? '');
    if (currentShopId == shopId) {
      shop['order_status_description'] = 'In-Transit';
    }
    return shop;
  }).toList();
  return updatedOrder;
}

LatLng? extractDropOffLocation(Map<String, dynamic> order) {
  final rawCoordinates = order['drop_off_coordinates'];
  if (rawCoordinates is! Map) return null;

  final rawLatitude = rawCoordinates['latitude'];
  final rawLongitude = rawCoordinates['longitude'];
  final latitude = rawLatitude is num
      ? rawLatitude.toDouble()
      : double.tryParse(rawLatitude?.toString() ?? '');
  final longitude = rawLongitude is num
      ? rawLongitude.toDouble()
      : double.tryParse(rawLongitude?.toString() ?? '');
  if (latitude == null || longitude == null) return null;
  if (latitude < -90 || latitude > 90) return null;
  if (longitude < -180 || longitude > 180) return null;
  return LatLng(latitude, longitude);
}

class PickupProgressBar extends StatelessWidget {
  const PickupProgressBar({super.key, required this.progress});

  final PickupProgress progress;

  static const _green = Color(0xFF28A66A);
  static const _inactive = Color(0xFFBDBDBD);

  @override
  Widget build(BuildContext context) {
    final steps = <_PickupStepData>[
      const _PickupStepData(
        keyName: 'accepted',
        label: 'Accepted',
        number: 1,
        state: _PickupStepState.complete,
      ),
      _PickupStepData(
        keyName: 'picked-up',
        label: progress.pickupLabel,
        number: 2,
        state: progress.pickedUpComplete
            ? _PickupStepState.complete
            : _PickupStepState.current,
      ),
      _PickupStepData(
        keyName: 'in-transit',
        label: 'In Transit',
        number: 3,
        state: progress.inTransitActive || progress.delivered
            ? _PickupStepState.complete
            : _PickupStepState.inactive,
      ),
      _PickupStepData(
        keyName: 'delivered',
        label: 'Delivered',
        number: 4,
        state: progress.delivered
            ? _PickupStepState.complete
            : _PickupStepState.inactive,
      ),
    ];

    return Container(
      key: const ValueKey('pickup-progress-bar'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            Expanded(child: _PickupStep(data: steps[index])),
            if (index < steps.length - 1)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  height: 1,
                  color: _connectorComplete(index, progress)
                      ? _green
                      : const Color(0xFFD7D7D7),
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool _connectorComplete(int index, PickupProgress value) {
    if (index == 0) return true;
    if (index == 1) return value.pickedUpComplete;
    return value.delivered;
  }
}

enum _PickupStepState { complete, current, inactive }

class _PickupStepData {
  const _PickupStepData({
    required this.keyName,
    required this.label,
    required this.number,
    required this.state,
  });

  final String keyName;
  final String label;
  final int number;
  final _PickupStepState state;
}

class _PickupStep extends StatelessWidget {
  const _PickupStep({required this.data});

  final _PickupStepData data;

  @override
  Widget build(BuildContext context) {
    final isComplete = data.state == _PickupStepState.complete;
    final isCurrent = data.state == _PickupStepState.current;
    final color = isComplete || isCurrent
        ? PickupProgressBar._green
        : PickupProgressBar._inactive;

    return Column(
      key: ValueKey('pickup-step-${data.keyName}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: ValueKey(
            'pickup-step-${data.keyName}-${isComplete ? 'check' : 'number'}',
          ),
          width: 21,
          height: 21,
          decoration: BoxDecoration(
            color: isComplete ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
          alignment: Alignment.center,
          child: isComplete
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${data.number}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            data.label,
            key: ValueKey('pickup-step-${data.keyName}-label'),
            maxLines: 1,
            style: TextStyle(
              color: isComplete || isCurrent
                  ? const Color(0xFF4B4B4B)
                  : const Color(0xFF8D8D8D),
              fontSize: 9,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class SelectedOrderPickupDetailScreen extends StatefulWidget {
  const SelectedOrderPickupDetailScreen({
    super.key,
    required this.order,
    this.pickupOnly = false,
    this.initialShopId,
    this.orderService,
  });

  final Map<String, dynamic> order;
  final bool pickupOnly;
  final int? initialShopId;
  final OrderService? orderService;

  @override
  State<SelectedOrderPickupDetailScreen> createState() =>
      _SelectedOrderPickupDetailScreenState();
}

class _SelectedOrderPickupDetailScreenState
    extends State<SelectedOrderPickupDetailScreen> {
  static const LatLng _defaultCenter = LatLng(7.3775, 125.8199);

  bool get _showIssueButton => false;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  DirectionsRoute? _route;
  bool _locationEnabled = false;
  bool _routeRequested = false;
  bool _routeLoading = false;
  int? _selectedShopIndex;
  int? _updatingShopId;
  bool _initialShopFocused = false;
  late Map<String, dynamic> _order;
  late final OrderService _orderService;

  List<Map<String, dynamic>> get _shops => extractActiveOrderShops(_order);

  List<Map<String, dynamic>> get _pendingShops =>
      extractPendingPickupShops(_order);

  PickupProgress get _progress => PickupProgress.fromOrder(_order);

  bool get _isDeliveryMode => !widget.pickupOnly && _progress.inTransitActive;

  LatLng? get _dropOffLocation => extractDropOffLocation(_order);

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    _order = Map<String, dynamic>.from(widget.order);
    _initializeLocation();
    _loadLatestOrder();
  }

  Future<void> _loadLatestOrder() async {
    final orderId = _asInt(_order['order_id'] ?? _order['id']);
    if (orderId <= 0) return;

    try {
      final latestOrder =
          await _orderService.fetchActiveDeliveryByOrderId(orderId);
      if (!mounted) return;
      _replaceOrder(latestOrder);
    } catch (_) {
      // Keep displaying the order passed by the dashboard when refresh fails.
    }
  }

  Future<void> _initializeLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      if (!mounted) return;
      setState(() => _locationEnabled = true);

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (!mounted) return;
        setState(() => _currentPosition = position);
        _tryLoadRoute();
      } catch (_) {
        // Shop markers remain usable when the current position is unavailable.
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (!mounted) return;
        setState(() => _currentPosition = position);
        _tryLoadRoute();
      }, onError: (_) {
        // Keep the last known position and shop markers on stream errors.
      });
    } catch (_) {
      // Location failures are non-blocking for the order detail view.
    }
  }

  List<LatLng> get _shopLocations {
    final locations = <LatLng>[];
    for (final shopEntry in _pendingShops) {
      final shop = _shopData(shopEntry);
      final latitude = _asDouble(shop['shop_lat']);
      final longitude = _asDouble(shop['shop_long']);
      if (latitude != null && longitude != null) {
        locations.add(LatLng(latitude, longitude));
      }
    }
    return locations;
  }

  List<LatLng> get _routeTargets {
    if (_isDeliveryMode) {
      final dropOff = _dropOffLocation;
      return dropOff == null ? <LatLng>[] : <LatLng>[dropOff];
    }
    return _shopLocations;
  }

  Set<Marker> get _markers {
    if (_isDeliveryMode) {
      final dropOff = _dropOffLocation;
      if (dropOff == null) return <Marker>{};
      return {
        Marker(
          markerId: const MarkerId('selected-order-drop-off'),
          position: dropOff,
          infoWindow: InfoWindow(
            title: _textOrFallback(_order['recipient_name'], 'Customer'),
            snippet: _textOrFallback(
              _order['delivery_address'],
              'Delivery address unavailable',
            ),
          ),
        ),
      };
    }

    final markers = <Marker>{};
    for (var index = 0; index < _shops.length; index++) {
      final entry = _shops[index];
      if (!isPendingPickupShop(entry)) continue;
      final shop = _shopData(entry);
      final latitude = _asDouble(shop['shop_lat']);
      final longitude = _asDouble(shop['shop_long']);
      if (latitude == null || longitude == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(
            entry['order_shop_id']?.toString() ??
                entry['shop_id']?.toString() ??
                'pickup-$index',
          ),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(
            title: _textOrFallback(shop['shop_name'], 'Pickup shop'),
            snippet:
                _textOrFallback(shop['shop_address'], 'Address unavailable'),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          onTap: () => _focusShop(index),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> get _polylines {
    final route = _route;
    if (route == null) return <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('selected-order-route'),
        points: route.polylinePoints,
        color: const Color(0xFF1268E8),
        width: 5,
      ),
    };
  }

  Future<void> _tryLoadRoute() async {
    if (_routeRequested || _routeLoading) return;
    final controller = _mapController;
    final position = _currentPosition;
    final locations = _routeTargets;
    if (controller == null || position == null || locations.isEmpty) return;

    _routeRequested = true;
    if (mounted) setState(() => _routeLoading = true);
    final route = await DirectionsService.getDeliveryRoute(
      riderLocation: LatLng(position.latitude, position.longitude),
      dropOffLocations: locations,
      optimizeRoute: true,
    );
    if (!mounted) return;

    setState(() {
      _route = route;
      _routeLoading = false;
    });
    if (route != null) {
      await _animateToBounds(route.bounds);
    }
  }

  Future<void> _animateToBounds(LatLngBounds bounds) async {
    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 52),
      );
    } catch (_) {
      // The map can reject bounds while its platform view is still laying out.
    }
  }

  Future<void> _showOverview() async {
    final route = _route;
    if (route != null) {
      await _animateToBounds(route.bounds);
      return;
    }

    final targets = _routeTargets;
    if (targets.isEmpty) {
      _showMessage(
        _isDeliveryMode
            ? 'The drop-off location is unavailable.'
            : 'No pickup locations are available.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final points = <LatLng>[
      ...targets,
      if (_currentPosition != null)
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
    ];
    if (points.length == 1) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    await _animateToBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
    );
  }

  Future<void> _focusShop(int index) async {
    if (index < 0 || index >= _shops.length) return;
    final shop = _shopData(_shops[index]);
    final latitude = _asDouble(shop['shop_lat']);
    final longitude = _asDouble(shop['shop_long']);
    if (latitude == null || longitude == null) {
      _showMessage('This shop location is unavailable.');
      return;
    }

    setState(() => _selectedShopIndex = index);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 16),
    );
    if (_sheetController.isAttached) {
      await _sheetController.animateTo(
        0.28,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _focusInitialShopIfNeeded() async {
    if (_initialShopFocused || widget.initialShopId == null) return;
    final index = _shops.indexWhere((entry) {
      final shop = _shopData(entry);
      return _asInt(entry['shop_id'] ?? shop['id']) == widget.initialShopId;
    });
    _initialShopFocused = true;
    if (index >= 0 && isPendingPickupShop(_shops[index])) {
      await _focusShop(index);
    }
  }

  void _showItems(Map<String, dynamic> shopEntry) {
    final items = _shopItems(shopEntry);
    final shop = _shopData(shopEntry);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.68,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _textOrFallback(shop['shop_name'], 'Pickup items'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No item details available.')),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final nestedItem = item['item'] is Map
                            ? Map<String, dynamic>.from(item['item'] as Map)
                            : <String, dynamic>{};
                        final name = _textOrFallback(
                          item['item_name_at_purchase'] ??
                              nestedItem['item_name'],
                          'Item',
                        );
                        final quantity = _asInt(item['quantity']);
                        final imageUrl = resolveItemImageUrl(
                          nestedItem['item_images'] ??
                              item['item_images'] ??
                              nestedItem['item_image'] ??
                              item['item_image'],
                        );
                        final measurement = _itemMeasurement(item, nestedItem);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildItemImage(imageUrl, index),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF202031),
                                        fontSize: 15,
                                        height: 1.05,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (measurement.isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        measurement,
                                        style: const TextStyle(
                                          color: Color(0xFF92929D),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'x$quantity',
                                key: ValueKey('pickup-item-$index-quantity'),
                                style: const TextStyle(
                                  color: Color(0xFF92929D),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage(String? imageUrl, int index) {
    Widget placeholder() => Container(
          color: const Color(0xFFF0F0F0),
          alignment: Alignment.center,
          child: const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFFAAAAAA),
            size: 28,
          ),
        );

    return ClipRRect(
      key: ValueKey('pickup-item-$index-image'),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 76,
        height: 76,
        child: imageUrl == null
            ? placeholder()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder(),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(
                        color: const Color(0xFFF0F0F0),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
      ),
    );
  }

  String _itemMeasurement(
    Map<String, dynamic> item,
    Map<String, dynamic> nestedItem,
  ) {
    final rawWeight = nestedItem['weight'] ?? item['weight'];
    final metric =
        (nestedItem['metric'] ?? item['metric'])?.toString().trim() ?? '';
    if (rawWeight == null && metric.isEmpty) return '';

    final parsedWeight = _asDouble(rawWeight);
    final weight = parsedWeight == null
        ? rawWeight?.toString().trim() ?? ''
        : parsedWeight == parsedWeight.roundToDouble()
            ? parsedWeight.toStringAsFixed(0)
            : parsedWeight.toString();
    return '$weight$metric';
  }

  Future<bool?> _showPickupConfirmation() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        key: const ValueKey('confirm-pickup-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm Pickup',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Are you sure you want to confirm the\npickup of this order?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        key: const ValueKey('confirm-pickup-yes'),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primaryGreenLight,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Yes'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        key: const ValueKey('confirm-pickup-no'),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreenLight,
                          side: const BorderSide(
                            color: AppColors.primaryGreenLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('No'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _replaceOrder(Map<String, dynamic> nextOrder) {
    final wasDeliveryMode = _isDeliveryMode;
    final previousDropOff = _dropOffLocation;
    final previousPickupTargets = _pickupTargetSignature(_order);
    final willBeDeliveryMode = !widget.pickupOnly &&
        PickupProgress.fromOrder(nextOrder).inTransitActive;
    final nextDropOff = extractDropOffLocation(nextOrder);
    final nextPickupTargets = _pickupTargetSignature(nextOrder);
    final deliveryTargetChanged = willBeDeliveryMode &&
        (previousDropOff?.latitude != nextDropOff?.latitude ||
            previousDropOff?.longitude != nextDropOff?.longitude);
    setState(() {
      _order = Map<String, dynamic>.from(nextOrder);
      if (wasDeliveryMode != willBeDeliveryMode ||
          deliveryTargetChanged ||
          previousPickupTargets != nextPickupTargets) {
        _route = null;
        _routeRequested = false;
        _routeLoading = false;
        _selectedShopIndex = null;
      }
    });

    if (willBeDeliveryMode && (!wasDeliveryMode || deliveryTargetChanged)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_sheetController.isAttached) {
          unawaited(
            _sheetController.animateTo(
              0.48,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
          );
        }
        _tryLoadRoute();
      });
    }
  }

  String _pickupTargetSignature(Map<String, dynamic> order) {
    return extractPendingPickupShops(order).map((entry) {
      final shop = _shopData(entry);
      return '${entry['order_shop_id'] ?? ''}:'
          '${entry['shop_id'] ?? shop['id'] ?? ''}:'
          '${shop['shop_lat'] ?? ''}:${shop['shop_long'] ?? ''}';
    }).join('|');
  }

  Future<void> _confirmPickup(Map<String, dynamic> shopEntry) async {
    if (_updatingShopId != null) return;

    final confirmed = await _showPickupConfirmation();
    if (!mounted || confirmed != true) return;

    final orderId = _asInt(_order['order_id'] ?? _order['id']);
    final shop = _shopData(shopEntry);
    final shopId = _asInt(shopEntry['shop_id'] ?? shop['id']);
    if (orderId <= 0) {
      _showMessage('Invalid order ID.', backgroundColor: AppColors.error);
      return;
    }
    if (shopId <= 0) {
      _showMessage('Invalid shop ID.', backgroundColor: AppColors.error);
      return;
    }

    int? inTransitStatusId;
    try {
      final statusProvider =
          Provider.of<OrderStatusProvider>(context, listen: false);
      inTransitStatusId =
          statusProvider.getOrderStatusIdByDescription('in-transit') ??
              statusProvider.getOrderStatusIdByDescription('in transit');
    } catch (_) {
      inTransitStatusId = null;
    }
    if (inTransitStatusId == null) {
      _showMessage(
        'Unable to find "In Transit" status. Please try again.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    setState(() => _updatingShopId = shopId);
    _showPickupLoading();

    final result = await _orderService.updateShopOrderStatus(
      orderId: orderId,
      shopId: shopId,
      statusId: inTransitStatusId,
      notes: 'Order picked up.',
    );
    if (!mounted) return;

    if (result['success'] != true) {
      _closePickupLoading();
      setState(() => _updatingShopId = null);
      _showMessage(
        result['message']?.toString() ?? 'Failed to confirm pickup.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    var refreshed = false;
    try {
      final refreshedOrder =
          await _orderService.fetchActiveDeliveryByOrderId(orderId);
      if (!mounted) return;
      _replaceOrder(refreshedOrder);
      refreshed = true;
    } catch (_) {
      if (!mounted) return;
      _replaceOrder(markActiveOrderShopInTransit(_order, shopId));
    }

    if (!mounted) return;
    _closePickupLoading();
    setState(() => _updatingShopId = null);
    if (widget.pickupOnly && _pendingShops.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    _showMessage(
      refreshed
          ? 'Order picked up successfully!'
          : 'Pickup confirmed, but the latest order details could not be loaded.',
      backgroundColor: refreshed ? AppColors.primaryGreen : AppColors.warning,
    );
  }

  void _showPickupLoading() {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Dialog(
            key: ValueKey('confirm-pickup-loading'),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  SizedBox(height: 16),
                  Text('Confirming pickup...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _closePickupLoading() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _contactShop(Map<String, dynamic> shopEntry) async {
    final contact = _shopContact(shopEntry);
    if (contact.isEmpty) {
      _showMessage('This shop does not have a contact number.');
      return;
    }

    try {
      final uri = Uri(scheme: 'tel', path: contact);
      if (await launchUrl(uri)) return;
      _showMessage('Unable to open the phone dialer.');
    } catch (_) {
      _showMessage('Unable to open the phone dialer.');
    }
  }

  Future<void> _contactRecipient() async {
    final contact = _order['recipient_contact_number']?.toString().trim() ?? '';
    if (contact.isEmpty) {
      _showMessage(
        'This customer does not have a contact number.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    try {
      final uri = Uri(scheme: 'tel', path: contact);
      if (await launchUrl(uri)) return;
      _showMessage('Unable to open the phone dialer.');
    } catch (_) {
      _showMessage('Unable to open the phone dialer.');
    }
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeTargets = _routeTargets;
    final firstLocation =
        routeTargets.isEmpty ? _defaultCenter : routeTargets.first;
    final orderCode = _textOrFallback(_order['order_code'], 'Order');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const ValueKey('selected-pickup-back'),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.chevron_left, color: Color(0xFF777777)),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              orderCode,
              key: const ValueKey('selected-pickup-order-code'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _formatOrderDate(_order['ordered_at']),
              style: const TextStyle(color: Color(0xFF555555), fontSize: 9),
            ),
          ],
        ),
        actions: [
          Container(
            key: const ValueKey('selected-pickup-overall-status'),
            margin: const EdgeInsets.only(right: 14, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0A000)),
            ),
            child: const Text(
              'In Progress',
              style: TextStyle(
                color: Color(0xFFF0A000),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            GoogleMap(
              key: const ValueKey('selected-pickup-map'),
              initialCameraPosition: CameraPosition(
                target: firstLocation,
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _tryLoadRoute();
                Future<void>.delayed(
                  const Duration(milliseconds: 350),
                  () async {
                    if (!mounted) return;
                    if (widget.initialShopId != null) {
                      await _focusInitialShopIfNeeded();
                    } else {
                      await _showOverview();
                    }
                  },
                );
              },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: _locationEnabled,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: PickupProgressBar(progress: _progress),
            ),
            Positioned(
              right: 16,
              bottom:
                  constraints.maxHeight * (_isDeliveryMode ? 0.48 : 0.38) + 10,
              child: ElevatedButton.icon(
                key: const ValueKey('selected-pickup-view-route'),
                onPressed: _showOverview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF555555),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                ),
                icon: _routeLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.near_me, size: 16),
                label: const Text('View', style: TextStyle(fontSize: 11)),
              ),
            ),
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _isDeliveryMode ? 0.48 : 0.38,
              minChildSize: _isDeliveryMode ? 0.36 : 0.28,
              maxChildSize: _isDeliveryMode ? 0.72 : 0.82,
              builder: (context, scrollController) => _isDeliveryMode
                  ? _buildDeliverySheet(scrollController)
                  : _buildPickupSheet(scrollController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupSheet(ScrollController scrollController) {
    final totalItems = _totalItems(_order, _shops);
    return Container(
      key: const ValueKey('selected-pickup-sheet'),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 4,
                  margin: const EdgeInsets.only(top: 9, bottom: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7D7D7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pickup Points (${_progress.pickedUpCount}/${_progress.totalShops})',
                          key: const ValueKey('selected-pickup-count'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '$totalItems ${totalItems == 1 ? 'item' : 'items'} total',
                        key: const ValueKey('selected-pickup-item-total'),
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (_shops.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No pickup shops available.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: _shops.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildShopCard(index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliverySheet(ScrollController scrollController) {
    final recipientName =
        _textOrFallback(_order['recipient_name'], 'Customer unavailable');
    final contact = _textOrFallback(
      _order['recipient_contact_number'],
      'Contact unavailable',
    );
    final address =
        _textOrFallback(_order['delivery_address'], 'Address unavailable');

    return Container(
      key: const ValueKey('selected-delivery-sheet'),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 4,
                  margin: const EdgeInsets.only(top: 9, bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7D7D7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      Container(
                        key: const ValueKey('selected-delivery-customer-card'),
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 13, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xFFE3E3E3)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 19,
                                  color: AppColors.primaryGreenLight,
                                ),
                                SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Items are collected - Ready for Delivery',
                                    key: ValueKey(
                                      'selected-delivery-ready-label',
                                    ),
                                    style: TextStyle(
                                      color: AppColors.primaryGreenLight,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            _deliveryDetailRow(
                              label: 'Customer',
                              value: recipientName,
                              key: const ValueKey(
                                'selected-delivery-customer-name',
                              ),
                            ),
                            const SizedBox(height: 9),
                            _deliveryDetailRow(
                              label: 'Contact',
                              value: contact,
                              key: const ValueKey(
                                'selected-delivery-contact-number',
                              ),
                            ),
                            const SizedBox(height: 9),
                            _deliveryDetailRow(
                              label: 'Drop off',
                              value: address,
                              key: const ValueKey(
                                'selected-delivery-drop-off-address',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 34,
                              child: OutlinedButton.icon(
                                key: const ValueKey(
                                  'selected-delivery-contact-button',
                                ),
                                onPressed: _contactRecipient,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF666666),
                                  side: const BorderSide(
                                    color: Color(0xFFE1E1E1),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                icon: const Icon(Icons.phone, size: 15),
                                label: const Text(
                                  'Contact',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton(
                          key: const ValueKey(
                            'selected-delivery-confirm-button',
                          ),
                          onPressed: () async {
                            final completed = await Navigator.of(context).push(
                              MaterialPageRoute<bool>(
                                builder: (_) => RiderConfirmDeliveryScreen(
                                  order: _order,
                                ),
                              ),
                            );
                            if (!mounted || completed != true) return;
                            Navigator.of(context).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppColors.primaryGreenLight,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: const Text(
                            'Confirm Delivery',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveryDetailRow({
    required String label,
    required String value,
    required Key key,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            key: key,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShopCard(int index) {
    final entry = _shops[index];
    final shop = _shopData(entry);
    final status = _normalizedShopStatus(entry);
    final label = _shopStatusLabel(status);
    final color = _shopStatusColor(status);
    final isSelected = _selectedShopIndex == index;
    final isWaiting = label == 'Waiting';

    return Container(
      key: ValueKey('selected-pickup-shop-$index'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isSelected ? AppColors.primaryGreen : const Color(0xFFE3E3E3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _textOrFallback(shop['shop_name'], 'Pickup shop'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withOpacity(0.45)),
                ),
                child: Text(
                  label,
                  key: ValueKey('selected-pickup-shop-$index-status'),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Color(0xFF999999)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _textOrFallback(shop['shop_address'], 'Address unavailable'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _shopActionButton(
                  key: ValueKey('selected-pickup-shop-$index-items'),
                  icon: Icons.inventory_2_outlined,
                  label: 'Items',
                  onPressed: () => _showItems(entry),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _shopActionButton(
                  key: ValueKey('selected-pickup-shop-$index-contact'),
                  icon: Icons.phone,
                  label: 'Contact',
                  onPressed: () => _contactShop(entry),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _shopActionButton(
                  key: ValueKey('selected-pickup-shop-$index-map'),
                  icon: Icons.near_me,
                  label: 'Map',
                  onPressed: () => _focusShop(index),
                ),
              ),
            ],
          ),
          if (isWaiting) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      key: ValueKey(
                        'selected-pickup-shop-$index-confirm-pickup',
                      ),
                      onPressed: _updatingShopId == null
                          ? () => _confirmPickup(entry)
                          : null,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primaryGreenLight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'Confirm Pickup',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showIssueButton) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextButton.icon(
                        key: ValueKey('selected-pickup-shop-$index-issue'),
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: const Color(0xFFE53935),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        icon: const Icon(Icons.warning_amber_rounded, size: 16),
                        label: const Text(
                          'Issue',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _shopActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: const Color(0xFF555555),
          side: const BorderSide(color: Color(0xFFE1E1E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Map<String, dynamic> _shopData(Map<String, dynamic> entry) {
    final rawShop = entry['shop'];
    return rawShop is Map
        ? Map<String, dynamic>.from(rawShop)
        : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _shopItems(Map<String, dynamic> entry) {
    final rawItems = entry['items'];
    if (rawItems is! List) return <Map<String, dynamic>>[];
    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _shopContact(Map<String, dynamic> entry) {
    final shop = _shopData(entry);
    final direct = shop['contact_number']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;

    for (final item in _shopItems(entry)) {
      final nestedItem = item['item'];
      if (nestedItem is! Map) continue;
      final nestedShop = nestedItem['shop'];
      if (nestedShop is! Map) continue;
      final contact = nestedShop['contact_number']?.toString().trim() ?? '';
      if (contact.isNotEmpty) return contact;
    }
    return '';
  }

  String _normalizedShopStatus(Map<String, dynamic> entry) {
    return normalizeOrderStatus(
      entry['order_status_description']?.toString() ?? '',
    );
  }

  String _shopStatusLabel(String status) {
    switch (status) {
      case 'picked up':
        return 'Picked Up';
      case 'in transit':
        return 'Picked Up';
      case 'delivered':
        return 'Delivered';
      case 'ready for pickup':
      case 'ready for pick up':
      case 'ready for delivery':
      case '':
        return 'Waiting';
      default:
        return OrderStatusColors.formatStatus(status);
    }
  }

  Color _shopStatusColor(String status) {
    switch (status) {
      case 'picked up':
      case 'in transit':
      case 'delivered':
        return AppColors.primaryGreenLight;
      default:
        return const Color(0xFFF0A000);
    }
  }

  int _totalItems(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> shops,
  ) {
    final explicit = _asInt(order['item_count']);
    if (explicit > 0) return explicit;

    var total = 0;
    for (final shop in shops) {
      for (final item in _shopItems(shop)) {
        total += _asInt(item['quantity']);
      }
    }
    return total;
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _textOrFallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatOrderDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw.isEmpty ? 'Date unavailable' : raw;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final suffix = date.hour >= 12 ? 'pm' : 'am';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} • '
        '$hour:$minute$suffix';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    _sheetController.dispose();
    super.dispose();
  }
}
