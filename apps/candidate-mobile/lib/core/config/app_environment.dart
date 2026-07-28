enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.enableLogging,
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
  });

  const AppConfig.development()
    : environment = AppEnvironment.development,
      enableLogging = true,
      supabaseUrl = '',
      supabasePublishableKey = '';

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
    );
  }

  final AppEnvironment environment;
  final bool enableLogging;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get isProduction => environment == AppEnvironment.production;

  bool get hasSupabaseConfiguration =>
      Uri.tryParse(supabaseUrl)?.hasScheme == true &&
      supabasePublishableKey.startsWith('sb_publishable_');
}
