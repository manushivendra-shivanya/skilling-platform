import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_tracker.dart';
import '../../core/repositories/candidate_session_repository.dart';
import '../../core/widgets/app_error_boundary.dart';
import '../../features/authentication/presentation/authenticated_placeholder_screen.dart';
import '../../features/authentication/presentation/otp_entry_screen.dart';
import '../../features/authentication/presentation/phone_entry_screen.dart';
import '../../features/coach/presentation/coach_screen.dart';
import '../../features/dev_tools/presentation/design_system_gallery_screen.dart';
import '../../features/home/presentation/home_dashboard_screen.dart';
import '../../features/jobs/presentation/jobs_screen.dart';
import '../../features/intelligence/presentation/diagnostic_screen.dart';
import '../../features/learning/presentation/learning_screen.dart';
import '../../features/navigation/presentation/global_placeholder_screen.dart';
import '../../features/navigation/presentation/main_navigation_shell.dart';
import '../../features/onboarding/domain/candidate_onboarding_repository.dart';
import '../../features/onboarding/presentation/candidate_onboarding_screen.dart';
import '../../features/onboarding/presentation/language_selection_screen.dart';
import '../../features/onboarding/presentation/sign_in_choice_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/practice/presentation/practice_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/app_startup_screen.dart';
import '../../features/voice/presentation/voice_interview_screen.dart';
import '../dependencies.dart';

const appStartupRoutePath = '/';
const appStartupRouteName = 'app-startup';
const welcomeRoutePath = '/welcome';
const welcomeRouteName = 'welcome';
const languageSelectionRoutePath = '/welcome/language';
const languageSelectionRouteName = 'language-selection';
const signInChoiceRoutePath = '/welcome/sign-in';
const signInChoiceRouteName = 'sign-in-choice';
const phoneEntryRoutePath = '/auth/phone';
const phoneEntryRouteName = 'phone-entry';
const otpEntryRoutePath = '/auth/otp';
const otpEntryRouteName = 'otp-entry';
const authenticatedRoutePath = '/auth/success';
const authenticatedRouteName = 'authenticated';
const candidateOnboardingRoutePath = '/onboarding';
const candidateOnboardingRouteName = 'candidate-onboarding';
const homeRoutePath = '/home';
const homeRouteName = 'home';
const learnRoutePath = '/learn';
const learnRouteName = 'learn';
const practiseRoutePath = '/practise';
const practiseRouteName = 'practise';
const jobsRoutePath = '/jobs';
const jobsRouteName = 'jobs';
const profileRoutePath = '/me';
const profileRouteName = 'me';
const aiCoachRoutePath = '/coach';
const aiCoachRouteName = 'ai-coach';
const notificationsRoutePath = '/notifications';
const notificationsRouteName = 'notifications';
const diagnosticRoutePath = '/diagnostic';
const diagnosticRouteName = 'diagnostic';
const voiceInterviewRoutePath = '/voice-interview';
const voiceInterviewRouteName = 'voice-interview';
const designSystemGalleryRoutePath = '/dev/design-system';
const designSystemGalleryRouteName = 'design-system-gallery';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter(
    analyticsTracker: ref.watch(analyticsTrackerProvider),
    candidateSessionRepository: ref.watch(candidateSessionRepositoryProvider),
    candidateOnboardingRepository: ref.watch(
      candidateOnboardingRepositoryProvider,
    ),
    showDevelopmentTools: !ref.watch(appConfigProvider).isProduction,
  );
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter({
  required AnalyticsTracker analyticsTracker,
  required CandidateSessionRepository candidateSessionRepository,
  required CandidateOnboardingRepository candidateOnboardingRepository,
  required bool showDevelopmentTools,
  String? initialLocation,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'root-navigator',
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    observers: [AppRouteObserver(analyticsTracker)],
    redirect: (context, state) => _redirectForCandidateState(
      location: state.matchedLocation,
      candidateSessionRepository: candidateSessionRepository,
      candidateOnboardingRepository: candidateOnboardingRepository,
    ),
    routes: [
      GoRoute(
        path: appStartupRoutePath,
        name: appStartupRouteName,
        builder: (context, state) => AppStartupScreen(
          onReady: (startupState) => context.go(
            startupState.session?.isAuthenticated == true
                ? authenticatedRoutePath
                : welcomeRoutePath,
          ),
        ),
      ),
      GoRoute(
        path: welcomeRoutePath,
        name: welcomeRouteName,
        builder: (context, state) => WelcomeScreen(
          onContinue: () => context.push(languageSelectionRoutePath),
          onOpenComponentGallery: showDevelopmentTools
              ? () => context.push(designSystemGalleryRoutePath)
              : null,
        ),
      ),
      GoRoute(
        path: languageSelectionRoutePath,
        name: languageSelectionRouteName,
        builder: (context, state) => LanguageSelectionScreen(
          onContinue: () => context.push(signInChoiceRoutePath),
        ),
      ),
      GoRoute(
        path: signInChoiceRoutePath,
        name: signInChoiceRouteName,
        builder: (context, state) => SignInChoiceScreen(
          onContinueWithPhone: () => context.push(phoneEntryRoutePath),
        ),
      ),
      GoRoute(
        path: phoneEntryRoutePath,
        name: phoneEntryRouteName,
        builder: (context, state) => PhoneEntryScreen(
          onOtpRequested: () => context.push(otpEntryRoutePath),
        ),
      ),
      GoRoute(
        path: otpEntryRoutePath,
        name: otpEntryRouteName,
        builder: (context, state) => OtpEntryScreen(
          onAuthenticated: () => context.go(authenticatedRoutePath),
          onRequestNewOtp: () => context.go(phoneEntryRoutePath),
        ),
      ),
      GoRoute(
        path: authenticatedRoutePath,
        name: authenticatedRouteName,
        builder: (context, state) => AuthenticatedPlaceholderScreen(
          onContinueToOnboarding: () =>
              context.push(candidateOnboardingRoutePath),
          onLoggedOut: () => context.go(welcomeRoutePath),
        ),
      ),
      GoRoute(
        path: candidateOnboardingRoutePath,
        name: candidateOnboardingRouteName,
        builder: (context, state) => CandidateOnboardingScreen(
          onContinueToHome: () => context.go(homeRoutePath),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainNavigationShell(
          navigationShell: navigationShell,
          analyticsTracker: analyticsTracker,
          onOpenCoach: () => context.push(aiCoachRoutePath),
          onOpenNotifications: () => context.push(notificationsRoutePath),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: homeRoutePath,
                name: homeRouteName,
                builder: (context, state) => HomeDashboardScreen(
                  onOpenCoach: () => context.push(aiCoachRoutePath),
                  onOpenDiagnostic: () => context.push(diagnosticRoutePath),
                  onOpenVoiceInterview: () =>
                      context.push(voiceInterviewRoutePath),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: learnRoutePath,
                name: learnRouteName,
                builder: (context, state) => const LearningScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: practiseRoutePath,
                name: practiseRouteName,
                builder: (context, state) => const PracticeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: jobsRoutePath,
                name: jobsRouteName,
                builder: (context, state) => const JobsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: profileRoutePath,
                name: profileRouteName,
                builder: (context, state) => ProfileScreen(
                  onLoggedOut: () => context.go(welcomeRoutePath),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: aiCoachRoutePath,
        name: aiCoachRouteName,
        builder: (context, state) => const CoachScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: notificationsRoutePath,
        name: notificationsRouteName,
        builder: (context, state) => GlobalPlaceholderScreen.notifications(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: diagnosticRoutePath,
        name: diagnosticRouteName,
        builder: (context, state) => const DiagnosticScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: voiceInterviewRoutePath,
        name: voiceInterviewRouteName,
        builder: (context, state) => const VoiceInterviewScreen(),
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

Future<String?> _redirectForCandidateState({
  required String location,
  required CandidateSessionRepository candidateSessionRepository,
  required CandidateOnboardingRepository candidateOnboardingRepository,
}) async {
  final needsCandidateSession =
      location == authenticatedRoutePath ||
      location == candidateOnboardingRoutePath ||
      _mainAndGlobalRoutePaths.contains(location);
  if (!needsCandidateSession) {
    return null;
  }

  final session = (await candidateSessionRepository.readSession()).when(
    success: (value) => value,
    failure: (_) => null,
  );
  if (session == null || !session.isAuthenticated) {
    return welcomeRoutePath;
  }

  if (location == candidateOnboardingRoutePath) {
    return null;
  }

  final draft = (await candidateOnboardingRepository.readDraft(
    session.candidateId,
  )).when(success: (value) => value, failure: (_) => null);
  if (draft == null) {
    return location == authenticatedRoutePath ? null : authenticatedRoutePath;
  }
  if (!draft.isCompleted) {
    return location == authenticatedRoutePath ? null : authenticatedRoutePath;
  }
  if (location == authenticatedRoutePath) {
    return homeRoutePath;
  }
  return null;
}

const _mainAndGlobalRoutePaths = {
  homeRoutePath,
  learnRoutePath,
  practiseRoutePath,
  jobsRoutePath,
  profileRoutePath,
  aiCoachRoutePath,
  notificationsRoutePath,
  diagnosticRoutePath,
  voiceInterviewRoutePath,
};

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
