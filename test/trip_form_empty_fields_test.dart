import 'package:driftline/src/theme.dart';
import 'package:driftline/src/trips/destination_cover_service.dart';
import 'package:driftline/src/trips/trip_database.dart';
import 'package:driftline/src/trips/trip_repository.dart';
import 'package:driftline/src/trips/widgets/trip_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('new trip form title and destination start empty without hints',
      (WidgetTester tester) async {
    final Database db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (Database database, int version) async {
        await database.execute('''
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
        await TripDatabase.createTable(database);
      },
    );
    addTearDown(db.close);

    final TripRepository repository = TripRepository(
      TripDatabase(db),
      coverService: DestinationCoverService(
        client: MockClient((_) async => http.Response('{}', 404)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: driftTheme(),
        home: TripEditorPage(
          title: 'Nouveau voyage',
          userId: 1,
          repository: repository,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Titre du voyage'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);

    // No example / placeholder copy.
    expect(find.textContaining('Essaouira'), findsNothing);
    expect(find.textContaining('Week-end'), findsNothing);
    expect(find.textContaining('Berlin'), findsNothing);
    expect(find.textContaining('Ex.'), findsNothing);

    final Iterable<TextField> fields = tester.widgetList<TextField>(
      find.byType(TextField),
    );
    final TextField titre = fields.firstWhere(
      (TextField field) => field.controller != null,
    );
    // Titre is the first text field in the form body after optional cover.
    final List<TextField> editable = fields
        .where((TextField f) => f.controller != null)
        .toList();
    expect(editable.length, greaterThanOrEqualTo(2));
    expect(editable[0].controller!.text, isEmpty);
    expect(editable[1].controller!.text, isEmpty);
    expect(editable[0].decoration?.hintText, anyOf(isNull, isEmpty));
    expect(editable[1].decoration?.hintText, anyOf(isNull, isEmpty));
    expect(titre.autofillHints, isEmpty);
  });
}
