import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/analytics/analytics_tracker.dart';
import '../core/config/app_environment.dart';
import '../core/logging/app_logger.dart';
import '../core/widgets/app_error_boundary.dart';
import 'app.dart';
import 'dependencies.dart';

Future<void> bootstrap({
  AppConfig? config,
  AppLogger? logger,
  AnalyticsTracker? analyticsTracker,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final resolvedConfig = config ?? AppConfig.fromDartDefines();
  final resolvedLogger =
      logger ?? DebugAppLogger(enabled: resolvedConfig.enableLogging);
  final resolvedAnalyticsTracker =
      analyticsTracker ?? InMemoryAnalyticsTracker();

  if (resolvedConfig.hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: resolvedConfig.supabaseUrl,
      publishableKey: resolvedConfig.supabasePublishableKey,
    );
  }

  FlutterError.onError = (details) {
    resolvedLogger.error(
      'flutter_framework_error',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    resolvedLogger.error(
      'uncaught_platform_error',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };

  ErrorWidget.builder = AppErrorBoundary.fromFlutterError;

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(resolvedConfig),
            appLoggerProvider.overrideWithValue(resolvedLogger),
            analyticsTrackerProvider.overrideWithValue(
              resolvedAnalyticsTracker,
            ),
          ],
          child: const SkillingApp(),
        ),
      );
    },
    (error, stackTrace) {
      resolvedLogger.error(
        'uncaught_zone_error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
