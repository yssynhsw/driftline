import 'dart:convert';

import 'destination_cover.dart';

/// One photo in a trip destination gallery (persisted as JSON in sqflite).
class GalleryPhoto {
  const GalleryPhoto({
    required this.url,
    this.credit = '',
    this.matchLevel = DestinationCoverResult.levelExact,
    this.representativeOnly = false,
  });

  final String url;
  final String credit;
  final String matchLevel;
  final bool representativeOnly;

  Map<String, Object?> toMap() => <String, Object?>{
        'url': url,
        'credit': credit,
        'matchLevel': matchLevel,
        'representativeOnly': representativeOnly,
      };

  factory GalleryPhoto.fromMap(Map<String, Object?> map) {
    return GalleryPhoto(
      url: '${map['url'] ?? ''}',
      credit: '${map['credit'] ?? ''}',
      matchLevel: '${map['matchLevel'] ?? DestinationCoverResult.levelExact}',
      representativeOnly: map['representativeOnly'] == true,
    );
  }

  factory GalleryPhoto.fromCover(DestinationCoverResult cover) {
    return GalleryPhoto(
      url: cover.imageUrl,
      credit: cover.credit,
      matchLevel: cover.matchLevel,
      representativeOnly: cover.representativeOnly,
    );
  }

  static String encodeList(List<GalleryPhoto> photos) {
    return jsonEncode(photos.map((GalleryPhoto p) => p.toMap()).toList());
  }

  static List<GalleryPhoto> decodeList(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return const <GalleryPhoto>[];
    }
    try {
      final Object decoded = jsonDecode(value);
      if (decoded is! List<dynamic>) {
        return const <GalleryPhoto>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (Map item) => GalleryPhoto.fromMap(
              item.map(
                (Object? key, Object? value) =>
                    MapEntry<String, Object?>('$key', value),
              ),
            ),
          )
          .where((GalleryPhoto photo) => photo.url.startsWith('https://'))
          .toList();
    } catch (_) {
      return const <GalleryPhoto>[];
    }
  }
}
