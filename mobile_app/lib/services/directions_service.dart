import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Model class representing a route from Google Directions API
class DirectionsRoute {
  final List<LatLng> polylinePoints;
  final String totalDistance;
  final String totalDuration;
  final LatLngBounds bounds;
  final List<RouteLeg> legs;

  DirectionsRoute({
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
    required this.bounds,
    required this.legs,
  });
}

/// Model class representing a leg of the route (between two waypoints)
class RouteLeg {
  final String startAddress;
  final String endAddress;
  final LatLng startLocation;
  final LatLng endLocation;
  final String distance;
  final String duration;

  RouteLeg({
    required this.startAddress,
    required this.endAddress,
    required this.startLocation,
    required this.endLocation,
    required this.distance,
    required this.duration,
  });
}

/// Service class for Google Directions API
class DirectionsService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Get the Google Maps API key from environment variables
  static String get _apiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
          'GOOGLE_MAPS_API_KEY not found in .env file. Please add it.');
    }
    return key;
  }

  /// Get directions from origin to destination with optional waypoints
  ///
  /// [origin] - Starting location (rider's current position)
  /// [destination] - Final destination
  /// [waypoints] - List of intermediate drop-off locations
  /// [optimizeWaypoints] - If true, the API will optimize the order of waypoints
  ///
  /// Returns a [DirectionsRoute] containing the route information and decoded polyline points
  static Future<DirectionsRoute?> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    bool optimizeWaypoints = true,
  }) async {
    try {
      // Build the waypoints parameter string
      String? waypointsParam;
      if (waypoints != null && waypoints.isNotEmpty) {
        final waypointStrings =
            waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
        waypointsParam = optimizeWaypoints
            ? 'optimize:true|$waypointStrings'
            : waypointStrings;
      }

      // Build the request URL
      final queryParams = {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': _apiKey,
        'mode': 'driving',
      };

      if (waypointsParam != null) {
        queryParams['waypoints'] = waypointsParam;
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      print('Directions API URL: $uri');

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        print('Directions API error: Status ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        print(
            'Directions API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        return null;
      }

      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        print('Directions API: No routes found');
        return null;
      }

      final route = data['routes'][0];

      // Decode the overview polyline
      final encodedPolyline = route['overview_polyline']['points'] as String;
      final polylinePoints = _decodePolyline(encodedPolyline);

      // Parse bounds
      final boundsData = route['bounds'];
      final bounds = LatLngBounds(
        southwest: LatLng(
          boundsData['southwest']['lat'].toDouble(),
          boundsData['southwest']['lng'].toDouble(),
        ),
        northeast: LatLng(
          boundsData['northeast']['lat'].toDouble(),
          boundsData['northeast']['lng'].toDouble(),
        ),
      );

      // Parse legs
      final legsData = route['legs'] as List;
      final legs = legsData.map((leg) {
        return RouteLeg(
          startAddress: leg['start_address'] ?? '',
          endAddress: leg['end_address'] ?? '',
          startLocation: LatLng(
            leg['start_location']['lat'].toDouble(),
            leg['start_location']['lng'].toDouble(),
          ),
          endLocation: LatLng(
            leg['end_location']['lat'].toDouble(),
            leg['end_location']['lng'].toDouble(),
          ),
          distance: leg['distance']['text'] ?? '',
          duration: leg['duration']['text'] ?? '',
        );
      }).toList();

      // Calculate total distance and duration
      String totalDistance = '';
      String totalDuration = '';
      int totalDistanceMeters = 0;
      int totalDurationSeconds = 0;

      for (var leg in legsData) {
        totalDistanceMeters += (leg['distance']['value'] as int);
        totalDurationSeconds += (leg['duration']['value'] as int);
      }

      // Format total distance
      if (totalDistanceMeters >= 1000) {
        totalDistance = '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
      } else {
        totalDistance = '$totalDistanceMeters m';
      }

      // Format total duration
      if (totalDurationSeconds >= 3600) {
        final hours = totalDurationSeconds ~/ 3600;
        final minutes = (totalDurationSeconds % 3600) ~/ 60;
        totalDuration = '$hours hr ${minutes} min';
      } else {
        final minutes = totalDurationSeconds ~/ 60;
        totalDuration = '$minutes min';
      }

      return DirectionsRoute(
        polylinePoints: polylinePoints,
        totalDistance: totalDistance,
        totalDuration: totalDuration,
        bounds: bounds,
        legs: legs,
      );
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }

  /// Decode an encoded polyline string into a list of LatLng points
  ///
  /// Google's Polyline Algorithm encodes coordinates into an ASCII string
  /// This function decodes that string back into latitude/longitude pairs
  ///
  /// Reference: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      // Decode latitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      // Convert to LatLng (values are in 1e5 precision)
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Get directions for delivery route with multiple drop-off locations
  ///
  /// This is a convenience method specifically for delivery scenarios where:
  /// - The rider starts at their current location
  /// - Stops at multiple drop-off points
  /// - The last drop-off is the final destination
  ///
  /// [riderLocation] - Current location of the rider (origin)
  /// [dropOffLocations] - List of all drop-off locations (last one becomes destination)
  /// [optimizeRoute] - Whether to optimize the order of stops
  static Future<DirectionsRoute?> getDeliveryRoute({
    required LatLng riderLocation,
    required List<LatLng> dropOffLocations,
    bool optimizeRoute = true,
  }) async {
    if (dropOffLocations.isEmpty) {
      print('No drop-off locations provided');
      return null;
    }

    // If only one drop-off, it's the destination with no waypoints
    if (dropOffLocations.length == 1) {
      return getDirections(
        origin: riderLocation,
        destination: dropOffLocations.first,
      );
    }

    // Multiple drop-offs: last one is destination, rest are waypoints
    final waypoints = dropOffLocations.sublist(0, dropOffLocations.length - 1);
    final destination = dropOffLocations.last;

    return getDirections(
      origin: riderLocation,
      destination: destination,
      waypoints: waypoints,
      optimizeWaypoints: optimizeRoute,
    );
  }
}
