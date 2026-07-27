import 'package:flutter/foundation.dart';

abstract interface class AppLogger {
  void debug(String event, {Map<String, Object?> context = const {}});

  void error(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  });
}

/// Writes operational events only. Callers must not include candidate PII in
/// event names or context.
class DebugAppLogger implements AppLogger {
  DebugAppLogger({required this.enabled});

  final bool enabled;

  @override
  void debug(String event, {Map<String, Object?> context = const {}}) {
    if (!enabled) {
      return;
    }

    debugPrint('[debug] $event $context');
  }

  @override
  void error(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    if (!enabled) {
      return;
    }

    debugPrint('[error] $event $context ${error ?? ''}');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
