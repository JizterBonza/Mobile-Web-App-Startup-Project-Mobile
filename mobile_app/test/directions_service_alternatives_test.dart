import 'package:agriconnect/services/directions_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _route({
  required int distance,
  required int duration,
}) {
  return <String, dynamic>{
    'overview_polyline': <String, dynamic>{
      'points': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
    },
    'bounds': <String, dynamic>{
      'southwest': <String, dynamic>{'lat': 7.4, 'lng': 125.8},
      'northeast': <String, dynamic>{'lat': 7.5, 'lng': 125.9},
    },
    'legs': <Map<String, dynamic>>[
      <String, dynamic>{
        'start_address': 'Rider',
        'end_address': 'Shop',
        'start_location': <String, dynamic>{'lat': 7.4, 'lng': 125.8},
        'end_location': <String, dynamic>{'lat': 7.5, 'lng': 125.9},
        'distance': <String, dynamic>{
          'text': '${distance / 1000} km',
          'value': distance,
        },
        'duration': <String, dynamic>{
          'text': '${duration ~/ 60} min',
          'value': duration,
        },
      },
    ],
  };
}

void main() {
  test('parses the default route and all valid alternatives', () {
    final routes = DirectionsService.parseDirectionsRoutes(
      <String, dynamic>{
        'routes': <dynamic>[
          _route(distance: 4200, duration: 720),
          _route(distance: 4800, duration: 840),
          <String, dynamic>{'malformed': true},
        ],
      },
    );

    expect(routes, hasLength(2));
    expect(routes[0].totalDistance, '4.2 km');
    expect(routes[0].totalDuration, '12 min');
    expect(routes[1].totalDistance, '4.8 km');
    expect(routes[1].totalDuration, '14 min');
    expect(routes.every((route) => route.polylinePoints.isNotEmpty), isTrue);
  });
}
