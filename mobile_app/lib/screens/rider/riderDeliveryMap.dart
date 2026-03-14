import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/constants.dart';
import '../../provider/orders_provider.dart';
import '../../provider/provider.dart';
import '../../services/directions_service.dart';
import '../../services/payment_service.dart';
import 'delivery_photo_preview_screen.dart';

class RiderDeliveryMapScreen extends StatefulWidget {
  const RiderDeliveryMapScreen({super.key});

  @override
  State<RiderDeliveryMapScreen> createState() => _RiderDeliveryMapScreenState();
}

class _RiderDeliveryMapScreenState extends State<RiderDeliveryMapScreen> {
  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Default center for the map (Davao Region, Philippines based on sample data)
  static const LatLng _defaultCenter = LatLng(7.3775, 125.8199);

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int? _selectedOrderIndex;
  List<Map<String, dynamic>> _deliveryOrders = [];
  bool _isLoading = true;
  String? _error;
  bool _isUpdatingStatus = false;

  // Live location tracking
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;
  bool _isLocationEnabled = false;

  // Route information
  DirectionsRoute? _currentRoute;
  bool _isLoadingRoute = false;
  bool _showRoute = false;

  Map<String, String> _paymentMethodNames = {};

  @override
  void initState() {
    super.initState();
    _initializeOrderStatusProvider();
    _loadOrders();
    _loadPaymentMethodNames();
    _initLocationTracking();
  }

  Future<void> _loadPaymentMethodNames() async {
    final names = await PaymentService.getPaymentMethodNames();
    if (mounted) setState(() => _paymentMethodNames = names);
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

      // Filter orders for in-transit status only
      final allOrders = ordersProvider.orders;
      final orderStatusProvider =
          Provider.of<OrderStatusProvider>(context, listen: false);
      await orderStatusProvider.initialize();

      // Get status ID for in-transit
      final inTransitStatusId = orderStatusProvider
              .getOrderStatusIdByDescription('in-transit') ??
          orderStatusProvider.getOrderStatusIdByDescription('in transit');

      _deliveryOrders = allOrders.where((order) {
        final orderStatusId = order['order_status'];
        int? statusId;
        if (orderStatusId is int) {
          statusId = orderStatusId;
        } else if (orderStatusId is String) {
          statusId = int.tryParse(orderStatusId);
        } else if (orderStatusId != null) {
          statusId = int.tryParse(orderStatusId.toString());
        }
        return statusId != null &&
            inTransitStatusId != null &&
            statusId == inTransitStatusId;
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

  /// Extract latitude from order data
  double? _getLatitude(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      final address = orderDetail?['address'] as Map<String, dynamic>?;
      if (address != null && address['latitude'] != null) {
        return double.tryParse(address['latitude'].toString());
      }
    } catch (e) {
      print('Error getting latitude: $e');
    }
    return null;
  }

  /// Extract longitude from order data
  double? _getLongitude(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      final address = orderDetail?['address'] as Map<String, dynamic>?;
      if (address != null && address['longitude'] != null) {
        return double.tryParse(address['longitude'].toString());
      }
    } catch (e) {
      print('Error getting longitude: $e');
    }
    return null;
  }

  /// Get shop name — prefers top-level 'shop', falls back to order_items
  String _getShopName(Map<String, dynamic> order) {
    try {
      if (order['shop'] is Map<String, dynamic>) {
        return (order['shop'] as Map<String, dynamic>)['shop_name']
                ?.toString() ??
            'Unknown Shop';
      }
      final orderItems = order['order_items'] as List<dynamic>?;
      if (orderItems != null && orderItems.isNotEmpty) {
        final firstItem = orderItems[0] as Map<String, dynamic>;
        final item = firstItem['item'] as Map<String, dynamic>?;
        final shop = item?['shop'] as Map<String, dynamic>?;
        return shop?['shop_name']?.toString() ?? 'Unknown Shop';
      }
    } catch (e) {
      print('Error getting shop name: $e');
    }
    return 'Unknown Shop';
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

  /// Get shipping address
  String _getShippingAddress(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      return orderDetail?['shipping_address']?.toString() ?? 'No address';
    } catch (e) {
      return 'No address';
    }
  }

  /// Get contact number
  String _getContactNumber(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      final address = orderDetail?['address'] as Map<String, dynamic>?;
      return address?['contact_number']?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Get delivery method ID
  int? _getDeliveryMethodId(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      final deliveryMethodId = orderDetail?['delivery_method_id'];
      if (deliveryMethodId != null) {
        return int.tryParse(deliveryMethodId.toString());
      }
      // Fallback to check flattened field
      final flattenedId = order['delivery_method_id'];
      if (flattenedId != null) {
        return int.tryParse(flattenedId.toString());
      }
    } catch (e) {
      print('Error getting delivery method ID: $e');
    }
    return null;
  }

  /// Get payment method display name (resolves ID to name like checkout)
  String _getPaymentMethod(Map<String, dynamic> order) {
    try {
      final orderDetail = order['order_detail'] as Map<String, dynamic>?;
      final id = orderDetail?['payment_method']?.toString() ??
          order['payment_method']?.toString() ??
          '';
      if (id.isEmpty) return '';
      return _paymentMethodNames[id] ?? id;
    } catch (e) {
      print('Error getting payment method: $e');
    }
    return '';
  }

  /// Capitalize first letter of a string
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
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
      final statusDesc = orderStatusProvider.getOrderStatusDescription(statusId);
      if (statusDesc != null) {
        return statusDesc;
      }
    }
    return 'in-transit';
  }

  /// Fetch and display the delivery route
  Future<void> _fetchDeliveryRoute() async {
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
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Filter only in-transit orders for routing
    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);
    final inTransitStatusId = orderStatusProvider
            .getOrderStatusIdByDescription('in-transit') ??
        orderStatusProvider.getOrderStatusIdByDescription('in transit');

    final inTransitOrders = _deliveryOrders.where((order) {
      final orderStatusId = order['order_status'];
      int? statusId;
      if (orderStatusId is int) {
        statusId = orderStatusId;
      } else if (orderStatusId is String) {
        statusId = int.tryParse(orderStatusId);
      } else if (orderStatusId != null) {
        statusId = int.tryParse(orderStatusId.toString());
      }
      return statusId != null &&
          inTransitStatusId != null &&
          statusId == inTransitStatusId;
    }).toList();

    if (inTransitOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No in-transit orders available for routing'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // Collect all drop-off locations with valid coordinates
      List<LatLng> dropOffLocations = [];

      for (var order in inTransitOrders) {
        final lat = _getLatitude(order);
        final lng = _getLongitude(order);

        if (lat != null && lng != null) {
          dropOffLocations.add(LatLng(lat, lng));
        }
      }

      if (dropOffLocations.isEmpty) {
        setState(() {
          _isLoadingRoute = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No valid delivery locations found'),
            backgroundColor: Colors.orange,
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
        dropOffLocations: dropOffLocations,
        optimizeRoute: true,
      );

      if (route != null) {
        setState(() {
          _currentRoute = route;
          _showRoute = true;
          _polylines = {
            Polyline(
              polylineId: PolylineId('delivery_route'),
              points: route.polylinePoints,
              color: AppColors.statusInTransit,
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
                Text('Route: ${route.totalDistance} • ${route.totalDuration}'),
              ],
            ),
            backgroundColor: AppColors.statusInTransit,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not calculate route. Check your API key.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error fetching route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating route: ${e.toString()}'),
          backgroundColor: Colors.red,
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
      _fetchDeliveryRoute();
    }
  }

  /// Get ordered at time
  String _getOrderedAt(Map<String, dynamic> order) {
    try {
      final orderedAt = order['ordered_at']?.toString() ?? '';
      if (orderedAt.isNotEmpty) {
        final dateTime = DateTime.tryParse(orderedAt);
        if (dateTime != null) {
          final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
          final period = dateTime.hour >= 12 ? 'PM' : 'AM';
          final minute = dateTime.minute.toString().padLeft(2, '0');
          return '$hour:$minute $period';
        }
      }
    } catch (e) {
      print('Error formatting time: $e');
    }
    return 'N/A';
  }

  void _createMarkers() {
    Set<Marker> markers = {};

    for (int i = 0; i < _deliveryOrders.length; i++) {
      final order = _deliveryOrders[i];
      final lat = _getLatitude(order);
      final lng = _getLongitude(order);

      // Skip orders without valid coordinates
      if (lat == null || lng == null) continue;

      final customerName = _getCustomerName(order);
      final orderCode = _getOrderCode(order);

      markers.add(
        Marker(
          markerId: MarkerId(order['id'].toString()),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: customerName,
            snippet: orderCode,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
    final order = _deliveryOrders[index];
    final lat = _getLatitude(order);
    final lng = _getLongitude(order);

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
    if (_deliveryOrders.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;

    for (var order in _deliveryOrders) {
      final lat = _getLatitude(order);
      final lng = _getLongitude(order);

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

  Future<void> _markAsDelivered(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();
    if (orderId == null) return;

    final ImagePicker picker = ImagePicker();
    bool photoConfirmed = false;

    // Loop until user confirms photo or cancels
    while (!photoConfirmed && mounted) {
      XFile? imageFile;

      // Capture image from camera
      try {
        imageFile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (imageFile == null) {
          // User cancelled camera
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delivery photo is required'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing camera: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Navigate to preview screen
      if (!mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => DeliveryPhotoPreviewScreen(
            imageFile: imageFile!,
            order: order,
            orderId: orderId,
          ),
        ),
      );

      // If photo was confirmed and saved successfully, exit loop and reload orders
      if (result == true) {
        photoConfirmed = true;
        if (mounted) {
          await _loadOrders();
        }
        break;
      }
      // If result is false, user wants to retake - loop will continue
      // If result is null, user closed preview - exit
      if (result == null) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Delivery Map',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
        actions: [
          IconButton(
            onPressed: _toggleRoute,
            icon: Icon(Icons.upload),
            tooltip: 'Upload Deliveries',
          ),
          IconButton(
            onPressed: _loadOrders,
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _fitAllMarkers,
            icon: Icon(Icons.zoom_out_map),
            tooltip: 'Fit All Locations',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.statusInTransit),
                  SizedBox(height: 16),
                  Text(
                    'Loading delivery orders...',
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildLegendItem(
                            AppColors.statusInTransit, 'In Transit'),
                        if (_isLocationEnabled)
                          _buildLegendItem(Colors.orange, 'You'),
                      ],
                    ),
                  ),
                ),

                // Route info banner (when route is displayed)
                if (_showRoute && _currentRoute != null)
                  Positioned(
                    top: 60,
                    left: 16,
                    right: 80,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.statusInTransit.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.route,
                              color: AppColors.statusInTransit,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Optimized Delivery Route',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_currentRoute!.totalDistance} • ${_currentRoute!.totalDuration}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_currentRoute!.legs.isNotEmpty)
                                  Text(
                                    '${_currentRoute!.legs.length} stops',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.statusInTransit,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _clearRoute,
                            icon: Icon(Icons.close, size: 18),
                            color: Colors.grey[500],
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Error banner
                if (_error != null)
                  Positioned(
                    top: 60,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.orange[700], size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Using cached data',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
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
                  child: Column(
                    children: [
                      // Route toggle button
                      _buildRouteButton(),
                      SizedBox(height: 8),
                      _buildZoomButton(Icons.add, () {
                        _mapController?.animateCamera(CameraUpdate.zoomIn());
                      }),
                      SizedBox(height: 8),
                      _buildZoomButton(Icons.remove, () {
                        _mapController?.animateCamera(CameraUpdate.zoomOut());
                      }),
                      SizedBox(height: 8),
                      _buildZoomButton(Icons.my_location, () {
                        // Center on rider's current location or default
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

                // Bottom sheet with delivery list
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Drag handle
                          Container(
                            margin: EdgeInsets.only(top: 12, bottom: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // Header
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'For Delivery',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.statusInTransit
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_deliveryOrders.length} orders',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.statusInTransit,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Divider(height: 1, color: Colors.grey[200]),

                          // Delivery list
                          Expanded(
                            child: _deliveryOrders.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.local_shipping_outlined,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'No delivery orders',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Orders in transit or delivered will appear here',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollController,
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _deliveryOrders.length,
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                            height: 1, color: Colors.grey[200]),
                                    itemBuilder: (context, index) {
                                      final order = _deliveryOrders[index];
                                      final isSelected =
                                          _selectedOrderIndex == index;

                                      return _buildDeliveryItem(
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
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
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Icon(icon, size: 20, color: Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteButton() {
    return Container(
      decoration: BoxDecoration(
        color: _showRoute ? AppColors.statusInTransit : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoadingRoute ? null : _toggleRoute,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: _isLoadingRoute
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.statusInTransit,
                      ),
                    ),
                  )
                : Icon(
                    Icons.route,
                    size: 20,
                    color:
                        _showRoute ? Colors.white : AppColors.statusInTransit,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryItem(
      Map<String, dynamic> order, int index, bool isSelected) {
    final status = _getOrderStatus(order);
    final orderCode = _getOrderCode(order);
    final customerName = _getCustomerName(order);
    final customerContact = _getContactNumber(order);
    final shippingAddress = _getShippingAddress(order);
    final total = _getTotalAmount(order);
    final itemsCount = _getItemsCount(order);
    final deliveryMethodId = _getDeliveryMethodId(order);
    final paymentMethod = _getPaymentMethod(order);

    return InkWell(
      onTap: () => _focusOnOrder(index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected
            ? AppColors.statusInTransit.withOpacity(0.08)
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order number indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),

            // Order details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order code and status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          orderCode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
                          color: _getStatusColor(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatStatus(status),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  // Customer name
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: AppColors.statusInTransit,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Customer contact (only show if delivery_method_id is 1)
                  if (customerContact.isNotEmpty && deliveryMethodId == 1) ...[
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: Colors.grey[500],
                        ),
                        SizedBox(width: 4),
                        Text(
                          customerContact,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 4),
                  // Shipping address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.statusInTransit,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shippingAddress,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Payment method
                  if (paymentMethod.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          paymentMethod.toLowerCase().contains('cash')
                              ? Icons.money
                              : Icons.credit_card,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          _capitalizeFirst(paymentMethod),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 6),
                  // Delivery status time
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 12,
                        color: AppColors.statusInTransit,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'In transit since ${_getOrderedAt(order)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.statusInTransit,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Price, items, and action button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatPrice(total),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepForestGreen,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$itemsCount ${itemsCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed:
                      _isUpdatingStatus ? null : () => _markAsDelivered(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusDelivered,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size(0, 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isUpdatingStatus
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.check_circle_outline, size: 14),
                      SizedBox(width: 4),
                      Text(
                        _isUpdatingStatus ? '...' : 'Delivered',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    _sheetController.dispose();
    super.dispose();
  }
}
