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
import '../../features/onboarding/domain/candidate_onboarding_draft.dart';
import '../../features/onboarding/domain/candidate_onboarding_repository.dart';
import '../../features/onboarding/presentation/candidate_onboarding_screen.dart';
import '../../features/onboarding/presentation/language_selection_screen.dart';
import '../../features/onboarding/presentation/sign_in_choice_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/practice/presentation/practice_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/app_startup_screen.dart';
import '../../features/voice/presentation/voice_interview_screen.dart';
import '../../features/workplace_simulation/presentation/simulation_entry_screen.dart';
import '../../features/workplace_simulation/presentation/supervisor_briefing_screen.dart';
import '../../features/workplace_simulation/presentation/document_desk_screen.dart';
import '../../features/workplace_simulation/presentation/barcode_station_screen.dart';
import '../../features/workplace_simulation/presentation/inspection_zone_screen.dart';
import '../../features/workplace_simulation/presentation/performance_feedback_screen.dart';
import '../../features/workplace_simulation/presentation/quarantine_zone_screen.dart';
import '../../features/workplace_simulation/presentation/receiving_dock_screen.dart';
import '../../features/workplace_simulation/presentation/receiving_office_screen.dart';
import '../../features/workplace_simulation/presentation/staging_area_screen.dart';
import '../../features/workplace_simulation_3d/presentation/workplace_3d_preview_screen.dart';
import '../../features/workplace_simulation/presentation/location_planning_screen.dart';
import '../../features/workplace_simulation/presentation/transport_placement_screen.dart';
import '../../features/workplace_simulation/presentation/putaway_office_screen.dart';
import '../../features/workplace_simulation/presentation/workplace_overview_screen.dart';
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
const workplaceSimulationHubRoutePath = '/practise/workplace-simulation';
const workplaceSimulationHubRouteName = 'workplace-simulation';
const workplaceSimulationRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01';
const workplaceSimulationRoutePattern =
    '/practise/workplace-simulation/:missionId';
const workplaceSimulationRouteName = 'workplace-simulation-entry';
const workplaceBriefingRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/briefing';
const workplaceBriefingRouteName = 'workplace-simulation-briefing';
const workplaceBriefingRoutePattern =
    '/practise/workplace-simulation/:missionId/briefing';
const workplaceOverviewRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/workplace';
const workplaceOverviewRouteName = 'workplace-simulation-workplace';
const workplaceOverviewRoutePattern =
    '/practise/workplace-simulation/:missionId/workplace';
const workplaceDocumentDeskRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/document-desk';
const workplaceDocumentDeskRouteName = 'workplace-simulation-document-desk';
const workplaceDocumentDeskRoutePattern =
    '/practise/workplace-simulation/:missionId/document-desk';
const workplaceReceivingDockRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/receiving-dock';
const workplaceReceivingDockRouteName = 'workplace-simulation-receiving-dock';
const workplaceReceivingDockRoutePattern =
    '/practise/workplace-simulation/:missionId/receiving-dock';
const workplaceInspectionZoneRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/inspection-zone';
const workplaceInspectionZoneRouteName = 'workplace-simulation-inspection-zone';
const workplaceInspectionZoneRoutePattern =
    '/practise/workplace-simulation/:missionId/inspection-zone';
const workplaceBarcodeStationRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/barcode-station';
const workplaceBarcodeStationRouteName = 'workplace-simulation-barcode-station';
const workplaceBarcodeStationRoutePattern =
    '/practise/workplace-simulation/:missionId/barcode-station';
const workplaceQuarantineZoneRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/quarantine-zone';
const workplaceQuarantineZoneRouteName = 'workplace-simulation-quarantine-zone';
const workplaceQuarantineZoneRoutePattern =
    '/practise/workplace-simulation/:missionId/quarantine-zone';
const workplaceReceivingOfficeRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/receiving-office';
const workplaceReceivingOfficeRouteName =
    'workplace-simulation-receiving-office';
const workplaceReceivingOfficeRoutePattern =
    '/practise/workplace-simulation/:missionId/receiving-office';
const workplacePerformanceFeedbackRoutePath =
    '/practise/workplace-simulation/receive-incoming-shipment-01/performance-feedback';
const workplacePerformanceFeedbackRouteName =
    'workplace-simulation-performance-feedback';
const workplacePerformanceFeedbackRoutePattern =
    '/practise/workplace-simulation/:missionId/performance-feedback';
const workplaceStagingAreaRouteName = 'workplace-simulation-staging-area';
const workplaceStagingAreaRoutePattern =
    '/practise/workplace-simulation/:missionId/staging-area';
const workplaceLocationPlanningRouteName =
    'workplace-simulation-location-planning';
const workplaceLocationPlanningRoutePattern =
    '/practise/workplace-simulation/:missionId/location-planning';
const workplaceTransportPlacementRouteName =
    'workplace-simulation-transport-placement';
const workplaceTransportPlacementRoutePattern =
    '/practise/workplace-simulation/:missionId/transport-placement';
const workplacePutawayOfficeRouteName = 'workplace-simulation-putaway-office';
const workplacePutawayOfficeRoutePattern =
    '/practise/workplace-simulation/:missionId/putaway-office';
const designSystemGalleryRoutePath = '/dev/design-system';
const designSystemGalleryRouteName = 'design-system-gallery';
const wms3dPreviewRoutePath = '/dev/wms-3d-preview';
const wms3dPreviewRouteName = 'wms-3d-preview';

String workplaceSimulationPath(String missionId) =>
    '$workplaceSimulationHubRoutePath/$missionId';
String workplaceBriefingPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/briefing';
String workplaceOverviewPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/workplace';
String workplaceDocumentDeskPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/document-desk';
String workplaceReceivingDockPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/receiving-dock';
String workplaceInspectionZonePath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/inspection-zone';
String workplaceBarcodeStationPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/barcode-station';
String workplaceQuarantineZonePath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/quarantine-zone';
String workplaceReceivingOfficePath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/receiving-office';
String workplacePerformanceFeedbackPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/performance-feedback';
String workplaceStagingAreaPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/staging-area';
String workplaceLocationPlanningPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/location-planning';
String workplaceTransportPlacementPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/transport-placement';
String workplacePutawayOfficePath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/putaway-office';

/// Maps a workstation id from mission content to its screen route. New
/// workstations only need an entry here plus a GoRoute below — the overview
/// screen itself has no per-department knowledge of where things live.
String workstationPath(String workstationId, String missionId) =>
    switch (workstationId) {
      'document-desk' => workplaceDocumentDeskPath(missionId),
      'receiving-dock' => workplaceReceivingDockPath(missionId),
      'inspection-zone' => workplaceInspectionZonePath(missionId),
      'barcode-station' => workplaceBarcodeStationPath(missionId),
      'quarantine-zone' => workplaceQuarantineZonePath(missionId),
      'receiving-office' => workplaceReceivingOfficePath(missionId),
      'staging-area' => workplaceStagingAreaPath(missionId),
      'location-planning' => workplaceLocationPlanningPath(missionId),
      'transport-placement' => workplaceTransportPlacementPath(missionId),
      'putaway-office' => workplacePutawayOfficePath(missionId),
      _ => workplaceOverviewPath(missionId),
    };

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
          onOpenWms3dPreview: showDevelopmentTools
              ? () => context.push(wms3dPreviewRoutePath)
              : null,
          onSkipToHome: showDevelopmentTools
              ? () => _skipToHomeForDev(
                  context: context,
                  candidateSessionRepository: candidateSessionRepository,
                  candidateOnboardingRepository: candidateOnboardingRepository,
                )
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
                builder: (context, state) => PracticeScreen(
                  onOpenWorkplaceSimulation: (missionId) =>
                      context.push(workplaceSimulationPath(missionId)),
                ),
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
        path: workplaceSimulationHubRoutePath,
        name: workplaceSimulationHubRouteName,
        redirect: (context, state) => workplaceSimulationRoutePath,
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
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceSimulationRoutePattern,
        name: workplaceSimulationRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return SimulationEntryScreen(
            missionId: missionId,
            onOpenBriefing: () =>
                context.push(workplaceBriefingPath(missionId)),
            onContinueWorkplace: () =>
                context.go(workplaceOverviewPath(missionId)),
            onExit: () => context.go(practiseRoutePath),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceBriefingRoutePattern,
        name: workplaceBriefingRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return SupervisorBriefingScreen(
            missionId: missionId,
            onBackToEntry: () => context.go(workplaceSimulationPath(missionId)),
            onOpenWorkplace: () => context.go(workplaceOverviewPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceOverviewRoutePattern,
        name: workplaceOverviewRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return WorkplaceOverviewScreen(
            missionId: missionId,
            onOpenWorkstation: (workstationId) =>
                context.go(workstationPath(workstationId, missionId)),
            onReturnToPractice: () => context.go(practiseRoutePath),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceDocumentDeskRoutePattern,
        name: workplaceDocumentDeskRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return DocumentDeskScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceReceivingDockRoutePattern,
        name: workplaceReceivingDockRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return ReceivingDockScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenInspectionZone: () =>
                context.go(workplaceInspectionZonePath(missionId)),
            onMissionComplete: () =>
                context.go(workplacePerformanceFeedbackPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceInspectionZoneRoutePattern,
        name: workplaceInspectionZoneRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return InspectionZoneScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenBarcodeStation: () =>
                context.go(workplaceBarcodeStationPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceBarcodeStationRoutePattern,
        name: workplaceBarcodeStationRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return BarcodeStationScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenQuarantineZone: () =>
                context.go(workplaceQuarantineZonePath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceQuarantineZoneRoutePattern,
        name: workplaceQuarantineZoneRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return QuarantineZoneScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenReceivingOffice: () =>
                context.go(workplaceReceivingOfficePath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceReceivingOfficeRoutePattern,
        name: workplaceReceivingOfficeRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return ReceivingOfficeScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onMissionComplete: () =>
                context.go(workplacePerformanceFeedbackPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplacePerformanceFeedbackRoutePattern,
        name: workplacePerformanceFeedbackRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return PerformanceFeedbackScreen(
            missionId: missionId,
            onReturnToPractice: () => context.go(practiseRoutePath),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceStagingAreaRoutePattern,
        name: workplaceStagingAreaRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return StagingAreaScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenLocationPlanning: () =>
                context.go(workplaceLocationPlanningPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceLocationPlanningRoutePattern,
        name: workplaceLocationPlanningRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return LocationPlanningScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenTransportPlacement: () =>
                context.go(workplaceTransportPlacementPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceTransportPlacementRoutePattern,
        name: workplaceTransportPlacementRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return TransportPlacementScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenPutawayOffice: () =>
                context.go(workplacePutawayOfficePath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplacePutawayOfficeRoutePattern,
        name: workplacePutawayOfficeRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return PutawayOfficeScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onMissionComplete: () =>
                context.go(workplacePerformanceFeedbackPath(missionId)),
          );
        },
      ),
      if (showDevelopmentTools)
        GoRoute(
          path: designSystemGalleryRoutePath,
          name: designSystemGalleryRouteName,
          builder: (context, state) => const DesignSystemGalleryScreen(),
        ),
      if (showDevelopmentTools)
        GoRoute(
          path: wms3dPreviewRoutePath,
          name: wms3dPreviewRouteName,
          builder: (context, state) =>
              Workplace3dPreviewScreen(onBack: () => context.pop()),
        ),
    ],
    errorBuilder: (context, state) => AppRouteErrorScreen(
      onReturnHome: () => context.go(appStartupRoutePath),
    ),
  );
}

/// Dev-tools-only shortcut: saves a fake authenticated session and a
/// completed onboarding draft directly, then lets the normal redirect
/// logic carry the router to Home. Exists purely so testing screens past
/// onboarding (e.g. the Learn tab) doesn't require re-typing the whole
/// candidate profile form on every fresh install.
Future<void> _skipToHomeForDev({
  required BuildContext context,
  required CandidateSessionRepository candidateSessionRepository,
  required CandidateOnboardingRepository candidateOnboardingRepository,
}) async {
  const session = CandidateSession(
    candidateId: 'dev-skip-candidate',
    isAuthenticated: true,
  );
  await candidateSessionRepository.saveSession(session);
  final acceptedAt = DateTime.now().toUtc();
  await candidateOnboardingRepository.saveDraft(
    session.candidateId,
    CandidateOnboardingDraft(
      currentStep: 10,
      goal: CandidateGoal.findJob,
      fullName: 'Dev Skip Candidate',
      city: 'Lucknow',
      state: 'Uttar Pradesh',
      pinCode: '226001',
      education: EducationLevel.twelfthPass,
      experience: ExperienceLevel.fresher,
      preferredRoles: const {LogisticsRole.warehouseAssociate},
      consents: {
        OnboardingConsentVersions.termsPurpose: ConsentAcceptance(
          purpose: OnboardingConsentVersions.termsPurpose,
          version: OnboardingConsentVersions.termsVersion,
          acceptedAt: acceptedAt,
        ),
        OnboardingConsentVersions.privacyPurpose: ConsentAcceptance(
          purpose: OnboardingConsentVersions.privacyPurpose,
          version: OnboardingConsentVersions.privacyVersion,
          acceptedAt: acceptedAt,
        ),
      },
      isCompleted: true,
    ),
  );
  if (context.mounted) {
    context.go(authenticatedRoutePath);
  }
}

Future<String?> _redirectForCandidateState({
  required String location,
  required CandidateSessionRepository candidateSessionRepository,
  required CandidateOnboardingRepository candidateOnboardingRepository,
}) async {
  final needsCandidateSession =
      location == authenticatedRoutePath ||
      location == candidateOnboardingRoutePath ||
      _mainAndGlobalRoutePaths.contains(location) ||
      location.startsWith('$workplaceSimulationHubRoutePath/');
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
  workplaceSimulationHubRoutePath,
  workplaceSimulationRoutePath,
  workplaceBriefingRoutePath,
  workplaceOverviewRoutePath,
  workplaceDocumentDeskRoutePath,
  workplaceReceivingDockRoutePath,
  workplaceInspectionZoneRoutePath,
  workplaceBarcodeStationRoutePath,
  workplaceQuarantineZoneRoutePath,
  workplaceReceivingOfficeRoutePath,
  workplacePerformanceFeedbackRoutePath,
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
