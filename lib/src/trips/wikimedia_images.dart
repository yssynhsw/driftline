import 'dart:collection';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Helpers for loading Wikimedia Commons / Wikipedia images in the app.
///
/// Applies to **every country**:
/// - Wikimedia rejects non-standard hotlink sizes (429 + w.wiki/GHai)
/// - Full originals are rate-limited; prefer 1280px thumbs
/// - Requests without a proper User-Agent are often blocked
class WikimediaImages {
  WikimediaImages._();

  static const String userAgent =
      'DriftlineTravelApp/1.0 (destination-cover; educational; contact=local-dev)';

  /// Headers required by CachedNetworkImage / flutter_cache_manager.
  static const Map<String, String> httpHeaders = <String, String>{
    'User-Agent': userAgent,
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    'Referer': 'https://commons.wikimedia.org/',
  };

  /// Wikimedia production thumbnail steps (w.wiki/GHai).
  static const List<int> allowedThumbWidths = <int>[
    20,
    40,
    60,
    120,
    250,
    330,
    500,
    960,
    1280,
    1920,
    3840,
  ];

  /// Preferred display width for trip covers.
  static const int coverThumbWidth = 1280;

  /// Shared cache that always sends Wikimedia-friendly headers.
  static final CacheManager cacheManager = CacheManager(
    Config(
      'driftlineWikimediaCovers',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 200,
      fileService: HttpFileService(httpClient: _WikimediaHttpClient()),
    ),
  );

  /// Normalize any Commons/Wikipedia media URL for reliable in-app display.
  static String normalizeForDisplay(String url, {int width = coverThumbWidth}) {
    String out = url.trim();
    if (out.isEmpty) {
      return out;
    }
    if (out.contains('thumb.wikimedia.org/wikipedia/')) {
      out = out.replaceFirst(
        'https://thumb.wikimedia.org/wikipedia/',
        'https://upload.wikimedia.org/wikipedia/',
      );
    }
    final int q = out.indexOf('?');
    if (q > 0) {
      out = out.substring(0, q);
    }

    final int safeWidth = _nearestAllowedWidth(width);

    // Full file on any Wikipedia project (commons, en, fr, …).
    final RegExp fullFile = RegExp(
      r'^(https://upload\.wikimedia\.org/wikipedia/[a-z0-9_-]+)/([0-9a-f])/([0-9a-f]{2})/([^/]+)$',
      caseSensitive: false,
    );
    final Match? full = fullFile.firstMatch(out);
    if (full != null) {
      final String fileName = full.group(4)!;
      return '${full.group(1)}/thumb/${full.group(2)}/${full.group(3)}/$fileName/${safeWidth}px-$fileName';
    }

    // Existing thumb → snap width to an allowed step.
    final RegExp thumbFile = RegExp(
      r'^(https://upload\.wikimedia\.org/wikipedia/[a-z0-9_-]+/thumb/.+/)(\d+)px-(.+)$',
      caseSensitive: false,
    );
    final Match? thumb = thumbFile.firstMatch(out);
    if (thumb != null) {
      return '${thumb.group(1)}${safeWidth}px-${thumb.group(3)}';
    }

    return out;
  }

  /// Alternate display sizes to try when the primary thumb fails to load.
  static List<String> displayCandidates(String url) {
    final LinkedHashSet<String> out = LinkedHashSet<String>();
    out.add(normalizeForDisplay(url));
    for (final int width in <int>[960, 500, 1920]) {
      out.add(normalizeForDisplay(url, width: width));
    }
    final String? original = tryOriginalFileUrl(url);
    if (original != null) {
      out.add(original);
    }
    return out.toList(growable: false);
  }

  /// Best-effort recovery of the original Commons/Wikipedia file URL.
  static String? tryOriginalFileUrl(String url) {
    final String normalized = normalizeForDisplay(url);
    final RegExp thumb = RegExp(
      r'^(https://upload\.wikimedia\.org/wikipedia/[a-z0-9_-]+)/thumb/([0-9a-f])/([0-9a-f]{2})/([^/]+)/\d+px-\4$',
      caseSensitive: false,
    );
    final Match? match = thumb.firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return '${match.group(1)}/${match.group(2)}/${match.group(3)}/${match.group(4)}';
  }

  static int _nearestAllowedWidth(int requested) {
    for (final int step in allowedThumbWidths) {
      if (step >= requested) {
        return step;
      }
    }
    return allowedThumbWidths.last;
  }
}

class _WikimediaHttpClient extends http.BaseClient {
  _WikimediaHttpClient() : _inner = http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    WikimediaImages.httpHeaders.forEach((String key, String value) {
      request.headers.putIfAbsent(key, () => value);
    });
    return _inner.send(request);
  }
}
