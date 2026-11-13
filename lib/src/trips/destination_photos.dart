/// Resolves real destination photographs (Unsplash CDN) without shipping a
/// secret API key. Photo IDs are public Unsplash CDN assets.
class DestinationPhotos {
  const DestinationPhotos._();

  /// Generic high-quality travel photograph used when nothing matches.
  static const String fallbackUrl =
      'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=1400&q=80';

  /// Curated real photos keyed by destination / landmark keywords.
  static const Map<String, String> _catalog = <String, String>{
    // Requested destinations
    'paris':
        'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1400&q=80',
    'eiffel':
        'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1400&q=80',
    'rome':
        'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=1400&q=80',
    'colosseum':
        'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=1400&q=80',
    'colisee':
        'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=1400&q=80',
    'istanbul':
        'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?auto=format&fit=crop&w=1400&q=80',
    'bosphore':
        'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?auto=format&fit=crop&w=1400&q=80',
    'dubai':
        'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1400&q=80',
    'dubaï':
        'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1400&q=80',
    'burj':
        'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1400&q=80',
    'tokyo':
        'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1400&q=80',
    'maldives':
        'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?auto=format&fit=crop&w=1400&q=80',
    'suisse':
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1400&q=80',
    'switzerland':
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1400&q=80',
    'zurich':
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1400&q=80',
    'barcelone':
        'https://images.unsplash.com/photo-1583422409516-2895a77efded?auto=format&fit=crop&w=1400&q=80',
    'barcelona':
        'https://images.unsplash.com/photo-1583422409516-2895a77efded?auto=format&fit=crop&w=1400&q=80',
    'londres':
        'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?auto=format&fit=crop&w=1400&q=80',
    'london':
        'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?auto=format&fit=crop&w=1400&q=80',
    'big ben':
        'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?auto=format&fit=crop&w=1400&q=80',
    'new york':
        'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?auto=format&fit=crop&w=1400&q=80',
    'nyc':
        'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?auto=format&fit=crop&w=1400&q=80',
    'manhattan':
        'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?auto=format&fit=crop&w=1400&q=80',
    // Demo / Morocco destinations already in the app
    'essaouira':
        'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1400&q=80',
    'marrakech':
        'https://images.unsplash.com/photo-1597212618440-806262de4f6b?auto=format&fit=crop&w=1400&q=80',
    'marrakesh':
        'https://images.unsplash.com/photo-1597212618440-806262de4f6b?auto=format&fit=crop&w=1400&q=80',
    'fes':
        'https://images.unsplash.com/photo-1553895501-af9e282e7fc1?auto=format&fit=crop&w=1400&q=80',
    'fès':
        'https://images.unsplash.com/photo-1553895501-af9e282e7fc1?auto=format&fit=crop&w=1400&q=80',
    'casablanca':
        'https://images.unsplash.com/photo-1539020140153-e479b8c22e70?auto=format&fit=crop&w=1400&q=80',
    'rabat':
        'https://images.unsplash.com/photo-1539020140153-e479b8c22e70?auto=format&fit=crop&w=1400&q=80',
    'agadir':
        'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1400&q=80',
    'chefchaouen':
        'https://images.unsplash.com/photo-1539020140153-e479b8c22e70?auto=format&fit=crop&w=1400&q=80',
    'morocco':
        'https://images.unsplash.com/photo-1539020140153-e479b8c22e70?auto=format&fit=crop&w=1400&q=80',
    'maroc':
        'https://images.unsplash.com/photo-1539020140153-e479b8c22e70?auto=format&fit=crop&w=1400&q=80',
    'alger':
        'https://images.unsplash.com/photo-1587974928442-77dc3e0dba72?auto=format&fit=crop&w=1400&q=80',
    'algeria':
        'https://images.unsplash.com/photo-1587974928442-77dc3e0dba72?auto=format&fit=crop&w=1400&q=80',
    'algérie':
        'https://images.unsplash.com/photo-1587974928442-77dc3e0dba72?auto=format&fit=crop&w=1400&q=80',
    // Tunis / Sidi Bou Said (Wikimedia — clearly Tunisia, not Egypt)
    'tunis':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d2/Sidi_Bou_Said-maison_bleue.jpg/1280px-Sidi_Bou_Said-maison_bleue.jpg',
    'sidi bou said':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d2/Sidi_Bou_Said-maison_bleue.jpg/1280px-Sidi_Bou_Said-maison_bleue.jpg',
    'carthage':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d2/Sidi_Bou_Said-maison_bleue.jpg/1280px-Sidi_Bou_Said-maison_bleue.jpg',
    'tunisia':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d2/Sidi_Bou_Said-maison_bleue.jpg/1280px-Sidi_Bou_Said-maison_bleue.jpg',
    'tunisie':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d2/Sidi_Bou_Said-maison_bleue.jpg/1280px-Sidi_Bou_Said-maison_bleue.jpg',
  };

  /// Country-level catalog keys — never used for a different city name.
  static const Set<String> _countryOnlyKeys = <String>{
    'morocco',
    'maroc',
    'algeria',
    'algérie',
    'tunisia',
    'tunisie',
    'switzerland',
    'suisse',
  };

  /// Exact curated match only (null when the place is not in the catalog).
  ///
  /// Prefers exact / whole-word destination matches. Country photos are used
  /// only when the destination field is empty.
  static String? lookupUrl({
    required String destination,
    String country = '',
    int width = 1400,
  }) {
    final String dest = destination.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final String pays = country.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (dest.isNotEmpty) {
      final String? exact = _catalog[dest];
      if (exact != null) {
        return _withWidth(exact, width);
      }
      // Whole-word match only (longest key wins). Skip country-only keys so a
      // city never inherits another country's stock photo.
      String? bestKey;
      for (final String key in _catalog.keys) {
        if (_countryOnlyKeys.contains(key)) {
          continue;
        }
        if (key.length < 3) {
          continue;
        }
        final bool wholeWord = RegExp(
          '\\b${RegExp.escape(key)}\\b',
          caseSensitive: false,
        ).hasMatch(dest);
        if (wholeWord && (bestKey == null || key.length > bestKey.length)) {
          bestKey = key;
        }
      }
      if (bestKey != null) {
        return _withWidth(_catalog[bestKey]!, width);
      }
      return null;
    }

    if (pays.isNotEmpty) {
      final String? exactPays = _catalog[pays];
      if (exactPays != null) {
        return _withWidth(exactPays, width);
      }
      String? bestPaysKey;
      for (final String key in _catalog.keys) {
        if (pays == key ||
            RegExp('\\b${RegExp.escape(key)}\\b').hasMatch(pays)) {
          if (bestPaysKey == null || key.length > bestPaysKey.length) {
            bestPaysKey = key;
          }
        }
      }
      if (bestPaysKey != null) {
        return _withWidth(_catalog[bestPaysKey]!, width);
      }
    }
    return null;
  }

  /// Returns a photograph URL for [destination] / [country].
  /// Prefers the curated catalog, otherwise the generic travel fallback.
  static String urlFor({
    required String destination,
    String country = '',
    int width = 1400,
  }) {
    return lookupUrl(
          destination: destination,
          country: country,
          width: width,
        ) ??
        _withWidth(fallbackUrl, width);
  }

  static String _withWidth(String url, int width) {
    if (!url.contains('images.unsplash.com')) {
      return url;
    }
    if (url.contains('w=')) {
      return url.replaceFirst(RegExp(r'w=\d+'), 'w=$width');
    }
    final String sep = url.contains('?') ? '&' : '?';
    return '$url${sep}w=$width&q=80&auto=format&fit=crop';
  }
}
