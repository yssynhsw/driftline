import 'dart:io';

import 'package:driftline/src/trip.dart';
import 'package:driftline/src/trips/destination_cover_service.dart';
import 'package:driftline/src/trips/itinerary_day.dart';
import 'package:driftline/src/trips/itinerary_step.dart';
import 'package:driftline/src/trips/trip_database.dart';
import 'package:driftline/src/trips/trip_repository.dart';
import 'package:driftline/src/trips/trip_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('trip CRUD, days, steps, cascade, reopen and user isolation', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'driftline_trips_',
    );
    final String path = p.join(dir.path, 'trips.db');
    Database db = await _open(path);
    TripRepository repository = TripRepository(
      TripDatabase(db),
      coverService: _offlineCoverService(),
    );

    // 1-2 Create + read trips
    final Trip created = await repository.createTrip(
      userId: 7,
      draft: _draft(),
    );
    expect(created.id, greaterThan(0));
    // 13 attributs métier Trip (itinéraire = relation itinerary_days).
    expect(created.id, isA<int>()); // id_trip
    expect(created.titre, isNotEmpty);
    expect(created.destination, isNotEmpty);
    expect(created.pays, isNotEmpty);
    expect(created.dateDepart, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(created.dateRetour, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(created.budget, greaterThan(0));
    expect(created.nombreVoyageurs, greaterThan(0));
    expect(created.typeVoyage, isNotEmpty);
    expect(created.statut, isNotEmpty);
    expect(created.userId, 7);
    expect(created.dateCreation, isA<DateTime>());
    expect(await repository.getAllTrips(7), hasLength(1));
    expect(await repository.getAllTrips(4), isEmpty);
    expect(await repository.getTripById(id: created.id, userId: 4), isNull);

    // 3 Update trip
    final Trip updated = await repository.updateTrip(
      id: created.id,
      userId: 7,
      draft: _draft(titre: 'Essaouira Soft', budget: 1400),
    );
    expect(updated.titre, 'Essaouira Soft');
    expect(updated.budget, 1400);

    // 5 Create day
    final ItineraryDay day = await repository.createItineraryDay(
      userId: 7,
      tripId: created.id,
      draft: const DayDraft(
        dayNumber: 1,
        date: '2026-06-01',
        title: 'Médina',
        description: 'Remparts',
        estimatedBudget: 80,
        notes: 'Matin',
      ),
    );
    expect(day.id, greaterThan(0));

    await expectLater(
      repository.createItineraryDay(
        userId: 7,
        tripId: created.id,
        draft: const DayDraft(
          dayNumber: 1,
          date: '2026-06-01',
          title: 'Doublon',
          description: '',
          estimatedBudget: 0,
          notes: '',
        ),
      ),
      throwsA(isA<TripStoreException>()),
    );

    // 6 Create several activities
    final ItineraryStep stepA = await repository.createStep(
      userId: 7,
      dayId: day.id,
      draft: const StepDraft(
        title: 'Bab el Marsa',
        description: 'Porte historique',
        startTime: '09:00',
        endTime: '10:30',
        estimatedCost: 0,
        location: 'Médina',
      ),
    );
    final ItineraryStep stepB = await repository.createStep(
      userId: 7,
      dayId: day.id,
      draft: const StepDraft(
        title: 'Déjeuner port',
        startTime: '12:30',
        endTime: '14:00',
        estimatedCost: 25,
      ),
    );
    expect(await repository.getStepsForDay(userId: 7, dayId: day.id), hasLength(2));

    // Updating day metadata must NOT wipe steps.
    await repository.updateItineraryDay(
      userId: 7,
      dayId: day.id,
      draft: DayDraft(
        dayNumber: day.dayNumber,
        date: day.date,
        title: 'Médina mise à jour',
        description: day.description,
        estimatedBudget: 90,
        notes: day.notes,
      ),
    );
    expect(await repository.getStepsForDay(userId: 7, dayId: day.id), hasLength(2));

    // 7 Update activity
    final ItineraryStep stepUpdated = await repository.updateStep(
      userId: 7,
      stepId: stepB.id,
      draft: const StepDraft(
        title: 'Déjeuner port',
        startTime: '12:45',
        endTime: '14:00',
        estimatedCost: 30,
      ),
    );
    expect(stepUpdated.estimatedCost, 30);
    expect(stepUpdated.startTime, '12:45');

    // Reorder activities
    await repository.reorderSteps(
      userId: 7,
      dayId: day.id,
      orderedStepIds: <int>[stepB.id, stepA.id],
    );
    final List<ItineraryStep> reordered =
        await repository.getStepsForDay(userId: 7, dayId: day.id);
    expect(reordered.first.id, stepB.id);
    expect(reordered.last.id, stepA.id);

    // 8 Delete one activity
    await repository.deleteStep(userId: 7, stepId: stepA.id);
    expect(await repository.getStepsForDay(userId: 7, dayId: day.id), hasLength(1));

    // 10 Reopen database — data persists
    await db.close();
    db = await _open(path);
    repository = TripRepository(
      TripDatabase(db),
      coverService: _offlineCoverService(),
    );
    expect(await repository.getAllTrips(7), hasLength(1));
    expect(
      await repository.getDaysByTripId(tripId: created.id, userId: 7),
      hasLength(1),
    );
    expect(
      await repository.getStepsForDay(userId: 7, dayId: day.id),
      hasLength(1),
    );

    // 12 Isolation: other user cannot mutate
    await expectLater(
      repository.createStep(
        userId: 4,
        dayId: day.id,
        draft: const StepDraft(title: 'Hack'),
      ),
      throwsA(isA<TripStoreException>()),
    );

    // 4 + 9 Delete trip cascades days/steps
    await repository.deleteTrip(id: created.id, userId: 7);
    expect(await repository.getAllTrips(7), isEmpty);
    await expectLater(
      repository.getStepsForDay(userId: 7, dayId: day.id),
      throwsA(isA<TripStoreException>()),
    );
    expect(await TripDatabase(db).stepsForDay(day.id), isEmpty);

    await db.close();
    await dir.delete(recursive: true);
  });

  test('migration from older schema keeps trips and creates steps table', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'driftline_migrate_',
    );
    final String path = p.join(dir.path, 'legacy.db');
    Database legacy = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
CREATE TABLE trips (
  id_trip INTEGER PRIMARY KEY AUTOINCREMENT,
  titre TEXT NOT NULL,
  destination TEXT NOT NULL,
  pays TEXT NOT NULL,
  date_depart TEXT NOT NULL,
  date_retour TEXT NOT NULL,
  budget REAL NOT NULL,
  nombre_voyageurs INTEGER NOT NULL,
  type_voyage TEXT NOT NULL,
  statut TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  date_creation TEXT NOT NULL
)
''');
        await db.insert('trips', <String, Object?>{
          'titre': 'Legacy',
          'destination': 'Fes',
          'pays': 'Morocco',
          'date_depart': '2026-08-01',
          'date_retour': '2026-08-03',
          'budget': 900,
          'nombre_voyageurs': 2,
          'type_voyage': 'Culturel',
          'statut': 'Planned',
          'user_id': 9,
          'date_creation': DateTime.now().toIso8601String(),
        });
      },
    );
    await legacy.close();

    final Database upgraded = await openDatabase(
      path,
      version: 8,
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 5) {
          await TripDatabase.createTable(db);
        }
        if (oldVersion < 6) {
          await TripDatabase.migrateV6(db);
        }
        if (oldVersion < 7) {
          await TripDatabase.migrateV7(db);
        }
        if (oldVersion < 8) {
          await TripDatabase.migrateV8(db);
        }
      },
    );

    final List<Map<String, Object?>> trips = await upgraded.query('trips');
    expect(trips, hasLength(1));
    expect(trips.first['titre'], 'Legacy');

    final List<Map<String, Object?>> tables = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='itinerary_steps'",
    );
    expect(tables, isNotEmpty);

    final TripDatabase tripDb = TripDatabase(upgraded);
    final ItineraryDay day = await tripDb.insertDay(
      tripId: trips.first['id_trip'] as int,
      draft: const DayDraft(
        dayNumber: 1,
        date: '2026-08-01',
        title: 'Jour 1',
        description: '',
        estimatedBudget: 40,
        notes: '',
        steps: <StepDraft>[
          StepDraft(title: 'Musée', estimatedCost: 10, startTime: '10:00', endTime: '12:00'),
        ],
      ),
    );
    expect(await tripDb.stepsForDay(day.id), hasLength(1));

    await upgraded.close();
    await dir.delete(recursive: true);
  });
}

Future<Database> _open(String path) {
  return openDatabase(
    path,
    version: 1,
    onCreate: (Database db, int version) async {
      await db.execute('''
CREATE TABLE IF NOT EXISTS trips (
  id_trip INTEGER PRIMARY KEY AUTOINCREMENT,
  titre TEXT NOT NULL,
  destination TEXT NOT NULL,
  pays TEXT NOT NULL,
  date_depart TEXT NOT NULL,
  date_retour TEXT NOT NULL,
  budget REAL NOT NULL,
  nombre_voyageurs INTEGER NOT NULL,
  type_voyage TEXT NOT NULL,
  statut TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  date_creation TEXT NOT NULL,
  cover_photo_url TEXT NOT NULL DEFAULT '',
  cover_photo_credit TEXT NOT NULL DEFAULT '',
  cover_match_level TEXT NOT NULL DEFAULT '',
  gallery_photos_json TEXT NOT NULL DEFAULT '[]'
)
''');
      await TripDatabase.createTable(db);
    },
  );
}

DestinationCoverService _offlineCoverService() {
  return DestinationCoverService(
    client: MockClient(
      (_) async => http.Response(
        '{"results":[],"query":{}}',
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      ),
    ),
  );
}

TripDraft _draft({String titre = 'Essaouira', double budget = 1200}) {
  return TripDraft(
    titre: titre,
    destination: 'Essaouira',
    pays: 'Morocco',
    dateDepart: '2026-06-01',
    dateRetour: '2026-06-03',
    budget: budget,
    nombreVoyageurs: 2,
    typeVoyage: 'Détente',
    statut: 'Planned',
  );
}
