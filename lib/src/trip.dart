import 'trips/gallery_photo.dart';

class Trip {
  const Trip({
    required this.id,
    required this.titre,
    required this.destination,
    required this.pays,
    required this.dateDepart,
    required this.dateRetour,
    required this.budget,
    required this.nombreVoyageurs,
    required this.typeVoyage,
    required this.statut,
    required this.userId,
    required this.dateCreation,
    this.coverPhotoUrl = '',
    this.coverPhotoCredit = '',
    this.coverMatchLevel = '',
    this.galleryPhotosJson = '[]',
  });

  final int id;
  final String titre;
  final String destination;
  final String pays;
  final String dateDepart;
  final String dateRetour;
  final double budget;
  final int nombreVoyageurs;
  final String typeVoyage;
  final String statut;
  final int userId;
  final DateTime dateCreation;
  final String coverPhotoUrl;
  final String coverPhotoCredit;
  final String coverMatchLevel;
  final String galleryPhotosJson;

  List<GalleryPhoto> get galleryPhotos =>
      GalleryPhoto.decodeList(galleryPhotosJson);

  int get durationDays {
    final DateTime? start = calendarDate(dateDepart);
    final DateTime? end = calendarDate(dateRetour);
    if (start == null || end == null) {
      return 0;
    }
    final int days = end.difference(start).inDays + 1;
    return days < 1 ? 0 : days;
  }

  Trip copyWith({
    int? id,
    String? titre,
    String? destination,
    String? pays,
    String? dateDepart,
    String? dateRetour,
    double? budget,
    int? nombreVoyageurs,
    String? typeVoyage,
    String? statut,
    int? userId,
    DateTime? dateCreation,
    String? coverPhotoUrl,
    String? coverPhotoCredit,
    String? coverMatchLevel,
    String? galleryPhotosJson,
  }) {
    return Trip(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      destination: destination ?? this.destination,
      pays: pays ?? this.pays,
      dateDepart: dateDepart ?? this.dateDepart,
      dateRetour: dateRetour ?? this.dateRetour,
      budget: budget ?? this.budget,
      nombreVoyageurs: nombreVoyageurs ?? this.nombreVoyageurs,
      typeVoyage: typeVoyage ?? this.typeVoyage,
      statut: statut ?? this.statut,
      userId: userId ?? this.userId,
      dateCreation: dateCreation ?? this.dateCreation,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      coverPhotoCredit: coverPhotoCredit ?? this.coverPhotoCredit,
      coverMatchLevel: coverMatchLevel ?? this.coverMatchLevel,
      galleryPhotosJson: galleryPhotosJson ?? this.galleryPhotosJson,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id_trip': id,
      'titre': titre,
      'destination': destination,
      'pays': pays,
      'date_depart': dateDepart,
      'date_retour': dateRetour,
      'budget': budget,
      'nombre_voyageurs': nombreVoyageurs,
      'type_voyage': typeVoyage,
      'statut': statut,
      'user_id': userId,
      'date_creation': dateCreation.toIso8601String(),
      'cover_photo_url': coverPhotoUrl,
      'cover_photo_credit': coverPhotoCredit,
      'cover_match_level': coverMatchLevel,
      'gallery_photos_json': galleryPhotosJson,
    };
  }

  factory Trip.fromMap(Map<String, Object?> row) {
    return Trip(
      id: row['id_trip'] as int,
      titre: row['titre'] as String,
      destination: row['destination'] as String,
      pays: row['pays'] as String,
      dateDepart: row['date_depart'] as String,
      dateRetour: row['date_retour'] as String,
      budget: (row['budget'] as num).toDouble(),
      nombreVoyageurs: row['nombre_voyageurs'] as int,
      typeVoyage: row['type_voyage'] as String,
      statut: row['statut'] as String,
      userId: row['user_id'] as int,
      dateCreation: DateTime.parse(row['date_creation'] as String),
      coverPhotoUrl: '${row['cover_photo_url'] ?? ''}',
      coverPhotoCredit: '${row['cover_photo_credit'] ?? ''}',
      coverMatchLevel: '${row['cover_match_level'] ?? ''}',
      galleryPhotosJson: '${row['gallery_photos_json'] ?? '[]'}',
    );
  }
}

/// Calendar date stored as `yyyy-MM-dd`, interpreted in local time.
DateTime? calendarDate(String raw) {
  final RegExpMatch? match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  final DateTime date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

String storeCalendarDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String displayCalendarDate(String stored) {
  final DateTime? date = calendarDate(stored);
  if (date == null) {
    return stored;
  }
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatBudget(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
