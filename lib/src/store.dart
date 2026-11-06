import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'db_factory_io.dart' if (dart.library.html) 'db_factory_web.dart';
import 'mail.dart';
import 'trip.dart';
import 'user.dart';

export 'trip.dart';
export 'user.dart';

/// Local SQLite accounts. Google sign-in stays closed until an OAuth
/// client is configured. Email codes go out through Resend, and phone
/// codes through Twilio, both via the local relay.
class UserStore {
  static final UserStore instance = UserStore();

  static const String _sessionKey = 'driftline_user_id';
  static const String _pepper = 'driftline';
  static final RegExp _fourDigits = RegExp(r'^\d{4}$');

  Database? _db;

  Future<void> open() async {
    if (_db != null) {
      return;
    }
    prepareDatabaseFactory();
    final String dbPath = join(await getDatabasesPath(), 'driftline.db');
    _db = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (Database db, int _) async {
        await _createUsers(db);
        await _createTrips(db);
        await _createAudit(db);
        await _createGuide(db);
      },
      onUpgrade: (Database db, int oldVersion, int _) async {
        if (oldVersion < 2) {
          await _createTrips(db);
        }
        if (oldVersion < 3) {
          await _migrateV3(db);
        }
        if (oldVersion < 4) {
          await _migrateV4(db);
        }
        if (oldVersion < 5) {
          await _migrateV5(db);
        }
        if (oldVersion < 6) {
          await _createGuide(db);
        }
      },
    );
    await _provisionAdmin();
  }

  Future<AppUser?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_sessionKey);
    if (id == null) {
      return null;
    }
    final user = await byId(id);
    if (user == null || !user.active) {
      return null;
    }
    return user;
  }

  Future<AuthResult> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    required String pays,
    required String langue,
    required String preferences,
    required String photoProfil,
    required String phone,
    required String captchaToken,
  }) async {
    final cleanNom = nom.trim();
    final cleanPrenom = prenom.trim();
    final cleanEmail = email.trim();
    final cleanPays = pays.trim();
    final cleanLangue = langue.trim();
    final cleanPreferences = preferences.trim();
    if (cleanNom.isEmpty ||
        cleanPrenom.isEmpty ||
        cleanEmail.isEmpty ||
        password.isEmpty ||
        cleanPays.isEmpty ||
        cleanLangue.isEmpty ||
        cleanPreferences.isEmpty ||
        photoProfil.trim().isEmpty ||
        phone.trim().isEmpty) {
      return const AuthResult(error: 'All fields are required.');
    }
    if (!cleanEmail.contains('@')) {
      return const AuthResult(error: 'Enter a valid email.');
    }
    if (password.length < 8) {
      return const AuthResult(error: 'Password must be at least 8 characters.');
    }
    if (!_validPhone(phone)) {
      return const AuthResult(error: 'Enter a valid phone number.');
    }
    if (kIsWeb) {
      final String? captchaError = await OutboundMail.verifyCaptcha(captchaToken);
      if (captchaError != null) {
        return AuthResult(error: captchaError);
      }
    }
    final String? limited = _registrationLimited();
    if (limited != null) {
      return AuthResult(error: limited);
    }
    final db = await _database();
    final existing = await _rowByEmail(db, cleanEmail);
    if (existing != null) {
      return const AuthResult(
        error: 'An account with that email already exists.',
      );
    }
    final String code = _sixDigits();
    final DateTime now = DateTime.now();
    try {
      await db.insert('users', {
        'nom': cleanNom,
        'prenom': cleanPrenom,
        'email': cleanEmail,
        'password_hash': _hash(cleanEmail, password),
        'photo_profil': _storedPhoto(photoProfil),
        'pays': cleanPays,
        'langue': cleanLangue,
        'preferences_voyage': cleanPreferences,
        'role': 'user',
        'phone': phone.trim(),
        'phone_verified': 0,
        'bio': '',
        'niveau_voyageur': 'Explorer',
        'date_creation': now.toIso8601String(),
        'active': 1,
        'email_verified': 0,
        'two_factor': 0,
        'verify_code': _hash(cleanEmail, code),
        'verify_expires': now.add(const Duration(minutes: 10)).toIso8601String(),
        'verify_attempts': 0,
        'failed_logins': 0,
        'last_email_code_at': now.toIso8601String(),
        'trips': 0,
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return const AuthResult(
          error: 'An account with that email already exists.',
        );
      }
      rethrow;
    }
    final ({bool mailed, String? notice}) delivered = await _deliverCode(
      email: cleanEmail,
      code: code,
      purpose: 'verify',
    );
    if (!delivered.mailed) {
      await db.update(
        'users',
        <String, Object?>{'last_email_code_at': null},
        where: 'email = ?',
        whereArgs: <Object?>[cleanEmail],
      );
      return AuthResult(
        error: 'unverified',
        notice: delivered.notice ?? 'The verification email could not be sent.',
      );
    }
    return const AuthResult(error: 'unverified', mailed: true);
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
    required bool remember,
    String? pin,
    String? captchaToken,
    bool checkCaptcha = false,
  }) async {
    if (checkCaptcha) {
      final String? captchaError = await OutboundMail.verifyCaptcha(
        captchaToken ?? '',
      );
      if (captchaError != null) {
        return AuthResult(error: captchaError);
      }
    }
    final db = await _database();
    final String cleanEmail = email.trim();
    final row = await _rowByEmail(db, cleanEmail);
    if (row == null) {
      _noteUnknownLogin(cleanEmail);
      return const AuthResult(error: 'Wrong email or password.');
    }
    final String? locked = _lockMessage(row['locked_until'] as String?);
    if (locked != null) {
      return AuthResult(error: locked);
    }
    if (!_passwordMatches(row, password)) {
      await _markFailedLogin(db, row);
      return const AuthResult(error: 'Wrong email or password.');
    }
    await db.update(
      'users',
      {'failed_logins': 0, 'locked_until': null},
      where: 'id_user = ?',
      whereArgs: [row['id_user']],
    );
    if (row['active'] != 1) {
      return const AuthResult(error: 'deactivated');
    }
    if (row['email_verified'] != 1) {
      return const AuthResult(error: 'unverified');
    }
    if (row['two_factor'] == 1) {
      if (pin == null) {
        return const AuthResult(error: '2fa');
      }
      final storedEmail = row['email'] as String;
      final pinHash = row['pin_hash'] as String?;
      if (pinHash == null || pinHash != _hash(storedEmail, pin)) {
        return const AuthResult(error: 'Wrong security code.');
      }
    }
    final user = _userFromRow(row);
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setInt(_sessionKey, user.id);
    } else {
      await prefs.remove(_sessionKey);
    }
    return AuthResult(user: user);
  }

  Future<AuthResult> signInWithProvider(String provider) async {
    if (provider != 'Google') {
      return const AuthResult(error: 'Only Google sign-in is available.');
    }
    return const AuthResult(
      error:
          'Google sign-in needs a Google OAuth client ID. Driftline does not use Firebase.',
    );
  }

  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    return _checkCode(
      email: email,
      code: code,
      hashColumn: 'verify_code',
      expiryColumn: 'verify_expires',
      attemptsColumn: 'verify_attempts',
      onMatch: <String, Object?>{
        'email_verified': 1,
        'verify_code': null,
        'verify_expires': null,
        'verify_attempts': 0,
      },
    );
  }

  Future<AuthResult> resendEmailCode(String email) async {
    final db = await _database();
    final row = await _rowByEmail(db, email.trim());
    if (row == null || row['email_verified'] == 1) {
      return const AuthResult(
        error: 'If the account exists and is unverified, a new code was issued.',
      );
    }
    final String? wait = _cooldownMessage(row['last_email_code_at'] as String?);
    if (wait != null) {
      return AuthResult(error: wait);
    }
    final String issued = _sixDigits();
    final String storedEmail = row['email'] as String;
    final DateTime now = DateTime.now();
    await db.update(
      'users',
      {
        'verify_code': _hash(storedEmail, issued),
        'verify_expires': now.add(const Duration(minutes: 10)).toIso8601String(),
        'verify_attempts': 0,
        'last_email_code_at': now.toIso8601String(),
      },
      where: 'id_user = ?',
      whereArgs: [row['id_user']],
    );
    final ({bool mailed, String? notice}) delivered = await _deliverCode(
      email: storedEmail,
      code: issued,
        purpose: 'verify',
    );
    if (delivered.mailed) {
      return const AuthResult(mailed: true);
    }
    await db.update(
      'users',
      <String, Object?>{'last_email_code_at': null},
      where: 'id_user = ?',
      whereArgs: <Object?>[row['id_user']],
    );
    return AuthResult(
      error: delivered.notice ?? 'The verification email could not be sent.',
    );
  }

  Future<AuthResult> requestPhoneCode(int id) async {
    final db = await _database();
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: <Object?>[id],
    );
    if (rows.isEmpty) {
      return const AuthResult(error: 'Account not found.');
    }
    final Map<String, Object?> row = rows.first;
    if ((row['phone'] as String).trim().isEmpty) {
      return const AuthResult(error: 'Add a phone number first.');
    }
    if (row['phone_verified'] == 1) {
      return const AuthResult(error: 'This phone number is already verified.');
    }
    final String? wait = _cooldownMessage(row['last_phone_code_at'] as String?);
    if (wait != null) {
      return AuthResult(error: wait);
    }
    final DateTime now = DateTime.now();
    await db.update(
      'users',
      <String, Object?>{
        'phone_code': 'twilio',
        'phone_expires': now.add(const Duration(minutes: 10)).toIso8601String(),
        'phone_attempts': 0,
        'last_phone_code_at': now.toIso8601String(),
      },
      where: 'id_user = ?',
      whereArgs: <Object?>[id],
    );
    final ({bool mailed, String? notice}) delivered = await _deliverSms(
      phone: row['phone'] as String,
    );
    if (delivered.mailed) {
      return const AuthResult(mailed: true);
    }
    await db.update(
      'users',
      <String, Object?>{'last_phone_code_at': null},
      where: 'id_user = ?',
      whereArgs: <Object?>[id],
    );
    return AuthResult(error: delivered.notice ?? 'The text could not be sent.');
  }

  Future<AuthResult> verifyPhone({
    required int id,
    required String code,
  }) async {
    final db = await _database();
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: <Object?>[id],
    );
    if (rows.isEmpty) {
      return const AuthResult(error: 'Invalid or expired code.');
    }
    final Map<String, Object?> row = rows.first;
    final int attempts = (row['phone_attempts'] as int?) ?? 0;
    if (attempts >= 5) {
      return const AuthResult(error: 'Too many attempts. Request a new code.');
    }
    final String? expiry = row['phone_expires'] as String?;
    final DateTime? until = expiry == null ? null : DateTime.tryParse(expiry);
    if (until != null && DateTime.now().isAfter(until)) {
      return const AuthResult(error: 'That code has expired.');
    }
    final String? hash = row['phone_code'] as String?;
    if (hash == 'twilio') {
      final String? rejected = await OutboundMail.checkSms(
        to: (row['phone'] as String?) ?? '',
        code: code.trim(),
      );
      if (rejected != null) {
        await db.update(
          'users',
          <String, Object?>{'phone_attempts': attempts + 1},
          where: 'id_user = ?',
          whereArgs: <Object?>[id],
        );
        return AuthResult(error: rejected);
      }
    } else {
      final String storedEmail = row['email'] as String;
      if (hash == null || hash != _hash(storedEmail, code.trim())) {
        await db.update(
          'users',
          <String, Object?>{'phone_attempts': attempts + 1},
          where: 'id_user = ?',
          whereArgs: <Object?>[id],
        );
        return const AuthResult(error: 'Invalid or expired code.');
      }
    }
    await db.update(
      'users',
      <String, Object?>{
        'phone_verified': 1,
        'phone_code': null,
        'phone_expires': null,
        'phone_attempts': 0,
      },
      where: 'id_user = ?',
      whereArgs: <Object?>[id],
    );
    final AppUser? user = await byId(id);
    return AuthResult(user: user);
  }

  Future<AuthResult> adminIssueReset({
    required int actorId,
    required int targetId,
  }) async {
    final String? denied = await _requireAdmin(actorId);
    if (denied != null) {
      return AuthResult(error: denied);
    }
    final db = await _database();
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: <Object?>[targetId],
    );
    if (rows.isEmpty) {
      return const AuthResult(error: 'Account not found.');
    }
    final Map<String, Object?> row = rows.first;
    final String issued = _sixDigits();
    final String storedEmail = row['email'] as String;
    final DateTime now = DateTime.now();
    await db.update(
      'users',
      <String, Object?>{
        'reset_code': _hash(storedEmail, issued),
        'reset_expires': now.add(const Duration(minutes: 10)).toIso8601String(),
        'reset_attempts': 0,
        'last_email_code_at': now.toIso8601String(),
      },
      where: 'id_user = ?',
      whereArgs: <Object?>[targetId],
    );
    final ({bool mailed, String? notice}) delivered = await _deliverCode(
      email: storedEmail,
      code: issued,
      purpose: 'reset',
    );
    await _audit(
      actorId,
      'issue_reset',
      targetId,
      delivered.mailed ? 'reset code emailed' : 'reset email failed',
    );
    if (!delivered.mailed) {
      await db.update(
        'users',
        <String, Object?>{'last_email_code_at': null},
        where: 'id_user = ?',
        whereArgs: <Object?>[targetId],
      );
      return AuthResult(
        error: delivered.notice ?? 'The reset email could not be sent.',
      );
    }
    return const AuthResult(mailed: true);
  }

  Future<AuthResult> requestReset(String email) async {
    final db = await _database();
    final row = await _rowByEmail(db, email.trim());
    if (row == null) {
      return const AuthResult(mailed: true);
    }
    final String? wait = _cooldownMessage(row['last_email_code_at'] as String?);
    if (wait != null) {
      return AuthResult(error: wait);
    }
    final String issued = _sixDigits();
    final String storedEmail = row['email'] as String;
    final DateTime now = DateTime.now();
    await db.update(
      'users',
      {
        'reset_code': _hash(storedEmail, issued),
        'reset_expires': now.add(const Duration(minutes: 10)).toIso8601String(),
        'reset_attempts': 0,
        'last_email_code_at': now.toIso8601String(),
      },
      where: 'id_user = ?',
      whereArgs: [row['id_user']],
    );
    final ({bool mailed, String? notice}) delivered = await _deliverCode(
      email: storedEmail,
      code: issued,
        purpose: 'reset',
    );
    if (delivered.mailed) {
      return const AuthResult(mailed: true);
    }
    await db.update(
      'users',
      <String, Object?>{'last_email_code_at': null},
      where: 'id_user = ?',
      whereArgs: <Object?>[row['id_user']],
    );
    return AuthResult(
      error: delivered.notice ?? 'The reset email could not be sent.',
    );
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    if (password.length < 8) {
      return const AuthResult(error: 'Password must be at least 8 characters.');
    }
    final AuthResult checked = await _checkCode(
      email: email,
      code: code,
      hashColumn: 'reset_code',
      expiryColumn: 'reset_expires',
      attemptsColumn: 'reset_attempts',
      onMatch: const <String, Object?>{},
    );
    if (checked.error != null) {
      return checked;
    }
    final db = await _database();
    final row = await _rowByEmail(db, email.trim());
    if (row == null) {
      return const AuthResult(error: 'Invalid or expired code.');
    }
    final String storedEmail = row['email'] as String;
    await db.update(
      'users',
      {
        'password_hash': _hash(storedEmail, password),
        'reset_code': null,
        'reset_expires': null,
        'reset_attempts': 0,
      },
      where: 'id_user = ?',
      whereArgs: [row['id_user']],
    );
    return const AuthResult();
  }

  Future<String?> changePassword({
    required int id,
    required String currentPassword,
    required String nextPassword,
  }) async {
    if (nextPassword.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    final db = await _database();
    final rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty || !_passwordMatches(rows.first, currentPassword)) {
      return 'Current password is wrong.';
    }
    final String storedEmail = rows.first['email'] as String;
    await db.update(
      'users',
      {'password_hash': _hash(storedEmail, nextPassword)},
      where: 'id_user = ?',
      whereArgs: [id],
    );
    await _audit(id, 'change_password', id, 'password updated');
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<AppUser> updateProfile({
    required int id,
    String? nom,
    String? prenom,
    String? pays,
    String? langue,
    String? preferences,
    String? photoProfil,
    String? phone,
    String? bio,
  }) async {
    final db = await _database();
    final values = <String, Object?>{};
    if (nom != null) {
      values['nom'] = nom.trim();
    }
    if (prenom != null) {
      values['prenom'] = prenom.trim();
    }
    if (pays != null) {
      values['pays'] = pays.trim();
    }
    if (langue != null) {
      values['langue'] = langue.trim();
    }
    if (preferences != null) {
      values['preferences_voyage'] = preferences.trim();
    }
    if (photoProfil != null) {
      values['photo_profil'] = _storedPhoto(photoProfil);
    }
    if (phone != null) {
      if (!_validPhone(phone)) {
        throw StateError('Enter a valid phone number.');
      }
      values['phone'] = phone.trim();
      values['phone_verified'] = 0;
    }
    if (bio != null) {
      values['bio'] = bio.trim();
    }
    if (values.isNotEmpty) {
      await db.update('users', values, where: 'id_user = ?', whereArgs: [id]);
    }
    return _require(id);
  }

  Future<AppUser> setTwoFactor({
    required int id,
    required bool enabled,
    String? pin,
  }) async {
    final db = await _database();
    final current = await byId(id);
    if (current == null) {
      throw StateError('User not found');
    }
    if (!enabled) {
      await db.update(
        'users',
        {'two_factor': 0, 'pin_hash': null},
        where: 'id_user = ?',
        whereArgs: [id],
      );
      return _require(id);
    }
    if (pin == null || !_fourDigits.hasMatch(pin)) {
      return current;
    }
    await db.update(
      'users',
      {'two_factor': 1, 'pin_hash': _hash(current.email, pin)},
      where: 'id_user = ?',
      whereArgs: [id],
    );
    return _require(id);
  }

  Future<AppUser> logTrip(int id) async {
    final db = await _database();
    final current = await byId(id);
    if (current == null) {
      throw StateError('User not found');
    }
    final trips = current.trips + 1;
    await db.update(
      'users',
      {'trips': trips, 'niveau_voyageur': _niveauFor(trips)},
      where: 'id_user = ?',
      whereArgs: [id],
    );
    return _require(id);
  }

  Future<void> deactivate(int id) async {
    final db = await _database();
    await db.update(
      'users',
      {'active': 0},
      where: 'id_user = ?',
      whereArgs: [id],
    );
    await logout();
  }

  Future<String?> deleteOwnAccount({
    required int id,
    required String password,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) {
      return 'Account not found.';
    }
    if ((rows.first['role'] as String) == 'admin') {
      return 'The administrator account cannot be deleted in the app.';
    }
    if (!_passwordMatches(rows.first, password)) {
      return 'Current password is wrong.';
    }
    await db.delete('trips', where: 'user_id = ?', whereArgs: [id]);
    await db.delete('guide_messages', where: 'user_id = ?', whereArgs: [id]);
    await db.delete('users', where: 'id_user = ?', whereArgs: [id]);
    await logout();
    return null;
  }

  Future<String?> adminDeleteUser({
    required int actorId,
    required int targetId,
  }) async {
    final String? denied = await _requireAdmin(actorId);
    if (denied != null) {
      return denied;
    }
    final AppUser? target = await byId(targetId);
    if (target == null) {
      return 'User not found.';
    }
    if (target.isAdmin) {
      return 'The administrator account cannot be deleted.';
    }
    final db = await _database();
    await db.delete('trips', where: 'user_id = ?', whereArgs: [targetId]);
    await db.delete('guide_messages', where: 'user_id = ?', whereArgs: [targetId]);
    await db.delete('users', where: 'id_user = ?', whereArgs: [targetId]);
    await _audit(actorId, 'delete_user', targetId, 'profile deleted');
    return null;
  }

  Future<String?> setAccountActive({
    required int actorId,
    required int targetId,
    required bool active,
  }) async {
    final String? denied = await _requireAdmin(actorId);
    if (denied != null) {
      return denied;
    }
    final AppUser? target = await byId(targetId);
    if (target == null) {
      return 'User not found.';
    }
    if (target.isAdmin) {
      return 'The administrator account cannot be suspended.';
    }
    final db = await _database();
    await db.update(
      'users',
      {'active': active ? 1 : 0},
      where: 'id_user = ?',
      whereArgs: [targetId],
    );
    await _audit(
      actorId,
      active ? 'reactivate_user' : 'suspend_user',
      targetId,
      active ? 'account reactivated' : 'account suspended',
    );
    return null;
  }

  Future<List<String>> recentAudit() async {
    final db = await _database();
    final rows = await db.query(
      'audit_log',
      orderBy: 'id DESC',
      limit: 12,
    );
    return rows.map((Map<String, Object?> row) {
      return '${row['created_at']}  ${row['action']}  #${row['target_id']}';
    }).toList();
  }

  Future<List<({String role, String text})>> guideMessages(int userId) async {
    final db = await _database();
    final List<Map<String, Object?>> rows = await db.query(
      'guide_messages',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'id ASC',
    );
    return rows
        .map(
          (Map<String, Object?> row) => (
            role: row['role'] as String,
            text: row['body'] as String,
          ),
        )
        .toList();
  }

  Future<void> addGuideMessage({
    required int userId,
    required String role,
    required String text,
  }) async {
    final db = await _database();
    await db.insert('guide_messages', <String, Object?>{
      'user_id': userId,
      'role': role,
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Trip>> listTrips() async {
    final db = await _database();
    final rows = await db.query('trips', orderBy: 'id_trip DESC');
    return rows.map(_tripFromRow).toList();
  }

  Future<Trip> saveTrip({
    int? id,
    required String titre,
    required String destination,
    required String pays,
    required String dateDepart,
    required String dateRetour,
    required double budget,
    required int nombreVoyageurs,
    required String typeVoyage,
    required String statut,
    required int userId,
  }) async {
    final db = await _database();
    final values = <String, Object?>{
      'titre': titre.trim(),
      'destination': destination.trim(),
      'pays': pays.trim(),
      'date_depart': dateDepart.trim(),
      'date_retour': dateRetour.trim(),
      'budget': budget,
      'nombre_voyageurs': nombreVoyageurs,
      'type_voyage': typeVoyage.trim(),
      'statut': statut.trim(),
      'user_id': userId,
    };
    final int tripId;
    if (id == null) {
      values['date_creation'] = DateTime.now().toIso8601String();
      tripId = await db.insert('trips', values);
    } else {
      tripId = id;
      await db.update('trips', values, where: 'id_trip = ?', whereArgs: [id]);
    }
    final rows = await db.query(
      'trips',
      where: 'id_trip = ?',
      whereArgs: [tripId],
    );
    return _tripFromRow(rows.first);
  }

  Future<void> deleteTrip(int id) async {
    final db = await _database();
    await db.delete('trips', where: 'id_trip = ?', whereArgs: [id]);
  }

  Future<AuthResult> reactivate({
    required String email,
    required String password,
  }) async {
    final db = await _database();
    final row = await _rowByEmail(db, email.trim());
    if (row == null || !_passwordMatches(row, password)) {
      return const AuthResult(error: 'Wrong email or password.');
    }
    if (row['active'] == 1) {
      return const AuthResult(error: 'This account is already active.');
    }
    await db.update(
      'users',
      {'active': 1},
      where: 'id_user = ?',
      whereArgs: [row['id_user']],
    );
    final user = await byId(row['id_user'] as int);
    if (user == null) {
      return const AuthResult(error: 'Wrong email or password.');
    }
    return AuthResult(user: user);
  }

  Future<List<AppUser>> listUsers({String query = ''}) async {
    final db = await _database();
    final trimmed = query.trim().toLowerCase();
    final List<Map<String, Object?>> rows;
    if (trimmed.isEmpty) {
      rows = await db.query('users', orderBy: 'id_user DESC');
    } else {
      final pattern = '%$trimmed%';
      rows = await db.query(
        'users',
        where: 'LOWER(nom) LIKE ? OR LOWER(prenom) LIKE ? OR LOWER(email) LIKE ? OR LOWER(pays) LIKE ?',
        whereArgs: [pattern, pattern, pattern, pattern],
        orderBy: 'id_user DESC',
      );
    }
    return rows.map(_userFromRow).toList();
  }

  Future<AppUser?> byId(int id) async {
    final db = await _database();
    final rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _userFromRow(rows.first);
  }

  Future<Database> _database() async {
    final current = _db;
    if (current != null) {
      return current;
    }
    await open();
    final opened = _db;
    if (opened == null) {
      throw StateError('Database is not open');
    }
    return opened;
  }

  Future<Map<String, Object?>?> _rowByEmail(Database db, String email) async {
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<AppUser> _require(int id) async {
    final user = await byId(id);
    if (user == null) {
      throw StateError('User not found');
    }
    return user;
  }

  bool _passwordMatches(Map<String, Object?> row, String password) {
    final storedEmail = row['email'] as String;
    return row['password_hash'] == _hash(storedEmail, password);
  }

  String _hash(String email, String secret) {
    final bytes = utf8.encode('$_pepper|$email|$secret');
    return sha256.convert(bytes).toString();
  }

  String _sixDigits() {
    final value = Random.secure().nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }

  Future<({bool mailed, String? notice})> _deliverCode({
    required String email,
    required String code,
    required String purpose,
  }) async {
    final String? notice = await OutboundMail.sendCode(
      to: email,
      code: code,
      purpose: purpose,
    );
    return (mailed: notice == null, notice: notice);
  }

  Future<({bool mailed, String? notice})> _deliverSms({
    required String phone,
  }) async {
    final String? notice = await OutboundMail.sendSms(to: phone);
    return (mailed: notice == null, notice: notice);
  }

  final Map<String, int> _unknownFails = <String, int>{};
  final Map<String, DateTime> _unknownLocks = <String, DateTime>{};
  DateTime? _registerWindow;
  int _registerCount = 0;

  String? _registrationLimited() {
    final DateTime now = DateTime.now();
    if (_registerWindow == null ||
        now.difference(_registerWindow!) > const Duration(minutes: 10)) {
      _registerWindow = now;
      _registerCount = 0;
    }
    _registerCount += 1;
    if (_registerCount > 5) {
      return 'Too many registration attempts. Try again later.';
    }
    return null;
  }

  String _storedPhoto(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      throw StateError('Choose a profile photo.');
    }
    if (value.startsWith('data:image/')) {
      if (!value.startsWith('data:image/jpeg;base64,') || value.length > 450000) {
        throw StateError('That photo could not be saved. Crop it and try again.');
      }
    }
    return value;
  }

  bool _validPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 && digits.length <= 15;
  }

  void _noteUnknownLogin(String email) {
    final String key = email.toLowerCase();
    final DateTime? until = _unknownLocks[key];
    if (until != null && DateTime.now().isBefore(until)) {
      return;
    }
    final int next = (_unknownFails[key] ?? 0) + 1;
    _unknownFails[key] = next;
    if (next >= 5) {
      _unknownLocks[key] = DateTime.now().add(const Duration(minutes: 15));
      _unknownFails[key] = 0;
    }
  }

  String? _lockMessage(String? iso) {
    if (iso == null) {
      return null;
    }
    final DateTime? until = DateTime.tryParse(iso);
    if (until == null || DateTime.now().isAfter(until)) {
      return null;
    }
    return 'Too many attempts. Try again later.';
  }

  String? _cooldownMessage(String? iso) {
    if (iso == null) {
      return null;
    }
    final DateTime? sent = DateTime.tryParse(iso);
    if (sent == null) {
      return null;
    }
    final int left = 60 - DateTime.now().difference(sent).inSeconds;
    if (left <= 0) {
      return null;
    }
    return 'Wait ${left}s before requesting another code.';
  }

  Future<void> _markFailedLogin(Database db, Map<String, Object?> row) async {
    final int fails = ((row['failed_logins'] as int?) ?? 0) + 1;
    final Map<String, Object?> values = <String, Object?>{'failed_logins': fails};
    if (fails >= 5) {
      values['failed_logins'] = 0;
      values['locked_until'] = DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String();
    }
    await db.update(
      'users',
      values,
      where: 'id_user = ?',
      whereArgs: [row['id_user']],
    );
  }

  Future<AuthResult> _checkCode({
    required String email,
    required String code,
    required String hashColumn,
    required String expiryColumn,
    required String attemptsColumn,
    required Map<String, Object?> onMatch,
  }) async {
    final db = await _database();
    final row = await _rowByEmail(db, email.trim());
    if (row == null) {
      return const AuthResult(error: 'Invalid or expired code.');
    }
    final int attempts = (row[attemptsColumn] as int?) ?? 0;
    if (attempts >= 5) {
      return const AuthResult(error: 'Too many attempts. Request a new code.');
    }
    final String? expiry = row[expiryColumn] as String?;
    final DateTime? until = expiry == null ? null : DateTime.tryParse(expiry);
    if (until != null && DateTime.now().isAfter(until)) {
      return const AuthResult(error: 'That code has expired.');
    }
    final String storedEmail = row['email'] as String;
    final String? hash = row[hashColumn] as String?;
    if (hash == null || hash != _hash(storedEmail, code.trim())) {
      await db.update(
        'users',
        <String, Object?>{attemptsColumn: attempts + 1},
        where: 'id_user = ?',
        whereArgs: <Object?>[row['id_user']],
      );
      return const AuthResult(error: 'Invalid or expired code.');
    }
    if (onMatch.isNotEmpty) {
      await db.update(
        'users',
        onMatch,
        where: 'id_user = ?',
        whereArgs: <Object?>[row['id_user']],
      );
    }
    final AppUser? user = await byId(row['id_user'] as int);
    return AuthResult(user: user);
  }

  Future<String?> _requireAdmin(int actorId) async {
    final AppUser? actor = await byId(actorId);
    if (actor == null || !actor.isAdmin) {
      return 'Not allowed.';
    }
    return null;
  }

  Future<void> _audit(
    int actorId,
    String action,
    int targetId,
    String detail,
  ) async {
    final db = await _database();
    await db.insert('audit_log', <String, Object?>{
      'actor_id': actorId,
      'action': action,
      'target_id': targetId,
      'detail': detail,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _createAudit(Database db) {
    return db.execute('''
CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor_id INTEGER,
  action TEXT NOT NULL,
  target_id INTEGER,
  detail TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
  }

  Future<void> _createGuide(Database db) {
    return db.execute('''
CREATE TABLE IF NOT EXISTS guide_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  role TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
  }

  Future<void> _migrateV5(Database db) async {
    final List<Map<String, Object?>> info = await db.rawQuery(
      'PRAGMA table_info(users)',
    );
    final bool hasFirebase = info.any(
      (Map<String, Object?> column) => column['name'] == 'firebase_uid',
    );
    if (!hasFirebase) {
      return;
    }
    await db.execute('ALTER TABLE users DROP COLUMN firebase_uid');
  }

  Future<void> _migrateV4(Database db) async {
    const List<String> statements = <String>[
      'ALTER TABLE users ADD COLUMN phone_code TEXT',
      'ALTER TABLE users ADD COLUMN phone_expires TEXT',
      'ALTER TABLE users ADD COLUMN phone_attempts INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE users ADD COLUMN last_phone_code_at TEXT',
    ];
    for (final String statement in statements) {
      try {
        await db.execute(statement);
      } on DatabaseException {
        // Column already exists.
      }
    }
  }

  Future<void> _migrateV3(Database db) async {
    const List<String> statements = <String>[
      "ALTER TABLE users ADD COLUMN phone TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE users ADD COLUMN phone_verified INTEGER NOT NULL DEFAULT 0',
      "ALTER TABLE users ADD COLUMN bio TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE users ADD COLUMN failed_logins INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE users ADD COLUMN locked_until TEXT',
      'ALTER TABLE users ADD COLUMN verify_expires TEXT',
      'ALTER TABLE users ADD COLUMN verify_attempts INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE users ADD COLUMN reset_expires TEXT',
      'ALTER TABLE users ADD COLUMN reset_attempts INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE users ADD COLUMN last_email_code_at TEXT',
    ];
    for (final String statement in statements) {
      try {
        await db.execute(statement);
      } on DatabaseException {
        // Column already exists.
      }
    }
    await _createAudit(db);
    await db.execute(
      "UPDATE users SET role = 'user' WHERE lower(role) != 'admin'",
    );
    final List<Map<String, Object?>> admins = await db.query(
      'users',
      columns: <String>['id_user'],
      where: "role = 'admin'",
      orderBy: 'id_user ASC',
    );
    for (var i = 1; i < admins.length; i++) {
      await db.update(
        'users',
        <String, Object?>{'role': 'user'},
        where: 'id_user = ?',
        whereArgs: <Object?>[admins[i]['id_user']],
      );
    }
    final List<Map<String, Object?>> coded = await db.query('users');
    for (final Map<String, Object?> row in coded) {
      final String storedEmail = row['email'] as String;
      final String? verify = row['verify_code'] as String?;
      if (verify != null && RegExp(r'^\d{6}$').hasMatch(verify)) {
        await db.update(
          'users',
          <String, Object?>{'verify_code': _hash(storedEmail, verify)},
          where: 'id_user = ?',
          whereArgs: <Object?>[row['id_user']],
        );
      }
      final String? reset = row['reset_code'] as String?;
      if (reset != null && RegExp(r'^\d{6}$').hasMatch(reset)) {
        await db.update(
          'users',
          <String, Object?>{'reset_code': _hash(storedEmail, reset)},
          where: 'id_user = ?',
          whereArgs: <Object?>[row['id_user']],
        );
      }
    }
  }

  Future<void> _provisionAdmin() async {
    const String email = String.fromEnvironment('ADMIN_EMAIL');
    const String password = String.fromEnvironment('ADMIN_PASSWORD');
    final db = await _database();
    final List<Map<String, Object?>> admins = await db.query(
      'users',
      where: "role = 'admin'",
      limit: 1,
    );
    if (admins.isNotEmpty || email.isEmpty || password.length < 8) {
      return;
    }
    if (await _rowByEmail(db, email) != null) {
      return;
    }
    final DateTime now = DateTime.now();
    await db.insert('users', <String, Object?>{
      'nom': 'Admin',
      'prenom': 'Driftline',
      'email': email.trim(),
      'password_hash': _hash(email.trim(), password),
      'photo_profil': '#121212',
      'pays': 'Morocco',
      'langue': 'English',
      'preferences_voyage': 'City',
      'role': 'admin',
      'phone': '',
      'phone_verified': 1,
      'bio': '',
      'niveau_voyageur': 'Explorer',
      'date_creation': now.toIso8601String(),
      'active': 1,
      'email_verified': 1,
      'two_factor': 0,
      'verify_attempts': 0,
      'reset_attempts': 0,
      'failed_logins': 0,
      'trips': 0,
    });
  }

  Future<void> _createUsers(Database db) {
    return db.execute('''
CREATE TABLE users (
  id_user INTEGER PRIMARY KEY AUTOINCREMENT,
  nom TEXT NOT NULL,
  prenom TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  photo_profil TEXT NOT NULL,
  pays TEXT NOT NULL,
  langue TEXT NOT NULL,
  preferences_voyage TEXT NOT NULL,
  role TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  phone_verified INTEGER NOT NULL DEFAULT 0,
  bio TEXT NOT NULL DEFAULT '',
  niveau_voyageur TEXT NOT NULL,
  date_creation TEXT NOT NULL,
  active INTEGER NOT NULL,
  email_verified INTEGER NOT NULL,
  two_factor INTEGER NOT NULL,
  pin_hash TEXT,
  verify_code TEXT,
  verify_expires TEXT,
  verify_attempts INTEGER NOT NULL DEFAULT 0,
  reset_code TEXT,
  reset_expires TEXT,
  reset_attempts INTEGER NOT NULL DEFAULT 0,
  failed_logins INTEGER NOT NULL DEFAULT 0,
  locked_until TEXT,
  last_email_code_at TEXT,
  phone_code TEXT,
  phone_expires TEXT,
  phone_attempts INTEGER NOT NULL DEFAULT 0,
  last_phone_code_at TEXT,
  trips INTEGER NOT NULL
)
''');
  }

  Future<void> _createTrips(Database db) {
    return db.execute('''
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
  date_creation TEXT NOT NULL
)
''');
  }

  Trip _tripFromRow(Map<String, Object?> row) {
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
    );
  }

  String _niveauFor(int trips) {
    if (trips < 3) {
      return 'Explorer';
    }
    if (trips < 8) {
      return 'Wanderer';
    }
    return 'Nomad';
  }

  AppUser _userFromRow(Map<String, Object?> row) {
    return AppUser(
      id: row['id_user'] as int,
      nom: row['nom'] as String,
      prenom: row['prenom'] as String,
      email: row['email'] as String,
      photoProfil: row['photo_profil'] as String,
      pays: row['pays'] as String,
      langue: row['langue'] as String,
      preferencesVoyage: row['preferences_voyage'] as String,
      role: row['role'] as String,
      phone: (row['phone'] as String?) ?? '',
      phoneVerified: row['phone_verified'] == 1,
      bio: (row['bio'] as String?) ?? '',
      niveauVoyageur: row['niveau_voyageur'] as String,
      dateCreation: DateTime.parse(row['date_creation'] as String),
      active: row['active'] == 1,
      emailVerified: row['email_verified'] == 1,
      twoFactor: row['two_factor'] == 1,
      trips: row['trips'] as int,
    );
  }
}
