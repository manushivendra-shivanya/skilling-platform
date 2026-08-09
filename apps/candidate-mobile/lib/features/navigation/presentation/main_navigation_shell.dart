import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_icons.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_tracker.dart';

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({
    required this.navigationShell,
    required this.analyticsTracker,
    required this.onOpenCoach,
    required this.onOpenNotifications,
    super.key,
  });

  static const destinationNames = ['home', 'learn', 'jobs', 'shift', 'me'];

  final StatefulNavigationShell navigationShell;
  final AnalyticsTracker analyticsTracker;
  final VoidCallback onOpenCoach;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = navigationShell.currentIndex;

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && navigationShell.currentIndex != 0) {
          _selectDestination(0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titleFor(selectedIndex)),
          actions: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                unawaited(
                  analyticsTracker.track(
                    AnalyticsEvent.globalActionOpened('notifications'),
                  ),
                );
                onOpenNotifications();
              },
              icon: const Icon(Icons.notifications_none_outlined),
            ),
          ],
        ),
        body: navigationShell,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'global-ai-coach-action',
          tooltip: 'Open AI Career Coach',
          onPressed: () {
            unawaited(
              analyticsTracker.track(
                AnalyticsEvent.globalActionOpened('ai_coach'),
              ),
            );
            onOpenCoach();
          },
          icon: const Icon(AppIcons.coach),
          label: const Text('AI Coach'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: _selectDestination,
          destinations: const [
            NavigationDestination(icon: Icon(AppIcons.home), label: 'Home'),
            NavigationDestination(icon: Icon(AppIcons.learn), label: 'Learn'),
            NavigationDestination(icon: Icon(AppIcons.jobs), label: 'Jobs'),
            NavigationDestination(icon: Icon(AppIcons.shift), label: 'Shift'),
            NavigationDestination(
              icon: Icon(AppIcons.profile),
              label: 'My Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _selectDestination(int index) {
    unawaited(
      analyticsTracker.track(
        AnalyticsEvent.mainTabSelected(destinationNames[index]),
      ),
    );
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  String _titleFor(int index) => switch (index) {
    0 => 'Saksham',
    1 => 'Learn',
    2 => 'Jobs',
    3 => 'Shift',
    4 => 'My Profile',
    _ => 'Saksham',
  };
}
