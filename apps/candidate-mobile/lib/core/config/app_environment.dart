import 'dart:convert';

enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.enableLogging,
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
    this.apiBaseUrl = '',
    this.microLessonCdnBaseUrl = '',
    this.googleWebClientId = '',
  });

  const AppConfig.development()
    : environment = AppEnvironment.development,
      enableLogging = true,
      supabaseUrl = '',
      supabasePublishableKey = '',
      apiBaseUrl = '',
      microLessonCdnBaseUrl = '',
      googleWebClientId = '';

  factory AppConfig.fromDartDefines() {
    const configuredEnvironment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );

    final environment = switch (configuredEnvironment) {
      'production' => AppEnvironment.production,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };

    return AppConfig(
      environment: environment,
      enableLogging: bool.fromEnvironment(
        'ENABLE_LOGGING',
        defaultValue: environment != AppEnvironment.production,
      ),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
      microLessonCdnBaseUrl: const String.fromEnvironment(
        'MICRO_LESSON_CDN_BASE_URL',
      ),
      googleWebClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    );
  }

  final AppEnvironment environment;
  final bool enableLogging;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String apiBaseUrl;
  final String microLessonCdnBaseUrl;
  // The OAuth "Web application" client ID from Google Cloud Console. This is
  // a public identifier (not a secret -- the matching client secret lives
  // only in Supabase's Google provider config) that google_sign_in uses as
  // its serverClientId to request a Supabase-verifiable ID token.
  final String googleWebClientId;

  bool get isProduction => environment == AppEnvironment.production;

  bool get hasSupabaseConfiguration =>
      Uri.tryParse(supabaseUrl)?.hasScheme == true &&
      _isPublicClientKey(supabasePublishableKey);

  /// True for either key format Supabase issues that's actually safe to
  /// embed in a shipped client app: the modern `sb_publishable_...` key,
  /// or a legacy JWT-format key whose own `role` claim is `anon` --
  /// checked by decoding the JWT, not by guessing from a prefix. This
  /// deliberately rejects `sb_secret_...` (modern secret key) and a
  /// legacy `service_role` JWT just as firmly as it rejects garbage --
  /// the whole point of this gate is to stop a secret key from ever
  /// reaching the client bundle, so "looks roughly like a JWT" is not
  /// enough; the claim itself has to say `anon`.
  static bool _isPublicClientKey(String key) {
    if (key.startsWith('sb_publishable_')) return true;
    return _legacyJwtRole(key) == 'anon';
  }

  static String? _legacyJwtRole(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      return payload is Map ? payload['role'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  bool get hasApiConfiguration => Uri.tryParse(apiBaseUrl)?.hasScheme == true;

  bool get hasMicroLessonCdnConfiguration =>
      Uri.tryParse(microLessonCdnBaseUrl)?.hasScheme == true;

  bool get hasGoogleSignInConfiguration =>
      hasSupabaseConfiguration && googleWebClientId.isNotEmpty;
}
