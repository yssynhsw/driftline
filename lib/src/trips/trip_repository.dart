import '../store.dart';
import 'itinerary_day.dart';
import 'trip_database.dart';
import 'trip_validation.dart';

/// Trip and itinerary CRUD. Reads and writes the database opened by [UserStore].
class TripRepository {
  const TripRepository(this._database);

  final TripDatabase _database;

  static Future<TripRepository> attached() async {
    return TripRepository(TripDatabase(await UserStore.instance.connection()));
  }

  Future<Trip> createTrip({
    required int userId,
    required TripDraft draft,
  }) async {
    _checkTrip(draft);
    return _database.insertTrip(userId: userId, draft: draft);
  }

  Future<List<Trip>> getAllTrips(int userId) {
    return _database.tripsForUser(userId);
  }

  /// Inserts the demo trips once per account. A title already present is left as-is.
  Future<void> ensureExampleTrips(int userId) async {
    final List<Trip> current = await getAllTrips(userId);
    final Set<String> titles = current.map((Trip trip) => trip.titre).toSet();
    for (final _ExampleTrip example in _exampleTrips) {
      if (titles.contains(example.draft.titre)) {
        continue;
      }
      final Trip trip = await createTrip(userId: userId, draft: example.draft);
      for (final DayDraft day in example.days) {
        await createItineraryDay(userId: userId, tripId: trip.id, draft: day);
      }
    }
  }

  Future<Trip?> getTripById({required int id, required int userId}) async {
    final Trip? trip = await _database.tripById(id);
    if (trip == null || trip.userId != userId) {
      return null;
    }
    return trip;
  }

  Future<Trip> updateTrip({
    required int id,
    required int userId,
    required TripDraft draft,
  }) async {
    await _ownedTrip(id, userId);
    _checkTrip(draft);
    return _database.updateTrip(id: id, draft: draft);
  }

  Future<void> deleteTrip({required int id, required int userId}) async {
    await _ownedTrip(id, userId);
    await _database.deleteTrip(id);
  }

  Future<ItineraryDay> createItineraryDay({
    required int userId,
    required int tripId,
    required DayDraft draft,
  }) async {
    final Trip trip = await _ownedTrip(tripId, userId);
    await _checkDay(trip, draft);
    return _database.insertDay(tripId: tripId, draft: draft);
  }

  Future<List<ItineraryDay>> getDaysByTripId({
    required int tripId,
    required int userId,
  }) async {
    await _ownedTrip(tripId, userId);
    return _database.daysForTrip(tripId);
  }

  Future<ItineraryDay> updateItineraryDay({
    required int userId,
    required int dayId,
    required DayDraft draft,
  }) async {
    final ItineraryDay? current = await _database.dayById(dayId);
    if (current == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    final Trip trip = await _ownedTrip(current.tripId, userId);
    await _checkDay(trip, draft, editingId: dayId);
    return _database.updateDay(id: dayId, draft: draft);
  }

  Future<void> deleteItineraryDay({
    required int userId,
    required int dayId,
  }) async {
    final ItineraryDay? current = await _database.dayById(dayId);
    if (current == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    await _ownedTrip(current.tripId, userId);
    await _database.deleteDay(dayId);
  }

  void _checkTrip(TripDraft draft) {
    final String? error = TripValidation.validateTrip(draft);
    if (error != null) {
      throw TripStoreException(error);
    }
  }

  Future<void> _checkDay(
    Trip trip,
    DayDraft draft, {
    int? editingId,
  }) async {
    final List<ItineraryDay> existing = await _database.daysForTrip(trip.id);
    final String? error = TripValidation.validateDay(
      trip: trip,
      draft: draft,
      existing: existing,
      editingId: editingId,
    );
    if (error != null) {
      throw TripStoreException(error);
    }
  }

  Future<Trip> _ownedTrip(int id, int userId) async {
    final Trip? trip = await getTripById(id: id, userId: userId);
    if (trip == null) {
      throw const TripStoreException('Voyage introuvable.');
    }
    return trip;
  }
}

class _ExampleTrip {
  const _ExampleTrip(this.draft, this.days);

  final TripDraft draft;
  final List<DayDraft> days;
}

const List<_ExampleTrip> _exampleTrips = <_ExampleTrip>[
  _ExampleTrip(
    TripDraft(
      titre: 'Week-end à Essaouira',
      destination: 'Essaouira',
      pays: 'Morocco',
      dateDepart: '2026-11-12',
      dateRetour: '2026-11-15',
      budget: 1800,
      nombreVoyageurs: 2,
      typeVoyage: 'Détente',
      statut: 'Planned',
    ),
    <DayDraft>[
      DayDraft(
        dayNumber: 1,
        date: '2026-11-12',
        title: 'Médina et remparts',
        description: 'Arrivée, balade dans la médina et coucher de soleil sur les remparts.',
        estimatedBudget: 350,
        notes: 'Réserver un riad près du port.',
      ),
      DayDraft(
        dayNumber: 2,
        date: '2026-11-13',
        title: 'Plage et port',
        description: 'Matinée à la plage, déjeuner au port puis quartier des artisans.',
        estimatedBudget: 280,
        notes: '',
      ),
      DayDraft(
        dayNumber: 3,
        date: '2026-11-14',
        title: 'Journée libre',
        description: 'Marché, café et dernière promenade avant le retour.',
        estimatedBudget: 220,
        notes: 'Départ le lendemain matin.',
      ),
    ],
  ),
  _ExampleTrip(
    TripDraft(
      titre: 'Marrakech en famille',
      destination: 'Marrakech',
      pays: 'Morocco',
      dateDepart: '2026-10-20',
      dateRetour: '2026-10-24',
      budget: 4200,
      nombreVoyageurs: 4,
      typeVoyage: 'Famille',
      statut: 'Active',
    ),
    <DayDraft>[
      DayDraft(
        dayNumber: 1,
        date: '2026-10-20',
        title: 'Jardins et piscine',
        description: 'Installation à l’hôtel et après-midi aux jardins.',
        estimatedBudget: 600,
        notes: 'Prévoir de l’eau pour les enfants.',
      ),
      DayDraft(
        dayNumber: 2,
        date: '2026-10-22',
        title: 'Souks et place Jemaa el-Fna',
        description: 'Visite des souks en fin de journée et dîner sur la place.',
        estimatedBudget: 700,
        notes: '',
      ),
    ],
  ),
  _ExampleTrip(
    TripDraft(
      titre: 'Randonnée à Chefchaouen',
      destination: 'Chefchaouen',
      pays: 'Morocco',
      dateDepart: '2026-09-02',
      dateRetour: '2026-09-05',
      budget: 1500,
      nombreVoyageurs: 2,
      typeVoyage: 'Aventure',
      statut: 'Done',
    ),
    <DayDraft>[
      DayDraft(
        dayNumber: 1,
        date: '2026-09-02',
        title: 'Médina bleue',
        description: 'Montée dans la médina et premiers points de vue.',
        estimatedBudget: 250,
        notes: '',
      ),
      DayDraft(
        dayNumber: 2,
        date: '2026-09-03',
        title: 'Sentier de la montagne',
        description: 'Randonnée vers le refuge et retour en fin d’après-midi.',
        estimatedBudget: 180,
        notes: 'Départ tôt.',
      ),
    ],
  ),
];
