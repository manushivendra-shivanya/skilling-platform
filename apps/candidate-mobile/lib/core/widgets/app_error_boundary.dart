import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_icons.dart';
import 'app_state_view.dart';

class AppErrorBoundary {
  const AppErrorBoundary._();

  static Widget fromFlutterError(FlutterErrorDetails details) {
    // Debug builds only (kDebugMode is compiled out of release builds, so
    // this never reaches a real candidate): append the real exception
    // instead of just the friendly message. `FlutterError.onError` already
    // logs this to the console via DebugAppLogger, but that requires
    // `adb logcat` -- reading it on-screen is the only option when the
    // only thing available is the phone itself, which is exactly the
    // situation this exists to unblock.
    final message = kDebugMode
        ? 'Please close and reopen the app. Your progress will not be '
              'affected by this technical issue.\n\n'
              'DEBUG BUILD ONLY — not shown in release:\n'
              '${details.exceptionAsString()}'
        : 'Please close and reopen the app. Your progress will not be '
              'affected by this technical issue.';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFFFFFFF),
        // Scrollable: AppStateView's Column is unbounded-height-safe
        // (mainAxisSize.min) but not overflow-safe -- the debug exception
        // text above has no length guarantee, and an overflow here would
        // be caught by this exact same ErrorWidget.builder, replacing a
        // readable exception with a blank re-trigger of itself.
        child: SingleChildScrollView(
          child: AppErrorBoundaryContent(
            title: 'We could not open this screen',
            message: message,
          ),
        ),
      ),
    );
  }
}

class AppErrorBoundaryContent extends StatelessWidget {
  const AppErrorBoundaryContent({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      icon: AppIcons.error,
      iconColor: AppColors.error,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
