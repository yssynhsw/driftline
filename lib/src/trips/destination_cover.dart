/// Result of an intelligent destination cover photo lookup.
class DestinationCoverResult {
  const DestinationCoverResult({
    required this.imageUrl,
    required this.matchLevel,
    required this.resolvedPlace,
    this.credit = '',
    this.country = '',
    this.landmark = '',
    this.sourcePage = '',
    this.latitude,
    this.longitude,
    this.representativeOnly = false,
  });

  /// Exact curated/local match for the destination / landmark.
  static const String levelExact = 'exact';

  /// Photo near the geocoded coordinates of the destination.
  static const String levelNearby = 'nearby';

  /// Broader regional / country representative photo.
  static const String levelRegional = 'regional';

  /// Generic travel fallback when nothing else worked.
  static const String levelFallback = 'fallback';

  final String imageUrl;
  final String matchLevel;
  final String resolvedPlace;
  final String credit;
  final String country;
  /// Emblematic place actually depicted (e.g. "Tour Eiffel").
  final String landmark;
  /// Wikipedia / Commons page used as provenance.
  final String sourcePage;
  final double? latitude;
  final double? longitude;
  final bool representativeOnly;

  String get badgeLabel {
    final String nation = country.trim().isNotEmpty ? country.trim() : resolvedPlace;
    if (matchLevel == levelFallback || imageUrl.trim().isEmpty) {
      return nation.isEmpty
          ? 'Aucune photo fiable trouvée'
          : 'Aucune photo fiable pour $nation';
    }
    if (landmark.trim().isNotEmpty && nation.isNotEmpty) {
      return 'Photo de $nation · $landmark';
    }
    switch (matchLevel) {
      case levelExact:
      case levelRegional:
        return nation.isEmpty ? 'Photo du pays' : 'Photo de $nation';
      case levelNearby:
        return nation.isEmpty
            ? 'Photo près de $resolvedPlace'
            : 'Photo de $nation';
      default:
        return 'Aucune photo fiable trouvée';
    }
  }
}
