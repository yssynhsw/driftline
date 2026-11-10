import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class OpenRouteException implements Exception {
  const OpenRouteException(this.message);
  final String message;

  @override
  String toString() => message;
}

enum TravelProfile {
  footWalking,
  drivingCar,
}

extension TravelProfileApi on TravelProfile {
  String get apiPath {
    switch (this) {
      case TravelProfile.footWalking:
        return 'foot-walking';
      case TravelProfile.drivingCar:
        return 'driving-car';
    }
  }

  String get label {
    switch (this) {
      case TravelProfile.footWalking:
        return 'À pied';
      case TravelProfile.drivingCar:
        return 'Voiture';
    }
  }
}

class RoutePoint {
  const RoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class RouteLegInfo {
  const RouteLegInfo({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.profile,
    this.points = const <RoutePoint>[],
  });

  final double distanceMeters;
  final double durationSeconds;
  final TravelProfile profile;
  final List<RoutePoint> points;

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get durationLabel {
    final int total = durationSeconds.round();
    final int hours = total ~/ 3600;
    final int minutes = (total % 3600) ~/ 60;
    if (hours > 0) {
      return minutes == 0 ? '$hours h' : '$hours h $minutes min';
    }
    return '${minutes.clamp(1, 999)} min';
  }
}

/// Real OpenRouteService directions client. Requires OPENROUTESERVICE_API_KEY.
/// Never invents distance/duration on failure.
class OpenRouteService {
  OpenRouteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => TripApiConfig.isOpenRouteServiceConfigured;

  Future<RouteLegInfo> routeBetween({
    required double fromLon,
    required double fromLat,
    required double toLon,
    required double toLat,
    TravelProfile profile = TravelProfile.footWalking,
  }) async {
    final String? key = TripApiConfig.openRouteServiceApiKey;
    if (key == null) {
      throw const OpenRouteException(
        'OpenRouteService n’est pas configuré (OPENROUTESERVICE_API_KEY manquante).',
      );
    }

    final Uri uri = Uri.https(
      'api.openrouteservice.org',
      '/v2/directions/${profile.apiPath}/geojson',
    );
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': key,
            },
            body: jsonEncode(<String, Object?>{
              'coordinates': <List<double>>[
                <double>[fromLon, fromLat],
                <double>[toLon, toLat],
              ],
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const OpenRouteException(
        'Impossible de joindre OpenRouteService. Vérifie ta connexion.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const OpenRouteException(
        'Clé OpenRouteService refusée. Vérifie OPENROUTESERVICE_API_KEY.',
      );
    }
    if (response.statusCode != 200) {
      throw OpenRouteException(
        'OpenRouteService indisponible (${response.statusCode}).',
      );
    }

    final Object decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const OpenRouteException('Réponse OpenRouteService invalide.');
    }

    // GeoJSON FeatureCollection
    final List<dynamic>? features = decoded['features'] as List<dynamic>?;
    if (features != null && features.isNotEmpty) {
      final Map<String, dynamic> feature =
          features.first as Map<String, dynamic>;
      final Map<String, dynamic>? props =
          feature['properties'] as Map<String, dynamic>?;
      final Map<String, dynamic>? summary =
          props?['summary'] as Map<String, dynamic>?;
      final double? distance = (summary?['distance'] as num?)?.toDouble();
      final double? duration = (summary?['duration'] as num?)?.toDouble();
      if (distance == null || duration == null) {
        throw const OpenRouteException(
          'OpenRouteService n’a pas renvoyé de distance/durée.',
        );
      }
      final List<RoutePoint> points = _parseGeoJsonLine(
        feature['geometry'],
      );
      return RouteLegInfo(
        distanceMeters: distance,
        durationSeconds: duration,
        profile: profile,
        points: points,
      );
    }

    // Legacy JSON routes[] fallback
    final List<dynamic>? routes = decoded['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const OpenRouteException('Aucun itinéraire trouvé.');
    }
    final Map<String, dynamic> first = routes.first as Map<String, dynamic>;
    final Map<String, dynamic>? summary =
        first['summary'] as Map<String, dynamic>?;
    final double? distance = (summary?['distance'] as num?)?.toDouble();
    final double? duration = (summary?['duration'] as num?)?.toDouble();
    if (distance == null || duration == null) {
      throw const OpenRouteException(
        'OpenRouteService n’a pas renvoyé de distance/durée.',
      );
    }
    return RouteLegInfo(
      distanceMeters: distance,
      durationSeconds: duration,
      profile: profile,
    );
  }

  static List<RoutePoint> _parseGeoJsonLine(Object? geometry) {
    if (geometry is! Map<String, dynamic>) {
      return const <RoutePoint>[];
    }
    final Object? coords = geometry['coordinates'];
    if (coords is! List<dynamic>) {
      return const <RoutePoint>[];
    }
    final List<RoutePoint> points = <RoutePoint>[];
    for (final Object? pair in coords) {
      if (pair is! List<dynamic> || pair.length < 2) {
        continue;
      }
      final double lon = (pair[0] as num).toDouble();
      final double lat = (pair[1] as num).toDouble();
      points.add(RoutePoint(latitude: lat, longitude: lon));
    }
    return points;
  }
}
