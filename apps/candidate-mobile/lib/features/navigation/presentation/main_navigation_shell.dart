import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_icons.dart';
import '../../../app/theme/coach_mark.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_tracker.dart';
import 'widgets/coach_attention_popup.dart';

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
        // Home is the one tab with its own bespoke header (HomeHeader's
        // gradient hero) -- giving it this generic AppBar too meant it alone
        // paid for two headers stacked on top of each other. Every other tab
        // keeps exactly what it had: a title matching its bottom-nav label,
        // plus the notifications bell. Home's notifications entry point now
        // lives inside HomeHeader itself instead.
        appBar: selectedIndex == 0
            ? null
            : AppBar(
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
        floatingActionButton: _buildFab(selectedIndex),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: _selectDestination,
          destinations: const [
            NavigationDestination(icon: Icon(AppIcons.home), label: 'Home'),
            NavigationDestination(icon: Icon(AppIcons.learn), label: 'Train'),
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

  /// Built once and reused across both branches below rather than
  /// duplicated per-branch: the FAB itself (icon, label, `onPressed`) is
  /// identical on every tab, only whether it's wrapped in the attention
  /// popup differs.
  ///
  /// The popup only wraps it on Home (`selectedIndex == 0`): that's where
  /// the candidate's first glance is already spent on the readiness ring
  /// and today's mission, so the coach entry point is the one most likely
  /// to go unnoticed there. It's also the one tab GoRouter's
  /// `StatefulNavigationShell` doesn't tear down and rebuild on every
  /// visit within a session -- switching tabs just hides the branch's
  /// Navigator, it doesn't recreate `MainNavigationShell` -- so the popup
  /// widget itself is what stays mounted (and its dismiss timer keeps
  /// running) once already shown; it isn't rebuilt from scratch and
  /// re-triggered by returning to Home from another tab.
  Widget _buildFab(int selectedIndex) {
    final fab = FloatingActionButton.extended(
      heroTag: 'global-ai-coach-action',
      tooltip: 'Open AI Career Coach',
      onPressed: () => _openCoach('ai_coach'),
      icon: const CoachMark(),
      label: const Text('AI Coach'),
    );

    if (selectedIndex != 0) return fab;

    return CoachAttentionPopup(
      onTap: () => _openCoach('ai_coach_attention_popup'),
      onShown: () {
        unawaited(
          analyticsTracker.track(
            AnalyticsEvent.globalActionOpened('ai_coach_attention_popup_shown'),
          ),
        );
      },
      child: fab,
    );
  }

  void _openCoach(String source) {
    unawaited(
      analyticsTracker.track(AnalyticsEvent.globalActionOpened(source)),
    );
    onOpenCoach();
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
    1 => 'Train',
    2 => 'Jobs',
    3 => 'Shift',
    4 => 'My Profile',
    _ => 'Saksham',
  };
}
