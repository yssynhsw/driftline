import 'package:sqflite/sqflite.dart';

import '../trip.dart';
import 'itinerary_day.dart';
import 'itinerary_step.dart';
import 'trip_validation.dart';

/// Gestion 2 SQLite data access on the shared [UserStore] database.
///
/// Uses only sqflite `insert` / `query` / `update` / `delete` and
/// `database.transaction()` for linked writes. Does not open a second DB file.
class TripDatabase {
  const TripDatabase(this._db);

  final Database _db;

  static Future<void> createTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS itinerary_days (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  trip_id INTEGER NOT NULL,
  day_number INTEGER NOT NULL,
  date TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  estimated_budget REAL NOT NULL,
  notes TEXT NOT NULL,
  start_time TEXT NOT NULL DEFAULT '',
  end_time TEXT NOT NULL DEFAULT '',
  program TEXT NOT NULL DEFAULT '',
  FOREIGN KEY(trip_id) REFERENCES trips(id_trip) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS itinerary_days_trip_day
ON itinerary_days(trip_id, day_number)
''');
    await _createStepsTable(db);
  }

  static Future<void> migrateV6(DatabaseExecutor db) async {
    await _ensureColumn(db, 'itinerary_days', 'start_time', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'itinerary_days', 'end_time', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'itinerary_days', 'program', "TEXT NOT NULL DEFAULT ''");
    await _createStepsTable(db);
  }

  static Future<void> migrateV7(DatabaseExecutor db) async {
    await _ensureColumn(
      db,
      'trips',
      'cover_photo_url',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'trips',
      'cover_photo_credit',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'trips',
      'cover_match_level',
      "TEXT NOT NULL DEFAULT ''",
    );
  }

  static Future<void> migrateV8(DatabaseExecutor db) async {
    await _ensureColumn(
      db,
      'trips',
      'gallery_photos_json',
      "TEXT NOT NULL DEFAULT '[]'",
    );
  }

  static Future<void> _createStepsTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS itinerary_steps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  day_id INTEGER NOT NULL,
  sort_order INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  start_time TEXT NOT NULL DEFAULT '',
  end_time TEXT NOT NULL DEFAULT '',
  estimated_cost REAL NOT NULL DEFAULT 0,
  location TEXT NOT NULL DEFAULT '',
  FOREIGN KEY(day_id) REFERENCES itinerary_days(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS itinerary_steps_day
ON itinerary_steps(day_id, sort_order)
''');
  }

  static Future<void> _ensureColumn(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final List<Map<String, Object?>> info = await db.rawQuery(
      'PRAGMA table_info($table)',
    );
    final bool exists = info.any(
      (Map<String, Object?> row) => row['name'] == column,
    );
    if (exists) {
      return;
    }
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  static Future<void> deleteTripCascade(DatabaseExecutor db, int id) async {
    Future<void> run(DatabaseExecutor executor) async {
      final List<Map<String, Object?>> days = await executor.query(
        'itinerary_days',
        columns: <String>['id'],
        where: 'trip_id = ?',
        whereArgs: <Object>[id],
      );
      for (final Map<String, Object?> day in days) {
        await executor.delete(
          'itinerary_steps',
          where: 'day_id = ?',
          whereArgs: <Object>[day['id'] as int],
        );
      }
      await executor.delete(
        'itinerary_days',
        where: 'trip_id = ?',
        whereArgs: <Object>[id],
      );
      await executor.delete(
        'trips',
        where: 'id_trip = ?',
        whereArgs: <Object>[id],
      );
    }

    // Keep integrity even when SQLite FK constraints are absent on older DBs.
    if (db is Database) {
      await db.transaction(run);
      return;
    }
    await run(db);
  }

  Future<List<Trip>> tripsForUser(int userId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'trips',
      where: 'user_id = ?',
      whereArgs: <Object>[userId],
      orderBy: 'date_depart DESC, id_trip DESC',
    );
    return rows.map(Trip.fromMap).toList();
  }

  Future<Trip?> tripById(int id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'trips',
      where: 'id_trip = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Trip.fromMap(rows.first);
  }

  Future<Trip> insertTrip({
    required int userId,
    required TripDraft draft,
    String coverPhotoUrl = '',
    String coverPhotoCredit = '',
    String coverMatchLevel = '',
    String galleryPhotosJson = '[]',
  }) async {
    final int id = await _db.insert('trips', <String, Object?>{
      'titre': draft.titre.trim(),
      'destination': draft.destination.trim(),
      'pays': draft.pays.trim(),
      'date_depart': draft.dateDepart.trim(),
      'date_retour': draft.dateRetour.trim(),
      'budget': draft.budget,
      'nombre_voyageurs': draft.nombreVoyageurs,
      'type_voyage': draft.typeVoyage.trim(),
      'statut': draft.statut.trim(),
      'user_id': userId,
      'date_creation': DateTime.now().toIso8601String(),
      'cover_photo_url': coverPhotoUrl,
      'cover_photo_credit': coverPhotoCredit,
      'cover_match_level': coverMatchLevel,
      'gallery_photos_json': galleryPhotosJson,
    });
    return _requireTrip(id);
  }

  Future<Trip> updateTrip({
    required int id,
    required TripDraft draft,
    String? coverPhotoUrl,
    String? coverPhotoCredit,
    String? coverMatchLevel,
    String? galleryPhotosJson,
  }) async {
    await _db.update(
      'trips',
      <String, Object?>{
        'titre': draft.titre.trim(),
        'destination': draft.destination.trim(),
        'pays': draft.pays.trim(),
        'date_depart': draft.dateDepart.trim(),
        'date_retour': draft.dateRetour.trim(),
        'budget': draft.budget,
        'nombre_voyageurs': draft.nombreVoyageurs,
        'type_voyage': draft.typeVoyage.trim(),
        'statut': draft.statut.trim(),
        'cover_photo_url': ?coverPhotoUrl,
        'cover_photo_credit': ?coverPhotoCredit,
        'cover_match_level': ?coverMatchLevel,
        'gallery_photos_json': ?galleryPhotosJson,
      },
      where: 'id_trip = ?',
      whereArgs: <Object>[id],
    );
    return _requireTrip(id);
  }

  Future<Trip> updateCoverPhoto({
    required int id,
    required String coverPhotoUrl,
    required String coverPhotoCredit,
    required String coverMatchLevel,
  }) async {
    await _db.update(
      'trips',
      <String, Object?>{
        'cover_photo_url': coverPhotoUrl,
        'cover_photo_credit': coverPhotoCredit,
        'cover_match_level': coverMatchLevel,
      },
      where: 'id_trip = ?',
      whereArgs: <Object>[id],
    );
    return _requireTrip(id);
  }

  Future<Trip> updateGalleryPhotos({
    required int id,
    required String galleryPhotosJson,
  }) async {
    await _db.update(
      'trips',
      <String, Object?>{'gallery_photos_json': galleryPhotosJson},
      where: 'id_trip = ?',
      whereArgs: <Object>[id],
    );
    return _requireTrip(id);
  }

  Future<void> deleteTrip(int id) => deleteTripCascade(_db, id);

  Future<List<ItineraryDay>> daysForTrip(int tripId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'itinerary_days',
      where: 'trip_id = ?',
      whereArgs: <Object>[tripId],
      orderBy: 'day_number ASC, date ASC',
    );
    return rows.map(ItineraryDay.fromMap).toList();
  }

  Future<ItineraryDay?> dayById(int id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'itinerary_days',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ItineraryDay.fromMap(rows.first);
  }

  Future<ItineraryDay> insertDay({
    required int tripId,
    required DayDraft draft,
  }) async {
    try {
      return await _db.transaction((Transaction txn) async {
        final int id = await txn.insert('itinerary_days', <String, Object?>{
          'trip_id': tripId,
          'day_number': draft.dayNumber,
          'date': draft.date.trim(),
          'title': draft.title.trim(),
          'description': draft.description.trim(),
          'estimated_budget': draft.estimatedBudget,
          'notes': draft.notes.trim(),
          'start_time': draft.startTime.trim(),
          'end_time': draft.endTime.trim(),
          'program': draft.program.trim(),
        });
        await _replaceSteps(txn, id, draft.steps);
        return ItineraryDay.fromMap(
          (await txn.query(
            'itinerary_days',
            where: 'id = ?',
            whereArgs: <Object>[id],
            limit: 1,
          ))
              .first,
        );
      });
    } on DatabaseException catch (error) {
      throw _dayError(error);
    }
  }

  Future<ItineraryDay> updateDay({
    required int id,
    required DayDraft draft,
    bool syncSteps = false,
  }) async {
    try {
      return await _db.transaction((Transaction txn) async {
        await txn.update(
          'itinerary_days',
          <String, Object?>{
            'day_number': draft.dayNumber,
            'date': draft.date.trim(),
            'title': draft.title.trim(),
            'description': draft.description.trim(),
            'estimated_budget': draft.estimatedBudget,
            'notes': draft.notes.trim(),
            'start_time': draft.startTime.trim(),
            'end_time': draft.endTime.trim(),
            'program': draft.program.trim(),
          },
          where: 'id = ?',
          whereArgs: <Object>[id],
        );
        // Keep existing itinerary_steps unless the caller explicitly syncs them
        // (AI replace / saveDaySteps). Editing day metadata must not wipe activities.
        if (syncSteps) {
          await _replaceSteps(txn, id, draft.steps);
        }
        return ItineraryDay.fromMap(
          (await txn.query(
            'itinerary_days',
            where: 'id = ?',
            whereArgs: <Object>[id],
            limit: 1,
          ))
              .first,
        );
      });
    } on DatabaseException catch (error) {
      throw _dayError(error);
    }
  }

  Future<void> deleteDay(int id) async {
    await _db.transaction((Transaction txn) async {
      await txn.delete(
        'itinerary_steps',
        where: 'day_id = ?',
        whereArgs: <Object>[id],
      );
      await txn.delete(
        'itinerary_days',
        where: 'id = ?',
        whereArgs: <Object>[id],
      );
    });
  }

  Future<void> reorderDays({
    required int tripId,
    required List<int> orderedDayIds,
  }) async {
    await _db.transaction((Transaction txn) async {
      // Two-phase update avoids UNIQUE(trip_id, day_number) collisions mid-swap.
      for (int i = 0; i < orderedDayIds.length; i++) {
        await txn.update(
          'itinerary_days',
          <String, Object?>{'day_number': -(i + 1)},
          where: 'id = ? AND trip_id = ?',
          whereArgs: <Object>[orderedDayIds[i], tripId],
        );
      }
      for (int i = 0; i < orderedDayIds.length; i++) {
        await txn.update(
          'itinerary_days',
          <String, Object?>{'day_number': i + 1},
          where: 'id = ? AND trip_id = ?',
          whereArgs: <Object>[orderedDayIds[i], tripId],
        );
      }
    });
  }

  Future<List<ItineraryStep>> stepsForDay(int dayId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'itinerary_steps',
      where: 'day_id = ?',
      whereArgs: <Object>[dayId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(ItineraryStep.fromMap).toList();
  }

  Future<List<ItineraryStep>> stepsForTrip(int tripId) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
SELECT s.*
FROM itinerary_steps s
INNER JOIN itinerary_days d ON d.id = s.day_id
WHERE d.trip_id = ?
ORDER BY d.day_number ASC, s.sort_order ASC, s.id ASC
''',
      <Object>[tripId],
    );
    return rows.map(ItineraryStep.fromMap).toList();
  }

  Future<void> replaceDaySteps({
    required int dayId,
    required List<StepDraft> steps,
  }) {
    return _db.transaction((Transaction txn) => _replaceSteps(txn, dayId, steps));
  }

  Future<ItineraryStep?> stepById(int id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'itinerary_steps',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ItineraryStep.fromMap(rows.first);
  }

  Future<ItineraryStep> insertStep({
    required int dayId,
    required StepDraft draft,
  }) async {
    final List<ItineraryStep> existing = await stepsForDay(dayId);
    final int sortOrder =
        draft.sortOrder > 0 ? draft.sortOrder : existing.length + 1;
    final int id = await _db.insert('itinerary_steps', <String, Object?>{
      'day_id': dayId,
      'sort_order': sortOrder,
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'start_time': draft.startTime.trim(),
      'end_time': draft.endTime.trim(),
      'estimated_cost': draft.estimatedCost,
      'location': draft.location.trim(),
    });
    final ItineraryStep? created = await stepById(id);
    if (created == null) {
      throw const TripStoreException('Activité introuvable après l’enregistrement.');
    }
    return created;
  }

  Future<ItineraryStep> updateStep({
    required int id,
    required StepDraft draft,
  }) async {
    final ItineraryStep? current = await stepById(id);
    if (current == null) {
      throw const TripStoreException('Activité introuvable.');
    }
    await _db.update(
      'itinerary_steps',
      <String, Object?>{
        'title': draft.title.trim(),
        'description': draft.description.trim(),
        'start_time': draft.startTime.trim(),
        'end_time': draft.endTime.trim(),
        'estimated_cost': draft.estimatedCost,
        'location': draft.location.trim(),
        if (draft.sortOrder > 0) 'sort_order': draft.sortOrder,
      },
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
    final ItineraryStep? updated = await stepById(id);
    if (updated == null) {
      throw const TripStoreException('Activité introuvable après mise à jour.');
    }
    return updated;
  }

  Future<void> deleteStep(int id) async {
    await _db.delete(
      'itinerary_steps',
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  Future<void> reorderSteps({
    required int dayId,
    required List<int> orderedStepIds,
  }) async {
    await _db.transaction((Transaction txn) async {
      for (int i = 0; i < orderedStepIds.length; i++) {
        await txn.update(
          'itinerary_steps',
          <String, Object?>{'sort_order': -(i + 1)},
          where: 'id = ? AND day_id = ?',
          whereArgs: <Object>[orderedStepIds[i], dayId],
        );
      }
      for (int i = 0; i < orderedStepIds.length; i++) {
        await txn.update(
          'itinerary_steps',
          <String, Object?>{'sort_order': i + 1},
          where: 'id = ? AND day_id = ?',
          whereArgs: <Object>[orderedStepIds[i], dayId],
        );
      }
    });
  }

  Future<void> _replaceSteps(
    DatabaseExecutor db,
    int dayId,
    List<StepDraft> steps,
  ) async {
    await db.delete(
      'itinerary_steps',
      where: 'day_id = ?',
      whereArgs: <Object>[dayId],
    );
    for (int i = 0; i < steps.length; i++) {
      final StepDraft step = steps[i];
      if (step.title.trim().isEmpty) {
        continue;
      }
      await db.insert('itinerary_steps', <String, Object?>{
        'day_id': dayId,
        'sort_order': step.sortOrder > 0 ? step.sortOrder : i + 1,
        'title': step.title.trim(),
        'description': step.description.trim(),
        'start_time': step.startTime.trim(),
        'end_time': step.endTime.trim(),
        'estimated_cost': step.estimatedCost,
        'location': step.location.trim(),
      });
    }
  }

  Future<Trip> _requireTrip(int id) async {
    final Trip? trip = await tripById(id);
    if (trip == null) {
      throw const TripStoreException(
        'Voyage introuvable après l’enregistrement.',
      );
    }
    return trip;
  }

  TripStoreException _dayError(DatabaseException error) {
    if (error.isUniqueConstraintError()) {
      return const TripStoreException('Ce numéro de jour est déjà utilisé.');
    }
    return TripStoreException('$error');
  }
}
