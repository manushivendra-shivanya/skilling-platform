import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_tracker.dart';
import '../../core/widgets/app_error_boundary.dart';
import '../../features/dev_tools/presentation/design_system_gallery_screen.dart';
import '../../features/splash/presentation/app_startup_screen.dart';
import '../dependencies.dart';

const appStartupRoutePath = '/';
const appStartupRouteName = 'app-startup';
const designSystemGalleryRoutePath = '/dev/design-system';
const designSystemGalleryRouteName = 'design-system-gallery';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter(
    analyticsTracker: ref.watch(analyticsTrackerProvider),
    showDevelopmentTools: !ref.watch(appConfigProvider).isProduction,
  );
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter({
  required AnalyticsTracker analyticsTracker,
  required bool showDevelopmentTools,
}) {
  return GoRouter(
    observers: [AppRouteObserver(analyticsTracker)],
    routes: [
      GoRoute(
        path: appStartupRoutePath,
        name: appStartupRouteName,
        builder: (context, state) => AppStartupScreen(
          onOpenComponentGallery: showDevelopmentTools
              ? () => context.push(designSystemGalleryRoutePath)
              : null,
        ),
      ),
      if (showDevelopmentTools)
        GoRoute(
          path: designSystemGalleryRoutePath,
          name: designSystemGalleryRouteName,
          builder: (context, state) => const DesignSystemGalleryScreen(),
        ),
    ],
    errorBuilder: (context, state) => AppRouteErrorScreen(
      onReturnHome: () => context.go(appStartupRoutePath),
    ),
  );
}

class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver(this._analyticsTracker);

  final AnalyticsTracker _analyticsTracker;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackRoute(newRoute);
    }
  }

  void _trackRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName == null || routeName.isEmpty) {
      return;
    }

    unawaited(_analyticsTracker.track(AnalyticsEvent.screenViewed(routeName)));
  }
}

class AppRouteErrorScreen extends StatelessWidget {
  const AppRouteErrorScreen({required this.onReturnHome, super.key});

  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppErrorBoundaryContent(
          title: 'This page is not available',
          message:
              'Return to the start of your skilling journey and try again.',
          actionLabel: 'Go to start',
          onAction: onReturnHome,
        ),
      ),
    );
  }
}
