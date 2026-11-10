import 'dart:convert';

import 'package:driftline/src/trips/api_config.dart';
import 'package:driftline/src/trips/gemini_service.dart';
import 'package:driftline/src/trips/open_meteo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('gemini parser validates structured itinerary JSON', () {
    const String raw = '''
{
  "summary": "Week-end Essaouira",
  "explanation": "Rythme calme orienté médina et plage.",
  "days": [
    {
      "day_number": 1,
      "date": "2026-06-01",
      "title": "Médina",
      "description": "Balade",
      "start_time": "09:00",
      "end_time": "18:00",
      "daily_budget": 120,
      "recommendations": "Eau et chapeau",
      "steps": [
        {
          "title": "Remparts",
          "description": "Vue mer",
          "start_time": "10:00",
          "end_time": "11:30",
          "estimated_cost": 0,
          "location": "Skala"
        }
      ]
    }
  ]
}
''';

    final GeneratedItinerary result =
        GeminiItineraryGenerator.parseGeneratedItinerary(raw);
    expect(result.days, hasLength(1));
    expect(result.days.first.title, 'Médina');
    expect(result.days.first.steps.single.title, 'Remparts');
    expect(result.explanation, contains('Rythme'));
  });

  test('gemini parser rejects empty payload', () {
    expect(
      () => GeminiItineraryGenerator.parseGeneratedItinerary('{"days":[]}'),
      throwsA(isA<GeminiException>()),
    );
  });

  test('gemini parser extracts JSON from markdown fences', () {
    const String raw = '''
Voici le plan:
```json
{"summary":"OK","days":[{"day_number":1,"date":"2026-06-01","title":"J1","description":"","daily_budget":10,"steps":[{"title":"A","start_time":"09:00","end_time":"10:00","estimated_cost":0}]}]}
```
''';
    final GeneratedItinerary result =
        GeminiItineraryGenerator.parseGeneratedItinerary(raw);
    expect(result.days.single.title, 'J1');
    expect(result.days.single.steps.single.title, 'A');
  });

  test('gemini reports unavailable when no compile-time config', () {
    // Without --dart-define in tests, config must stay unset.
    expect(TripApiConfig.isGeminiConfigured, isFalse);
    expect(TripApiConfig.usesProxy, isFalse);
    expect(TripApiConfig.proxyHeaders()['Content-Type'], 'application/json');
  });

  test('open-meteo omits forecast_days when using a date range', () async {
    Uri? forecastUri;
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.host.contains('geocoding')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'results': <Map<String, Object?>>[
              <String, Object?>{
                'name': 'Essaouira',
                'latitude': 31.51,
                'longitude': -9.77,
              },
            ],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      forecastUri = request.url;
      return http.Response(
        jsonEncode(<String, Object?>{
          'daily': <String, Object?>{
            'time': <String>['2026-11-12'],
            'temperature_2m_max': <double>[24.0],
            'temperature_2m_min': <double>[16.0],
            'weather_code': <int>[1],
            'precipitation_probability_max': <int>[10],
          },
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final OpenMeteoForecastService service =
        OpenMeteoForecastService(client: client);
    await service.load(
      destination: 'Essaouira',
      dateDepart: '2026-11-12',
      dateRetour: '2026-11-15',
    );

    expect(forecastUri, isNotNull);
    expect(forecastUri!.queryParameters.containsKey('forecast_days'), isFalse);
    expect(forecastUri!.queryParameters['start_date'], isNotEmpty);
    expect(forecastUri!.queryParameters['end_date'], isNotEmpty);
  });

  test('open-meteo service parses geocode and rich forecast', () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.host.contains('geocoding')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'results': <Map<String, Object?>>[
              <String, Object?>{
                'name': 'Essaouira',
                'latitude': 31.51,
                'longitude': -9.77,
              },
            ],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, Object?>{
          'current': <String, Object?>{
            'temperature_2m': 21.5,
            'apparent_temperature': 20.0,
            'relative_humidity_2m': 72,
            'weather_code': 95,
            'wind_speed_10m': 18.0,
          },
          'hourly': <String, Object?>{
            'time': <String>[
              '${DateTime.now().toIso8601String().substring(0, 13)}:00',
            ],
            'temperature_2m': <double>[21.0],
            'weather_code': <int>[95],
            'precipitation_probability': <int>[90],
          },
          'daily': <String, Object?>{
            'time': <String>['2026-06-01'],
            'temperature_2m_max': <double>[28.0],
            'temperature_2m_min': <double>[18.0],
            'weather_code': <int>[1],
            'precipitation_probability_max': <int>[10],
          },
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final OpenMeteoForecastService service =
        OpenMeteoForecastService(client: client);
    final WeatherForecastResult result = await service.load(
      destination: 'Essaouira',
      dateDepart: '2026-06-01',
      dateRetour: '2026-06-01',
    );

    expect(result.destination, 'Essaouira');
    expect(result.days.single.tempMax, 28);
    expect(result.current?.temperature, 21.5);
    expect(result.current?.humidity, 72);
    expect(result.current?.conditionLabel, 'Orage');
  });

  test('open-meteo surfaces network failures without fake data', () async {
    final MockClient client = MockClient((http.Request request) async {
      throw Exception('offline');
    });
    final OpenMeteoForecastService service =
        OpenMeteoForecastService(client: client);
    await expectLater(
      service.load(
        destination: 'Essaouira',
        dateDepart: '2026-06-01',
        dateRetour: '2026-06-01',
      ),
      throwsA(isA<OpenMeteoException>()),
    );
  });
}
