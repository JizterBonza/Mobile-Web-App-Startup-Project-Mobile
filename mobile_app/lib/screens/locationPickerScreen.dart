import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../constants/constants.dart';

class LocationPickerScreen extends StatefulWidget {
  /// Initial location to display on the map
  final LatLng? initialLocation;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;

  // Default to Philippines center (Manila)
  static const LatLng _defaultLocation = LatLng(14.5995, 120.9842);

  LatLng _selectedLocation = _defaultLocation;
  String _address = '';
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = true;
  String? _errorMessage;

  // Address breakdown components
  String? _street;
  String? _barangay; // subLocality
  String? _city; // locality
  String? _province; // administrativeArea
  String? _postalCode;
  String? _country;

  @override
  void initState() {
    super.initState();
    print('DEBUG: LocationPickerScreen initState called');
    print('DEBUG: Initial location provided: ${widget.initialLocation}');
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _isLoadingLocation = false;
      print(
          'DEBUG: Using provided initial location - Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}');
      _getAddressFromLatLng(_selectedLocation);
    } else {
      print('DEBUG: No initial location, getting current location...');
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Location permissions are permanently denied. Please enable in settings.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable GPS.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, 17),
      );

      // Get address
      _getAddressFromLatLng(_selectedLocation);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get current location';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        // Store address breakdown components
        _street = place.street;
        _barangay = place.subLocality; // Barangay in Philippines
        _city = place.locality; // City/Municipality
        _province = place.administrativeArea; // Province/Region
        _postalCode = place.postalCode;
        _country = place.country;

        // Build address string
        List<String> addressParts = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
          print('DEBUG: Street: ${place.street}');
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
          print('DEBUG: Barangay/Sublocality: ${place.subLocality}');
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
          print('DEBUG: City/Locality: ${place.locality}');
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
          print(
              'DEBUG: Province/Administrative Area: ${place.administrativeArea}');
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
          print('DEBUG: Postal Code: ${place.postalCode}');
        }
        if (place.country != null && place.country!.isNotEmpty) {
          print('DEBUG: Country: ${place.country}');
        }

        setState(() {
          _address = addressParts.join(', ');
          _isLoadingAddress = false;
        });
        print('DEBUG: Address resolved - $_address');
      } else {
        setState(() {
          _address = 'Unknown location';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _address = 'Unable to get address';
        _isLoadingAddress = false;
      });
    }
  }

  void _onMapTap(LatLng position) {
    print(
        'DEBUG: Map tapped at - Lat: ${position.latitude}, Lng: ${position.longitude}');
    setState(() {
      _selectedLocation = position;
    });
    _getAddressFromLatLng(position);
  }

  void _onCameraMove(CameraPosition position) {
    print(
        'DEBUG: Camera moving - Lat: ${position.target.latitude}, Lng: ${position.target.longitude}');
    setState(() {
      _selectedLocation = position.target;
    });
  }

  void _onCameraIdle() {
    print(
        'DEBUG: Camera idle - Final position - Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}');
    _getAddressFromLatLng(_selectedLocation);
  }

  void _confirmLocation() {
    print('DEBUG: Location confirmed!');
    print('DEBUG: Latitude: ${_selectedLocation.latitude}');
    print('DEBUG: Longitude: ${_selectedLocation.longitude}');
    print('DEBUG: Address: $_address');
    print('DEBUG: Street: $_street');
    print('DEBUG: Barangay: $_barangay');
    print('DEBUG: City: $_city');
    print('DEBUG: Province: $_province');
    print('DEBUG: Postal Code: $_postalCode');
    print('DEBUG: Country: $_country');

    Navigator.pop(context, {
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'address': _address,
      // Address breakdown
      'street': _street ?? '',
      'barangay': _barangay ?? '',
      'city': _city ?? '',
      'province': _province ?? '',
      'postal_code': _postalCode ?? '',
      'country': _country ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
        'DEBUG: Building LocationPickerScreen - isLoadingLocation: $_isLoadingLocation, errorMessage: $_errorMessage');
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Pin Your Location',
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
            onPressed: _getCurrentLocation,
            icon: Icon(Icons.my_location),
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              print('DEBUG: Google Map created successfully!');
              print(
                  'DEBUG: Initial location - Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}');
              _mapController = controller;
              if (!_isLoadingLocation) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedLocation, 17),
                );
              }
            },
            onTap: _onMapTap,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),

          // Center pin marker
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_pin,
                size: 48,
                color: AppColors.mediumGreen,
              ),
            ),
          ),

          // Loading overlay
          if (_isLoadingLocation)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.mediumGreen),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Getting your location...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error message
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                      icon: Icon(Icons.close, size: 18, color: Colors.red[700]),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom panel with address and confirm button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Address display
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.mediumGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: AppColors.mediumGreen,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              _isLoadingAddress
                                  ? Row(
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              AppColors.mediumGreen,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Getting address...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _address.isEmpty
                                          ? 'Move the map to select location'
                                          : _address,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[900],
                                        height: 1.3,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Coordinates display
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gps_fixed,
                              size: 14, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    // Confirm button
                    ElevatedButton(
                      onPressed: _address.isNotEmpty ? _confirmLocation : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumGreen,
                        disabledBackgroundColor: Colors.grey[400],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Zoom controls
          Positioned(
            right: 16,
            bottom: 240,
            child: Column(
              children: [
                _buildZoomButton(Icons.add, () {
                  _mapController?.animateCamera(CameraUpdate.zoomIn());
                }),
                SizedBox(height: 8),
                _buildZoomButton(Icons.remove, () {
                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                }),
              ],
            ),
          ),
        ],
      ),
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
}
