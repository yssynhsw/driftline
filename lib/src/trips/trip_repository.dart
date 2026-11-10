import '../store.dart';
import 'budget_engine.dart';
import 'conflict_service.dart';
import 'destination_cover.dart';
import 'destination_cover_service.dart';
import 'gallery_photo.dart';
import 'itinerary_day.dart';
import 'itinerary_step.dart';
import 'trip_database.dart';
import 'trip_stats.dart';
import 'trip_validation.dart';

/// Trip and itinerary CRUD over the shared sqflite DB opened by [UserStore].
///
/// Always attach with [attached] so Gestion 2 writes into `driftline.db`
/// (same DatabaseService as Gestion 1), never a separate file.
class TripRepository {
  TripRepository(
    this._database, {
    DestinationCoverService? coverService,
  }) : _coverService = coverService ?? DestinationCoverService();

  final TripDatabase _database;
  final DestinationCoverService _coverService;

  static Future<TripRepository> attached() async {
    return TripRepository(TripDatabase(await UserStore.instance.connection()));
  }

  Future<Trip> createTrip({
    required int userId,
    required TripDraft draft,
  }) async {
    _checkTrip(draft);
    final DestinationCoverResult cover = await _coverService.resolve(
      destination: draft.destination,
      country: draft.pays,
    );
    final List<GalleryPhoto> gallery = await _coverService.resolveGallery(
      destination: draft.destination,
      country: draft.pays,
      minCount: 5,
      maxCount: 5,
    );
    return _database.insertTrip(
      userId: userId,
      draft: draft,
      coverPhotoUrl: cover.imageUrl,
      coverPhotoCredit: cover.credit,
      coverMatchLevel: cover.matchLevel,
      galleryPhotosJson: GalleryPhoto.encodeList(gallery),
    );
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
    final Trip current = await _ownedTrip(id, userId);
    _checkTrip(draft);
    final bool destinationChanged =
        current.destination.trim().toLowerCase() !=
            draft.destination.trim().toLowerCase() ||
        current.pays.trim().toLowerCase() != draft.pays.trim().toLowerCase();
    if (destinationChanged ||
        current.coverPhotoUrl.trim().isEmpty ||
        current.galleryPhotos.isEmpty) {
      final DestinationCoverResult cover = await _coverService.resolve(
        destination: draft.destination,
        country: draft.pays,
      );
      final List<GalleryPhoto> gallery = await _coverService.resolveGallery(
        destination: draft.destination,
        country: draft.pays,
        minCount: 5,
        maxCount: 5,
        forceRefresh: destinationChanged,
      );
      return _database.updateTrip(
        id: id,
        draft: draft,
        coverPhotoUrl: cover.imageUrl,
        coverPhotoCredit: cover.credit,
        coverMatchLevel: cover.matchLevel,
        galleryPhotosJson: GalleryPhoto.encodeList(gallery),
      );
    }
    return _database.updateTrip(id: id, draft: draft);
  }

  Future<Trip> ensureCoverPhoto({
    required int id,
    required int userId,
  }) async {
    final Trip trip = await _ownedTrip(id, userId);
    if (trip.coverPhotoUrl.trim().isNotEmpty) {
      return trip;
    }
    final DestinationCoverResult cover = await _coverService.resolve(
      destination: trip.destination,
      country: trip.pays,
    );
    return _database.updateCoverPhoto(
      id: id,
      coverPhotoUrl: cover.imageUrl,
      coverPhotoCredit: cover.credit,
      coverMatchLevel: cover.matchLevel,
    );
  }

  Future<Trip> ensureGalleryPhotos({
    required int id,
    required int userId,
    bool forceRefresh = false,
  }) async {
    final Trip trip = await _ownedTrip(id, userId);
    final bool hasGenericOnly = trip.galleryPhotos.isNotEmpty &&
        trip.galleryPhotos.every(
          (GalleryPhoto photo) =>
              photo.representativeOnly ||
              photo.matchLevel == DestinationCoverResult.levelFallback ||
              photo.credit.toLowerCase().contains('unsplash'),
        );
    if (!forceRefresh &&
        !hasGenericOnly &&
        trip.galleryPhotos.length >= 5) {
      return trip;
    }
    final List<GalleryPhoto> gallery = await _coverService.resolveGallery(
      destination: trip.destination,
      country: trip.pays,
      minCount: 5,
      maxCount: 5,
      forceRefresh: forceRefresh || hasGenericOnly,
    );
    if (gallery.isEmpty) {
      return trip;
    }
    return _database.updateGalleryPhotos(
      id: id,
      galleryPhotosJson: GalleryPhoto.encodeList(gallery),
    );
  }

  Future<DestinationCoverResult> previewCover({
    required String destination,
    String country = '',
    bool forceRefresh = false,
  }) {
    return _coverService.resolve(
      destination: destination,
      country: country,
      forceRefresh: forceRefresh,
    );
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
    bool syncSteps = false,
  }) async {
    final ItineraryDay? current = await _database.dayById(dayId);
    if (current == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    final Trip trip = await _ownedTrip(current.tripId, userId);
    await _checkDay(trip, draft, editingId: dayId);
    return _database.updateDay(
      id: dayId,
      draft: draft,
      syncSteps: syncSteps,
    );
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

  Future<void> reorderItineraryDays({
    required int userId,
    required int tripId,
    required List<int> orderedDayIds,
  }) async {
    await _ownedTrip(tripId, userId);
    await _database.reorderDays(tripId: tripId, orderedDayIds: orderedDayIds);
  }

  Future<List<ItineraryStep>> getStepsForDay({
    required int userId,
    required int dayId,
  }) async {
    final ItineraryDay? day = await _database.dayById(dayId);
    if (day == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    await _ownedTrip(day.tripId, userId);
    return _database.stepsForDay(dayId);
  }

  Future<List<ItineraryStep>> getStepsForTrip({
    required int userId,
    required int tripId,
  }) async {
    await _ownedTrip(tripId, userId);
    return _database.stepsForTrip(tripId);
  }

  Future<void> saveDaySteps({
    required int userId,
    required int dayId,
    required List<StepDraft> steps,
  }) async {
    final ItineraryDay? day = await _database.dayById(dayId);
    if (day == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    await _ownedTrip(day.tripId, userId);
    for (final StepDraft step in steps) {
      final String? error = TripValidation.validateStep(step);
      if (error != null) {
        throw TripStoreException(error);
      }
    }
    await _database.replaceDaySteps(dayId: dayId, steps: steps);
  }

  Future<ItineraryStep> createStep({
    required int userId,
    required int dayId,
    required StepDraft draft,
  }) async {
    final ItineraryDay? day = await _database.dayById(dayId);
    if (day == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    await _ownedTrip(day.tripId, userId);
    final String? error = TripValidation.validateStep(draft);
    if (error != null) {
      throw TripStoreException(error);
    }
    return _database.insertStep(dayId: dayId, draft: draft);
  }

  Future<ItineraryStep> updateStep({
    required int userId,
    required int stepId,
    required StepDraft draft,
  }) async {
    final ItineraryStep? current = await _database.stepById(stepId);
    if (current == null) {
      throw const TripStoreException('Activité introuvable.');
    }
    final ItineraryDay? day = await _database.dayById(current.dayId);
    if (day == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    await _ownedTrip(day.tripId, userId);
    final String? error = TripValidation.validateStep(draft);
    if (error != null) {
      throw TripStoreException(error);
    }
    return _database.updateStep(id: stepId, draft: draft);
  }

  Future<void> deleteStep({
    required int userId,
    required int stepId,
  }) async {
    final ItineraryStep? current = await _database.stepById(stepId);
    if (current == null) {
      throw const TripStoreException('Activité introuvable.');
    }
    final ItineraryDay? day = await _database.dayById(current.dayId);
    if (day == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    await _ownedTrip(day.tripId, userId);
    await _database.deleteStep(stepId);
  }

  Future<void> reorderSteps({
    required int userId,
    required int dayId,
    required List<int> orderedStepIds,
  }) async {
    final ItineraryDay? day = await _database.dayById(dayId);
    if (day == null) {
      throw const TripStoreException('Journée introuvable.');
    }
    await _ownedTrip(day.tripId, userId);
    await _database.reorderSteps(dayId: dayId, orderedStepIds: orderedStepIds);
  }

  Future<List<DayDraft>> replaceItineraryFromAi({
    required int userId,
    required int tripId,
    required List<DayDraft> days,
    bool clearExisting = true,
  }) async {
    final Trip trip = await _ownedTrip(tripId, userId);
    if (clearExisting) {
      final List<ItineraryDay> current = await _database.daysForTrip(tripId);
      for (final ItineraryDay day in current) {
        await _database.deleteDay(day.id);
      }
    }
    final List<DayDraft> saved = <DayDraft>[];
    for (final DayDraft draft in days) {
      await _checkDay(trip, draft);
      final ItineraryDay day = await _database.insertDay(
        tripId: tripId,
        draft: draft,
      );
      saved.add(
        DayDraft(
          dayNumber: day.dayNumber,
          date: day.date,
          title: day.title,
          description: day.description,
          estimatedBudget: day.estimatedBudget,
          notes: day.notes,
          startTime: day.startTime,
          endTime: day.endTime,
          program: day.program,
          steps: draft.steps,
        ),
      );
    }
    return saved;
  }

  Future<BudgetBreakdown> budgetForTrip({
    required int userId,
    required int tripId,
  }) async {
    final Trip trip = await _ownedTrip(tripId, userId);
    final List<ItineraryDay> days = await _database.daysForTrip(tripId);
    final List<ItineraryStep> steps = await _database.stepsForTrip(tripId);
    return BudgetEngine.analyze(trip: trip, days: days, steps: steps);
  }

  Future<List<ScheduleConflict>> conflictsForTrip({
    required int userId,
    required int tripId,
  }) async {
    final Trip trip = await _ownedTrip(tripId, userId);
    final List<ItineraryDay> days = await _database.daysForTrip(tripId);
    final List<ItineraryStep> steps = await _database.stepsForTrip(tripId);
    return ConflictService.analyze(trip: trip, days: days, steps: steps);
  }

  Future<TripDashboardStats> dashboardStats(int userId) async {
    final List<Trip> trips = await getAllTrips(userId);
    final Map<int, List<ItineraryDay>> daysByTrip = <int, List<ItineraryDay>>{};
    for (final Trip trip in trips) {
      daysByTrip[trip.id] = await _database.daysForTrip(trip.id);
    }
    return TripStats.compute(trips: trips, daysByTrip: daysByTrip);
  }

  List<Trip> filterAndSortTrips({
    required List<Trip> trips,
    String query = '',
    String? status,
    String? destination,
    String? type,
    String sortBy = 'date',
  }) {
    final String needle = query.trim().toLowerCase();
    Iterable<Trip> filtered = trips;
    if (needle.isNotEmpty) {
      filtered = filtered.where((Trip trip) {
        return trip.titre.toLowerCase().contains(needle) ||
            trip.destination.toLowerCase().contains(needle) ||
            trip.pays.toLowerCase().contains(needle);
      });
    }
    if (status != null && status.isNotEmpty && status != 'Tous') {
      filtered = filtered.where((Trip trip) => trip.statut == status);
    }
    if (destination != null && destination.trim().isNotEmpty) {
      final String dest = destination.trim().toLowerCase();
      filtered = filtered.where(
        (Trip trip) => trip.destination.toLowerCase().contains(dest),
      );
    }
    if (type != null && type.isNotEmpty && type != 'Tous') {
      filtered = filtered.where((Trip trip) => trip.typeVoyage == type);
    }
    final List<Trip> result = filtered.toList();
    result.sort((Trip a, Trip b) {
      switch (sortBy) {
        case 'budget':
          return b.budget.compareTo(a.budget);
        case 'creation':
          return b.dateCreation.compareTo(a.dateCreation);
        case 'date':
        default:
          return b.dateDepart.compareTo(a.dateDepart);
      }
    });
    return result;
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
