import 'dart:async';
import 'dart:convert';
import 'dart:io';

final Map<String, String> _env = <String, String>{};

String _setting(String name) => _env[name] ?? '';

void _loadEnv() {
  _env.addAll(Platform.environment);
  final List<File> files = <File>[File('tool/local.env')];
  final Uri script = Platform.script;
  if (script.scheme == 'file') {
    files.insert(
      0,
      File(
        '${File.fromUri(script).parent.path}${Platform.pathSeparator}local.env',
      ),
    );
  }
  for (final File file in files) {
    _readEnvFile(file);
  }
}

void _readEnvFile(File file) {
  if (!file.existsSync()) {
    return;
  }
  for (final String line in file.readAsLinesSync()) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final int eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    final String name = trimmed.substring(0, eq).trim();
    final String value = trimmed.substring(eq + 1).trim();
    final String clean = _unquote(value);
    if ((_env[name] ?? '').isEmpty && clean.isNotEmpty) {
      _env[name] = clean;
    }
  }
}

String _unquote(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1).trim();
  }
  return value;
}

/// Local relay so the Flutter web app can send mail and SMS without
/// shipping the Resend or Twilio secrets in the browser bundle.
Future<void> main() async {
  _loadEnv();
  final String key = _setting('RESEND_API_KEY');
  final String from =
      _setting('RESEND_FROM').isEmpty
          ? 'Driftline <onboarding@resend.dev>'
          : _setting('RESEND_FROM');
  final String sid = _setting('TWILIO_ACCOUNT_SID');
  final String token = _setting('TWILIO_AUTH_TOKEN');
  final String smsFrom = _setting('TWILIO_FROM');
  final String verifySid = _setting('TWILIO_VERIFY_SERVICE_SID');
  final String captchaSecret = _setting('RECAPTCHA_SECRET');
  final String weatherKey = _setting('WEATHER_API_KEY');
  final String geminiKey = _setting('GEMINI_API_KEY');
  if (key.isEmpty && (sid.isEmpty || token.isEmpty) && captchaSecret.isEmpty) {
    stderr.writeln(
      'Set RESEND_API_KEY, Twilio credentials, or RECAPTCHA_SECRET in tool/local.env.',
    );
    exitCode = 1;
    return;
  }
  final HttpServer server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    8787,
  );
  stdout.writeln('Driftline relay is listening on http://127.0.0.1:8787');
  if (key.isEmpty) {
    stderr.writeln('RESEND_API_KEY is missing. Email will be rejected.');
  }
  if (verifySid.isEmpty && smsFrom.isEmpty) {
    stderr.writeln(
      'Set TWILIO_VERIFY_SERVICE_SID, or TWILIO_FROM, before SMS can leave.',
    );
  }
  await for (final HttpRequest request in server) {
    try {
      await _handle(
        request,
        key: key,
        from: from,
        sid: sid,
        token: token,
        smsFrom: smsFrom,
        verifySid: verifySid,
        captchaSecret: captchaSecret,
        weatherKey: weatherKey,
        geminiKey: geminiKey,
      );
    } catch (error, stack) {
      stderr.writeln(error);
      stderr.writeln(stack);
      await _json(request.response, HttpStatus.internalServerError, <String, String>{
        'error': 'Relay failed.',
      });
    }
  }
}

Future<void> _handle(
  HttpRequest request, {
  required String key,
  required String from,
  required String sid,
  required String token,
  required String smsFrom,
  required String verifySid,
  required String captchaSecret,
  required String weatherKey,
  required String geminiKey,
}) async {
  _cors(request.response);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }
  if (request.method == 'GET' && request.uri.path == '/weather') {
    await _weather(request, weatherKey);
    return;
  }
  if (request.method != 'POST' ||
      (request.uri.path != '/send' &&
          request.uri.path != '/sms' &&
          request.uri.path != '/sms-check' &&
          request.uri.path != '/chat' &&
          request.uri.path != '/captcha')) {
    await _json(request.response, HttpStatus.notFound, <String, String>{
      'error': 'Not found.',
    });
    return;
  }
  final String body = await utf8.decoder.bind(request).join();
  if (body.length > 12000) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Request is too large.',
    });
    return;
  }
  final Object? decoded = jsonDecode(body);
  if (decoded is! Map) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Expected a JSON object.',
    });
    return;
  }
  if (request.uri.path == '/captcha') {
    await _verifyCaptcha(
      request,
      token: (decoded['token'] ?? '').toString().trim(),
      secret: captchaSecret,
    );
    return;
  }
  if (request.uri.path == '/chat') {
    await _guide(request, decoded: decoded, geminiKey: geminiKey);
    return;
  }
  final String code = (decoded['code'] ?? '').toString().trim();
  if (request.uri.path == '/sms' && verifySid.isNotEmpty) {
    await _startVerify(
      request,
      to: (decoded['to'] ?? '').toString().trim(),
      sid: sid,
      token: token,
      verifySid: verifySid,
    );
    return;
  }
  if (request.uri.path == '/sms-check') {
    await _checkVerify(
      request,
      to: (decoded['to'] ?? '').toString().trim(),
      code: code,
      sid: sid,
      token: token,
      verifySid: verifySid,
    );
    return;
  }
  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Enter a 6-digit code.',
    });
    return;
  }
  if (request.uri.path == '/sms') {
    await _sendSms(
      request,
      to: (decoded['to'] ?? '').toString().trim(),
      code: code,
      sid: sid,
      token: token,
      smsFrom: smsFrom,
    );
    return;
  }
  if (key.isEmpty) {
    await _json(request.response, HttpStatus.serviceUnavailable, <String, String>{
      'error': 'RESEND_API_KEY is not set on the relay.',
    });
    return;
  }
  final String to = (decoded['to'] ?? '').toString().trim();
  final String purpose = (decoded['purpose'] ?? '').toString().trim();
  if (!_emailOk(to)) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Enter a valid email.',
    });
    return;
  }
  if (purpose != 'verify' && purpose != 'reset') {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Unknown email purpose.',
    });
    return;
  }
  final String subject = purpose == 'verify'
      ? 'Your Driftline verification code'
      : 'Your Driftline password reset code';
  final String text = purpose == 'verify'
      ? 'Your Driftline verification code is $code. It expires in 10 minutes.'
      : 'Your Driftline password reset code is $code. It expires in 10 minutes.';
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest outbound = await client.postUrl(
      Uri.parse('https://api.resend.com/emails'),
    );
    outbound.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
    outbound.headers.contentType = ContentType.json;
    outbound.add(
      utf8.encode(
        jsonEncode(<String, Object>{
          'from': from,
          'to': <String>[to],
          'subject': subject,
          'text': text,
        }),
      ),
    );
    final HttpClientResponse incoming = await outbound.close();
    final String reply = await utf8.decoder.bind(incoming).join();
    if (incoming.statusCode >= 200 && incoming.statusCode < 300) {
      stdout.writeln('Sent $purpose mail to $to');
      await _json(request.response, HttpStatus.ok, <String, bool>{'ok': true});
      return;
    }
    String message = 'Resend rejected the email.';
    try {
      final Object? parsed = jsonDecode(reply);
      if (parsed is Map && parsed['message'] is String) {
        message = parsed['message'] as String;
      }
    } catch (_) {}
    stderr.writeln('Resend ${incoming.statusCode} for $to');
    await _json(request.response, HttpStatus.badGateway, <String, String>{
      'error': message,
    });
  } finally {
    client.close();
  }
}

Future<void> _weather(HttpRequest request, String weatherKey) async {
  if (weatherKey.isEmpty) {
    await _json(request.response, HttpStatus.serviceUnavailable, <String, String>{
      'error': 'WEATHER_API_KEY is not set on the relay.',
    });
    return;
  }
  final Uri url = Uri.https('api.weatherapi.com', '/v1/forecast.json', <String, String>{
    'key': weatherKey,
    'q': 'auto:ip',
    'days': '1',
    'aqi': 'no',
    'alerts': 'no',
  });
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest outbound = await client.getUrl(url);
    final HttpClientResponse incoming = await outbound.close();
    final String reply = await utf8.decoder.bind(incoming).join();
    if (incoming.statusCode < 200 || incoming.statusCode >= 300) {
      stderr.writeln('Weather ${incoming.statusCode}');
      await _json(request.response, HttpStatus.badGateway, <String, String>{
        'error': 'Weather is unavailable right now.',
      });
      return;
    }
    final Object? parsed = jsonDecode(reply);
    if (parsed is! Map) {
      await _json(request.response, HttpStatus.badGateway, <String, String>{
        'error': 'Weather is unavailable right now.',
      });
      return;
    }
    final Map<String, Object?> location =
        (parsed['location'] as Map?)?.cast<String, Object?>() ??
            <String, Object?>{};
    final Map<String, Object?> current =
        (parsed['current'] as Map?)?.cast<String, Object?>() ??
            <String, Object?>{};
    final Map<String, Object?> condition =
        (current['condition'] as Map?)?.cast<String, Object?>() ??
            <String, Object?>{};
    final List<Object?> days =
        ((parsed['forecast'] as Map?)?['forecastday'] as List?) ??
            const <Object?>[];
    final Map<String, Object?> today = days.isEmpty || days.first is! Map
        ? <String, Object?>{}
        : (days.first as Map).cast<String, Object?>();
    final Map<String, Object?> day =
        (today['day'] as Map?)?.cast<String, Object?>() ?? <String, Object?>{};
    String icon = (condition['icon'] ?? '').toString();
    if (icon.startsWith('//')) {
      icon = 'https:$icon';
    }
    await _json(request.response, HttpStatus.ok, <String, Object>{
      'place': location['name'] ?? '',
      'region': location['region'] ?? '',
      'country': location['country'] ?? '',
      'tempC': current['temp_c'] ?? 0,
      'condition': condition['text'] ?? '',
      'icon': icon,
      'highC': day['maxtemp_c'] ?? current['temp_c'] ?? 0,
      'lowC': day['mintemp_c'] ?? current['temp_c'] ?? 0,
      'date': today['date'] ?? '',
    });
  } finally {
    client.close();
  }
}

Future<void> _guide(
  HttpRequest request, {
  required Map<Object?, Object?> decoded,
  required String geminiKey,
}) async {
  if (geminiKey.isEmpty) {
    await _json(request.response, HttpStatus.serviceUnavailable, <String, String>{
      'error': 'GEMINI_API_KEY is not set on the relay.',
    });
    return;
  }
  final String preferences = (decoded['preferences'] ?? '').toString().trim();
  final String home = (decoded['home'] ?? '').toString().trim();
  final String language = (decoded['language'] ?? '').toString().trim();
  final Object? rawMessages = decoded['messages'];
  if (rawMessages is! List || rawMessages.isEmpty) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Send the conversation first.',
    });
    return;
  }
  final List<Map<String, Object>> contents = <Map<String, Object>>[];
  for (final Object? item in rawMessages.take(12)) {
    if (item is! Map) {
      continue;
    }
    final String text = (item['text'] ?? '').toString().trim();
    if (text.isEmpty || text.length > 2000) {
      continue;
    }
    final String role = item['role'] == 'assistant' ? 'model' : 'user';
    contents.add(<String, Object>{
      'role': role,
      'parts': <Map<String, String>>[
        <String, String>{'text': text},
      ],
    });
  }
  if (contents.isEmpty || contents.last['role'] != 'user') {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Send a message first.',
    });
    return;
  }
  final String taste = preferences.isEmpty
      ? 'no travel preferences chosen yet'
      : preferences;
  final String system =
      'You are Driftline, a travel guide. Write only the message the traveler should read. '
      'The traveler is based in ${home.isEmpty ? 'their home country' : home} and likes $taste. '
      'Write in ${language.isEmpty ? 'English' : language}. '
      'If they have not named a country to visit, ask which country they want to visit. '
      'If they have, describe a trip there that fits those tastes: the best season, where to go, one sample day, food, and one practical caution.';
  final Map<String, Object> payload = <String, Object>{
    'system_instruction': <String, Object>{
      'parts': <Map<String, String>>[
        <String, String>{'text': system},
      ],
    },
    'contents': contents,
    'generationConfig': <String, Object>{
      'temperature': 0.7,
      'maxOutputTokens': 2000,
    },
  };
  const List<String> models = <String>[
    'gemini-3.5-flash',
    'gemini-3.6-flash',
  ];
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);
  try {
    int status = 0;
    String reply = '';
    for (final String model in models) {
      final Uri url = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$model:generateContent',
        <String, String>{'key': geminiKey},
      );
      final HttpClientRequest outbound = await client.postUrl(url);
      outbound.headers.contentType = ContentType.json;
      outbound.headers.set('x-goog-api-key', geminiKey);
      outbound.add(utf8.encode(jsonEncode(payload)));
      try {
        final HttpClientResponse incoming = await outbound.close().timeout(
          const Duration(seconds: 20),
        );
        status = incoming.statusCode;
        reply = await utf8.decoder.bind(incoming).join().timeout(
          const Duration(seconds: 15),
        );
      } on TimeoutException {
        status = 503;
        reply = '';
        continue;
      }
      if (status >= 200 && status < 300) {
        break;
      }
      if (status != 404 && status != 503) {
        break;
      }
    }
    if (status < 200 || status >= 300) {
      stderr.writeln('Gemini $status');
      await _json(request.response, HttpStatus.badGateway, <String, String>{
        'error': _twilioMessage(reply, 'The travel guide is unavailable.'),
      });
      return;
    }
    final Object? parsed = jsonDecode(reply);
    final String? text = _geminiText(parsed);
    if (text == null || text.isEmpty) {
      await _json(request.response, HttpStatus.badGateway, <String, String>{
        'error': 'The travel guide returned an empty answer.',
      });
      return;
    }
    await _json(request.response, HttpStatus.ok, <String, String>{
      'reply': text.trim(),
    });
  } on TimeoutException {
    await _json(request.response, HttpStatus.gatewayTimeout, <String, String>{
      'error': 'The travel guide took too long. Try again.',
    });
  } finally {
    client.close();
  }
}

String? _geminiText(Object? parsed) {
  if (parsed is! Map) {
    return null;
  }
  final Object? candidates = parsed['candidates'];
  if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
    return null;
  }
  final Object? content = (candidates.first as Map)['content'];
  if (content is! Map) {
    return null;
  }
  final Object? parts = content['parts'];
  if (parts is! List) {
    return null;
  }
  final StringBuffer buffer = StringBuffer();
  for (final Object? part in parts) {
    if (part is Map && part['text'] is String) {
      buffer.write(part['text']);
    }
  }
  return buffer.toString();
}

Future<void> _startVerify(
  HttpRequest request, {
  required String to,
  required String sid,
  required String token,
  required String verifySid,
}) async {
  final String? denied = _twilioReady(sid, token, verifySid);
  if (denied != null) {
    await _json(request.response, HttpStatus.serviceUnavailable, <String, String>{
      'error': denied,
    });
    return;
  }
  final String? destination = _e164(to);
  if (destination == null) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Use a phone number with a country code, such as +21620000000.',
    });
    return;
  }
  final ({int status, String body}) reply = await _twilioForm(
    Uri.parse(
      'https://verify.twilio.com/v2/Services/$verifySid/Verifications',
    ),
    sid: sid,
    token: token,
    form: <String, String>{'To': destination, 'Channel': 'sms'},
  );
  if (reply.status >= 200 && reply.status < 300) {
    stdout.writeln('Started SMS verification');
    await _json(request.response, HttpStatus.ok, <String, bool>{'ok': true});
    return;
  }
  stderr.writeln('Twilio Verify ${reply.status}');
  await _json(request.response, HttpStatus.badGateway, <String, String>{
    'error': _twilioMessage(reply.body, 'Twilio could not send the text.'),
  });
}

Future<void> _checkVerify(
  HttpRequest request, {
  required String to,
  required String code,
  required String sid,
  required String token,
  required String verifySid,
}) async {
  final String? denied = _twilioReady(sid, token, verifySid);
  if (denied != null) {
    await _json(request.response, HttpStatus.serviceUnavailable, <String, String>{
      'error': denied,
    });
    return;
  }
  if (!RegExp(r'^\d{4,10}$').hasMatch(code)) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Enter the code from the text message.',
    });
    return;
  }
  final String? destination = _e164(to);
  if (destination == null) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Use a phone number with a country code, such as +21620000000.',
    });
    return;
  }
  final ({int status, String body}) reply = await _twilioForm(
    Uri.parse(
      'https://verify.twilio.com/v2/Services/$verifySid/VerificationCheck',
    ),
    sid: sid,
    token: token,
    form: <String, String>{'To': destination, 'Code': code},
  );
  if (reply.status >= 200 && reply.status < 300) {
    final Object? parsed = jsonDecode(reply.body);
    if (parsed is Map && parsed['status'] == 'approved') {
      await _json(request.response, HttpStatus.ok, <String, bool>{'ok': true});
      return;
    }
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Invalid or expired code.',
    });
    return;
  }
  stderr.writeln('Twilio Verify check ${reply.status}');
  await _json(request.response, HttpStatus.badGateway, <String, String>{
    'error': _twilioMessage(reply.body, 'Invalid or expired code.'),
  });
}

String? _twilioReady(String sid, String token, String verifySid) {
  if (sid.isEmpty || token.isEmpty) {
    return 'Twilio credentials are not set on the relay.';
  }
  if (verifySid.isEmpty) {
    return 'TWILIO_VERIFY_SERVICE_SID is not set on the relay.';
  }
  if (token == '[AuthToken]') {
    return 'Replace [AuthToken] in tool/local.env with the Twilio auth token for this account.';
  }
  return null;
}

Future<({int status, String body})> _twilioForm(
  Uri url, {
  required String sid,
  required String token,
  required Map<String, String> form,
}) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest outbound = await client.postUrl(url);
    final String basic = base64Encode(utf8.encode('$sid:$token'));
    outbound.headers.set(HttpHeaders.authorizationHeader, 'Basic $basic');
    outbound.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    outbound.add(
      utf8.encode(
        form.entries
            .map(
              (MapEntry<String, String> entry) =>
                  '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
            )
            .join('&'),
      ),
    );
    final HttpClientResponse incoming = await outbound.close();
    final String body = await utf8.decoder.bind(incoming).join();
    return (status: incoming.statusCode, body: body);
  } finally {
    client.close();
  }
}

String _twilioMessage(String body, String fallback) {
  try {
    final Object? parsed = jsonDecode(body);
    if (parsed is Map && parsed['message'] is String) {
      return parsed['message'] as String;
    }
    if (parsed is Map && parsed['error'] is Map) {
      final Object? message = (parsed['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
  } catch (_) {}
  return fallback;
}

Future<void> _sendSms(
  HttpRequest request, {
  required String to,
  required String code,
  required String sid,
  required String token,
  required String smsFrom,
}) async {
  if (sid.isEmpty || token.isEmpty) {
    await _json(request.response, HttpStatus.serviceUnavailable, <String, String>{
      'error': 'Twilio credentials are not set on the relay.',
    });
    return;
  }
  if (smsFrom.isEmpty) {
    await _json(request.response, HttpStatus.serviceUnavailable, <String, String>{
      'error':
          'This Twilio trial has no sending number yet. Verify a phone number in the Twilio console, claim a number, then set TWILIO_FROM.',
    });
    return;
  }
  final String? destination = _e164(to);
  final String? sender = _e164(smsFrom);
  if (destination == null || sender == null) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Use a phone number with a country code, such as +212612345678.',
    });
    return;
  }
  final String text =
      'Your Driftline phone code is $code. It expires in 10 minutes.';
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest outbound = await client.postUrl(
      Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$sid/Messages.json',
      ),
    );
    final String basic = base64Encode(utf8.encode('$sid:$token'));
    outbound.headers.set(HttpHeaders.authorizationHeader, 'Basic $basic');
    outbound.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    outbound.add(
      utf8.encode(
        'To=${Uri.encodeQueryComponent(destination)}'
        '&From=${Uri.encodeQueryComponent(sender)}'
        '&Body=${Uri.encodeQueryComponent(text)}',
      ),
    );
    final HttpClientResponse incoming = await outbound.close();
    final String reply = await utf8.decoder.bind(incoming).join();
    if (incoming.statusCode >= 200 && incoming.statusCode < 300) {
      stdout.writeln('Sent SMS to $destination');
      await _json(request.response, HttpStatus.ok, <String, bool>{'ok': true});
      return;
    }
    String message = 'Twilio rejected the message.';
    try {
      final Object? parsed = jsonDecode(reply);
      if (parsed is Map && parsed['message'] is String) {
        message = parsed['message'] as String;
      }
    } catch (_) {}
    stderr.writeln('Twilio ${incoming.statusCode} for $destination');
    await _json(request.response, HttpStatus.badGateway, <String, String>{
      'error': message,
    });
  } finally {
    client.close();
  }
}

Future<void> _verifyCaptcha(
  HttpRequest request, {
  required String token,
  required String secret,
}) async {
  if (secret.isEmpty) {
    await _json(request.response, HttpStatus.serviceUnavailable, <String, String>{
      'error': 'RECAPTCHA_SECRET is not set on the relay.',
    });
    return;
  }
  if (token.isEmpty) {
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': 'Complete the CAPTCHA.',
    });
    return;
  }
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest outbound = await client.postUrl(
      Uri.parse('https://www.google.com/recaptcha/api/siteverify'),
    );
    outbound.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    outbound.add(
      utf8.encode(
        'secret=${Uri.encodeQueryComponent(secret)}'
        '&response=${Uri.encodeQueryComponent(token)}',
      ),
    );
    final HttpClientResponse incoming = await outbound.close();
    final String reply = await utf8.decoder.bind(incoming).join();
    final Object? parsed = jsonDecode(reply);
    if (parsed is Map && parsed['success'] == true) {
      final Object? score = parsed['score'];
      if (score is num && score < 0.5) {
        await _json(request.response, HttpStatus.badRequest, <String, String>{
          'error': 'CAPTCHA score was too low. Try again.',
        });
        return;
      }
      await _json(request.response, HttpStatus.ok, <String, bool>{'ok': true});
      return;
    }
    String message = 'CAPTCHA verification failed.';
    if (parsed is Map && parsed['error-codes'] is List) {
      final List<Object?> codes = (parsed['error-codes'] as List<Object?>);
      if (codes.contains('invalid-input-secret')) {
        message =
            'The reCAPTCHA secret does not match this site key. Add the secret from the Google reCAPTCHA admin.';
      } else if (codes.contains('timeout-or-duplicate')) {
        message = 'That CAPTCHA expired. Complete it again.';
      }
    }
    await _json(request.response, HttpStatus.badRequest, <String, String>{
      'error': message,
    });
  } finally {
    client.close();
  }
}

String? _e164(String raw) {
  String digits = raw.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.startsWith('00')) {
    digits = '+${digits.substring(2)}';
  }
  if (!digits.startsWith('+')) {
    return null;
  }
  final String national = digits.substring(1);
  if (!RegExp(r'^\d{8,15}$').hasMatch(national)) {
    return null;
  }
  return '+$national';
}

bool _emailOk(String value) {
  return value.length <= 200 &&
      value.contains('@') &&
      !value.contains(' ') &&
      !value.startsWith('@') &&
      !value.endsWith('@');
}

void _cors(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'content-type');
  response.headers.set('Access-Control-Allow-Private-Network', 'true');
}

Future<void> _json(
  HttpResponse response,
  int status,
  Map<String, Object> body,
) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}
