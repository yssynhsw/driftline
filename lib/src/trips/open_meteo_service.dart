import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'trip_services.dart';

class WeatherCurrent {
  const WeatherCurrent({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    this.precipitationProbability,
  });

  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final int? precipitationProbability;

  String get conditionLabel => weatherLabel(weatherCode);
}

class WeatherHourlyForecast {
  const WeatherHourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    this.precipitationProbability,
  });

  final DateTime time;
  final double temperature;
  final int weatherCode;
  final int? precipitationProbability;

  String get conditionLabel => weatherLabel(weatherCode);
}

class WeatherDayForecast {
  const WeatherDayForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.weatherCode,
    required this.precipitationProbability,
  });

  final String date;
  final double tempMin;
  final double tempMax;
  final int weatherCode;
  final int? precipitationProbability;

  String get conditionLabel => weatherLabel(weatherCode);

  String get recommendation {
    if (precipitationProbability != null && precipitationProbability! >= 60) {
      return 'Pluie probable : privilégie les activités en intérieur.';
    }
    if (tempMax >= 32) {
      return 'Forte chaleur : visite tôt le matin et hydrate-toi.';
    }
    if (weatherCode <= 1) {
      return 'Conditions favorables pour les activités en extérieur.';
    }
    return 'Adapte le programme selon les conditions locales.';
  }
}

class WeatherForecastResult {
  const WeatherForecastResult({
    required this.destination,
    required this.latitude,
    required this.longitude,
    required this.days,
    required this.fetchedAt,
    this.limitedHorizon = false,
    this.current,
    this.hourly = const <WeatherHourlyForecast>[],
  });

  final String destination;
  final double latitude;
  final double longitude;
  final List<WeatherDayForecast> days;
  final DateTime fetchedAt;
  final bool limitedHorizon;
  final WeatherCurrent? current;
  final List<WeatherHourlyForecast> hourly;
}

class OpenMeteoException implements Exception {
  const OpenMeteoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Real Open-Meteo client: geocoding + current + hourly + daily forecasts.
class OpenMeteoForecastService implements DestinationForecast {
  OpenMeteoForecastService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  WeatherForecastResult? _cache;
  String? _cacheKey;

  @override
  bool get isAvailable => true;

  WeatherForecastResult? get lastResult => _cache;

  @override
  Future<WeatherForecastResult> load({
    required String destination,
    required String dateDepart,
    required String dateRetour,
  }) async {
    final ({double lat, double lon, String name}) place =
        await _geocode(destination);
    return loadAt(
      latitude: place.lat,
      longitude: place.lon,
      label: place.name,
      dateDepart: dateDepart,
      dateRetour: dateRetour,
    );
  }

  Future<WeatherForecastResult> loadAt({
    required double latitude,
    required double longitude,
    required String label,
    required String dateDepart,
    required String dateRetour,
  }) async {
    final String key =
        '$label|$latitude|$longitude|$dateDepart|$dateRetour';
    final WeatherForecastResult? cached = _cache;
    if (cached != null &&
        _cacheKey == key &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(minutes: 20)) {
      return cached;
    }

    // Open-Meteo returns HTTP 400 if forecast_days is combined with start/end.
    var range = _resolveForecastRange(dateDepart, dateRetour);
    final Uri uri = Uri.https('api.open-meteo.com', '/v1/forecast', <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation',
      'hourly':
          'temperature_2m,weather_code,precipitation_probability',
      'daily':
          'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
      'timezone': 'auto',
      'start_date': range.start,
      'end_date': range.end,
    });

    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const OpenMeteoException(
        'Impossible de joindre Open-Meteo. Vérifie ta connexion.',
      );
    }
    if (response.statusCode != 200) {
      // Fallback: plain 7-day forecast without an explicit date window.
      final Uri fallbackUri = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        <String, String>{
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'current':
              'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation',
          'hourly':
              'temperature_2m,weather_code,precipitation_probability',
          'daily':
              'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
          'timezone': 'auto',
          'forecast_days': '7',
        },
      );
      final int firstStatus = response.statusCode;
      try {
        response =
            await _client.get(fallbackUri).timeout(const Duration(seconds: 20));
      } catch (_) {
        throw OpenMeteoException(
          'Open-Meteo a renvoyé une erreur ($firstStatus).',
        );
      }
      if (response.statusCode != 200) {
        throw OpenMeteoException(
          'Open-Meteo a renvoyé une erreur (${response.statusCode}).',
        );
      }
      range = (start: range.start, end: range.end, clamped: true);
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final WeatherForecastResult parsed = parseForecastJson(
      json,
      destination: label,
      latitude: latitude,
      longitude: longitude,
      dateDepart: dateDepart,
      dateRetour: dateRetour,
    );
    final WeatherForecastResult result = range.clamped
        ? WeatherForecastResult(
            destination: parsed.destination,
            latitude: parsed.latitude,
            longitude: parsed.longitude,
            days: parsed.days,
            fetchedAt: parsed.fetchedAt,
            limitedHorizon: true,
            current: parsed.current,
            hourly: parsed.hourly,
          )
        : parsed;
    _cache = result;
    _cacheKey = key;
    return result;
  }

  /// Normalizes trip dates and clamps them to Open-Meteo's forecast window.
  static ({String start, String end, bool clamped}) _resolveForecastRange(
    String dateDepart,
    String dateRetour,
  ) {
    final DateTime today = DateTime.now();
    final DateTime minDay = DateTime(today.year, today.month, today.day);
    final DateTime maxDay = minDay.add(const Duration(days: 15));

    DateTime start = _parseFlexibleDate(dateDepart) ?? minDay;
    DateTime end = _parseFlexibleDate(dateRetour) ?? start;
    if (end.isBefore(start)) {
      end = start;
    }

    bool clamped = false;
    if (start.isBefore(minDay)) {
      start = minDay;
      clamped = true;
    }
    if (start.isAfter(maxDay)) {
      start = maxDay;
      clamped = true;
    }
    if (end.isAfter(maxDay)) {
      end = maxDay;
      clamped = true;
    }
    if (end.isBefore(start)) {
      end = start;
      clamped = true;
    }

    return (
      start: _isoDate(start),
      end: _isoDate(end),
      clamped: clamped,
    );
  }

  static DateTime? _parseFlexibleDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final DateTime? iso = DateTime.tryParse(value);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }
    final RegExpMatch? eu = RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})$')
        .firstMatch(value);
    if (eu != null) {
      final int day = int.parse(eu.group(1)!);
      final int month = int.parse(eu.group(2)!);
      final int year = int.parse(eu.group(3)!);
      return DateTime(year, month, day);
    }
    return null;
  }

  static String _isoDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static WeatherForecastResult parseForecastJson(
    Map<String, dynamic> json, {
    required String destination,
    required double latitude,
    required double longitude,
    required String dateDepart,
    required String dateRetour,
  }) {
    final Map<String, dynamic>? daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) {
      throw const OpenMeteoException('Réponse météo incomplète.');
    }

    final List<dynamic> dates = (daily['time'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> max =
        (daily['temperature_2m_max'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> min =
        (daily['temperature_2m_min'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> codes = (daily['weather_code'] as List<dynamic>?) ??
        (daily['weathercode'] as List<dynamic>?) ??
        <dynamic>[];
    final List<dynamic> rain =
        (daily['precipitation_probability_max'] as List<dynamic>?) ??
            <dynamic>[];

    final List<WeatherDayForecast> days = <WeatherDayForecast>[];
    for (int i = 0; i < dates.length; i++) {
      days.add(
        WeatherDayForecast(
          date: '${dates[i]}',
          tempMax: (max.length > i ? max[i] as num? : null)?.toDouble() ?? 0,
          tempMin: (min.length > i ? min[i] as num? : null)?.toDouble() ?? 0,
          weatherCode:
              (codes.length > i ? codes[i] as num? : null)?.toInt() ?? 0,
          precipitationProbability:
              rain.length > i ? (rain[i] as num?)?.toInt() : null,
        ),
      );
    }

    WeatherCurrent? current;
    final Map<String, dynamic>? currentJson =
        json['current'] as Map<String, dynamic>?;
    if (currentJson != null) {
      current = WeatherCurrent(
        temperature:
            (currentJson['temperature_2m'] as num?)?.toDouble() ?? 0,
        feelsLike:
            (currentJson['apparent_temperature'] as num?)?.toDouble() ?? 0,
        humidity:
            (currentJson['relative_humidity_2m'] as num?)?.toInt() ?? 0,
        windSpeed:
            (currentJson['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        weatherCode: (currentJson['weather_code'] as num?)?.toInt() ?? 0,
        precipitationProbability: null,
      );
    }

    final List<WeatherHourlyForecast> hourly = <WeatherHourlyForecast>[];
    final Map<String, dynamic>? hourlyJson =
        json['hourly'] as Map<String, dynamic>?;
    if (hourlyJson != null) {
      final List<dynamic> times =
          (hourlyJson['time'] as List<dynamic>?) ?? <dynamic>[];
      final List<dynamic> temps =
          (hourlyJson['temperature_2m'] as List<dynamic>?) ?? <dynamic>[];
      final List<dynamic> hCodes =
          (hourlyJson['weather_code'] as List<dynamic>?) ?? <dynamic>[];
      final List<dynamic> hRain =
          (hourlyJson['precipitation_probability'] as List<dynamic>?) ??
              <dynamic>[];
      final DateTime now = DateTime.now();
      for (int i = 0; i < times.length; i++) {
        final DateTime? t = DateTime.tryParse('${times[i]}');
        if (t == null) {
          continue;
        }
        if (t.isBefore(now.subtract(const Duration(hours: 1)))) {
          continue;
        }
        hourly.add(
          WeatherHourlyForecast(
            time: t,
            temperature:
                (temps.length > i ? temps[i] as num? : null)?.toDouble() ?? 0,
            weatherCode:
                (hCodes.length > i ? hCodes[i] as num? : null)?.toInt() ?? 0,
            precipitationProbability:
                hRain.length > i ? (hRain[i] as num?)?.toInt() : null,
          ),
        );
        if (hourly.length >= 24) {
          break;
        }
      }
    }

    bool limited = days.isEmpty;
    try {
      final int expected =
          DateTime.parse(dateRetour).difference(DateTime.parse(dateDepart)).inDays +
              1;
      limited = days.length < expected;
    } catch (_) {
      limited = days.isEmpty;
    }

    return WeatherForecastResult(
      destination: destination,
      latitude: latitude,
      longitude: longitude,
      days: days,
      fetchedAt: DateTime.now(),
      limitedHorizon: limited,
      current: current,
      hourly: hourly,
    );
  }

  Future<({double lat, double lon, String name})> _geocode(
    String destination,
  ) async {
    final List<String> queries = _geocodeQueries(destination);
    Object? lastError;
    for (final String query in queries) {
      try {
        final ({double lat, double lon, String name})? hit =
            await _geocodeOnce(query);
        if (hit != null) {
          return hit;
        }
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError is OpenMeteoException) {
      throw lastError;
    }
    throw OpenMeteoException(
      'Destination introuvable pour la météo : $destination',
    );
  }

  Future<({double lat, double lon, String name})?> _geocodeOnce(
    String query,
  ) async {
    final Uri uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      <String, String>{
        'name': query,
        'count': '1',
        'language': 'fr',
        'format': 'json',
      },
    );
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const OpenMeteoException(
        'Géocodage impossible. Vérifie ta connexion.',
      );
    }
    if (response.statusCode != 200) {
      throw OpenMeteoException(
        'Géocodage Open-Meteo en échec (${response.statusCode}).',
      );
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic>? results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return null;
    }
    final Map<String, dynamic> first = results.first as Map<String, dynamic>;
    return (
      lat: (first['latitude'] as num).toDouble(),
      lon: (first['longitude'] as num).toDouble(),
      name: '${first['name']}',
    );
  }

  /// Builds several geocode candidates from free-form trip destinations.
  static List<String> _geocodeQueries(String destination) {
    final String raw = destination.trim();
    if (raw.isEmpty) {
      return const <String>[];
    }

    final LinkedHashSet<String> queries = LinkedHashSet<String>();
    void add(String value) {
      final String cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (cleaned.length >= 2) {
        queries.add(cleaned);
      }
    }

    add(raw);
    if (raw.contains(',')) {
      add(raw.split(',').first);
      add(raw.split(',').last);
    }

    final String lower = raw.toLowerCase();
    const List<String> known = <String>[
      'essaouira',
      'marrakech',
      'marrakesh',
      'chefchaouen',
      'casablanca',
      'agadir',
      'rabat',
      'fes',
      'fès',
      'paris',
      'rome',
      'istanbul',
      'dubai',
      'dubaï',
      'tokyo',
      'maldives',
      'barcelone',
      'barcelona',
      'londres',
      'london',
      'new york',
      'zurich',
    ];
    for (final String city in known) {
      if (lower.contains(city)) {
        add(city);
      }
    }

    final String stripped = raw
        .replaceAll(
          RegExp(
            r'\b(week-?end|voyage|trip|séjour|sejour|à|a|au|aux|en|de|du|des)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    add(stripped);

    return queries.toList();
  }
}

IconDataWeather weatherIcon(int code) {
  if (code == 0) {
    return IconDataWeather.clear;
  }
  if (code <= 3) {
    return IconDataWeather.partlyCloudy;
  }
  if (code <= 48) {
    return IconDataWeather.fog;
  }
  if (code <= 67) {
    return IconDataWeather.rain;
  }
  if (code <= 77) {
    return IconDataWeather.snow;
  }
  if (code <= 82) {
    return IconDataWeather.rain;
  }
  if (code >= 95) {
    return IconDataWeather.thunder;
  }
  return IconDataWeather.cloudy;
}

enum IconDataWeather { clear, partlyCloudy, cloudy, fog, rain, snow, thunder }

String weatherLabel(int code) {
  if (code == 0) {
    return 'Ciel clair';
  }
  if (code <= 3) {
    return 'Partiellement nuageux';
  }
  if (code <= 48) {
    return 'Brouillard';
  }
  if (code <= 57) {
    return 'Bruine';
  }
  if (code <= 67) {
    return 'Pluie';
  }
  if (code <= 77) {
    return 'Neige';
  }
  if (code <= 82) {
    return 'Averses';
  }
  if (code <= 86) {
    return 'Averses de neige';
  }
  if (code >= 95) {
    return 'Orage';
  }
  return 'Variable';
}
