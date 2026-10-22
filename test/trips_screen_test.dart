import 'dart:io';

import 'package:driftline/src/theme.dart';
import 'package:driftline/src/trips/screens/trips_list_screen.dart';
import 'package:driftline/src/trips/trip_database.dart';
import 'package:driftline/src/trips/trip_repository.dart';
import 'package:driftline/src/trips/trip_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('empty trips screen offers a new trip', (WidgetTester tester) async {
    final _Harness harness = await _harness();
    await tester.pumpWidget(
      _app(TripsListScreen(userId: 3, repository: harness.repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes voyages'), findsOneWidget);
    expect(find.text('Aucun voyage pour le moment.'), findsOneWidget);

    await tester.tap(find.text('Nouveau voyage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Le titre est obligatoire.'), findsOneWidget);
    await harness.close();
  });

  testWidgets('a saved trip opens its details', (WidgetTester tester) async {
    final _Harness harness = await _harness();
    await harness.repository.createTrip(
      userId: 3,
      draft: const TripDraft(
        titre: 'Marrakech',
        destination: 'Marrakech',
        pays: 'Morocco',
        dateDepart: '2026-07-01',
        dateRetour: '2026-07-04',
        budget: 1500,
        nombreVoyageurs: 2,
        typeVoyage: 'Culturel',
        statut: 'Planned',
      ),
    );

    await tester.pumpWidget(
      _app(TripsListScreen(userId: 3, repository: harness.repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marrakech'), findsOneWidget);
    expect(find.text('Planifié'), findsOneWidget);
    expect(find.text('01/07/2026 – 04/07/2026'), findsOneWidget);

    await tester.tap(find.text('Marrakech'));
    await tester.pumpAndSettle();

    expect(find.text('Détails du voyage'), findsOneWidget);
    expect(find.text('Voir l’itinéraire'), findsOneWidget);
    expect(find.text('4 jours'), findsOneWidget);
    await harness.close();
  });
}

Widget _app(Widget home) {
  return MaterialApp(theme: driftTheme(), home: home);
}

class _Harness {
  _Harness(this.repository, this._database, this._directory);

  final TripRepository repository;
  final Database _database;
  final Directory _directory;

  Future<void> close() async {
    await _database.close();
    if (_directory.existsSync()) {
      await _directory.delete(recursive: true);
    }
  }
}

Future<_Harness> _harness() async {
  final Directory directory = await Directory.systemTemp.createTemp(
    'driftline_trip_screen_',
  );
  final Database database = await openDatabase(
    p.join(directory.path, 'trips.db'),
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
      await TripDatabase.createTable(db);
    },
  );
  return _Harness(
    TripRepository(TripDatabase(database)),
    database,
    directory,
  );
}
