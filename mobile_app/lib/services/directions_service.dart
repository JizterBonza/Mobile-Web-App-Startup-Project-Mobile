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
    final routes = await getAlternativeDirections(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      optimizeWaypoints: optimizeWaypoints,
      requestAlternatives: false,
    );
    return routes.isEmpty ? null : routes.first;
  }

  /// Returns the default route followed by any alternatives supplied by
  /// Google. Alternatives are requested only when there are no intermediate
  /// waypoints, matching the Directions API restriction.
  static Future<List<DirectionsRoute>> getAlternativeDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    bool optimizeWaypoints = true,
    bool requestAlternatives = true,
  }) async {
    try {
      String? waypointsParam;
      if (waypoints != null && waypoints.isNotEmpty) {
        final waypointStrings =
            waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
        waypointsParam = optimizeWaypoints
            ? 'optimize:true|$waypointStrings'
            : waypointStrings;
      }

      final queryParams = {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': _apiKey,
        'mode': 'driving',
      };

      if (waypointsParam != null) {
        queryParams['waypoints'] = waypointsParam;
      } else if (requestAlternatives) {
        queryParams['alternatives'] = 'true';
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        print('Directions API error: Status ${response.statusCode}');
        return <DirectionsRoute>[];
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return <DirectionsRoute>[];
      }

      if (decoded['status'] != 'OK') {
        print(
            'Directions API error: ${decoded['status']} - ${decoded['error_message'] ?? 'Unknown error'}');
        return <DirectionsRoute>[];
      }

      return parseDirectionsRoutes(decoded);
    } catch (e) {
      print('Error getting directions: $e');
      return <DirectionsRoute>[];
    }
  }

  static List<DirectionsRoute> parseDirectionsRoutes(
    Map<String, dynamic> data,
  ) {
    final rawRoutes = data['routes'];
    if (rawRoutes is! List) return <DirectionsRoute>[];

    final routes = <DirectionsRoute>[];
    for (final rawRoute in rawRoutes.whereType<Map>()) {
      try {
        routes.add(_parseRoute(Map<String, dynamic>.from(rawRoute)));
      } catch (_) {
        // Ignore malformed alternatives while retaining valid routes.
      }
    }
    return routes;
  }

  static DirectionsRoute _parseRoute(Map<String, dynamic> route) {
    final overview = route['overview_polyline'] as Map;
    final polylinePoints = _decodePolyline(overview['points'] as String);
    final boundsData = route['bounds'] as Map;
    final southwest = boundsData['southwest'] as Map;
    final northeast = boundsData['northeast'] as Map;
    final bounds = LatLngBounds(
      southwest: LatLng(
        (southwest['lat'] as num).toDouble(),
        (southwest['lng'] as num).toDouble(),
      ),
      northeast: LatLng(
        (northeast['lat'] as num).toDouble(),
        (northeast['lng'] as num).toDouble(),
      ),
    );

    final legsData = route['legs'] as List;
    final legs = legsData.whereType<Map>().map((rawLeg) {
      final leg = Map<String, dynamic>.from(rawLeg);
      final start = leg['start_location'] as Map;
      final end = leg['end_location'] as Map;
      final distance = leg['distance'] as Map;
      final duration = leg['duration'] as Map;
      return RouteLeg(
        startAddress: leg['start_address']?.toString() ?? '',
        endAddress: leg['end_address']?.toString() ?? '',
        startLocation: LatLng(
          (start['lat'] as num).toDouble(),
          (start['lng'] as num).toDouble(),
        ),
        endLocation: LatLng(
          (end['lat'] as num).toDouble(),
          (end['lng'] as num).toDouble(),
        ),
        distance: distance['text']?.toString() ?? '',
        duration: duration['text']?.toString() ?? '',
      );
    }).toList();

    var totalDistanceMeters = 0;
    var totalDurationSeconds = 0;
    for (final rawLeg in legsData.whereType<Map>()) {
      final distance = rawLeg['distance'];
      final duration = rawLeg['duration'];
      if (distance is Map && distance['value'] is num) {
        totalDistanceMeters += (distance['value'] as num).toInt();
      }
      if (duration is Map && duration['value'] is num) {
        totalDurationSeconds += (duration['value'] as num).toInt();
      }
    }

    return DirectionsRoute(
      polylinePoints: polylinePoints,
      totalDistance: _formatDistance(totalDistanceMeters),
      totalDuration: _formatDuration(totalDurationSeconds),
      bounds: bounds,
      legs: legs,
    );
  }

  static String _formatDistance(int meters) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '$meters m';
  }

  static String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours hr $minutes min';
    }
    return '${seconds ~/ 60} min';
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
