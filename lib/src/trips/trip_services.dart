import 'package:http/http.dart' as http;

import 'gemini_service.dart';
import 'open_meteo_service.dart';
import 'trip_validation.dart';

export 'gemini_service.dart';
export 'open_meteo_service.dart';

/// Contract for Gemini itinerary generation.
abstract class ItineraryGenerator {
  bool get isAvailable;

  Future<List<DayDraft>> generate({
    required String destination,
    required String dateDepart,
    required String dateRetour,
    required double budget,
    required String preferences,
  });
}

class UnavailableItineraryGenerator implements ItineraryGenerator {
  const UnavailableItineraryGenerator();

  @override
  bool get isAvailable => false;

  @override
  Future<List<DayDraft>> generate({
    required String destination,
    required String dateDepart,
    required String dateRetour,
    required double budget,
    required String preferences,
  }) {
    throw UnsupportedError('Génération IA indisponible.');
  }
}

/// Contract for destination weather forecasts.
abstract class DestinationForecast {
  bool get isAvailable;

  Future<WeatherForecastResult> load({
    required String destination,
    required String dateDepart,
    required String dateRetour,
  });
}

class UnavailableDestinationForecast implements DestinationForecast {
  const UnavailableDestinationForecast();

  @override
  bool get isAvailable => false;

  @override
  Future<WeatherForecastResult> load({
    required String destination,
    required String dateDepart,
    required String dateRetour,
  }) {
    throw UnsupportedError('Prévisions météo indisponibles.');
  }
}

/// Default wired services for Gestion 2.
class TripServiceLocator {
  TripServiceLocator._();

  static ItineraryGenerator itineraryGenerator({http.Client? client}) {
    return GeminiItineraryGenerator(client: client);
  }

  static DestinationForecast destinationForecast({http.Client? client}) {
    return OpenMeteoForecastService(client: client);
  }
}
