enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({required this.environment, required this.enableLogging});

  const AppConfig.development()
    : environment = AppEnvironment.development,
      enableLogging = true;

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
    );
  }

  final AppEnvironment environment;
  final bool enableLogging;

  bool get isProduction => environment == AppEnvironment.production;
}
