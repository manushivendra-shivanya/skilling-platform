import 'dart:convert';

import 'package:candidate_mobile/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an unsigned but structurally real legacy Supabase JWT (header +
/// `{"role": role}` payload + a dummy signature segment) -- enough to
/// exercise `hasSupabaseConfiguration`'s own decode logic, which never
/// checks the signature (that's Supabase's job server-side; this getter
/// only asks "does this look like a key we can safely embed client-side").
String _legacyJwt(String role) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256'})}.${segment({'role': role})}.dummy-signature';
}

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

  test(
    'backend is also enabled by a legacy JWT key whose role claim is anon',
    () {
      final anonJwt = AppConfig(
        environment: AppEnvironment.staging,
        enableLogging: true,
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: _legacyJwt('anon'),
      );
      final serviceRoleJwt = AppConfig(
        environment: AppEnvironment.staging,
        enableLogging: true,
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: _legacyJwt('service_role'),
      );
      const malformedJwt = AppConfig(
        environment: AppEnvironment.staging,
        enableLogging: true,
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: 'not.a.jwt',
      );

      expect(anonJwt.hasSupabaseConfiguration, isTrue);
      expect(
        serviceRoleJwt.hasSupabaseConfiguration,
        isFalse,
        reason: 'a service_role JWT must never be treated as embeddable',
      );
      expect(malformedJwt.hasSupabaseConfiguration, isFalse);
    },
  );

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
