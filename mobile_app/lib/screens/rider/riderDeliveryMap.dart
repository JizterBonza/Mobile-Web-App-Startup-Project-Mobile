import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/constants.dart';
import '../../services/directions_service.dart';
import '../../services/order_service.dart';
import '../../widgets/active_deliveries_section.dart';
import 'selectedOrderPickupDetail.dart';

const Color _deliveryBlue = Color(0xFF1268E8);

typedef DeliveryMapRouteLoader = Future<DirectionsRoute?> Function({
  required LatLng riderLocation,
  required List<LatLng> dropOffLocations,
});

class DeliveryMapPoint {
  const DeliveryMapPoint({
    required this.order,
    required this.markerId,
    required this.position,
  });

  final Map<String, dynamic> order;
  final String markerId;
  final LatLng position;

  String get recipientName =>
      _textOrFallback(order['recipient_name'], 'Delivery customer');

  String get deliveryAddress =>
      _textOrFallback(order['delivery_address'], 'Address unavailable');
}

bool isOrderForDelivery(Map<String, dynamic> order) =>
    PickupProgress.fromOrder(order).inTransitActive;

List<Map<String, dynamic>> extractDeliveryMapOrders(dynamic rawOrders) {
  if (rawOrders is! List) return <Map<String, dynamic>>[];

  final orders = <Map<String, dynamic>>[];
  final seenIds = <String>{};
  for (var index = 0; index < rawOrders.length; index++) {
    final rawOrder = rawOrders[index];
    if (rawOrder is! Map) continue;
    final order = Map<String, dynamic>.from(rawOrder);
    if (!isOrderForDelivery(order)) continue;

    final orderId = _positiveInt(order['order_id'] ?? order['id']);
    final orderCode = order['order_code']?.toString().trim() ?? '';
    final identity = orderId != null
        ? 'id-$orderId'
        : orderCode.isNotEmpty
            ? 'code-$orderCode'
            : 'index-$index';
    if (seenIds.add(identity)) orders.add(order);
  }
  return orders;
}

List<DeliveryMapPoint> extractDeliveryMapPoints(
  List<Map<String, dynamic>> orders,
) {
  final points = <DeliveryMapPoint>[];
  final markerIds = <String>{};
  for (var index = 0; index < orders.length; index++) {
    final order = orders[index];
    final location = extractDropOffLocation(order);
    if (location == null) continue;

    final orderId = _positiveInt(order['order_id'] ?? order['id']);
    var markerId = orderId == null
        ? 'delivery-fallback-$index'
        : 'delivery-order-$orderId';
    if (!markerIds.add(markerId)) {
      markerId = '$markerId-$index';
      markerIds.add(markerId);
    }
    points.add(
      DeliveryMapPoint(
        order: order,
        markerId: markerId,
        position: location,
      ),
    );
  }
  return points;
}

int? _positiveInt(dynamic value) {
  final parsed =
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

String _textOrFallback(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

class RiderDeliveryMapScreen extends StatefulWidget {
  const RiderDeliveryMapScreen({
    super.key,
    this.orderService,
    this.initialRiderLocation,
    this.routeLoader,
  });

  final OrderService? orderService;
  final LatLng? initialRiderLocation;
  final DeliveryMapRouteLoader? routeLoader;

  @override
  State<RiderDeliveryMapScreen> createState() => _RiderDeliveryMapScreenState();
}

class _RiderDeliveryMapScreenState extends State<RiderDeliveryMapScreen> {
  static const LatLng _defaultCenter = LatLng(7.3775, 125.8199);

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  late final OrderService _orderService;
  late final DeliveryMapRouteLoader _routeLoader;

  List<Map<String, dynamic>> _deliveryOrders = <Map<String, dynamic>>[];
  List<DeliveryMapPoint> _deliveryPoints = <DeliveryMapPoint>[];
  LatLng? _currentPosition;
  DirectionsRoute? _route;
  String? _routedPointSignature;
  bool _locationEnabled = false;
  bool _isLoading = true;
  bool _isLoadingRoute = false;
  bool _showRoute = false;
  String? _error;
  int _requestId = 0;
  int _routeRequestId = 0;

  Set<Marker> get _markers => _deliveryPoints.map((point) {
        return Marker(
          markerId: MarkerId(point.markerId),
          position: point.position,
          infoWindow: InfoWindow(
            title: point.recipientName,
            snippet: point.deliveryAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
          onTap: () => _openDeliveryDetail(point.order),
        );
      }).toSet();

  Set<Polyline> get _polylines {
    final route = _route;
    if (!_showRoute || route == null) return <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('all-deliveries-route'),
        points: route.polylinePoints,
        color: _deliveryBlue,
        width: 6,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    _routeLoader = widget.routeLoader ??
        ({
          required LatLng riderLocation,
          required List<LatLng> dropOffLocations,
        }) {
          return DirectionsService.getDeliveryRoute(
            riderLocation: riderLocation,
            dropOffLocations: dropOffLocations,
            optimizeRoute: true,
          );
        };
    _currentPosition = widget.initialRiderLocation;
    _locationEnabled = widget.initialRiderLocation != null;
    _loadDeliveries();
    if (widget.initialRiderLocation == null) _initializeLocation();
  }

  Future<void> _loadDeliveries({bool preserveExisting = false}) async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _isLoading = !preserveExisting;
        _error = null;
      });
    }

    try {
      final result = await _orderService.fetchActiveDeliveries();
      final orders = extractDeliveryMapOrders(result['orders']);
      final points = extractDeliveryMapPoints(orders);
      if (!mounted || requestId != _requestId) return;

      final previousSignature = _pointSignature(_deliveryPoints);
      final nextSignature = _pointSignature(points);
      setState(() {
        _deliveryOrders = orders;
        _deliveryPoints = points;
        _isLoading = false;
        _error = null;
        if (previousSignature != nextSignature) {
          _routeRequestId++;
          _route = null;
          _routedPointSignature = null;
          _showRoute = false;
          _isLoadingRoute = false;
        }
      });

      if (_currentPosition != null &&
          points.isNotEmpty &&
          (previousSignature != nextSignature || _route == null)) {
        await _fetchDeliveryRoute();
      } else if (_mapController != null) {
        await _fitAllDeliveries();
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      final message = _errorMessage(error);
      if (preserveExisting) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
        _showMessage('Unable to refresh delivery points. $message');
        return;
      }
      setState(() {
        _deliveryOrders = <Map<String, dynamic>>[];
        _deliveryPoints = <DeliveryMapPoint>[];
        _route = null;
        _routedPointSignature = null;
        _showRoute = false;
        _isLoadingRoute = false;
        _isLoading = false;
        _error = message;
      });
    }
  }

  String _pointSignature(List<DeliveryMapPoint> points) => points
      .map(
        (point) =>
            '${point.markerId}:${point.position.latitude}:${point.position.longitude}',
      )
      .join('|');

  String _errorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Unable to load delivery orders.' : message;
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
        if (_deliveryPoints.isNotEmpty) await _fetchDeliveryRoute();
      } catch (_) {
        // Delivery markers remain usable without a rider position.
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
        // Keep the latest known position when stream updates fail.
      });
    } catch (_) {
      // Location permission and service failures do not block the map.
    }
  }

  Future<void> _openDeliveryDetail(Map<String, dynamic> order) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SelectedOrderPickupDetailScreen(
          order: order,
          orderService: _orderService,
        ),
      ),
    );
    if (!mounted) return;

    if (completed == true) {
      _removeOrderLocally(order);
      _showMessage(
        'Delivery completed successfully.',
        backgroundColor: AppColors.primaryGreen,
      );
    }
    await _loadDeliveries(preserveExisting: true);
  }

  void _removeOrderLocally(Map<String, dynamic> order) {
    final orderId = _positiveInt(order['order_id'] ?? order['id']);
    if (orderId == null) return;
    setState(() {
      _deliveryOrders = _deliveryOrders.where((candidate) {
        return _positiveInt(candidate['order_id'] ?? candidate['id']) !=
            orderId;
      }).toList();
      _deliveryPoints = extractDeliveryMapPoints(_deliveryOrders);
      _routeRequestId++;
      _route = null;
      _routedPointSignature = null;
      _showRoute = false;
      _isLoadingRoute = false;
    });
  }

  Future<void> _fetchDeliveryRoute() async {
    if (_isLoadingRoute) return;
    final position = _currentPosition;
    if (position == null) {
      _showMessage('Your current location is unavailable.');
      return;
    }
    if (_deliveryPoints.isEmpty) {
      _showMessage('No delivery locations are available.');
      return;
    }

    final signature = _pointSignature(_deliveryPoints);
    if (_showRoute && _route != null && _routedPointSignature == signature) {
      return;
    }

    final routeRequestId = ++_routeRequestId;
    setState(() => _isLoadingRoute = true);
    DirectionsRoute? route;
    try {
      route = await _routeLoader(
        riderLocation: position,
        dropOffLocations:
            _deliveryPoints.map((point) => point.position).toList(),
      );
    } catch (_) {
      route = null;
    }
    if (!mounted || routeRequestId != _routeRequestId) return;

    setState(() {
      _route = route;
      _routedPointSignature = route == null ? null : signature;
      _showRoute = route != null;
      _isLoadingRoute = false;
    });
    if (route == null) {
      _showMessage('Unable to load the delivery route.');
      return;
    }
    await _animateToBounds(route.bounds);
  }

  void _toggleRoute() {
    if (_showRoute) {
      setState(() => _showRoute = false);
      return;
    }
    if (_route != null) {
      setState(() => _showRoute = true);
      unawaited(_animateToBounds(_route!.bounds));
      return;
    }
    unawaited(_fetchDeliveryRoute());
  }

  Future<void> _fitAllDeliveries() async {
    if (_deliveryPoints.isEmpty) return;
    final points = _deliveryPoints.map((point) => point.position).toList();
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

  Future<void> _animateToBounds(LatLngBounds bounds) async {
    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 52),
      );
    } catch (_) {
      // Bounds can be rejected while the platform map is laying out.
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
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text(
          'Delivery Map',
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
            key: const ValueKey('delivery-map-refresh'),
            onPressed: _isLoading ? null : _loadDeliveries,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const ValueKey('delivery-map-fit-all'),
            onPressed: _deliveryPoints.isEmpty ? null : _fitAllDeliveries,
            tooltip: 'Fit all',
            icon: const Icon(Icons.zoom_out_map),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _DeliveryMapLoading();
    if (_error != null) {
      return _DeliveryMapError(
        message: _error!,
        onRetry: _loadDeliveries,
      );
    }
    return _buildMapBody();
  }

  Widget _buildMapBody() {
    final initialTarget = _deliveryPoints.isEmpty
        ? _defaultCenter
        : _deliveryPoints.first.position;
    return Stack(
      children: [
        GoogleMap(
          key: const ValueKey('all-deliveries-map'),
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: _deliveryPoints.isEmpty ? 12 : 13,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            Future<void>.delayed(
              const Duration(milliseconds: 350),
              () async {
                if (!mounted) return;
                if (_showRoute && _route != null) {
                  await _animateToBounds(_route!.bounds);
                } else {
                  await _fitAllDeliveries();
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
          child: _DeliveryLegend(showRider: _locationEnabled),
        ),
        Positioned(
          top: 12,
          right: 16,
          child: ElevatedButton.icon(
            key: const ValueKey('delivery-map-route'),
            onPressed: _deliveryPoints.isEmpty ? null : _toggleRoute,
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
          builder: (context, scrollController) =>
              _buildDeliverySheet(scrollController),
        ),
      ],
    );
  }

  Widget _buildDeliverySheet(ScrollController scrollController) {
    return Container(
      key: const ValueKey('delivery-map-sheet'),
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
                          'For Delivery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        key: const ValueKey('delivery-map-count'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xFF8CB8F5)),
                        ),
                        child: Text(
                          '${_deliveryOrders.length} '
                          '${_deliveryOrders.length == 1 ? 'delivery' : 'deliveries'}',
                          style: const TextStyle(
                            color: _deliveryBlue,
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
          if (_deliveryOrders.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _DeliveryMapEmpty(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: _deliveryOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = _deliveryOrders[index];
                  return GestureDetector(
                    key: ValueKey(
                      'delivery-map-order-${order['order_id'] ?? index}',
                    ),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openDeliveryDetail(order),
                    child: ActiveDeliveryCard(
                      order: order,
                      fullWidth: true,
                      statusLabel: 'In Transit',
                      onContinue: () => _openDeliveryDetail(order),
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

class _DeliveryMapLoading extends StatelessWidget {
  const _DeliveryMapLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryGreenLight),
          SizedBox(height: 14),
          Text('Loading delivery points...'),
        ],
      ),
    );
  }
}

class _DeliveryMapError extends StatelessWidget {
  const _DeliveryMapError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

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
              'Unable to load delivery points',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey('delivery-map-retry'),
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

class _DeliveryMapEmpty extends StatelessWidget {
  const _DeliveryMapEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 42,
            color: Color(0xFFBDBDBD),
          ),
          SizedBox(height: 9),
          Text(
            'No deliveries available',
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

class _DeliveryLegend extends StatelessWidget {
  const _DeliveryLegend({required this.showRider});

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
          const _DeliveryLegendDot(
            color: _deliveryBlue,
            label: 'Customer drop-off',
          ),
          if (showRider) ...[
            const SizedBox(width: 10),
            const _DeliveryLegendDot(
              color: Color(0xFF4285F4),
              label: 'You',
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryLegendDot extends StatelessWidget {
  const _DeliveryLegendDot({required this.color, required this.label});

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
