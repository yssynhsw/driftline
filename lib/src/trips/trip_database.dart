import 'package:sqflite/sqflite.dart';

import '../trip.dart';
import 'itinerary_day.dart';
import 'trip_validation.dart';

/// SQL access for trips and itinerary days on the shared Driftline database.
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
  notes TEXT NOT NULL
)
''');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS itinerary_days_trip_day
ON itinerary_days(trip_id, day_number)
''');
  }

  static Future<void> deleteTripCascade(DatabaseExecutor db, int id) async {
    await db.delete(
      'itinerary_days',
      where: 'trip_id = ?',
      whereArgs: <Object>[id],
    );
    await db.delete('trips', where: 'id_trip = ?', whereArgs: <Object>[id]);
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
    });
    return _requireTrip(id);
  }

  Future<Trip> updateTrip({
    required int id,
    required TripDraft draft,
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
      },
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
      final int id = await _db.insert('itinerary_days', <String, Object?>{
        'trip_id': tripId,
        'day_number': draft.dayNumber,
        'date': draft.date.trim(),
        'title': draft.title.trim(),
        'description': draft.description.trim(),
        'estimated_budget': draft.estimatedBudget,
        'notes': draft.notes.trim(),
      });
      return await _requireDay(id);
    } on DatabaseException catch (error) {
      throw _dayError(error);
    }
  }

  Future<ItineraryDay> updateDay({
    required int id,
    required DayDraft draft,
  }) async {
    try {
      await _db.update(
        'itinerary_days',
        <String, Object?>{
          'day_number': draft.dayNumber,
          'date': draft.date.trim(),
          'title': draft.title.trim(),
          'description': draft.description.trim(),
          'estimated_budget': draft.estimatedBudget,
          'notes': draft.notes.trim(),
        },
        where: 'id = ?',
        whereArgs: <Object>[id],
      );
      return await _requireDay(id);
    } on DatabaseException catch (error) {
      throw _dayError(error);
    }
  }

  Future<void> deleteDay(int id) {
    return _db.delete(
      'itinerary_days',
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
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

  Future<ItineraryDay> _requireDay(int id) async {
    final ItineraryDay? day = await dayById(id);
    if (day == null) {
      throw const TripStoreException(
        'Journée introuvable après l’enregistrement.',
      );
    }
    return day;
  }

  TripStoreException _dayError(DatabaseException error) {
    if (error.isUniqueConstraintError()) {
      return const TripStoreException('Ce numéro de jour est déjà utilisé.');
    }
    return TripStoreException('$error');
  }
}
