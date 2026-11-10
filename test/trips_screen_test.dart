import 'dart:io';

import 'package:driftline/src/theme.dart';
import 'package:driftline/src/trips/destination_cover_service.dart';
import 'package:driftline/src/trips/screens/trips_list_screen.dart';
import 'package:driftline/src/trips/trip_database.dart';
import 'package:driftline/src/trips/trip_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // NoIsolate avoids Windows widget-test deadlocks with ffi isolates.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    PathProviderPlatform.instance = _FakePathProvider();
  });

  testWidgets(
    'empty trips screen offers a new trip',
    (WidgetTester tester) async {
      final _Harness harness = await _harness();
      addTearDown(harness.close);

      await tester.pumpWidget(
        _app(TripsListScreen(userId: 3, repository: harness.repository)),
      );
      await _pumpAsync(tester);

      expect(find.text('Mes voyages'), findsOneWidget);
      expect(find.text('Nouveau voyage'), findsOneWidget);
      await _scrollTo(tester, 'Aucun voyage pour le moment.');
      expect(find.text('Aucun voyage pour le moment.'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

}

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.pump();
  // sqflite futures need the real event loop under FakeAsync.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Tableau de bord').evaluate().isNotEmpty ||
        find.text('Détails du voyage').evaluate().isNotEmpty ||
        find.text('Impossible de charger les voyages.').evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  }
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  final Finder list = find.byType(ListView);
  if (list.evaluate().isEmpty) {
    return;
  }
  for (int i = 0; i < 12; i++) {
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(list.first, const Offset(0, -240), warnIfMissed: false);
    await tester.pump();
  }
}

Widget _app(Widget home) {
  return MaterialApp(
    theme: driftTheme(),
    home: home,
  );
}

class _Harness {
  _Harness(this.repository, this._database);

  final TripRepository repository;
  final Database _database;

  Future<void> close() => _database.close();
}

Future<_Harness> _harness() async {
  final Database database = await openDatabase(
    inMemoryDatabasePath,
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
  return _Harness(
    TripRepository(
      TripDatabase(database),
      coverService: DestinationCoverService(
        client: MockClient(
          (_) async => http.Response(
            '{"results":[],"query":{}}',
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          ),
        ),
      ),
    ),
    database,
  );
}

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getLibraryPath() async {
    return Directory.systemTemp.path;
  }
}
