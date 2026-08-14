import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_icons.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

class AppOfflineBanner extends StatelessWidget {
  const AppOfflineBanner({
    this.message = 'You are offline. Saved work will sync when you reconnect.',
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _AppStatusBanner(
      icon: AppIcons.offline,
      message: message,
      backgroundColor: AppColors.warningSoft,
      foregroundColor: AppColors.warning,
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    );
  }
}

class AppPendingSyncBanner extends StatelessWidget {
  const AppPendingSyncBanner({
    required this.pendingCount,
    this.onViewDetails,
    super.key,
  });

  final int pendingCount;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _AppStatusBanner(
      icon: AppIcons.pendingSync,
      message: l10n.homeSyncBanner(pendingCount),
      backgroundColor: AppColors.infoSoft,
      foregroundColor: AppColors.info,
      actionLabel: onViewDetails == null ? null : l10n.actionView,
      onAction: onViewDetails,
    );
  }
}

class _AppStatusBanner extends StatelessWidget {
  const _AppStatusBanner({
    required this.icon,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.mediumBorder,
        ),
        child: Row(
          children: [
            Icon(icon, color: foregroundColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: foregroundColor),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: foregroundColor),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
