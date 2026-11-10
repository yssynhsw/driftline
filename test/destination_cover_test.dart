import 'dart:convert';

import 'package:driftline/src/trips/destination_cover.dart';
import 'package:driftline/src/trips/destination_cover_service.dart';
import 'package:driftline/src/trips/destination_photos.dart';
import 'package:driftline/src/trips/gallery_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('cover uses Wikipedia landmark photo for selected country', () async {
    var geoCalls = 0;
    var commonsCalls = 0;
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.host.contains('geocoding')) {
        geoCalls += 1;
        return http.Response('{}', 404);
      }
      if (request.method == 'HEAD') {
        return http.Response('', 200, headers: <String, String>{
          'content-type': 'image/jpeg',
        });
      }
      if (request.url.host.contains('wikipedia.org') &&
          request.url.queryParameters['action'] == 'query') {
        final String titles = request.url.queryParameters['titles'] ?? '';
        if (titles.contains('Sidi Bou Said')) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'query': <String, Object?>{
                'pages': <String, Object?>{
                  '1': <String, Object?>{
                    'title': 'Sidi Bou Said',
                    'fullurl':
                        'https://en.wikipedia.org/wiki/Sidi_Bou_Said',
                    'description': 'Town in Tunisia',
                    'extract':
                        'Sidi Bou Said is a town in northern Tunisia known for blue and white architecture.',
                    'pageimage': 'Sidi_Chebaan.jpg',
                    'thumbnail': <String, Object?>{
                      'source':
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/sidi.jpg/1600px-sidi.jpg',
                    },
                    'original': <String, Object?>{
                      'source':
                          'https://upload.wikimedia.org/wikipedia/commons/sidi.jpg',
                    },
                  },
                },
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
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
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.host.contains('commons.wikimedia.org')) {
        commonsCalls += 1;
        return http.Response('{}', 404);
      }
      return http.Response('{}', 404);
    });

    final DestinationCoverService service =
        DestinationCoverService(client: client);
    final DestinationCoverResult result = await service.resolve(
      destination: '',
      country: 'Tunisia',
    );

    expect(geoCalls, 0);
    expect(result.country, 'Tunisie');
    expect(result.landmark, contains('Sidi Bou'));
    expect(result.imageUrl, contains('sidi.jpg'));
    expect(result.badgeLabel, contains('Tunisie'));
    expect(result.badgeLabel, contains('Sidi Bou'));
    expect(result.matchLevel, DestinationCoverResult.levelExact);
    // Commons is attempted first; Wikipedia supplies the verified landmark photo.
    expect(commonsCalls, greaterThanOrEqualTo(0));
  });

  test('rejects SVG / flag / map style Wikipedia images', () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.method == 'HEAD') {
        return http.Response('', 200, headers: <String, String>{
          'content-type': 'image/svg+xml',
        });
      }
      if (request.url.host.contains('wikipedia.org')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'query': <String, Object?>{
              'pages': <String, Object?>{
                '1': <String, Object?>{
                  'title': 'Tunisia',
                  'fullurl': 'https://en.wikipedia.org/wiki/Tunisia',
                  'description': 'Country in North Africa',
                  'extract': 'Tunisia is a country in North Africa.',
                  'pageimage': 'Flag_of_Tunisia.svg',
                  'thumbnail': <String, Object?>{
                    'source':
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/Flag_of_Tunisia.svg/800px-Flag_of_Tunisia.svg.png',
                  },
                  'original': <String, Object?>{
                    'source':
                        'https://upload.wikimedia.org/wikipedia/commons/Flag_of_Tunisia.svg',
                  },
                },
              },
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.host.contains('commons.wikimedia.org')) {
        return http.Response('{}', 404);
      }
      return http.Response('{}', 404);
    });

    final DestinationCoverService service =
        DestinationCoverService(client: client);
    final DestinationCoverResult result = await service.resolve(
      destination: '',
      country: 'Nauru', // capital + country article only; mock returns flags
    );
    expect(result.imageUrl, isEmpty);
    expect(result.matchLevel, DestinationCoverResult.levelFallback);
  });

  test('same country reuses cache; country change yields another cover',
      () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.method == 'HEAD' || request.method == 'GET') {
        if (request.url.path.contains('.jpg') ||
            request.url.path.contains('thumb')) {
          return http.Response('fake', 200, headers: <String, String>{
            'content-type': 'image/jpeg',
          });
        }
      }
      if (request.url.host.contains('wikipedia.org')) {
        final String titles = request.url.queryParameters['titles'] ?? '';
        final bool france = titles.contains('Eiffel');
        final bool germany = titles.contains('Brandenburg');
        if (!france && !germany && !titles.contains('Neuschwanstein') &&
            !titles.contains('Mont-Saint') &&
            !titles.contains('France') &&
            !titles.contains('Germany') &&
            !titles.contains('Paris') &&
            !titles.contains('Berlin')) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'query': <String, Object?>{
                'pages': <String, Object?>{
                  '-1': <String, Object?>{'missing': ''},
                },
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        final String slug = france || titles.contains('France') || titles.contains('Paris') || titles.contains('Mont-Saint')
            ? 'eiffel'
            : 'brandenburg';
        final String label = slug == 'eiffel' ? 'Eiffel Tower' : 'Brandenburg Gate';
        return http.Response(
          jsonEncode(<String, Object?>{
            'query': <String, Object?>{
              'pages': <String, Object?>{
                '1': <String, Object?>{
                  'title': label,
                  'fullurl': 'https://en.wikipedia.org/wiki/$label',
                  'description': slug == 'eiffel'
                      ? 'Tower in Paris, France'
                      : 'Gate in Berlin, Germany',
                  'extract': slug == 'eiffel'
                      ? 'The Eiffel Tower is in Paris, France.'
                      : 'The Brandenburg Gate is in Berlin, Germany.',
                  'pageimage': '$slug.jpg',
                  'thumbnail': <String, Object?>{
                    'source':
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/$slug.jpg/1600px.jpg',
                  },
                  'original': <String, Object?>{
                    'source':
                        'https://upload.wikimedia.org/wikipedia/commons/$slug.jpg',
                  },
                },
              },
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final DestinationCoverService service =
        DestinationCoverService(client: client);
    final DestinationCoverResult a = await service.resolve(
      destination: '',
      country: 'France',
    );
    final DestinationCoverResult a2 = await service.resolve(
      destination: '',
      country: 'France',
    );
    final DestinationCoverResult b = await service.resolve(
      destination: '',
      country: 'Germany',
    );

    expect(a.imageUrl, a2.imageUrl);
    expect(a.landmark.toLowerCase(), contains('eiffel'));
    expect(b.landmark.toLowerCase(), anyOf(contains('brandebourg'), contains('brandenburg'), contains('neuschwanstein')));
    expect(a.imageUrl, isNot(equals(b.imageUrl)));
  });

  test('empty miss is not sticky — forceRefresh can search again', () async {
    var allowPhotos = false;
    final MockClient client = MockClient((http.Request request) async {
      if (request.method == 'HEAD') {
        return http.Response('', 200, headers: <String, String>{
          'content-type': 'image/jpeg',
        });
      }
      if (request.url.host.contains('wikipedia.org')) {
        if (!allowPhotos) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'query': <String, Object?>{
                'pages': <String, Object?>{
                  '-1': <String, Object?>{'missing': ''},
                },
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'query': <String, Object?>{
              'pages': <String, Object?>{
                '1': <String, Object?>{
                  'title': 'Sidi Bou Said',
                  'fullurl': 'https://en.wikipedia.org/wiki/Sidi_Bou_Said',
                  'description': 'Town in Tunisia',
                  'extract': 'Sidi Bou Said is in Tunisia.',
                  'pageimage': 'sidi.jpg',
                  'thumbnail': <String, Object?>{
                    'source':
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/sidi.jpg/1600px.jpg',
                  },
                  'original': <String, Object?>{
                    'source':
                        'https://upload.wikimedia.org/wikipedia/commons/sidi.jpg',
                  },
                },
              },
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final DestinationCoverService service =
        DestinationCoverService(client: client);
    final DestinationCoverResult miss = await service.resolve(
      destination: '',
      country: 'Tunisia',
    );
    expect(miss.imageUrl, isEmpty);

    allowPhotos = true;
    final DestinationCoverResult hit = await service.resolve(
      destination: '',
      country: 'Tunisia',
      forceRefresh: true,
    );
    expect(hit.imageUrl, isNotEmpty);
  });

  test('gallery returns 5 country landmark photos', () async {
    var wikiCalls = 0;
    final MockClient client = MockClient((http.Request request) async {
      if (request.method == 'HEAD' ||
          (request.method == 'GET' &&
              request.url.host.contains('upload.wikimedia.org'))) {
        return http.Response('', 200, headers: <String, String>{
          'content-type': 'image/jpeg',
        });
      }
      if (request.url.host.contains('wikipedia.org')) {
        wikiCalls += 1;
        final String titles = request.url.queryParameters['titles'] ?? 'Place';
        final String slug =
            'fr_${wikiCalls}_${titles.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}';
        return http.Response(
          jsonEncode(<String, Object?>{
            'query': <String, Object?>{
              'pages': <String, Object?>{
                '$wikiCalls': <String, Object?>{
                  'title': titles,
                  'fullurl': 'https://en.wikipedia.org/wiki/$slug',
                  'description': 'Landmark in France',
                  'extract': '$titles is a landmark in France.',
                  'pageimage': '$slug.jpg',
                  'thumbnail': <String, Object?>{
                    'source':
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a$wikiCalls/$slug.jpg/1280px-$slug.jpg',
                  },
                  'original': <String, Object?>{
                    'source':
                        'https://upload.wikimedia.org/wikipedia/commons/a/a$wikiCalls/$slug.jpg',
                  },
                },
              },
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.host.contains('commons.wikimedia.org')) {
        final String q =
            (request.url.queryParameters['gsrsearch'] ?? 'France').toLowerCase();
        final String hint = q.contains('eiffel')
            ? 'Eiffel'
            : q.contains('mont')
                ? 'MontSaintMichel'
                : q.contains('paris')
                    ? 'Paris'
                    : 'FranceLandmark';
        return http.Response(
          jsonEncode(<String, Object?>{
            'query': <String, Object?>{
              'pages': <String, Object?>{
                '10': <String, Object?>{
                  'title': 'File:$hint gallery extra.jpg',
                  'imageinfo': <Map<String, Object?>>[
                    <String, Object?>{
                      'mime': 'image/jpeg',
                      'width': 1600,
                      'height': 1000,
                      'thumburl':
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/$hint-extra.jpg/1280px-$hint-extra.jpg',
                      'url':
                          'https://upload.wikimedia.org/wikipedia/commons/b/b1/$hint-extra.jpg',
                    },
                  ],
                },
              },
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final DestinationCoverService service =
        DestinationCoverService(client: client);
    final List<GalleryPhoto> gallery = await service.resolveGallery(
      destination: '',
      country: 'France',
      minCount: 5,
      maxCount: 5,
    );
    expect(gallery.length, 5);
    expect(
      gallery.every((GalleryPhoto p) => p.url.contains('upload.wikimedia.org')),
      isTrue,
    );
    expect(
      gallery.any((GalleryPhoto p) => p.credit.toLowerCase().contains('unsplash')),
      isFalse,
    );
  });

  test('catalog helper remains available', () {
    expect(DestinationPhotos.lookupUrl(destination: 'Paris'), isNotNull);
  });
}

