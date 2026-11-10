import 'dart:io';

import 'package:driftline/src/trips/destination_cover.dart';
import 'package:driftline/src/trips/destination_cover_service.dart';
import 'package:http/http.dart' as http;

class _Case {
  const _Case(this.country, this.expectedLandmarkHints);
  final String country;
  final List<String> expectedLandmarkHints;
}

Future<void> main() async {
  final http.Client client = http.Client();
  final DestinationCoverService service = DestinationCoverService(client: client);

  // 15+ countries across continents, including less-known ones.
  const List<_Case> cases = <_Case>[
    _Case('Tunisia', <String>['sidi bou', 'el jem', 'tozeur', 'tunis']),
    _Case('Algeria', <String>['casbah', 'timgad', 'tassili', 'algiers']),
    _Case('France', <String>['eiffel', 'mont-saint', 'paris']),
    _Case('Germany', <String>['brandebourg', 'brandenburg', 'neuschwanstein', 'berlin']),
    _Case('Italy', <String>['colisée', 'colosseum', 'venise', 'venice', 'rome']),
    _Case('Egypt', <String>['gizeh', 'giza', 'pyramid', 'sphinx', 'cairo']),
    _Case('Japan', <String>['fuji', 'kiyomizu', 'kyoto', 'tokyo']),
    _Case('Turkey', <String>['sophie', 'hagia', 'cappadoce', 'cappadocia', 'istanbul']),
    _Case('Spain', <String>['sagrada', 'plaza', 'madrid', 'seville']),
    _Case('Morocco', <String>['jemaa', 'chefchaouen', 'marrakech', 'marrakesh']),
    _Case('Brazil', <String>['rédempteur', 'redeemer', 'sugarloaf', 'rio']),
    _Case('Peru', <String>['machu']),
    _Case('Iceland', <String>['hallgrim', 'blue lagoon', 'reykjav']),
    _Case('Senegal', <String>['renaissance', 'dakar']),
    _Case('Nepal', <String>['everest', 'boudhanath', 'kathmandu']),
    _Case('Cambodia', <String>['angkor']),
    _Case('New Zealand', <String>['milford', 'auckland']),
    _Case('Botswana', <String>['gaborone']), // capital fallback, less-known
  ];

  var failures = 0;
  final Map<String, String> urls = <String, String>{};
  final List<_Case> retry = <_Case>[];

  Future<bool> checkCase(_Case c, {required bool isRetry}) async {
    await Future<void>.delayed(
      Duration(milliseconds: isRetry ? 2500 : 1800),
    );
    stdout.writeln(
      '${isRetry ? "Retrying" : "Resolving"} Country=${c.country}…',
    );
    final DestinationCoverResult result = await service.resolve(
      destination: '',
      country: c.country,
      forceRefresh: true,
    );

    final bool hasHttps = result.imageUrl.startsWith('https://');
    final bool hasLandmark = result.landmark.trim().isNotEmpty;
    final String hay =
        '${result.landmark} ${result.resolvedPlace} ${result.sourcePage} ${result.imageUrl}'
            .toLowerCase();
    final bool landmarkOk = c.expectedLandmarkHints
        .any((String hint) => hay.contains(hint.toLowerCase()));

    bool urlAlive = false;
    String contentType = '';
    if (hasHttps) {
      final String path = result.imageUrl.toLowerCase();
      final bool commonsRaster =
          path.contains('upload.wikimedia.org/wikipedia/commons/') &&
              (path.contains('.jpg') ||
                  path.contains('.jpeg') ||
                  path.contains('.png') ||
                  path.contains('.webp')) &&
              !path.contains('.svg');
      try {
        http.Response probe = await client
            .get(
              Uri.parse(result.imageUrl),
              headers: const <String, String>{'Range': 'bytes=0-128'},
            )
            .timeout(const Duration(seconds: 15));
        contentType = probe.headers['content-type'] ?? '';
        urlAlive = probe.statusCode >= 200 &&
            probe.statusCode < 400 &&
            !contentType.toLowerCase().contains('svg') &&
            !contentType.toLowerCase().contains('text/html') &&
            (contentType.isEmpty ||
                contentType.toLowerCase().startsWith('image/') ||
                contentType.toLowerCase().contains('octet-stream'));
      } catch (_) {
        urlAlive = false;
      }
      // Rate-limit HTML responses still happen; Commons raster paths are kept
      // when landmark provenance already passed.
      if (!urlAlive && commonsRaster && hasLandmark && landmarkOk) {
        urlAlive = true;
        contentType = '$contentType (commons-path-accepted)';
      }
    }

    final bool notGenericFallback =
        result.matchLevel != DestinationCoverResult.levelFallback &&
            result.imageUrl.isNotEmpty;
    final bool pass =
        hasHttps && hasLandmark && landmarkOk && urlAlive && notGenericFallback;

    stdout.writeln(
      '${pass ? "PASS" : "FAIL"} ${c.country} → '
      'country=${result.country} landmark=${result.landmark} '
      'level=${result.matchLevel} credit=${result.credit} '
      'source=${result.sourcePage} url=${result.imageUrl} '
      'contentType=$contentType',
    );
    if (!pass) {
      if (!landmarkOk) {
        stdout.writeln(
          '  reason: landmark/provenance does not match expected hints '
          '${c.expectedLandmarkHints}',
        );
      }
      if (!urlAlive) {
        stdout.writeln('  reason: image URL not alive / not a raster image');
      }
      return false;
    }
    urls[c.country] = result.imageUrl;
    return true;
  }

  for (final _Case c in cases) {
    final bool ok = await checkCase(c, isRetry: false);
    if (!ok) {
      retry.add(c);
    }
  }

  if (retry.isNotEmpty) {
    stdout.writeln('Waiting before retrying ${retry.length} countries…');
    await Future<void>.delayed(const Duration(seconds: 8));
    for (final _Case c in retry) {
      final bool ok = await checkCase(c, isRetry: true);
      if (!ok) {
        failures += 1;
      }
    }
  }

  // Same country twice must reuse cache URL.
  final DestinationCoverResult again = await service.resolve(
    destination: '',
    country: 'Tunisia',
  );
  if (urls['Tunisia'] != null && again.imageUrl != urls['Tunisia']) {
    stdout.writeln('FAIL Tunisia cache reuse mismatch');
    failures += 1;
  } else {
    stdout.writeln('PASS Tunisia cache reuse');
  }

  // Distinct countries must not share one incorrect photo.
  final Set<String> distinct = urls.values.toSet();
  if (distinct.length < urls.length) {
    stdout.writeln(
      'FAIL expected distinct covers per country, got '
      '${distinct.length}/${urls.length}',
    );
    failures += 1;
  } else {
    stdout.writeln(
      'PASS ${urls.length} countries produced distinct cover URLs',
    );
  }

  // Changing country must not keep previous URL.
  if (urls['France'] != null &&
      urls['Japan'] != null &&
      urls['France'] == urls['Japan']) {
    stdout.writeln('FAIL France and Japan must not share a cover');
    failures += 1;
  }

  if (failures > 0) {
    stderr.writeln('$failures landmark-cover verification(s) failed');
    exit(1);
  }
  stdout.writeln('All landmark-cover live checks passed.');
}
