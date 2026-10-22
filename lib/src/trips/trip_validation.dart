import '../trip.dart';
import 'itinerary_day.dart';

class TripStoreException implements Exception {
  const TripStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TripDraft {
  const TripDraft({
    required this.titre,
    required this.destination,
    required this.pays,
    required this.dateDepart,
    required this.dateRetour,
    required this.budget,
    required this.nombreVoyageurs,
    required this.typeVoyage,
    required this.statut,
  });

  final String titre;
  final String destination;
  final String pays;
  final String dateDepart;
  final String dateRetour;
  final double budget;
  final int nombreVoyageurs;
  final String typeVoyage;
  final String statut;
}

class DayDraft {
  const DayDraft({
    required this.dayNumber,
    required this.date,
    required this.title,
    required this.description,
    required this.estimatedBudget,
    required this.notes,
  });

  final int dayNumber;
  final String date;
  final String title;
  final String description;
  final double estimatedBudget;
  final String notes;
}

class TripValidation {
  const TripValidation._();

  static String? validateTrip(TripDraft draft) {
    if (draft.titre.trim().isEmpty) {
      return 'Le titre est obligatoire.';
    }
    if (draft.destination.trim().isEmpty) {
      return 'La destination est obligatoire.';
    }
    if (draft.pays.trim().isEmpty) {
      return 'Le pays est obligatoire.';
    }
    final DateTime? depart = calendarDate(draft.dateDepart);
    final DateTime? retour = calendarDate(draft.dateRetour);
    if (depart == null || retour == null) {
      return 'Choisis une date de départ et une date de retour.';
    }
    if (retour.isBefore(depart)) {
      return 'La date de retour doit être après ou égale au départ.';
    }
    if (draft.budget < 0) {
      return 'Le budget doit être supérieur ou égal à zéro.';
    }
    if (draft.nombreVoyageurs < 1) {
      return 'Le nombre de voyageurs doit être supérieur à zéro.';
    }
    if (draft.typeVoyage.trim().isEmpty) {
      return 'Choisis un type de voyage.';
    }
    if (draft.statut.trim().isEmpty) {
      return 'Choisis un statut.';
    }
    return null;
  }

  static String? validateDay({
    required Trip trip,
    required DayDraft draft,
    required List<ItineraryDay> existing,
    int? editingId,
  }) {
    if (draft.dayNumber < 1) {
      return 'Le numéro du jour doit être supérieur à zéro.';
    }
    if (draft.title.trim().isEmpty) {
      return 'Le titre du programme est obligatoire.';
    }
    if (draft.estimatedBudget < 0) {
      return 'Le budget estimé doit être supérieur ou égal à zéro.';
    }
    final DateTime? date = calendarDate(draft.date);
    final DateTime? depart = calendarDate(trip.dateDepart);
    final DateTime? retour = calendarDate(trip.dateRetour);
    if (date == null || depart == null || retour == null) {
      return 'Choisis une date pour cette journée.';
    }
    if (date.isBefore(depart) || date.isAfter(retour)) {
      return 'La date doit être comprise entre le départ et le retour.';
    }
    final bool duplicate = existing.any(
      (ItineraryDay day) =>
          day.dayNumber == draft.dayNumber && day.id != editingId,
    );
    if (duplicate) {
      return 'Ce numéro de jour est déjà utilisé.';
    }
    return null;
  }
}
