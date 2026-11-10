// Legacy geo/commons helpers retained for future ranking experiments.
// ignore_for_file: unused_element

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'country_landmarks.dart';
import 'destination_cover.dart';
import 'gallery_photo.dart';
import 'wikimedia_images.dart';

/// Resolves a real cover photograph for any destination without shipping
/// Unsplash/Pexels secrets in the Flutter client.
///
/// Cover photos are **country + emblematic landmark** based:
/// 1. Map the selected Country to curated famous places (and capital)
/// 2. Pull the lead photograph from the landmark's Wikipedia page
/// 3. Reject maps / flags / logos / SVG; require a live image URL
/// 4. Fall back to Commons only when the filename clearly names the landmark
/// 5. Never claim a generic country-name title match as proof of place
class DestinationCoverService {
  DestinationCoverService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const String _userAgent =
      'DriftlineTravelApp/1.0 (destination-cover; educational; contact=local-dev)';

  final Map<String, DestinationCoverResult> _memoryCache =
      <String, DestinationCoverResult>{};
  final Map<String, List<GalleryPhoto>> _galleryCache =
      <String, List<GalleryPhoto>>{};

  /// Builds a 5-photo country gallery from emblematic landmarks.
  ///
  /// Driven by the selected Country (not a random city search). Works for every
  /// country in the app catalog via curated landmarks + capital fallbacks.
  Future<List<GalleryPhoto>> resolveGallery({
    required String destination,
    String country = '',
    int minCount = 5,
    int maxCount = 5,
    bool forceRefresh = false,
  }) async {
    final int minPhotos = minCount.clamp(1, 8);
    final int maxPhotos = maxCount.clamp(minPhotos, 8);
    final String dest = destination.trim();
    final String pays = country.trim();

    final String englishCountry = pays.isNotEmpty
        ? _toEnglishCountry(pays)
        : _toEnglishCountry(
            (dest.isNotEmpty ? await _geocode(dest, '') : null)?.country ?? '',
          );
    if (englishCountry.isEmpty) {
      return const <GalleryPhoto>[];
    }

    final String displayCountry = _displayCountryName(englishCountry);
    final String cacheKey =
        'gallery|country|${_fold(englishCountry)}|$maxPhotos';
    if (!forceRefresh) {
      final List<GalleryPhoto>? cached = _galleryCache[cacheKey];
      if (cached != null && cached.length >= minPhotos) {
        return cached;
      }
    } else {
      _galleryCache.remove(cacheKey);
    }

    final List<GalleryPhoto> photos = <GalleryPhoto>[];
    final Set<String> seenUrls = <String>{};

    void addPhoto(GalleryPhoto photo) {
      if (photos.length >= maxPhotos) {
        return;
      }
      final String normalized = WikimediaImages.normalizeForDisplay(photo.url);
      if (normalized.isEmpty || !_looksLikeCommonsRasterPath(normalized)) {
        return;
      }
      if (_isUnreliableImage(normalized, photo.credit, '')) {
        return;
      }
      final String key = normalized.split('?').first.toLowerCase();
      if (!seenUrls.add(key)) {
        return;
      }
      photos.add(
        GalleryPhoto(
          url: normalized,
          credit: photo.credit,
          matchLevel: photo.matchLevel,
          representativeOnly: false,
        ),
      );
    }

    final List<CountryLandmark> landmarks =
        landmarksForCountry(englishCountry).take(8).toList(growable: false);

    // 1) Wikipedia lead image for each landmark (high trust).
    for (final CountryLandmark landmark in landmarks) {
      if (photos.length >= maxPhotos) {
        break;
      }
      final _WikiPageImage? page =
          await _fetchWikipediaPageImage(landmark.wikipediaTitle);
      if (page == null) {
        continue;
      }
      if (_isUnreliableImage(page.imageUrl, page.title, page.description)) {
        continue;
      }
      addPhoto(
        GalleryPhoto(
          url: page.imageUrl,
          credit: page.credit,
          matchLevel: DestinationCoverResult.levelExact,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    // 2) Commons photos whose filenames name the landmark.
    if (photos.length < minPhotos) {
      for (final CountryLandmark landmark in landmarks) {
        if (photos.length >= maxPhotos) {
          break;
        }
        final List<String> tokens = <String>[
          ...landmark.aliases,
          landmark.label,
        ];
        var tokenAttempts = 0;
        for (final String raw in tokens) {
          if (photos.length >= maxPhotos || tokenAttempts >= 2) {
            break;
          }
          final String token = raw.trim();
          if (token.length < 4 || token.split(RegExp(r'\s+')).length > 3) {
            continue;
          }
          tokenAttempts += 1;
          final List<GalleryPhoto> hits = await _commonsTextSearchMany(
            query: token,
            resolvedPlace: landmark.label,
            country: displayCountry,
            level: DestinationCoverResult.levelExact,
            limit: 6,
            requireTitleHint: token,
          );
          for (final GalleryPhoto hit in hits) {
            final String path = Uri.parse(hit.url).path;
            if (!_titleMatchesAny(
              path,
              <String>[token, ...landmark.aliases, landmark.label],
            )) {
              continue;
            }
            if (_landmarkPathScore(
                  path,
                  landmark: landmark,
                  queryToken: token,
                ) <=
                0) {
              continue;
            }
            addPhoto(hit);
            if (photos.length >= maxPhotos) {
              break;
            }
          }
        }
      }
    }

    // 3) Last resort: Commons search on country + tourism (still no Unsplash).
    if (photos.length < minPhotos) {
      for (final String query in <String>[
        '$englishCountry landmark',
        '$englishCountry tourism',
        '$displayCountry tourisme',
      ]) {
        if (photos.length >= maxPhotos) {
          break;
        }
        final List<GalleryPhoto> hits = await _commonsTextSearchMany(
          query: query,
          resolvedPlace: displayCountry,
          country: displayCountry,
          level: DestinationCoverResult.levelRegional,
          limit: 8,
          requireTitleHint: englishCountry,
        );
        for (final GalleryPhoto hit in hits) {
          addPhoto(hit);
          if (photos.length >= maxPhotos) {
            break;
          }
        }
      }
    }

    final List<GalleryPhoto> result =
        List<GalleryPhoto>.unmodifiable(photos.take(maxPhotos));
    if (result.length >= minPhotos) {
      _galleryCache[cacheKey] = result;
    }
    return result;
  }

  Future<DestinationCoverResult> resolve({
    required String destination,
    String country = '',
    bool forceRefresh = false,
  }) async {
    final String dest = destination.trim();
    final String pays = country.trim();

    if (dest.isEmpty && pays.isEmpty) {
      return const DestinationCoverResult(
        imageUrl: '',
        matchLevel: DestinationCoverResult.levelFallback,
        resolvedPlace: '',
        credit: '',
        representativeOnly: true,
      );
    }

    // Country field wins; otherwise infer country from a typed place.
    final String englishCountry;
    if (pays.isNotEmpty) {
      englishCountry = _toEnglishCountry(pays);
    } else {
      final _GeoPlace? place = dest.isNotEmpty ? await _geocode(dest, '') : null;
      englishCountry = _toEnglishCountry(place?.country ?? '');
    }
    if (englishCountry.isEmpty) {
      return DestinationCoverResult(
        imageUrl: '',
        matchLevel: DestinationCoverResult.levelFallback,
        resolvedPlace: dest,
        country: pays,
        representativeOnly: true,
      );
    }

    final String displayCountry = _displayCountryName(englishCountry);
    final String cacheKey = 'country|${_fold(englishCountry)}';
    if (!forceRefresh) {
      final DestinationCoverResult? cached = _memoryCache[cacheKey];
      // Only reuse successful covers — empty misses must remain retryable.
      if (cached != null && cached.imageUrl.trim().isNotEmpty) {
        return _withDisplayUrl(cached);
      }
    } else {
      _memoryCache.remove(cacheKey);
    }

    final List<CountryLandmark> landmarks =
        landmarksForCountry(englishCountry).take(4).toList(growable: false);
    final List<String> countryHints = _countryHints(englishCountry);

    for (int i = 0; i < landmarks.length; i++) {
      final CountryLandmark landmark = landmarks[i];
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      // Wikipedia lead image is usually the emblematic photo of the landmark.
      final DestinationCoverResult? wiki = await _wikipediaLandmarkCover(
        landmark: landmark,
        englishCountry: englishCountry,
        displayCountry: displayCountry,
        countryHints: countryHints,
      );
      if (wiki != null) {
        return _cache(cacheKey, _withDisplayUrl(wiki));
      }

      // Commons fallback: filename must name the landmark (not only the country).
      final DestinationCoverResult? commons = await _commonsLandmarkCover(
        landmark: landmark,
        englishCountry: englishCountry,
        displayCountry: displayCountry,
      );
      if (commons != null) {
        return _cache(cacheKey, _withDisplayUrl(commons));
      }
    }

    // No trustworthy photo — do NOT cache empties so the user can retry.
    return DestinationCoverResult(
      imageUrl: '',
      matchLevel: DestinationCoverResult.levelFallback,
      resolvedPlace: displayCountry,
      country: displayCountry,
      representativeOnly: true,
    );
  }

  /// English [kCountries] key used by the landmark catalog.
  String _toEnglishCountry(String raw) {
    final String folded = _fold(raw.trim());
    if (folded.isEmpty) {
      return '';
    }
    const Map<String, String> aliases = <String, String>{
      'tunisia': 'Tunisia',
      'tunisie': 'Tunisia',
      'algeria': 'Algeria',
      'algerie': 'Algeria',
      'germany': 'Germany',
      'allemagne': 'Germany',
      'deutschland': 'Germany',
      'morocco': 'Morocco',
      'maroc': 'Morocco',
      'france': 'France',
      'spain': 'Spain',
      'espagne': 'Spain',
      'italy': 'Italy',
      'italie': 'Italy',
      'egypt': 'Egypt',
      'egypte': 'Egypt',
      'japan': 'Japan',
      'japon': 'Japan',
      'turkey': 'Turkey',
      'turquie': 'Turkey',
      'united states': 'United States',
      'usa': 'United States',
      'etats unis': 'United States',
      'united kingdom': 'United Kingdom',
      'uk': 'United Kingdom',
      'royaume uni': 'United Kingdom',
      'czechia': 'Czechia',
      'czech republic': 'Czechia',
      'republique tcheque': 'Czechia',
      'south korea': 'South Korea',
      'korea': 'South Korea',
      'coree du sud': 'South Korea',
      'uae': 'United Arab Emirates',
      'united arab emirates': 'United Arab Emirates',
      'emirats arabes unis': 'United Arab Emirates',
      'ivory coast': 'Ivory Coast',
      'cote divoire': 'Ivory Coast',
      'russia': 'Russia',
      'russie': 'Russia',
      'brazil': 'Brazil',
      'bresil': 'Brazil',
      'china': 'China',
      'chine': 'China',
      'india': 'India',
      'inde': 'India',
      'greece': 'Greece',
      'grece': 'Greece',
      'switzerland': 'Switzerland',
      'suisse': 'Switzerland',
      'netherlands': 'Netherlands',
      'pays bas': 'Netherlands',
      'holland': 'Netherlands',
      'portugal': 'Portugal',
      'peru': 'Peru',
      'perou': 'Peru',
      'mexico': 'Mexico',
      'mexique': 'Mexico',
      'canada': 'Canada',
      'australia': 'Australia',
      'australie': 'Australia',
      'new zealand': 'New Zealand',
      'nouvelle zelande': 'New Zealand',
      'south africa': 'South Africa',
      'afrique du sud': 'South Africa',
      'kenya': 'Kenya',
      'senegal': 'Senegal',
      'vietnam': 'Vietnam',
      'thailand': 'Thailand',
      'thailande': 'Thailand',
      'indonesia': 'Indonesia',
      'indonesie': 'Indonesia',
      'argentina': 'Argentina',
      'argentine': 'Argentina',
      'chile': 'Chile',
      'chili': 'Chile',
      'poland': 'Poland',
      'pologne': 'Poland',
      'sweden': 'Sweden',
      'suede': 'Sweden',
      'norway': 'Norway',
      'norvege': 'Norway',
      'denmark': 'Denmark',
      'danemark': 'Denmark',
      'finland': 'Finland',
      'finlande': 'Finland',
      'ireland': 'Ireland',
      'irlande': 'Ireland',
      'iceland': 'Iceland',
      'islande': 'Iceland',
      'hungary': 'Hungary',
      'hongrie': 'Hungary',
      'croatia': 'Croatia',
      'croatie': 'Croatia',
      'belgium': 'Belgium',
      'belgique': 'Belgium',
      'austria': 'Austria',
      'autriche': 'Austria',
      'jordan': 'Jordan',
      'jordanie': 'Jordan',
      'saudi arabia': 'Saudi Arabia',
      'arabie saoudite': 'Saudi Arabia',
      'nepal': 'Nepal',
      'cambodia': 'Cambodia',
      'cambodge': 'Cambodia',
      'cuba': 'Cuba',
      'colombia': 'Colombia',
      'colombie': 'Colombia',
      'ukraine': 'Ukraine',
      'malaysia': 'Malaysia',
      'malaisie': 'Malaysia',
      'maldives': 'Maldives',
      'singapore': 'Singapore',
      'singapour': 'Singapore',
      'ethiopia': 'Ethiopia',
      'ethiopie': 'Ethiopia',
      'ghana': 'Ghana',
      'nigeria': 'Nigeria',
      'iran': 'Iran',
      'israel': 'Israel',
    };
    final String? mapped = aliases[folded];
    if (mapped != null) {
      return mapped;
    }
    // Exact / case-insensitive match against catalog keys.
    for (final String key in kCountryLandmarks.keys) {
      if (_fold(key) == folded) {
        return key;
      }
    }
    for (final String key in kCountryCapitals.keys) {
      if (_fold(key) == folded) {
        return key;
      }
    }
    return raw.trim();
  }

  String _displayCountryName(String englishCountry) {
    const Map<String, String> fr = <String, String>{
      'Tunisia': 'Tunisie',
      'Algeria': 'Algérie',
      'Germany': 'Allemagne',
      'Morocco': 'Maroc',
      'Spain': 'Espagne',
      'Italy': 'Italie',
      'Egypt': 'Égypte',
      'Japan': 'Japon',
      'Turkey': 'Turquie',
      'United States': 'États-Unis',
      'United Kingdom': 'Royaume-Uni',
      'United Arab Emirates': 'Émirats arabes unis',
      'South Korea': 'Corée du Sud',
      'South Africa': 'Afrique du Sud',
      'Czechia': 'Tchéquie',
      'Brazil': 'Brésil',
      'China': 'Chine',
      'India': 'Inde',
      'Greece': 'Grèce',
      'Switzerland': 'Suisse',
      'Netherlands': 'Pays-Bas',
      'Peru': 'Pérou',
      'Mexico': 'Mexique',
      'Australia': 'Australie',
      'New Zealand': 'Nouvelle-Zélande',
      'Poland': 'Pologne',
      'Sweden': 'Suède',
      'Norway': 'Norvège',
      'Denmark': 'Danemark',
      'Finland': 'Finlande',
      'Ireland': 'Irlande',
      'Iceland': 'Islande',
      'Hungary': 'Hongrie',
      'Croatia': 'Croatie',
      'Belgium': 'Belgique',
      'Austria': 'Autriche',
      'Jordan': 'Jordanie',
      'Saudi Arabia': 'Arabie saoudite',
      'Cambodia': 'Cambodge',
      'Colombia': 'Colombie',
      'Russia': 'Russie',
      'Argentina': 'Argentine',
      'Chile': 'Chili',
      'Thailand': 'Thaïlande',
      'Indonesia': 'Indonésie',
      'Malaysia': 'Malaisie',
      'Singapore': 'Singapour',
      'Ethiopia': 'Éthiopie',
      'Ivory Coast': 'Côte d\'Ivoire',
    };
    return fr[englishCountry] ?? englishCountry;
  }

  List<String> _countryHints(String englishCountry) {
    final Set<String> hints = <String>{
      englishCountry,
      _displayCountryName(englishCountry),
    };
    // Demonyms / common alternate spellings used in Wikipedia extracts.
    const Map<String, List<String>> extras = <String, List<String>>{
      'Tunisia': <String>['Tunisian', 'Tunis'],
      'Algeria': <String>['Algerian', 'Algiers'],
      'Germany': <String>['German', 'Berlin', 'Bavaria'],
      'France': <String>['French', 'Paris'],
      'Italy': <String>['Italian', 'Rome', 'Venice'],
      'Egypt': <String>['Egyptian', 'Giza', 'Cairo'],
      'Japan': <String>['Japanese', 'Honshu', 'Kyoto'],
      'Turkey': <String>['Turkish', 'Istanbul', 'Anatolia'],
      'Spain': <String>['Spanish', 'Barcelona', 'Seville'],
      'Morocco': <String>['Moroccan', 'Marrakesh', 'Marrakech'],
      'United States': <String>['American', 'USA', 'United States'],
      'United Kingdom': <String>['British', 'England', 'London'],
      'Brazil': <String>['Brazilian', 'Rio'],
      'China': <String>['Chinese'],
      'India': <String>['Indian'],
      'Greece': <String>['Greek', 'Hellenic'],
      'Peru': <String>['Peruvian'],
      'Jordan': <String>['Jordanian'],
      'Nepal': <String>['Nepalese', 'Nepali'],
      'Cambodia': <String>['Cambodian', 'Khmer'],
    };
    hints.addAll(extras[englishCountry] ?? const <String>[]);
    return hints.toList(growable: false);
  }

  Future<DestinationCoverResult?> _wikipediaLandmarkCover({
    required CountryLandmark landmark,
    required String englishCountry,
    required String displayCountry,
    required List<String> countryHints,
  }) async {
    final _WikiPageImage? page = await _fetchWikipediaPageImage(
      landmark.wikipediaTitle,
    );
    if (page == null) {
      return null;
    }
    if (_isUnreliableImage(page.imageUrl, page.title, page.description)) {
      return null;
    }
    // Country article fallback must still look like a real photo of the place,
    // and the extract should mention the country (it usually does).
    final bool isCountryArticle =
        _fold(landmark.wikipediaTitle) == _fold(englishCountry);
    if (isCountryArticle &&
        !_extractMentionsCountry('${page.description} ${page.extract}', countryHints)) {
      return null;
    }
    if (!isCountryArticle &&
        page.extract.isNotEmpty &&
        !_extractMentionsCountry(
          '${page.description} ${page.extract} ${page.title}',
          <String>[...countryHints, ...landmark.matchTokens],
        )) {
      // Famous landmarks sometimes omit the country in the short description;
      // still accept when the page title clearly is our landmark.
      if (!_titleMatchesAny(page.title, landmark.matchTokens)) {
        return null;
      }
    }
    if (!await _urlLooksAlive(page.imageUrl)) {
      return null;
    }
    return DestinationCoverResult(
      imageUrl: page.imageUrl,
      matchLevel: DestinationCoverResult.levelExact,
      resolvedPlace: landmark.label,
      country: displayCountry,
      landmark: landmark.label,
      sourcePage: page.canonicalUrl.isNotEmpty
          ? page.canonicalUrl
          : 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(landmark.wikipediaTitle.replaceAll(' ', '_'))}',
      credit: page.credit,
      representativeOnly: false,
    );
  }

  Future<DestinationCoverResult?> _commonsLandmarkCover({
    required CountryLandmark landmark,
    required String englishCountry,
    required String displayCountry,
  }) async {
    // Prefer short, distinctive tokens (aliases/label) over long wiki titles
    // like "Giza pyramid complex" which over-constrain title matching.
    final List<String> tokens = <String>[
      ...landmark.aliases,
      landmark.label,
    ];
    final Set<String> seen = <String>{};
    var attempts = 0;
    for (final String raw in tokens) {
      if (attempts >= 2) {
        break;
      }
      final String token = raw.trim();
      if (token.length < 4) {
        continue;
      }
      // Skip very long multi-word titles for Commons search.
      if (token.split(RegExp(r'\s+')).length > 3) {
        continue;
      }
      final String key = _fold(token);
      if (!seen.add(key)) {
        continue;
      }
      attempts += 1;
      final List<GalleryPhoto> hits = await _commonsTextSearchMany(
        query: token,
        resolvedPlace: landmark.label,
        country: displayCountry,
        level: DestinationCoverResult.levelExact,
        limit: 6,
        requireTitleHint: token,
      );
      GalleryPhoto? best;
      int bestScore = 0;
      for (final GalleryPhoto photo in hits) {
        final String path = Uri.parse(photo.url).path;
        if (_isUnreliableImage(photo.url, path, photo.credit)) {
          continue;
        }
        if (!_titleMatchesAny(
          path,
          <String>[token, ...landmark.aliases, landmark.label],
        )) {
          continue;
        }
        final int score = _landmarkPathScore(
          path,
          landmark: landmark,
          queryToken: token,
        );
        if (score <= 0) {
          continue;
        }
        if (score > bestScore) {
          bestScore = score;
          best = photo;
        }
      }
      if (best != null) {
        final String normalized = _normalizeMediaUrl(best.url);
        if (!await _urlLooksAlive(normalized)) {
          continue;
        }
        return DestinationCoverResult(
          imageUrl: normalized,
          matchLevel: DestinationCoverResult.levelExact,
          resolvedPlace: landmark.label,
          country: displayCountry,
          landmark: landmark.label,
          sourcePage: 'https://commons.wikimedia.org/',
          credit: best.credit.isEmpty ? 'Wikimedia Commons' : best.credit,
          representativeOnly: false,
        );
      }
    }
    return null;
  }

  Future<_WikiPageImage?> _fetchWikipediaPageImage(String title) async {
    final Uri uri = Uri.https('en.wikipedia.org', '/w/api.php', <String, String>{
      'action': 'query',
      'format': 'json',
      'origin': '*',
      'redirects': '1',
      'titles': title,
      'prop': 'pageimages|info|extracts|description',
      'piprop': 'thumbnail|original|name',
      'pithumbsize': '1280',
      'inprop': 'url',
      'exintro': '1',
      'explaintext': '1',
      'exchars': '420',
    });
    try {
      http.Response response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode == 429 ||
          response.body.contains('too many requests')) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 14));
      }
      if (response.statusCode != 200 ||
          response.body.contains('too many requests')) {
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Map<String, dynamic> json = decoded;
      final Map<String, dynamic>? pages = (json['query']
          as Map<String, dynamic>?)?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) {
        return null;
      }
      final Map<String, dynamic> page =
          pages.values.whereType<Map<String, dynamic>>().first;
      if (page.containsKey('missing')) {
        return null;
      }
      final Map<String, dynamic>? original =
          page['original'] as Map<String, dynamic>?;
      final Map<String, dynamic>? thumb =
          page['thumbnail'] as Map<String, dynamic>?;
      final String thumbUrl =
          WikimediaImages.normalizeForDisplay('${thumb?['source'] ?? ''}'.trim());
      final String originalUrl = WikimediaImages.normalizeForDisplay(
        '${original?['source'] ?? ''}'.trim(),
      );
      // Prefer standard 1280px thumbs — full originals trigger Wikimedia 429s.
      String imageUrl = '';
      if (thumbUrl.isNotEmpty &&
          !_isUnreliableImage(thumbUrl, '${page['pageimage'] ?? ''}', '')) {
        imageUrl = thumbUrl;
      } else if (originalUrl.isNotEmpty &&
          !_isUnreliableImage(originalUrl, '${page['pageimage'] ?? ''}', '')) {
        imageUrl = originalUrl;
      }
      if (imageUrl.isEmpty) {
        return null;
      }
      final String creditName = '${page['pageimage'] ?? page['title'] ?? title}';
      return _WikiPageImage(
        title: '${page['title'] ?? title}',
        imageUrl: imageUrl,
        description: '${page['description'] ?? ''}',
        extract: '${page['extract'] ?? ''}',
        canonicalUrl: '${page['fullurl'] ?? ''}',
        credit: 'Wikipedia · $creditName',
      );
    } catch (_) {
      return null;
    }
  }

  String _normalizeMediaUrl(String url) =>
      WikimediaImages.normalizeForDisplay(url);

  DestinationCoverResult _withDisplayUrl(DestinationCoverResult cover) {
    final String raw = cover.imageUrl.trim();
    if (raw.isEmpty) {
      return cover;
    }
    final String display = WikimediaImages.normalizeForDisplay(raw);
    if (display == raw) {
      return cover;
    }
    return DestinationCoverResult(
      imageUrl: display,
      matchLevel: cover.matchLevel,
      resolvedPlace: cover.resolvedPlace,
      credit: cover.credit,
      country: cover.country,
      landmark: cover.landmark,
      sourcePage: cover.sourcePage,
      latitude: cover.latitude,
      longitude: cover.longitude,
      representativeOnly: cover.representativeOnly,
    );
  }

  bool _extractMentionsCountry(String text, List<String> hints) {
    final String folded = _fold(text);
    for (final String hint in hints) {
      final String h = _fold(hint.trim());
      if (h.length >= 3 && folded.contains(h)) {
        return true;
      }
    }
    return false;
  }

  bool _titleMatchesAny(String text, List<String> tokens) {
    final String folded = _fold(text);
    for (final String token in tokens) {
      if (_titleMatchesPlace(folded, token)) {
        return true;
      }
    }
    return false;
  }

  bool _isUnreliableImage(String url, String title, String description) {
    final String hay = _fold('$url $title $description');
    if (hay.contains('.svg') || hay.contains('image/svg')) {
      return true;
    }
    const List<String> banned = <String>[
      'flag_of',
      'flag of',
      'coat of arms',
      'coats of arms',
      'location map',
      'locator map',
      'orthographic',
      'logo',
      'icon',
      'pictogram',
      'emblem',
      'seal_of',
      'banner',
      'wordmark',
      'colonies',
      'reclus',
      'traffic',
      'apfel',
      'apple-',
      'apple_',
      'babucha',
      'bust_of',
      'bust of',
    ];
    for (final String bad in banned) {
      if (hay.contains(_fold(bad))) {
        return true;
      }
    }
    return false;
  }

  /// Scores how convincingly a Commons file path depicts [landmark].
  int _landmarkPathScore(
    String path, {
    required CountryLandmark landmark,
    required String queryToken,
  }) {
    final String folded = _fold(path);
    int score = 0;
    if (_titleMatchesPlace(folded, queryToken)) {
      score += 20;
    }
    for (final String token in landmark.matchTokens) {
      if (token.trim().length >= 5 && _titleMatchesPlace(folded, token)) {
        score += 12;
      }
    }
    // Ambiguous short tokens (e.g. bare "Fuji") need mountain context.
    if (_fold(queryToken) == 'fuji' || folded.contains('fuji')) {
      if (!(folded.contains('mount') ||
          folded.contains('fuji-san') ||
          folded.contains('fujisan') ||
          folded.contains('mt_fuji') ||
          folded.contains('mt-fuji') ||
          folded.contains('yamanashi') ||
          folded.contains('hakone') ||
          folded.contains('kawaguchiko'))) {
        score -= 40;
      }
    }
    if (folded.contains('pyramid') ||
        folded.contains('sphinx') ||
        folded.contains('colosse') ||
        folded.contains('eiffel') ||
        folded.contains('angkor') ||
        folded.contains('machu') ||
        folded.contains('neuschwanstein') ||
        folded.contains('sagrada')) {
      score += 15;
    }
    if (folded.contains('traffic') ||
        folded.contains('apfel') ||
        folded.contains('apple') ||
        folded.contains('babucha') ||
        folded.contains('bust')) {
      score -= 50;
    }
    return score;
  }

  Future<bool> _urlLooksAlive(String url) async {
    if (!url.startsWith('https://')) {
      return false;
    }
    try {
      final Uri uri = Uri.parse(url);
      http.Response response = await _client
          .head(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      // Some Wikimedia edges answer HEAD with HTML error pages / odd codes.
      if (response.statusCode == 405 ||
          response.statusCode == 403 ||
          response.statusCode == 400 ||
          response.statusCode == 429 ||
          (response.headers['content-type'] ?? '')
              .toLowerCase()
              .contains('text/html')) {
        response = await _client
            .get(uri, headers: <String, String>{
              ..._headers,
              'Range': 'bytes=0-64',
            })
            .timeout(const Duration(seconds: 10));
      }
      final String mime = (response.headers['content-type'] ?? '').toLowerCase();
      final bool okStatus =
          response.statusCode >= 200 && response.statusCode < 400;
      if (okStatus &&
          !mime.contains('svg') &&
          !mime.contains('text/html') &&
          (mime.isEmpty ||
              mime.startsWith('image/') ||
              mime.contains('octet-stream'))) {
        return true;
      }
      // During Wikimedia rate limits, HEAD/GET may return HTML error pages
      // even for valid Commons files. Accept only stable commons raster paths.
      return _looksLikeCommonsRasterPath(url);
    } catch (_) {
      return _looksLikeCommonsRasterPath(url);
    }
  }

  bool _looksLikeCommonsRasterPath(String url) {
    final String folded = _fold(url);
    if (!folded.contains('upload.wikimedia.org/wikipedia/')) {
      return false;
    }
    return (folded.contains('.jpg') ||
            folded.contains('.jpeg') ||
            folded.contains('.png') ||
            folded.contains('.webp')) &&
        !folded.contains('.svg');
  }

  Future<DestinationCoverResult?> _pickBestGeoCover({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String resolvedPlace,
    required String country,
    required List<String> titleHints,
    required String levelWhenTitled,
    required String levelWhenGpsOnly,
  }) async {
    final List<GalleryPhoto> candidates = await _commonsGeoSearchMany(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      resolvedPlace: resolvedPlace,
      country: country,
      level: levelWhenGpsOnly,
      limit: 12,
      preferTitleMatch: true,
    );
    if (candidates.isEmpty) {
      return null;
    }

    GalleryPhoto? titled;
    for (final String hint in titleHints) {
      for (final GalleryPhoto photo in candidates) {
        // Reconstruct match via URL alone is impossible; re-query ranking uses
        // preferTitleContains. Prefer candidates already scored as exact-ish
        // by taking first when hint appears in credit/url path lightly, else
        // rely on order from _pickCommonsImages (title-prefer sorted).
        if (photo.matchLevel == DestinationCoverResult.levelExact ||
            _fold(photo.credit).contains(_fold(hint))) {
          titled = photo;
          break;
        }
      }
      if (titled != null) {
        break;
      }
    }

    // Re-fetch with strict title filter when possible.
    for (final String hint in titleHints) {
      final List<GalleryPhoto> strict = await _commonsGeoSearchMany(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        resolvedPlace: hint,
        country: country,
        level: levelWhenTitled,
        limit: 6,
        preferTitleMatch: true,
        requireTitleHint: hint,
      );
      if (strict.isNotEmpty) {
        final GalleryPhoto best = strict.first;
        return DestinationCoverResult(
          imageUrl: best.url,
          matchLevel: levelWhenTitled,
          resolvedPlace: resolvedPlace,
          country: country,
          credit: best.credit,
          latitude: latitude,
          longitude: longitude,
        );
      }
    }

    final GalleryPhoto gpsPhoto = titled ?? candidates.first;
    return DestinationCoverResult(
      imageUrl: gpsPhoto.url,
      matchLevel: levelWhenGpsOnly,
      resolvedPlace: resolvedPlace,
      country: country,
      credit: gpsPhoto.credit,
      latitude: latitude,
      longitude: longitude,
    );
  }

  DestinationCoverResult _cache(String key, DestinationCoverResult value) {
    _memoryCache[key] = value;
    return value;
  }

  List<String> _searchQueries({
    required String destination,
    required String country,
    required _GeoPlace? place,
  }) {
    final LinkedQueries queries = LinkedQueries();
    void add(String value) {
      final String cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (cleaned.length >= 2) {
        queries.add(cleaned);
      }
    }

    // Never search by country alone here — that returns unrelated capital /
    // landmark photos (e.g. Egypt for a Tunisian city).
    add(destination);
    if (country.isNotEmpty) {
      add('$destination $country');
    }
    if (place != null) {
      add(place.name);
      if (place.admin1.isNotEmpty) {
        add('${place.name} ${place.admin1}');
      }
      if (place.country.isNotEmpty) {
        add('${place.name} ${place.country}');
      }
    }

    final String stripped = destination
        .replaceAll(
          RegExp(
            r'\b(week-?end|voyage|trip|séjour|sejour|à|a|au|aux|en|de|du|des)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    add(stripped);
    return queries.values;
  }

  Future<_GeoPlace?> _geocode(String destination, String country) async {
    final List<String> attempts = <String>[
      if (destination.isNotEmpty && country.isNotEmpty) '$destination, $country',
      if (destination.isNotEmpty) destination,
      if (country.isNotEmpty && destination.isEmpty) country,
    ];
    for (final String name in attempts) {
      final Uri uri = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        <String, String>{
          'name': name,
          'count': '5',
          'language': 'fr',
          'format': 'json',
        },
      );
      try {
        final http.Response response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          continue;
        }
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? results = json['results'] as List<dynamic>?;
        if (results == null || results.isEmpty) {
          continue;
        }
        final Map<String, dynamic> best = _bestGeocodeResult(
          results.whereType<Map<String, dynamic>>().toList(),
          destination: destination,
          country: country,
        );
        return _GeoPlace(
          name: '${best['name'] ?? name}',
          country: '${best['country'] ?? country}',
          admin1: '${best['admin1'] ?? ''}',
          lat: (best['latitude'] as num).toDouble(),
          lon: (best['longitude'] as num).toDouble(),
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Map<String, dynamic> _bestGeocodeResult(
    List<Map<String, dynamic>> results, {
    required String destination,
    required String country,
  }) {
    final String destFold = _fold(destination);
    final String countryFold = _fold(country);
    Map<String, dynamic> best = results.first;
    int bestScore = -999;
    for (final Map<String, dynamic> row in results) {
      final String name = _fold('${row['name'] ?? ''}');
      final String rowCountry = _fold('${row['country'] ?? ''}');
      int score = 0;
      if (name == destFold) {
        score += 100;
      } else if (name.contains(destFold) || destFold.contains(name)) {
        score += 40;
      }
      if (countryFold.isNotEmpty &&
          (rowCountry.contains(countryFold) ||
              countryFold.contains(rowCountry))) {
        score += 30;
      }
      if (score > bestScore) {
        bestScore = score;
        best = row;
      }
    }
    return best;
  }

  Future<DestinationCoverResult?> _commonsTextSearch({
    required String query,
    required String resolvedPlace,
    required String country,
    required String level,
    bool representativeOnly = false,
  }) async {
    final List<GalleryPhoto> photos = await _commonsTextSearchMany(
      query: query,
      resolvedPlace: resolvedPlace,
      country: country,
      level: level,
      limit: 1,
      representativeOnly: representativeOnly,
      requireTitleHint: representativeOnly ? '' : resolvedPlace,
    );
    if (photos.isEmpty) {
      return null;
    }
    return DestinationCoverResult(
      imageUrl: photos.first.url,
      matchLevel: photos.first.matchLevel,
      resolvedPlace: resolvedPlace,
      country: country,
      credit: photos.first.credit,
      representativeOnly: photos.first.representativeOnly,
    );
  }

  Future<List<GalleryPhoto>> _commonsTextSearchMany({
    required String query,
    required String resolvedPlace,
    required String country,
    required String level,
    required int limit,
    bool representativeOnly = false,
    String requireTitleHint = '',
  }) async {
    final Uri uri = Uri.https('commons.wikimedia.org', '/w/api.php', <String, String>{
      'action': 'query',
      'format': 'json',
      'origin': '*',
      'generator': 'search',
      'gsrsearch': query,
      'gsrnamespace': '6',
      'gsrlimit': '$limit',
      'prop': 'imageinfo',
      'iiprop': 'url|mime|extmetadata|size',
      'iiurlwidth': '1400',
    });
    return _pickCommonsImages(
      uri: uri,
      resolvedPlace: resolvedPlace,
      country: country,
      level: level,
      representativeOnly: representativeOnly,
      preferTitleContains: resolvedPlace,
      requireTitleHint: requireTitleHint.isNotEmpty
          ? requireTitleHint
          : (representativeOnly ? '' : resolvedPlace),
      limit: limit,
    );
  }

  Future<List<GalleryPhoto>> _commonsGeoSearchMany({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String resolvedPlace,
    required String country,
    required String level,
    required int limit,
    bool representativeOnly = false,
    bool preferTitleMatch = false,
    String requireTitleHint = '',
  }) async {
    final Uri uri = Uri.https('commons.wikimedia.org', '/w/api.php', <String, String>{
      'action': 'query',
      'format': 'json',
      'origin': '*',
      'generator': 'geosearch',
      'ggscoord': '$latitude|$longitude',
      'ggsradius': '$radiusMeters',
      'ggsnamespace': '6',
      'ggslimit': '$limit',
      'ggsprimary': 'all',
      'prop': 'imageinfo|coordinates',
      'iiprop': 'url|mime|extmetadata|size',
      'iiurlwidth': '1400',
    });
    return _pickCommonsImages(
      uri: uri,
      resolvedPlace: resolvedPlace,
      country: country,
      level: level,
      representativeOnly: representativeOnly,
      preferTitleContains: resolvedPlace,
      requireTitleHint: requireTitleHint,
      limit: limit,
      // GPS already proves location; title match is preferred via ranking.
      allowGpsWithoutTitle: preferTitleMatch && requireTitleHint.isEmpty,
    );
  }

  Future<List<GalleryPhoto>> _pickCommonsImages({
    required Uri uri,
    required String resolvedPlace,
    required String country,
    required String level,
    required bool representativeOnly,
    required int limit,
    String preferTitleContains = '',
    String requireTitleHint = '',
    bool allowGpsWithoutTitle = false,
  }) async {
    try {
      final http.Response response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 18));
      if (response.statusCode != 200) {
        return const <GalleryPhoto>[];
      }
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic>? query =
          json['query'] as Map<String, dynamic>?;
      final Map<String, dynamic>? pages =
          query?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) {
        return const <GalleryPhoto>[];
      }

      final List<Map<String, dynamic>> ranked = pages.values
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final int scoreA = _scorePage(a, preferTitleContains);
          final int scoreB = _scorePage(b, preferTitleContains);
          return scoreB.compareTo(scoreA);
        });

      final List<GalleryPhoto> photos = <GalleryPhoto>[];
      final String hint = requireTitleHint.trim();
      for (final Map<String, dynamic> page in ranked) {
        if (photos.length >= limit) {
          break;
        }
        final String title = '${page['title'] ?? ''}'.toLowerCase();
        final bool titleOk =
            hint.isEmpty || _titleMatchesPlace(title, hint);
        if (!representativeOnly &&
            !allowGpsWithoutTitle &&
            hint.isNotEmpty &&
            !titleOk) {
          // Reject photos whose title does not mention this destination.
          continue;
        }
        if (allowGpsWithoutTitle &&
            hint.isNotEmpty &&
            !titleOk &&
            _scorePage(page, preferTitleContains) < 10) {
          continue;
        }
        final List<dynamic>? infos = page['imageinfo'] as List<dynamic>?;
        if (infos == null || infos.isEmpty) {
          continue;
        }
        final Map<String, dynamic> info = infos.first as Map<String, dynamic>;
        final String mime = '${info['mime'] ?? ''}';
        if (!mime.startsWith('image/') || mime.contains('svg')) {
          continue;
        }
        final String url = '${info['thumburl'] ?? info['url'] ?? ''}'.trim();
        if (url.isEmpty || !url.startsWith('https://')) {
          continue;
        }
        if (_scorePage(page, preferTitleContains) <= 0) {
          continue;
        }
        photos.add(
          GalleryPhoto(
            url: url,
            credit: _creditFrom(info),
            matchLevel: level,
            representativeOnly: representativeOnly,
          ),
        );
      }
      return photos;
    } catch (_) {
      return const <GalleryPhoto>[];
    }
  }

  /// True when [title] clearly refers to [place] (full name or main tokens).
  bool _titleMatchesPlace(String title, String place) {
    final String foldedTitle = _fold(title);
    final String foldedPlace = _fold(place.trim());
    if (foldedPlace.isEmpty) {
      return true;
    }
    if (foldedTitle.contains(foldedPlace)) {
      return true;
    }
    final List<String> tokens = foldedPlace
        .split(RegExp(r'[\s\-_]+'))
        .where((String t) => t.length >= 4)
        .toList();
    if (tokens.isEmpty) {
      return foldedTitle.contains(foldedPlace);
    }
    // Require every significant token (e.g. "new"+"york", "sidi"+"said").
    return tokens.every(foldedTitle.contains);
  }

  String _fold(String value) {
    const String from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
    const String to = 'aaaaaaceeeeiiiinooooouuuuyyoeae';
    final String lower = value.toLowerCase();
    final StringBuffer out = StringBuffer();
    for (final int code in lower.runes) {
      final String ch = String.fromCharCode(code);
      final int index = from.indexOf(ch);
      out.write(index >= 0 ? to[index] : ch);
    }
    return out.toString();
  }

  int _scorePage(Map<String, dynamic> page, String prefer) {
    final String title = '${page['title'] ?? ''}'.toLowerCase();
    int score = 0;
    if (prefer.trim().isNotEmpty && _titleMatchesPlace(title, prefer)) {
      score += 50;
    }
    if (title.contains('panorama') ||
        title.contains('skyline') ||
        title.contains('landscape') ||
        title.contains('tourism') ||
        title.contains('tourisme')) {
      score += 8;
    }
    if (title.contains('map') ||
        title.contains('carte') ||
        title.contains('logo') ||
        title.contains('coat of arms') ||
        title.contains('flag') ||
        title.contains('icon') ||
        title.contains('colonies') ||
        title.contains('reclus') ||
        title.contains('188') ||
        title.contains('189') ||
        title.contains('engraving') ||
        title.contains('pyramid') ||
        title.contains('sphinx')) {
      // Avoid maps, colonial plates, and classic Maghreb false positives.
      score -= 60;
    }
    final List<dynamic>? infos = page['imageinfo'] as List<dynamic>?;
    if (infos != null && infos.isNotEmpty) {
      final Map<String, dynamic> info = infos.first as Map<String, dynamic>;
      final int width = (info['width'] as num?)?.toInt() ?? 0;
      final int height = (info['height'] as num?)?.toInt() ?? 0;
      if (width >= 800 && height >= 500) {
        score += 10;
      }
    }
    return score;
  }

  String _creditFrom(Map<String, dynamic> info) {
    final Map<String, dynamic>? meta =
        info['extmetadata'] as Map<String, dynamic>?;
    if (meta == null) {
      return 'Wikimedia Commons';
    }
    String read(String key) {
      final Object? raw = meta[key];
      if (raw is Map<String, dynamic>) {
        return '${raw['value'] ?? ''}'
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
      }
      return '';
    }

    final String artist = read('Artist');
    final String credit = read('Credit');
    final String license = read('LicenseShortName');
    final String who = artist.isNotEmpty
        ? artist
        : (credit.isNotEmpty ? credit : 'Wikimedia Commons');
    if (license.isEmpty) {
      return who;
    }
    return '$who · $license';
  }

  Map<String, String> get _headers => <String, String>{
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      };
}

class _WikiPageImage {
  const _WikiPageImage({
    required this.title,
    required this.imageUrl,
    required this.description,
    required this.extract,
    required this.canonicalUrl,
    required this.credit,
  });

  final String title;
  final String imageUrl;
  final String description;
  final String extract;
  final String canonicalUrl;
  final String credit;
}

class _GeoPlace {
  const _GeoPlace({
    required this.name,
    required this.country,
    required this.admin1,
    required this.lat,
    required this.lon,
  });

  final String name;
  final String country;
  final String admin1;
  final double lat;
  final double lon;
}

class LinkedQueries {
  final List<String> _values = <String>[];
  final Set<String> _seen = <String>{};

  void add(String value) {
    final String key = value.toLowerCase();
    if (_seen.add(key)) {
      _values.add(value);
    }
  }

  List<String> get values => List<String>.unmodifiable(_values);
}
