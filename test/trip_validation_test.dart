import 'package:driftline/src/trip.dart';
import 'package:driftline/src/trips/itinerary_day.dart';
import 'package:driftline/src/trips/trip_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a return date can match the departure date', () {
    expect(TripValidation.validateTrip(_draft(dateRetour: '2026-06-01')), isNull);
    final Trip trip = _trip();
    expect(trip.durationDays, 1);
  });

  test('a return date before departure is rejected', () {
    expect(
      TripValidation.validateTrip(_draft(dateRetour: '2026-05-30')),
      'La date de retour doit être après ou égale au départ.',
    );
  });

  test('budget and traveller count must stay in range', () {
    expect(
      TripValidation.validateTrip(_draft(budget: -5)),
      'Le budget doit être supérieur ou égal à zéro.',
    );
    expect(
      TripValidation.validateTrip(_draft(nombreVoyageurs: 0)),
      'Le nombre de voyageurs doit être supérieur à zéro.',
    );
  });

  test('a day must fall inside the trip and keep a unique number', () {
    final Trip trip = _trip(dateRetour: '2026-06-03');
    final List<ItineraryDay> existing = <ItineraryDay>[
      _day(id: 4, dayNumber: 1),
    ];

    expect(
      TripValidation.validateDay(
        trip: trip,
        draft: _dayDraft(date: '2026-06-04'),
        existing: existing,
      ),
      'La date doit être comprise entre le départ et le retour.',
    );
    expect(
      TripValidation.validateDay(
        trip: trip,
        draft: _dayDraft(dayNumber: 1),
        existing: existing,
      ),
      'Ce numéro de jour est déjà utilisé.',
    );
    expect(
      TripValidation.validateDay(
        trip: trip,
        draft: _dayDraft(dayNumber: 1),
        existing: existing,
        editingId: 4,
      ),
      isNull,
    );
  });
}

TripDraft _draft({
  String dateRetour = '2026-06-01',
  double budget = 1200,
  int nombreVoyageurs = 2,
}) {
  return TripDraft(
    titre: 'Essaouira',
    destination: 'Essaouira',
    pays: 'Morocco',
    dateDepart: '2026-06-01',
    dateRetour: dateRetour,
    budget: budget,
    nombreVoyageurs: nombreVoyageurs,
    typeVoyage: 'Détente',
    statut: 'Planned',
  );
}

Trip _trip({String dateRetour = '2026-06-01'}) {
  return Trip(
    id: 1,
    titre: 'Essaouira',
    destination: 'Essaouira',
    pays: 'Morocco',
    dateDepart: '2026-06-01',
    dateRetour: dateRetour,
    budget: 1200,
    nombreVoyageurs: 2,
    typeVoyage: 'Détente',
    statut: 'Planned',
    userId: 7,
    dateCreation: DateTime.utc(2026, 5, 1),
  );
}

ItineraryDay _day({required int id, required int dayNumber}) {
  return ItineraryDay(
    id: id,
    tripId: 1,
    dayNumber: dayNumber,
    date: '2026-06-01',
    title: 'Médina',
    description: 'Remparts',
    estimatedBudget: 80,
    notes: '',
  );
}

DayDraft _dayDraft({int dayNumber = 2, String date = '2026-06-02'}) {
  return DayDraft(
    dayNumber: dayNumber,
    date: date,
    title: 'Plage',
    description: '',
    estimatedBudget: 40,
    notes: '',
  );
}
