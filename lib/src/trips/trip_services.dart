import 'trip_validation.dart';

/// Future Gemini integration. This phase never calls a network generator.
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
    throw UnsupportedError('Génération IA bientôt disponible.');
  }
}

/// Future Open-Meteo integration. No forecast is fetched in this phase.
abstract class DestinationForecast {
  bool get isAvailable;

  Future<void> load({
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
  Future<void> load({
    required String destination,
    required String dateDepart,
    required String dateRetour,
  }) {
    throw UnsupportedError('Prévisions météo bientôt disponibles.');
  }
}
