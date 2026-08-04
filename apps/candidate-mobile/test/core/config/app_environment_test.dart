import 'package:candidate_mobile/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend is enabled only with a valid URL and publishable key', () {
    const configured = AppConfig(
      environment: AppEnvironment.staging,
      enableLogging: true,
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_example',
    );
    const secretKey = AppConfig(
      environment: AppEnvironment.staging,
      enableLogging: true,
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_secret_must_not_be_used',
    );

    expect(configured.hasSupabaseConfiguration, isTrue);
    expect(secretKey.hasSupabaseConfiguration, isFalse);
    expect(const AppConfig.development().hasSupabaseConfiguration, isFalse);
  });

  test('micro-lesson CDN is enabled only with an absolute URL', () {
    const configured = AppConfig(
      environment: AppEnvironment.staging,
      enableLogging: true,
      microLessonCdnBaseUrl: 'https://cdn.example.com',
    );
    const invalid = AppConfig(
      environment: AppEnvironment.staging,
      enableLogging: true,
      microLessonCdnBaseUrl: 'cdn.example.com',
    );

    expect(configured.hasMicroLessonCdnConfiguration, isTrue);
    expect(invalid.hasMicroLessonCdnConfiguration, isFalse);
    expect(
      const AppConfig.development().hasMicroLessonCdnConfiguration,
      isFalse,
    );
  });
}
