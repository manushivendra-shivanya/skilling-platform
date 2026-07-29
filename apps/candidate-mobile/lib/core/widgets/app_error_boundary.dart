import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_icons.dart';
import 'app_state_view.dart';

class AppErrorBoundary {
  const AppErrorBoundary._();

  static Widget fromFlutterError(FlutterErrorDetails details) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFFFFFFF),
        child: AppErrorBoundaryContent(
          title: 'We could not open this screen',
          message:
              'Please close and reopen the app. Your progress will not be affected by this technical issue.',
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
