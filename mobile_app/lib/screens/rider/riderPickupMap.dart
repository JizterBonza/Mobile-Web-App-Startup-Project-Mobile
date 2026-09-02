import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/constants.dart';
import '../../services/directions_service.dart';
import '../../services/order_service.dart';
import '../../widgets/active_deliveries_section.dart';
import 'selectedOrderPickupDetail.dart';

typedef PickupAlternativeRouteLoader = Future<List<DirectionsRoute>> Function({
  required LatLng origin,
  required LatLng destination,
});

class PickupMapPoint {
  const PickupMapPoint({
    required this.order,
    required this.shopEntry,
    required this.markerId,
    required this.position,
  });

  final Map<String, dynamic> order;
  final Map<String, dynamic> shopEntry;
  final String markerId;
  final LatLng position;

  Map<String, dynamic> get shop {
    final rawShop = shopEntry['shop'];
    return rawShop is Map
        ? Map<String, dynamic>.from(rawShop)
        : <String, dynamic>{};
  }

  int? get shopId {
    final value = shopEntry['shop_id'] ?? shop['id'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String get shopName => _textOrFallback(shop['shop_name'], 'Pickup shop');

  String get shopAddress =>
      _textOrFallback(shop['shop_address'], 'Address unavailable');

  static String _textOrFallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

List<Map<String, dynamic>> extractPickupMapOrders(dynamic rawOrders) {
  if (rawOrders is! List) return <Map<String, dynamic>>[];
  return rawOrders
      .whereType<Map>()
      .map((order) => Map<String, dynamic>.from(order))
      .where((order) => extractPendingPickupShops(order).isNotEmpty)
      .toList();
}

List<PickupMapPoint> extractPickupMapPoints(
  List<Map<String, dynamic>> orders,
) {
  final points = <PickupMapPoint>[];
  final markerIds = <String>{};

  for (var orderIndex = 0; orderIndex < orders.length; orderIndex++) {
    final order = orders[orderIndex];
    final pendingShops = extractPendingPickupShops(order);
    for (var shopIndex = 0; shopIndex < pendingShops.length; shopIndex++) {
      final entry = pendingShops[shopIndex];
      final rawShop = entry['shop'];
      if (rawShop is! Map) continue;
      final shop = Map<String, dynamic>.from(rawShop);
      final latitude = _coordinate(shop['shop_lat'], minimum: -90, maximum: 90);
      final longitude =
          _coordinate(shop['shop_long'], minimum: -180, maximum: 180);
      if (latitude == null || longitude == null) continue;

      final orderShopId = _positiveInt(entry['order_shop_id']);
      final orderId = _positiveInt(order['order_id'] ?? order['id']);
      final shopId = _positiveInt(entry['shop_id'] ?? shop['id']);
      var markerId = orderShopId != null
          ? 'pickup-order-shop-$orderShopId'
          : orderId != null && shopId != null
              ? 'pickup-order-$orderId-shop-$shopId'
              : 'pickup-fallback-$orderIndex-$shopIndex';
      if (!markerIds.add(markerId)) {
        markerId = '$markerId-$orderIndex-$shopIndex';
        markerIds.add(markerId);
      }

      points.add(
        PickupMapPoint(
          order: order,
          shopEntry: entry,
          markerId: markerId,
          position: LatLng(latitude, longitude),
        ),
      );
    }
  }

  return points;
}

PickupMapPoint? suggestNextPickupPoint(
  LatLng riderLocation,
  List<PickupMapPoint> points,
) {
  if (points.isEmpty) return null;
  var suggested = points.first;
  var shortestDistance = Geolocator.distanceBetween(
    riderLocation.latitude,
    riderLocation.longitude,
    suggested.position.latitude,
    suggested.position.longitude,
  );
  for (final point in points.skip(1)) {
    final distance = Geolocator.distanceBetween(
      riderLocation.latitude,
      riderLocation.longitude,
      point.position.latitude,
      point.position.longitude,
    );
    if (distance < shortestDistance) {
      suggested = point;
      shortestDistance = distance;
    }
  }
  return suggested;
}

double? _coordinate(
  dynamic value, {
  required double minimum,
  required double maximum,
}) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite) return null;
  if (parsed < minimum || parsed > maximum) return null;
  return parsed;
}

int? _positiveInt(dynamic value) {
  final parsed =
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

class RiderPickupMapScreen extends StatefulWidget {
  const RiderPickupMapScreen({
    super.key,
    this.order,
    this.orderService,
    this.initialRiderLocation,
    this.routeLoader,
  });

  final Map<String, dynamic>? order;
  final OrderService? orderService;
  final LatLng? initialRiderLocation;
  final PickupAlternativeRouteLoader? routeLoader;

  @override
  State<RiderPickupMapScreen> createState() => _RiderPickupMapScreenState();
}

class _RiderPickupMapScreenState extends State<RiderPickupMapScreen> {
  static const LatLng _defaultCenter = LatLng(7.3775, 125.8199);

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  late final OrderService _orderService;
  late final PickupAlternativeRouteLoader _routeLoader;

  List<Map<String, dynamic>> _pickupOrders = <Map<String, dynamic>>[];
  List<PickupMapPoint> _pickupPoints = <PickupMapPoint>[];
  LatLng? _currentPosition;
  List<DirectionsRoute> _routes = <DirectionsRoute>[];
  bool _locationEnabled = false;
  bool _isLoading = true;
  bool _isLoadingRoute = false;
  bool _showRoute = false;
  String? _routedPickupMarkerId;
  String? _error;
  int _requestId = 0;

  int get _pendingPickupCount => _pickupOrders.fold<int>(
        0,
        (total, order) => total + extractPendingPickupShops(order).length,
      );

  Set<Marker> get _markers => _pickupPoints.map((point) {
        return Marker(
          markerId: MarkerId(point.markerId),
          position: point.position,
          infoWindow: InfoWindow(
            title: point.shopName,
            snippet: point.shopAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          onTap: () => _openPickupDetail(
            point.order,
            initialShopId: point.shopId,
          ),
        );
      }).toSet();

  Set<Polyline> get _polylines {
    if (!_showRoute || _routes.isEmpty) return <Polyline>{};
    return <Polyline>{
      for (var index = _routes.length - 1; index >= 0; index--)
        Polyline(
          polylineId: PolylineId('pickup-route-$index'),
          points: _routes[index].polylinePoints,
          color: index == 0 ? const Color(0xFF1268E8) : const Color(0xFF8D949E),
          width: index == 0 ? 6 : 3,
          zIndex: index == 0 ? 2 : 1,
        ),
    };
  }

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    _routeLoader = widget.routeLoader ??
        ({required origin, required destination}) {
          return DirectionsService.getAlternativeDirections(
            origin: origin,
            destination: destination,
          );
        };
    _currentPosition = widget.initialRiderLocation;
    if (widget.order != null) return;
    _loadPickups();
    if (widget.initialRiderLocation == null) _initializeLocation();
  }

  Future<void> _loadPickups({bool preserveExisting = false}) async {
    final requestId = ++_requestId;
    final canPreserve = preserveExisting;
    if (mounted) {
      setState(() {
        _isLoading = !canPreserve;
        _error = null;
      });
    }

    try {
      final result = await _orderService.fetchActiveDeliveries();
      final orders = extractPickupMapOrders(result['orders']);
      final points = extractPickupMapPoints(orders);
      if (!mounted || requestId != _requestId) return;

      final previousSignature = _pointSignature(_pickupPoints);
      final nextSignature = _pointSignature(points);
      setState(() {
        _pickupOrders = orders;
        _pickupPoints = points;
        _isLoading = false;
        _error = null;
        if (previousSignature != nextSignature) {
          _routes = <DirectionsRoute>[];
          _routedPickupMarkerId = null;
        }
      });

      if (_currentPosition != null &&
          points.isNotEmpty &&
          (previousSignature != nextSignature || _routes.isEmpty)) {
        await _fetchRoute();
      } else if (_mapController != null) {
        await _fitAllPickups();
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      final message = _errorMessage(error);
      if (canPreserve) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
        _showMessage('Unable to refresh pickup points. $message');
        return;
      }
      setState(() {
        _pickupOrders = <Map<String, dynamic>>[];
        _pickupPoints = <PickupMapPoint>[];
        _routes = <DirectionsRoute>[];
        _routedPickupMarkerId = null;
        _isLoading = false;
        _error = message;
      });
    }
  }

  String _pointSignature(List<PickupMapPoint> points) => points
      .map(
        (point) =>
            '${point.markerId}:${point.position.latitude}:${point.position.longitude}',
      )
      .join('|');

  String _errorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Unable to load pickup orders.' : message;
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
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
        if (_pickupPoints.isNotEmpty) await _fetchRoute();
      } catch (_) {
        // Pickup markers remain usable without a current rider position.
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (!mounted) return;
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }, onError: (_) {
        // Keep the most recent location when live updates fail.
      });
    } catch (_) {
      // Location permission and service failures are non-blocking.
    }
  }

  Future<void> _openPickupDetail(
    Map<String, dynamic> order, {
    int? initialShopId,
  }) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SelectedOrderPickupDetailScreen(
          order: order,
          pickupOnly: true,
          initialShopId: initialShopId,
          orderService: _orderService,
        ),
      ),
    );
    if (!mounted) return;
    if (completed == true) _removeOrderLocally(order);
    await _loadPickups(preserveExisting: true);
    if (!mounted || completed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All pickup points completed.'),
        backgroundColor: AppColors.primaryGreenLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeOrderLocally(Map<String, dynamic> order) {
    final orderId = _positiveInt(order['order_id'] ?? order['id']);
    if (orderId == null) return;
    setState(() {
      _pickupOrders = _pickupOrders.where((candidate) {
        return _positiveInt(candidate['order_id'] ?? candidate['id']) !=
            orderId;
      }).toList();
      _pickupPoints = extractPickupMapPoints(_pickupOrders);
      _routes = <DirectionsRoute>[];
      _routedPickupMarkerId = null;
      _showRoute = false;
    });
  }

  Future<void> _fetchRoute() async {
    if (_isLoadingRoute) return;
    final position = _currentPosition;
    if (position == null) {
      _showMessage('Your current location is unavailable.');
      return;
    }
    if (_pickupPoints.isEmpty) {
      _showMessage('No pickup locations are available.');
      return;
    }

    setState(() => _isLoadingRoute = true);
    final riderLocation = position;
    final suggestedPickup = suggestNextPickupPoint(
      riderLocation,
      _pickupPoints,
    );
    if (suggestedPickup == null) {
      setState(() => _isLoadingRoute = false);
      _showMessage('No pickup locations are available.');
      return;
    }
    if (_showRoute &&
        _routes.isNotEmpty &&
        _routedPickupMarkerId == suggestedPickup.markerId) {
      setState(() => _isLoadingRoute = false);
      return;
    }

    List<DirectionsRoute> routes;
    try {
      routes = await _routeLoader(
        origin: riderLocation,
        destination: suggestedPickup.position,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routes = <DirectionsRoute>[];
        _routedPickupMarkerId = null;
        _showRoute = false;
        _isLoadingRoute = false;
      });
      _showMessage('Unable to load the pickup route.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _routedPickupMarkerId = routes.isEmpty ? null : suggestedPickup.markerId;
      _showRoute = routes.isNotEmpty;
      _isLoadingRoute = false;
    });
    if (routes.isEmpty) {
      _showMessage('Unable to load the pickup route.');
      return;
    }
    await _animateToBounds(routes.first.bounds);
  }

  void _toggleRoute() {
    if (_showRoute) {
      setState(() {
        _showRoute = false;
        _routes = <DirectionsRoute>[];
        _routedPickupMarkerId = null;
      });
      return;
    }
    _fetchRoute();
  }

  Future<void> _fitAllPickups() async {
    final controller = _mapController;
    if (controller == null) return;
    final points = _pickupPoints.map((point) => point.position).toList();
    if (points.isEmpty) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_defaultCenter, 12),
      );
      return;
    }
    if (points.length == 1) {
      await controller.animateCamera(
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

  Future<void> _animateToBounds(LatLngBounds bounds) async {
    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 52),
      );
    } catch (_) {
      // Google Maps can reject bounds while its platform view is laying out.
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Map<String, dynamic> _cardOrder(Map<String, dynamic> order) {
    return <String, dynamic>{
      ...order,
      'pickup_store_count': extractPendingPickupShops(order).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectedOrder = widget.order;
    if (selectedOrder != null) {
      return SelectedOrderPickupDetailScreen(
        order: selectedOrder,
        orderService: _orderService,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text(
          'Pickup Map',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF222222),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF666666)),
        actions: [
          IconButton(
            key: const ValueKey('pickup-map-refresh'),
            onPressed: _isLoading ? null : _loadPickups,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const ValueKey('pickup-map-fit-all'),
            onPressed: _pickupPoints.isEmpty ? null : _fitAllPickups,
            tooltip: 'Fit all',
            icon: const Icon(Icons.zoom_out_map),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const _PickupMapLoading()
          : _error != null
              ? _PickupMapError(error: _error!, onRetry: _loadPickups)
              : _buildMapBody(),
    );
  }

  Widget _buildMapBody() {
    final initialTarget =
        _pickupPoints.isEmpty ? _defaultCenter : _pickupPoints.first.position;
    return Stack(
      children: [
        GoogleMap(
          key: const ValueKey('all-pickups-map'),
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: _pickupPoints.isEmpty ? 12 : 13,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            Future<void>.delayed(
              const Duration(milliseconds: 350),
              () async {
                if (!mounted) return;
                if (_showRoute && _routes.isNotEmpty) {
                  await _animateToBounds(_routes.first.bounds);
                } else {
                  await _fitAllPickups();
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
          compassEnabled: true,
        ),
        Positioned(
          top: 12,
          left: 16,
          child: _PickupLegend(showRider: _locationEnabled),
        ),
        Positioned(
          top: 12,
          right: 16,
          child: ElevatedButton.icon(
            key: const ValueKey('pickup-map-route'),
            onPressed: _pickupPoints.isEmpty ? null : _toggleRoute,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF555555),
              elevation: 2,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: _isLoadingRoute
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _showRoute ? Icons.route_outlined : Icons.near_me,
                    size: 16,
                  ),
            label: Text(
              _showRoute ? 'Hide route' : 'Route',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.38,
          minChildSize: 0.18,
          maxChildSize: 0.86,
          builder: (context, scrollController) => _buildPickupSheet(
            scrollController,
          ),
        ),
      ],
    );
  }

  Widget _buildPickupSheet(ScrollController scrollController) {
    return Container(
      key: const ValueKey('all-pickups-sheet'),
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
                      const Expanded(
                        child: Text(
                          'For Pickup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        key: const ValueKey('pickup-map-count'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4D6),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xFFF2B84B)),
                        ),
                        child: Text(
                          '$_pendingPickupCount pickup '
                          '${_pendingPickupCount == 1 ? 'point' : 'points'}',
                          style: const TextStyle(
                            color: Color(0xFFF0A000),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (_pickupOrders.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _PickupMapEmpty(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: _pickupOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = _pickupOrders[index];
                  return GestureDetector(
                    key: ValueKey(
                      'pickup-map-order-${order['order_id'] ?? index}',
                    ),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openPickupDetail(order),
                    child: ActiveDeliveryCard(
                      order: _cardOrder(order),
                      fullWidth: true,
                      actionLabel: 'Continue Pickup',
                      onContinue: () => _openPickupDetail(order),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    _sheetController.dispose();
    super.dispose();
  }
}

class _PickupMapLoading extends StatelessWidget {
  const _PickupMapLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryGreenLight),
          SizedBox(height: 14),
          Text('Loading pickup points...'),
        ],
      ),
    );
  }
}

class _PickupMapError extends StatelessWidget {
  const _PickupMapError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Unable to load pickup points',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey('pickup-map-retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreenLight,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupMapEmpty extends StatelessWidget {
  const _PickupMapEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 42,
            color: Color(0xFFBDBDBD),
          ),
          SizedBox(height: 9),
          Text(
            'No pickups available',
            style: TextStyle(
              color: Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupLegend extends StatelessWidget {
  const _PickupLegend({required this.showRider});

  final bool showRider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LegendDot(color: Color(0xFFF0A000), label: 'For Pickup'),
          if (showRider) ...[
            const SizedBox(width: 10),
            const _LegendDot(color: Color(0xFF4285F4), label: 'You'),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
