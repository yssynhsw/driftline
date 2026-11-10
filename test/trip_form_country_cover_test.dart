import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:driftline/src/countries.dart';
import 'package:driftline/src/theme.dart';
import 'package:driftline/src/trips/destination_cover_service.dart';
import 'package:driftline/src/trips/trip_database.dart';
import 'package:driftline/src/trips/trip_repository.dart';
import 'package:driftline/src/trips/widgets/destination_photo.dart';
import 'package:driftline/src/trips/widgets/trip_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;

    // CachedNetworkImage → flutter_cache_manager needs path_provider.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        final Directory dir =
            await Directory.systemTemp.createTemp('driftline_cover_test');
        return dir.path;
      },
    );
  });

  testWidgets(
    'selecting Country loads national cover without destination',
    (WidgetTester tester) async {
      final List<String> coverCountries = <String>[];
      final Map<String, Completer<void>> gates = <String, Completer<void>>{
        'Tunisia': Completer<void>(),
        'Algeria': Completer<void>(),
        'Germany': Completer<void>(),
        'France': Completer<void>(),
      };

      Map<String, Object?> wikiPage({
        required String title,
        required String country,
        required String slug,
        required String description,
      }) {
        return <String, Object?>{
          'title': title,
          'fullurl': 'https://en.wikipedia.org/wiki/${title.replaceAll(' ', '_')}',
          'description': description,
          'extract': '$title is a landmark in $country.',
          'pageimage': '$slug.jpg',
          'thumbnail': <String, Object?>{
            'source':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/$slug.jpg/1600px-$slug.jpg',
          },
          'original': <String, Object?>{
            'source':
                'https://upload.wikimedia.org/wikipedia/commons/$slug.jpg',
          },
        };
      }

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

      final DestinationCoverService coverService = DestinationCoverService(
        client: MockClient((http.Request request) async {
          if (request.url.host.contains('geocoding')) {
            return http.Response('{}', 404);
          }
          if (request.method == 'HEAD' ||
              (request.method == 'GET' &&
                  request.url.host.contains('upload.wikimedia.org'))) {
            return http.Response('', 200, headers: <String, String>{
              'content-type': 'image/jpeg',
            });
          }
          if (request.url.host.contains('wikipedia.org') &&
              request.url.queryParameters['action'] == 'query') {
            final String titles =
                (request.url.queryParameters['titles'] ?? '').toLowerCase();
            String field = '';
            Map<String, Object?>? page;
            if (titles.contains('sidi bou') ||
                titles.contains('el jem') ||
                titles.contains('tozeur') ||
                titles == 'tunisia' ||
                titles.contains('tunis')) {
              field = 'Tunisia';
              page = wikiPage(
                title: 'Sidi Bou Said',
                country: 'Tunisia',
                slug: 'tn',
                description: 'Town in Tunisia',
              );
            } else if (titles.contains('casbah') ||
                titles.contains('timgad') ||
                titles.contains('tassili') ||
                titles.contains('algiers') ||
                titles == 'algeria') {
              field = 'Algeria';
              page = wikiPage(
                title: 'Casbah of Algiers',
                country: 'Algeria',
                slug: 'dz',
                description: 'Citadel in Algiers, Algeria',
              );
            } else if (titles.contains('brandenburg') ||
                titles.contains('neuschwanstein') ||
                titles.contains('berlin') ||
                titles == 'germany') {
              field = 'Germany';
              page = wikiPage(
                title: 'Brandenburg Gate',
                country: 'Germany',
                slug: 'de',
                description: 'Monument in Berlin, Germany',
              );
            } else if (titles.contains('eiffel') ||
                titles.contains('mont-saint') ||
                titles.contains('paris') ||
                titles == 'france') {
              field = 'France';
              page = wikiPage(
                title: 'Eiffel Tower',
                country: 'France',
                slug: 'fr',
                description: 'Tower in Paris, France',
              );
            }
            if (field.isNotEmpty && page != null) {
              coverCountries.add(field);
              final Completer<void>? gate = gates[field];
              if (gate != null && !gate.isCompleted) {
                await gate.future;
              }
              return http.Response(
                jsonEncode(<String, Object?>{
                  'query': <String, Object?>{
                    'pages': <String, Object?>{'1': page},
                  },
                }),
                200,
                headers: const <String, String>{
                  'content-type': 'application/json',
                },
              );
            }
            return http.Response(
              jsonEncode(<String, Object?>{
                'query': <String, Object?>{
                  'pages': <String, Object?>{
                    '-1': <String, Object?>{'missing': ''},
                  },
                },
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final TripRepository repository = TripRepository(
        TripDatabase(db),
        coverService: coverService,
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

      final List<TextField> editable = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((TextField f) => f.controller != null)
          .toList();
      expect(editable[0].controller!.text, isEmpty);
      expect(editable[1].controller!.text, isEmpty);
      expect(editable[0].decoration?.hintText, anyOf(isNull, isEmpty));
      expect(editable[1].decoration?.hintText, anyOf(isNull, isEmpty));

      String currentCountry = '';

      Future<void> openCountrySheet() async {
        final Finder value = find.descendant(
          of: find.byType(CountryField),
          matching: find.text(
            currentCountry.isEmpty ? 'Choose a country' : currentCountry,
          ),
        );
        await tester.tap(value);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Search countries'), findsOneWidget);
      }

      Future<void> pickCountry(String name, String badge) async {
        await openCountrySheet();
        await tester.enterText(find.byType(TextField).last, name);
        await tester.pump();
        await tester.tap(find.widgetWithText(ListTile, name));
        currentCountry = name;
        await tester.pump();

        // Old photo cleared immediately; loading shown while gated.
        expect(find.byType(DestinationPhoto), findsNothing);
        expect(
          find.text('Recherche d\'une photo emblématique…'),
          findsOneWidget,
        );

        gates[name]!.complete();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        for (int i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (find.textContaining(badge).evaluate().isNotEmpty) {
            break;
          }
        }

        expect(find.text(name), findsWidgets);
        expect(find.textContaining(badge), findsOneWidget);
        expect(editable[0].controller!.text, isEmpty);
        expect(editable[1].controller!.text, isEmpty);
      }

      await pickCountry('Tunisia', 'Photo de Tunisie');
      expect(coverCountries.contains('Tunisia'), isTrue);

      await pickCountry('Algeria', 'Photo de Algérie');
      expect(coverCountries.contains('Algeria'), isTrue);

      await pickCountry('Germany', 'Photo de Allemagne');
      expect(coverCountries.contains('Germany'), isTrue);

      await pickCountry('France', 'Photo de France');
      expect(coverCountries.contains('France'), isTrue);

      // Drain flutter_cache_manager cleanup timers from CachedNetworkImage.
      await tester.pump(const Duration(seconds: 11));
    },
  );
}
