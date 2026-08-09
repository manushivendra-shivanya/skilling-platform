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
      supabasePublishableKey.startsWith('sb_publishable_');

  bool get hasApiConfiguration => Uri.tryParse(apiBaseUrl)?.hasScheme == true;

  bool get hasMicroLessonCdnConfiguration =>
      Uri.tryParse(microLessonCdnBaseUrl)?.hasScheme == true;

  bool get hasGoogleSignInConfiguration =>
      hasSupabaseConfiguration && googleWebClientId.isNotEmpty;
}
