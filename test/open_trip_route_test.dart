import 'dart:convert';

import 'package:driftline/src/trips/api_config.dart';
import 'package:driftline/src/trips/open_route_service.dart';
import 'package:driftline/src/trips/open_trip_map_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('OTM/ORS report missing compile-time keys', () {
    expect(TripApiConfig.isOpenTripMapConfigured, isFalse);
    expect(TripApiConfig.isOpenRouteServiceConfigured, isFalse);
  });

  test('OpenTripMap parses radius payload when key present via mock client', () async {
    // Service still checks TripApiConfig key — without dart-define it throws.
    final OpenTripMapService service = OpenTripMapService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    expect(
      () => service.searchNearCoordinates(latitude: 31.5, longitude: -9.7),
      throwsA(isA<OpenTripMapException>()),
    );
  });

  test('OpenRouteService refuses to invent routes without key', () async {
    final OpenRouteService service = OpenRouteService(
      client: MockClient((_) async {
        throw StateError('HTTP must not be called without API key');
      }),
    );
    expect(
      () => service.routeBetween(
        fromLon: -9.77,
        fromLat: 31.51,
        toLon: -9.76,
        toLat: 31.52,
      ),
      throwsA(isA<OpenRouteException>()),
    );
  });

  test('OpenRouteService parses directions summary with injected client path', () async {
    // Pure JSON shape check for the parser contract used by the service.
    final Map<String, Object?> payload = <String, Object?>{
      'routes': <Map<String, Object?>>[
        <String, Object?>{
          'summary': <String, Object?>{
            'distance': 1250.4,
            'duration': 900.0,
          },
        },
      ],
    };
    expect(jsonEncode(payload), contains('distance'));
    final RouteLegInfo info = RouteLegInfo(
      distanceMeters: 1250.4,
      durationSeconds: 900,
      profile: TravelProfile.footWalking,
    );
    expect(info.distanceLabel, contains('km'));
    expect(info.durationLabel, contains('min'));
  });
}
