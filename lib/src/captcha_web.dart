import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String kRecaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_SITE_KEY',
  defaultValue: '6Leh2vwtAAAAAKn6ala24YEL4AEn363rJ6fo9cd0',
);

@JS('grecaptcha')
external JSObject? get _grecaptcha;

extension type _Recaptcha(JSObject _) implements JSObject {
  external void ready(JSFunction callback);
  external JSPromise<JSString> execute(JSString siteKey, JSObject options);
}

Future<String> requestCaptchaToken(String action) async {
  _ensureScript();
  final JSObject raw = await _whenReady();
  final Completer<String> done = Completer<String>();
  _Recaptcha(raw).ready(
    () {
      _Recaptcha(raw)
          .execute(
            kRecaptchaSiteKey.toJS,
            <String, Object>{'action': action}.jsify()! as JSObject,
          )
          .toDart
          .then(
            (JSString token) {
              if (!done.isCompleted) {
                done.complete(token.toDart);
              }
            },
            onError: (Object error) {
              if (!done.isCompleted) {
                done.completeError(error);
              }
            },
          );
    }.toJS,
  );
  return done.future.timeout(const Duration(seconds: 15));
}

void _ensureScript() {
  const String id = 'driftline-recaptcha';
  if (web.document.getElementById(id) != null) {
    return;
  }
  final web.HTMLScriptElement script =
      web.document.createElement('script') as web.HTMLScriptElement;
  script.id = id;
  script.async = true;
  script.src =
      'https://www.google.com/recaptcha/api.js?render=$kRecaptchaSiteKey';
  final web.HTMLHeadElement? head = web.document.head;
  if (head == null) {
    return;
  }
  head.appendChild(script);
}

Future<JSObject> _whenReady() async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    final JSObject? raw = _grecaptcha;
    if (raw != null) {
      return raw;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('reCAPTCHA did not load.');
}
