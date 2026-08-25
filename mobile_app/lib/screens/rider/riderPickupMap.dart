import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/orders_provider.dart';
import '../../provider/provider.dart';
import '../../services/order_service.dart';
import '../../services/directions_service.dart';
import '../../utils/status_utils.dart';
import 'selectedOrderPickupDetail.dart';

class RiderPickupMapScreen extends StatefulWidget {
  const RiderPickupMapScreen({super.key, this.order});

  final Map<String, dynamic>? order;

  @override
  State<RiderPickupMapScreen> createState() => _RiderPickupMapScreenState();
}

class _RiderPickupMapScreenState extends State<RiderPickupMapScreen> {
  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Default center for the map (Davao Region, Philippines based on sample data)
  static const LatLng _defaultCenter = LatLng(7.3775, 125.8199);

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int? _selectedOrderIndex;
  List<Map<String, dynamic>> _pickupOrders = [];
  bool _isLoading = true;
  String? _error;

  // Live location tracking
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;
  bool _isLocationEnabled = false;

  // Route information
  DirectionsRoute? _currentRoute;
  bool _isLoadingRoute = false;
  bool _showRoute = false;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) return;
    _initializeOrderStatusProvider();
    _loadOrders();
    _initLocationTracking();
  }

  Future<void> _initializeOrderStatusProvider() async {
    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);
    await orderStatusProvider.initialize();
  }

  Future<void> _initLocationTracking() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return;
      }

      setState(() {
        _isLocationEnabled = true;
      });

      // Get initial position
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        setState(() {
          _currentPosition = position;
        });
        _updateRiderMarker();
      } catch (e) {
        print('Error getting initial position: $e');
      }

      // Start listening to location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) {
          setState(() {
            _currentPosition = position;
          });
          _updateRiderMarker();
        },
        onError: (e) {
          print('Error in location stream: $e');
        },
      );
    } catch (e) {
      print('Error initializing location tracking: $e');
    }
  }

  void _updateRiderMarker() {
    if (_currentPosition == null) return;

    // Remove old rider marker and add updated one
    _markers.removeWhere((m) => m.markerId.value == 'rider_location');

    final riderMarker = Marker(
      markerId: MarkerId('rider_location'),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      infoWindow: InfoWindow(title: 'Your Location'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      zIndex: 2, // Show above other markers
    );

    setState(() {
      _markers.add(riderMarker);
    });
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ordersProvider =
          Provider.of<OrdersProvider>(context, listen: false);
      await ordersProvider.fetchRiderOrders(useCache: false);

      // Temporarily show only orders that are ready for delivery.
      final allOrders = ordersProvider.orders;
      final orderStatusProvider =
          Provider.of<OrderStatusProvider>(context, listen: false);
      await orderStatusProvider.initialize();

      _pickupOrders = allOrders.where((order) {
        final orderStatusId = order['order_status'];
        int? statusId;
        if (orderStatusId is int) {
          statusId = orderStatusId;
        } else if (orderStatusId is String) {
          statusId = int.tryParse(orderStatusId);
        } else if (orderStatusId != null) {
          statusId = int.tryParse(orderStatusId.toString());
        }
        if (statusId == null) return false;
        final statusDescription =
            orderStatusProvider.getOrderStatusDescription(statusId);
        return statusDescription != null &&
            isReadyForDeliveryStatus(statusDescription);
      }).toList();

      _createMarkers();

      setState(() {
        _isLoading = false;
        _error = ordersProvider.error;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// Get shop data — prefers top-level 'shop', falls back to order_items
  Map<String, dynamic>? _getShopData(Map<String, dynamic> order) {
    try {
      if (order['shop'] is Map<String, dynamic>) {
        return order['shop'] as Map<String, dynamic>;
      }
      final orderItems = order['order_items'] as List<dynamic>?;
      if (orderItems != null && orderItems.isNotEmpty) {
        final firstItem = orderItems[0] as Map<String, dynamic>;
        final item = firstItem['item'] as Map<String, dynamic>?;
        return item?['shop'] as Map<String, dynamic>?;
      }
    } catch (e) {
      print('Error getting shop data: $e');
    }
    return null;
  }

  /// Extract shop latitude from order data
  double? _getShopLatitude(Map<String, dynamic> order) {
    try {
      final shop = _getShopData(order);
      if (shop != null && shop['shop_lat'] != null) {
        return double.tryParse(shop['shop_lat'].toString());
      }
    } catch (e) {
      print('Error getting shop latitude: $e');
    }
    return null;
  }

  /// Extract shop longitude from order data
  double? _getShopLongitude(Map<String, dynamic> order) {
    try {
      final shop = _getShopData(order);
      if (shop != null && shop['shop_long'] != null) {
        return double.tryParse(shop['shop_long'].toString());
      }
    } catch (e) {
      print('Error getting shop longitude: $e');
    }
    return null;
  }

  /// Get shop name from order items
  String _getShopName(Map<String, dynamic> order) {
    try {
      final shop = _getShopData(order);
      return shop?['shop_name']?.toString() ?? 'Unknown Shop';
    } catch (e) {
      print('Error getting shop name: $e');
    }
    return 'Unknown Shop';
  }

  /// Get shop address from order items
  String _getShopAddress(Map<String, dynamic> order) {
    try {
      final shop = _getShopData(order);
      return shop?['shop_address']?.toString() ?? 'No address available';
    } catch (e) {
      print('Error getting shop address: $e');
    }
    return 'No address available';
  }

  /// Get shop contact number from order items
  String _getShopContact(Map<String, dynamic> order) {
    try {
      final shop = _getShopData(order);
      return shop?['contact_number']?.toString() ?? '';
    } catch (e) {
      print('Error getting shop contact: $e');
    }
    return '';
  }

  /// Get order code from order detail
  String _getOrderCode(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      return orderDetail?['order_code']?.toString() ?? 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Get customer name from user data
  String _getCustomerName(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      final address = orderDetail?['address'] as Map<String, dynamic>?;
      return address?['recipient_name']?.toString() ?? 'Unknown Customer';
    } catch (e) {
      return 'Unknown Customer';
    }
  }

  /// Get delivery address (customer's shipping address)
  String _getDeliveryAddress(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      return orderDetail?['shipping_address']?.toString() ?? 'No address';
    } catch (e) {
      return 'No address';
    }
  }

  /// Get customer contact number
  String _getCustomerContact(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      final address = orderDetail?['address'] as Map<String, dynamic>?;
      return address?['contact_number']?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Get total amount
  double _getTotalAmount(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      return double.tryParse(orderDetail?['total_amount']?.toString() ?? '0') ??
          0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get items count
  int _getItemsCount(Map<String, dynamic> order) {
    try {
      final orderItems = order['order_items'] as List<dynamic>?;
      return orderItems?.length ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get order status description using OrderStatusProvider
  String _getOrderStatus(Map<String, dynamic> order) {
    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);
    final orderStatusId = order['order_status'];
    int? statusId;
    if (orderStatusId is int) {
      statusId = orderStatusId;
    } else if (orderStatusId is String) {
      statusId = int.tryParse(orderStatusId);
    } else if (orderStatusId != null) {
      statusId = int.tryParse(orderStatusId.toString());
    }

    if (statusId != null) {
      final statusDesc =
          orderStatusProvider.getOrderStatusDescription(statusId);
      if (statusDesc != null) {
        return statusDesc;
      }
    }
    return 'pending';
  }

  /// Fetch and display the pickup route to shops
  Future<void> _fetchPickupRoute() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.location_off, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Waiting for your location...'),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_pickupOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No orders available for routing'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // Collect all shop/pickup locations with valid coordinates
      List<LatLng> pickupLocations = [];

      for (var order in _pickupOrders) {
        final lat = _getShopLatitude(order);
        final lng = _getShopLongitude(order);

        if (lat != null && lng != null) {
          pickupLocations.add(LatLng(lat, lng));
        }
      }

      if (pickupLocations.isEmpty) {
        setState(() {
          _isLoadingRoute = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No valid pickup locations found'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final riderLocation = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      final route = await DirectionsService.getDeliveryRoute(
        riderLocation: riderLocation,
        dropOffLocations: pickupLocations,
        optimizeRoute: true,
      );

      if (route != null) {
        setState(() {
          _currentRoute = route;
          _showRoute = true;
          _polylines = {
            Polyline(
              polylineId: PolylineId('pickup_route'),
              points: route.polylinePoints,
              color: AppColors.primaryGreen,
              width: 5,
              patterns: [],
            ),
          };
        });

        // Fit the map to show the entire route
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(route.bounds, 80),
        );

        // Show route info
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.route, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                    'Pickup Route: ${route.totalDistance} • ${route.totalDuration}'),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not calculate route. Check your API key.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error fetching route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating route: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  /// Clear the displayed route
  void _clearRoute() {
    setState(() {
      _showRoute = false;
      _currentRoute = null;
      _polylines = {};
    });
  }

  /// Toggle route display
  void _toggleRoute() {
    if (_showRoute) {
      _clearRoute();
    } else {
      _fetchPickupRoute();
    }
  }

  void _createMarkers() {
    Set<Marker> markers = {};

    for (int i = 0; i < _pickupOrders.length; i++) {
      final order = _pickupOrders[i];
      final lat = _getShopLatitude(order);
      final lng = _getShopLongitude(order);

      // Skip orders without valid shop coordinates
      if (lat == null || lng == null) continue;

      final shopName = _getShopName(order);
      final shopAddress = _getShopAddress(order);

      markers.add(
        Marker(
          markerId: MarkerId(order['id'].toString()),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: shopName,
            snippet: shopAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _isReadyForDelivery(order)
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueOrange,
          ),
          onTap: () {
            setState(() {
              _selectedOrderIndex = i;
            });
            _sheetController.animateTo(
              0.5,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _focusOnOrder(int index) {
    final order = _pickupOrders[index];
    final lat = _getShopLatitude(order);
    final lng = _getShopLongitude(order);

    if (lat != null && lng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(lat, lng),
          16,
        ),
      );
    }
    setState(() {
      _selectedOrderIndex = index;
    });
  }

  void _fitAllMarkers() {
    if (_pickupOrders.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;

    for (var order in _pickupOrders) {
      final lat = _getShopLatitude(order);
      final lng = _getShopLongitude(order);

      if (lat == null || lng == null) continue;

      if (minLat == null || lat < minLat) minLat = lat;
      if (maxLat == null || lat > maxLat) maxLat = lat;
      if (minLng == null || lng < minLng) minLng = lng;
      if (maxLng == null || lng > maxLng) maxLng = lng;
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        50,
      ),
    );
  }

  String _formatPrice(double price) {
    return '₱${price.toStringAsFixed(2)}';
  }

  Color _getStatusColor(String status) {
    return OrderStatusColors.getColor(status);
  }

  String _formatStatus(String status) {
    return OrderStatusColors.formatStatus(status);
  }

  /// Check if an order is in the rider's actionable pickup state.
  bool _isReadyForDelivery(Map<String, dynamic> order) {
    return isReadyForDeliveryStatus(_getOrderStatus(order));
  }

  @override
  Widget build(BuildContext context) {
    final selectedOrder = widget.order;
    if (selectedOrder != null) {
      return SelectedOrderPickupDetailScreen(order: selectedOrder);
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          'Pickup Map',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
        actions: [
          _buildAppBarAction(Icons.refresh, 'Refresh', _loadOrders),
          _buildAppBarAction(Icons.zoom_out_map, 'Fit All', _fitAllMarkers),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  SizedBox(height: 16),
                  Text(
                    'Loading pickup orders...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _defaultCenter,
                    zoom: 12,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    // Fit all markers after map is created
                    Future.delayed(Duration(milliseconds: 500), () {
                      _fitAllMarkers();
                    });
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                ),

                // Legend
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildLegendItem(
                          AppColors.statusReadyForDelivery,
                          'Ready for Delivery',
                        ),
                        if (_isLocationEnabled)
                          _buildLegendItem(AppColors.accentAmber, 'You'),
                      ],
                    ),
                  ),
                ),

                // Error banner
                if (_error != null)
                  Positioned(
                    top: 56,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Using cached data',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Route info banner
                if (_showRoute && _currentRoute != null)
                  Positioned(
                    top: 56,
                    left: 16,
                    right: 80,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.route,
                              color: AppColors.primaryGreen,
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Pickup Route',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_currentRoute!.totalDistance} • ${_currentRoute!.totalDuration}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                if (_currentRoute!.legs.isNotEmpty)
                                  Text(
                                    '${_currentRoute!.legs.length} shops',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _clearRoute,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close,
                                  size: 16, color: Colors.grey[400]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Zoom controls
                Positioned(
                  right: 16,
                  bottom: 320,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRouteButton(),
                        Divider(
                            height: 1,
                            indent: 8,
                            endIndent: 8,
                            color: Colors.grey[200]),
                        _buildZoomButton(Icons.add, () {
                          _mapController?.animateCamera(CameraUpdate.zoomIn());
                        }),
                        Divider(
                            height: 1,
                            indent: 8,
                            endIndent: 8,
                            color: Colors.grey[200]),
                        _buildZoomButton(Icons.remove, () {
                          _mapController?.animateCamera(CameraUpdate.zoomOut());
                        }),
                        Divider(
                            height: 1,
                            indent: 8,
                            endIndent: 8,
                            color: Colors.grey[200]),
                        _buildZoomButton(Icons.my_location, () {
                          if (_currentPosition != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(_currentPosition!.latitude,
                                    _currentPosition!.longitude),
                                16,
                              ),
                            );
                          } else {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(_defaultCenter, 14),
                            );
                          }
                        }),
                      ],
                    ),
                  ),
                ),

                // Bottom sheet with pickup list
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.35,
                  minChildSize: 0.15,
                  maxChildSize: 0.85,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 10, bottom: 8),
                            width: 48,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'For Pickup',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_pickupOrders.length} orders',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4),
                          Expanded(
                            child: _pickupOrders.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inbox_outlined,
                                          size: 40,
                                          color: Colors.grey[300],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'No pickup orders',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    itemCount: _pickupOrders.length,
                                    itemBuilder: (context, index) {
                                      final order = _pickupOrders[index];
                                      final isSelected =
                                          _selectedOrderIndex == index;

                                      return _buildPickupItem(
                                          order, index, isSelected);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildAppBarAction(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryGreen),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildRouteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoadingRoute ? null : _toggleRoute,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _showRoute ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _isLoadingRoute
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                  ),
                )
              : Icon(
                  Icons.route,
                  size: 20,
                  color: _showRoute ? Colors.white : AppColors.primaryGreen,
                ),
        ),
      ),
    );
  }

  Widget _buildPickupItem(
      Map<String, dynamic> order, int index, bool isSelected) {
    final status = _getOrderStatus(order);
    final orderCode = _getOrderCode(order);
    final shopName = _getShopName(order);
    final shopAddress = _getShopAddress(order);
    final shopContact = _getShopContact(order);
    final customerName = _getCustomerName(order);
    final deliveryAddress = _getDeliveryAddress(order);
    final total = _getTotalAmount(order);
    final itemsCount = _getItemsCount(order);
    final statusColor = _getStatusColor(status);

    return GestureDetector(
      onTap: () => _focusOnOrder(index),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withOpacity(0.06)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          orderCode,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[900],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatStatus(status),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 13, color: AppColors.primaryGreen),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shopName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreenDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shopAddress,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (shopContact.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 11, color: Colors.grey[400]),
                        SizedBox(width: 4),
                        Text(
                          shopContact,
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 6),
                  Container(
                    height: 1,
                    color: Colors.grey[200],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Text(
                        'Deliver to: ',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                      Expanded(
                        child: Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey[400]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          deliveryAddress,
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatPrice(total),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreenDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '$itemsCount ${itemsCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Builder(
                  builder: (context) {
                    if (_isReadyForDelivery(order)) {
                      return Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: ElevatedButton(
                          onPressed: () => _handlePickup(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size(0, 28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 13),
                              SizedBox(width: 4),
                              Text(
                                'Pickup',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.grey[300],
                          size: 18,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get order items list
  List<Map<String, dynamic>> _getOrderItems(Map<String, dynamic> order) {
    try {
      final orderItems = order['order_items'] as List<dynamic>?;
      if (orderItems == null || orderItems.isEmpty) {
        return [];
      }
      return orderItems.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting order items: $e');
      return [];
    }
  }

  /// Get item name from order item
  String _getItemName(dynamic item) {
    try {
      final nestedItem = item['item'] as Map<String, dynamic>?;
      return nestedItem?['item_name']?.toString() ??
          item['item_name']?.toString() ??
          item['name']?.toString() ??
          'Unknown Item';
    } catch (e) {
      return 'Unknown Item';
    }
  }

  /// Get item quantity from order item
  int _getItemQuantity(dynamic item) {
    try {
      final quantity = item['quantity'];
      if (quantity is int) return quantity;
      if (quantity is String) return int.tryParse(quantity) ?? 1;
      return 1;
    } catch (e) {
      return 1;
    }
  }

  /// Get item price from order item
  double _getItemPrice(dynamic item) {
    try {
      final nestedItem = item['item'] as Map<String, dynamic>?;
      final price = item['price'] ??
          item['item_price'] ??
          nestedItem?['item_price'] ??
          item['price_at_purchase'] ??
          0;
      if (price is double) return price;
      if (price is int) return price.toDouble();
      if (price is String) return double.tryParse(price) ?? 0.0;
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void _handlePickup(Map<String, dynamic> order) {
    final orderCode = _getOrderCode(order);
    final shopName = _getShopName(order);
    final orderItems = _getOrderItems(order);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirm Pickup',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you ready to pick up this order?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long,
                            size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          orderCode,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.store,
                            size: 16, color: AppColors.primaryGreen),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            shopName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (orderItems.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Items to Pickup:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(orderItems.length, (index) {
                      final item = orderItems[index];
                      final itemName = _getItemName(item);
                      final quantity = _getItemQuantity(item);
                      final price = _getItemPrice(item);
                      final totalPrice = price * quantity;

                      return Column(
                        children: [
                          if (index > 0)
                            Divider(
                              height: 1,
                              color: Colors.grey[200],
                              indent: 12,
                              endIndent: 12,
                            ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[900],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Qty: $quantity',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            _formatPrice(totalPrice),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryGreenDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
              SizedBox(height: 12),
              Text(
                'This will update the order status to "In Transit".',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmPickup(order);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Confirm Pickup',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  final OrderService _orderService = OrderService();

  Future<void> _confirmPickup(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString() ?? order['order_id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid order ID'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryGreen),
              SizedBox(height: 16),
              Text(
                'Updating order status...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Get status code for "in-transit" from OrderStatusProvider
      final orderStatusProvider =
          Provider.of<OrderStatusProvider>(context, listen: false);
      final inTransitStatusId =
          orderStatusProvider.getOrderStatusIdByDescription('in-transit') ??
              orderStatusProvider.getOrderStatusIdByDescription('in transit');

      if (inTransitStatusId == null) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Unable to find "In Transit" status. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final shopId = order['shop_id']?.toString();
      final result = await _orderService.updateOrderStatus(
        orderId: orderId,
        status: inTransitStatusId.toString(),
        shopId: shopId,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Order picked up successfully!'),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        // Reload orders to reflect the change
        await _loadOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update order status'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    _sheetController.dispose();
    super.dispose();
  }
}
