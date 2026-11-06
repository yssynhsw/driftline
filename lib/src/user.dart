/// Local account. Password hashes stay in SQLite, not on this object.
class AppUser {
  const AppUser({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.photoProfil,
    required this.pays,
    required this.langue,
    required this.preferencesVoyage,
    this.role = 'user',
    this.phone = '',
    this.phoneVerified = false,
    this.bio = '',
    required this.niveauVoyageur,
    required this.dateCreation,
    required this.active,
    required this.emailVerified,
    required this.twoFactor,
    required this.trips,
  });

  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String photoProfil;
  final String pays;
  final String langue;
  final String preferencesVoyage;
  final String role;
  final String phone;
  final bool phoneVerified;
  final String bio;
  final String niveauVoyageur;
  final DateTime dateCreation;
  final bool active;
  final bool emailVerified;
  final bool twoFactor;
  final int trips;

  String get name => '$prenom $nom';

  bool get isAdmin => role == 'admin';

  String get roleLabel => isAdmin ? 'Admin' : 'User';

  String get initials {
    final first = _firstGlyph(prenom);
    final last = _firstGlyph(nom);
    return '$first$last'.toUpperCase();
  }

  /// Comma-separated [preferencesVoyage], trimmed, with empty pieces dropped.
  List<String> get preferences {
    return preferencesVoyage
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// Trip target for the current level. Explorer is 3, otherwise 8.
  int get goal {
    if (niveauVoyageur == 'Nomad' || niveauVoyageur == 'Wanderer') {
      return 8;
    }
    return 3;
  }

  /// Progress inside the current level, from 0 to 1.
  ///
  /// Explorer is `trips / 3`, Wanderer is `(trips - 3) / 5`, Nomad is 1.
  double get levelProgress {
    final double raw;
    if (niveauVoyageur == 'Nomad') {
      raw = 1;
    } else if (niveauVoyageur == 'Wanderer') {
      raw = (trips - 3) / 5;
    } else {
      raw = trips / 3;
    }
    if (raw < 0) {
      return 0;
    }
    if (raw > 1) {
      return 1;
    }
    return raw;
  }
}

String _firstGlyph(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return String.fromCharCodes([trimmed.runes.first]);
}

/// Outcome of an auth call.
///
/// `error == null` and [user] set means success, except password reset
/// requests, which succeed with no user. `unverified`, `2fa`, and
/// `deactivated` are machine-readable states. Any other [error] is a message
/// for the screen. [mailed] means the provider accepted the message. [notice]
/// explains a delivery problem. [code] is not shown in the app.
class AuthResult {
  const AuthResult({
    this.user,
    this.error,
    this.code,
    this.notice,
    this.mailed = false,
  });

  final AppUser? user;
  final String? error;
  final String? code;
  final String? notice;
  final bool mailed;
}
