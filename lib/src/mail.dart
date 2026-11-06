import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sends codes through the local relay. Resend and Twilio secrets stay
/// in that process.
class OutboundMail {
  static const String _base = String.fromEnvironment(
    'RELAY_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  static Future<String?> sendCode({
    required String to,
    required String code,
    required String purpose,
  }) {
    return _post('/send', <String, String>{
      'to': to,
      'code': code,
      'purpose': purpose,
    });
  }

  static Future<String?> verifyCaptcha(String token) {
    return _post('/captcha', <String, String>{'token': token});
  }

  static Future<String?> sendSms({required String to}) {
    return _post('/sms', <String, String>{'to': to});
  }

  static Future<String?> checkSms({
    required String to,
    required String code,
  }) {
    return _post('/sms-check', <String, String>{
      'to': to,
      'code': code,
    });
  }

  static Future<({Map<String, Object?>? data, String? error})> weather() {
    return _get('/weather');
  }

  static Future<({String? reply, String? error})> guide({
    required String preferences,
    required String home,
    required String language,
    required List<Map<String, String>> messages,
  }) async {
    final ({Map<String, Object?>? data, String? error}) result = await _postJson(
      '/chat',
      <String, Object>{
        'preferences': preferences,
        'home': home,
        'language': language,
        'messages': messages,
      },
    );
    if (result.error != null) {
      return (reply: null, error: result.error);
    }
    final Object? reply = result.data?['reply'];
    if (reply is String && reply.trim().isNotEmpty) {
      return (reply: reply.trim(), error: null);
    }
    return (reply: null, error: 'The travel guide returned an empty answer.');
  }

  static Future<({Map<String, Object?>? data, String? error})> _get(
    String path,
  ) async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_base$path'))
          .timeout(const Duration(seconds: 20));
      return _decode(response);
    } catch (_) {
      return (
        data: null,
        error: 'The relay is not running. Start it with dart run tool/mail_server.dart.',
      );
    }
  }

  static Future<({Map<String, Object?>? data, String? error})> _postJson(
    String path,
    Map<String, Object> body,
  ) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_base$path'),
            headers: const <String, String>{
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _decode(response);
    } catch (_) {
      return (
        data: null,
        error: 'The relay is not running. Start it with dart run tool/mail_server.dart.',
      );
    }
  }

  static ({Map<String, Object?>? data, String? error}) _decode(
    http.Response response,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map) {
        return (data: decoded.cast<String, Object?>(), error: null);
      }
      return (data: null, error: 'The relay returned an unexpected response.');
    }
    if (decoded is Map && decoded['error'] is String) {
      return (data: null, error: decoded['error'] as String);
    }
    return (data: null, error: 'The request could not be completed.');
  }

  static Future<String?> _post(String path, Map<String, String> body) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_base$path'),
            headers: const <String, String>{
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
      return 'The message could not be sent.';
    } catch (_) {
      return 'The relay is not running. Start it with dart run tool/mail_server.dart.';
    }
  }
}
