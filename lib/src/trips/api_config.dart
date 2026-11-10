/// Secure Gemini configuration for Driftline.
///
/// Development (direct Gemini, local only):
/// `flutter run --dart-define=GEMINI_API_KEY=your_dev_key`
///
/// Production / shared devices (preferred):
/// `flutter build apk --dart-define=GEMINI_PROXY_URL=https://your-host/api/v1/gemini/generate`
/// optional: `--dart-define=GEMINI_APP_TOKEN=shared_app_token`
///
/// The proxy holds `GEMINI_API_KEY` server-side. Flutter never ships that secret.
/// No API key is hardcoded. End-user UI must never show configuration fields.
class TripApiConfig {
  const TripApiConfig._();

  static const String geminiDefineKey = 'GEMINI_API_KEY';
  static const String geminiProxyDefineKey = 'GEMINI_PROXY_URL';
  static const String geminiAppTokenDefineKey = 'GEMINI_APP_TOKEN';
  static const String openTripMapDefineKey = 'OPENTRIPMAP_API_KEY';
  static const String openRouteServiceDefineKey = 'OPENROUTESERVICE_API_KEY';

  static const String compileTimeGeminiKey = String.fromEnvironment(
    geminiDefineKey,
    defaultValue: '',
  );

  static const String compileTimeGeminiProxyUrl = String.fromEnvironment(
    geminiProxyDefineKey,
    defaultValue: '',
  );

  static const String compileTimeGeminiAppToken = String.fromEnvironment(
    geminiAppTokenDefineKey,
    defaultValue: '',
  );

  static const String compileTimeOpenTripMapKey = String.fromEnvironment(
    openTripMapDefineKey,
    defaultValue: '',
  );

  static const String compileTimeOpenRouteServiceKey = String.fromEnvironment(
    openRouteServiceDefineKey,
    defaultValue: '',
  );

  /// Production path wins when both proxy and local key are present.
  static String? get geminiProxyUrl {
    final String value = compileTimeGeminiProxyUrl.trim();
    return value.isEmpty ? null : value;
  }

  static String? get compileTimeApiKey {
    final String value = compileTimeGeminiKey.trim();
    return value.isEmpty ? null : value;
  }

  static String? get geminiAppToken {
    final String value = compileTimeGeminiAppToken.trim();
    return value.isEmpty ? null : value;
  }

  /// True when either a proxy or a compile-time key is configured.
  static bool get isGeminiConfigured =>
      geminiProxyUrl != null || compileTimeApiKey != null;

  /// True when requests will go through the backend proxy (no local key needed).
  static bool get usesProxy => geminiProxyUrl != null;

  static Future<String?> geminiApiKey() async {
    // Direct key is only for local development builds.
    if (geminiProxyUrl != null) {
      return null;
    }
    return compileTimeApiKey;
  }

  static Future<bool> hasGeminiApiKey() async => isGeminiConfigured;

  static Map<String, String> proxyHeaders() {
    final String? token = geminiAppToken;
    if (token == null) {
      return const <String, String>{
        'Content-Type': 'application/json',
      };
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'X-Driftline-Token': token,
    };
  }

  static String? get openTripMapApiKey {
    final String value = compileTimeOpenTripMapKey.trim();
    return value.isEmpty ? null : value;
  }

  static String? get openRouteServiceApiKey {
    final String value = compileTimeOpenRouteServiceKey.trim();
    return value.isEmpty ? null : value;
  }

  static bool get isOpenTripMapConfigured => openTripMapApiKey != null;

  static bool get isOpenRouteServiceConfigured =>
      openRouteServiceApiKey != null;
}
