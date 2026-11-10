import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class OpenTripMapException implements Exception {
  const OpenTripMapException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TouristPlace {
  const TouristPlace({
    required this.xid,
    required this.name,
    required this.kinds,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
    this.description = '',
    this.rate,
  });

  final String xid;
  final String name;
  final String kinds;
  final double latitude;
  final double longitude;
  final double? distanceMeters;
  final String description;
  final String? rate;

  String get categoryLabel {
    if (kinds.trim().isEmpty) {
      return 'Lieu';
    }
    return kinds.split(',').first.trim().replaceAll('_', ' ');
  }
}

/// Real OpenTripMap client (radius + xid detail). Requires OPENTRIPMAP_API_KEY.
class OpenTripMapService {
  OpenTripMapService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => TripApiConfig.isOpenTripMapConfigured;

  Future<({double lat, double lon})> geocodeDestination({
    required String destination,
    String country = '',
  }) {
    return _geocode(
      country.trim().isEmpty
          ? destination.trim()
          : '${destination.trim()}, ${country.trim()}',
    );
  }

  Future<List<TouristPlace>> searchNearDestination({
    required String destination,
    required String country,
    int radiusMeters = 3000,
    int limit = 12,
    String kinds = '',
  }) async {
    final ({double lat, double lon}) coords = await geocodeDestination(
      destination: destination,
      country: country,
    );
    return searchNearCoordinates(
      latitude: coords.lat,
      longitude: coords.lon,
      radiusMeters: radiusMeters,
      limit: limit,
      kinds: kinds,
    );
  }

  Future<List<TouristPlace>> searchNearCoordinates({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
    int limit = 12,
    String kinds = '',
  }) async {
    final String? key = TripApiConfig.openTripMapApiKey;
    if (key == null) {
      throw const OpenTripMapException(
        'OpenTripMap n’est pas configuré (OPENTRIPMAP_API_KEY manquante).',
      );
    }

    final Map<String, String> query = <String, String>{
      'radius': '$radiusMeters',
      'lon': longitude.toString(),
      'lat': latitude.toString(),
      'rate': '2',
      'format': 'json',
      'limit': '$limit',
      'apikey': key,
    };
    final String trimmedKinds = kinds.trim();
    if (trimmedKinds.isNotEmpty) {
      query['kinds'] = trimmedKinds;
    }

    final Uri uri = Uri.https(
      'api.opentripmap.com',
      '/0.1/en/places/radius',
      query,
    );

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const OpenTripMapException(
        'Impossible de joindre OpenTripMap. Vérifie ta connexion.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const OpenTripMapException(
        'Clé OpenTripMap refusée. Vérifie OPENTRIPMAP_API_KEY.',
      );
    }
    if (response.statusCode != 200) {
      throw OpenTripMapException(
        'OpenTripMap indisponible (${response.statusCode}).',
      );
    }

    final Object decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw const OpenTripMapException('Réponse OpenTripMap invalide.');
    }

    final List<TouristPlace> places = <TouristPlace>[];
    for (final Object? raw in decoded) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final String name = '${raw['name'] ?? ''}'.trim();
      final String xid = '${raw['xid'] ?? ''}'.trim();
      if (name.isEmpty || xid.isEmpty) {
        continue;
      }
      final Object? point = raw['point'];
      double lat = latitude;
      double lon = longitude;
      if (point is Map<String, dynamic>) {
        lat = (point['lat'] as num?)?.toDouble() ?? lat;
        lon = (point['lon'] as num?)?.toDouble() ?? lon;
      }
      places.add(
        TouristPlace(
          xid: xid,
          name: name,
          kinds: '${raw['kinds'] ?? ''}',
          latitude: lat,
          longitude: lon,
          distanceMeters: (raw['dist'] as num?)?.toDouble(),
          rate: raw['rate']?.toString(),
        ),
      );
    }
    return places;
  }

  Future<TouristPlace> loadDetails(TouristPlace place) async {
    final String? key = TripApiConfig.openTripMapApiKey;
    if (key == null) {
      throw const OpenTripMapException(
        'OpenTripMap n’est pas configuré (OPENTRIPMAP_API_KEY manquante).',
      );
    }
    final Uri uri = Uri.https(
      'api.opentripmap.com',
      '/0.1/en/places/xid/${place.xid}',
      <String, String>{'apikey': key},
    );
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const OpenTripMapException(
        'Impossible de joindre OpenTripMap pour le détail du lieu.',
      );
    }
    if (response.statusCode != 200) {
      return place;
    }
    final Object decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return place;
    }
    String description = '';
    final Object? info = decoded['info'];
    if (info is Map<String, dynamic>) {
      description = '${info['descr'] ?? ''}'.trim();
    }
    final Object? extracts = decoded['wikipedia_extracts'];
    if (description.isEmpty && extracts is Map<String, dynamic>) {
      description = '${extracts['text'] ?? ''}'.trim();
    }
    final Object? point = decoded['point'];
    double lat = place.latitude;
    double lon = place.longitude;
    if (point is Map<String, dynamic>) {
      lat = (point['lat'] as num?)?.toDouble() ?? lat;
      lon = (point['lon'] as num?)?.toDouble() ?? lon;
    }
    return TouristPlace(
      xid: place.xid,
      name: '${decoded['name'] ?? place.name}'.trim(),
      kinds: '${decoded['kinds'] ?? place.kinds}',
      latitude: lat,
      longitude: lon,
      distanceMeters: place.distanceMeters,
      description: description,
      rate: decoded['rate']?.toString() ?? place.rate,
    );
  }

  Future<({double lat, double lon})> _geocode(String query) async {
    final Uri uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      <String, String>{
        'name': query,
        'count': '1',
        'language': 'en',
        'format': 'json',
      },
    );
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const OpenTripMapException(
        'Géocodage impossible pour cette destination.',
      );
    }
    if (response.statusCode != 200) {
      throw const OpenTripMapException(
        'Géocodage Open-Meteo indisponible.',
      );
    }
    final Object decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const OpenTripMapException('Réponse géocodage invalide.');
    }
    final List<dynamic>? results = decoded['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw const OpenTripMapException(
        'Aucune coordonnée trouvée pour cette destination.',
      );
    }
    final Map<String, dynamic> first = results.first as Map<String, dynamic>;
    return (
      lat: (first['latitude'] as num).toDouble(),
      lon: (first['longitude'] as num).toDouble(),
    );
  }
}
