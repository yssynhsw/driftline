import 'dart:io';

import 'package:driftline/src/trip.dart';
import 'package:driftline/src/trips/trip_database.dart';
import 'package:driftline/src/trips/trip_repository.dart';
import 'package:driftline/src/trips/trip_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('trips and days persist, update, and cascade on delete', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'driftline_trips_',
    );
    final String path = p.join(dir.path, 'trips.db');
    final Database db = await _open(path);
    final TripRepository repository = TripRepository(TripDatabase(db));

    final Trip created = await repository.createTrip(
      userId: 7,
      draft: _draft(),
    );
    expect(created.id, greaterThan(0));
    expect(await repository.getAllTrips(4), isEmpty);
    expect(
      await repository.getTripById(id: created.id, userId: 4),
      isNull,
    );

    final day = await repository.createItineraryDay(
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
    await expectLater(
      repository.createItineraryDay(
        userId: 7,
        tripId: created.id,
        draft: const DayDraft(
          dayNumber: 2,
          date: '2026-07-01',
          title: 'Trop tard',
          description: '',
          estimatedBudget: 0,
          notes: '',
        ),
      ),
      throwsA(
        isA<TripStoreException>().having(
          (TripStoreException error) => error.message,
          'message',
          contains('comprise'),
        ),
      ),
    );

    final Trip updated = await repository.updateTrip(
      id: created.id,
      userId: 7,
      draft: _draft(titre: 'Essaouira modifiée', budget: 900),
    );
    expect(updated.titre, 'Essaouira modifiée');
    expect(updated.budget, 900);
    expect(updated.userId, 7);

    await db.close();
    final Database reopened = await _open(path);
    final TripRepository again = TripRepository(TripDatabase(reopened));
    final Trip? loaded = await again.getTripById(id: created.id, userId: 7);
    expect(loaded?.titre, 'Essaouira modifiée');
    final days = await again.getDaysByTripId(tripId: created.id, userId: 7);
    expect(days.single.title, 'Médina');
    expect(days.single.id, day.id);

    await again.deleteItineraryDay(userId: 7, dayId: day.id);
    expect(
      await again.getDaysByTripId(tripId: created.id, userId: 7),
      isEmpty,
    );

    await again.createItineraryDay(
      userId: 7,
      tripId: created.id,
      draft: const DayDraft(
        dayNumber: 1,
        date: '2026-06-01',
        title: 'Plage',
        description: '',
        estimatedBudget: 20,
        notes: '',
      ),
    );
    await again.deleteTrip(id: created.id, userId: 7);
    expect(await again.getTripById(id: created.id, userId: 7), isNull);
    final List<Map<String, Object?>> leftover = await reopened.query(
      'itinerary_days',
      where: 'trip_id = ?',
      whereArgs: <Object>[created.id],
    );
    expect(leftover, isEmpty);

    await reopened.close();
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
  date_creation TEXT NOT NULL
)
''');
      await TripDatabase.createTable(db);
    },
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
