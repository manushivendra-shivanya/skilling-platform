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
import '../../features/navigation/presentation/learn_and_practice_screen.dart';
import '../../features/navigation/presentation/global_placeholder_screen.dart';
import '../../features/navigation/presentation/main_navigation_shell.dart';
import '../../features/onboarding/domain/candidate_onboarding_draft.dart';
import '../../features/onboarding/domain/candidate_onboarding_repository.dart';
import '../../features/onboarding/presentation/candidate_onboarding_screen.dart';
import '../../features/onboarding/presentation/language_selection_screen.dart';
import '../../features/onboarding/presentation/sign_in_choice_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/shifts/presentation/my_shifts_screen.dart';
import '../../features/shifts/presentation/shift_availability_screen.dart';
import '../../features/shifts/presentation/shift_grievance_screen.dart';
import '../../features/shifts/presentation/shift_payout_screen.dart';
import '../../features/shifts/presentation/shift_screen.dart';
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
import '../../features/workplace_simulation/presentation/processing_entry_screen.dart';
import '../../features/workplace_simulation/presentation/packing_station_screen.dart';
import '../../features/workplace_simulation/presentation/quality_check_screen.dart';
import '../../features/workplace_simulation/presentation/processing_office_screen.dart';
import '../../features/workplace_simulation/presentation/picking_station_screen.dart';
import '../../features/workplace_simulation/presentation/consolidation_bay_screen.dart';
import '../../features/workplace_simulation/presentation/vehicle_check_screen.dart';
import '../../features/workplace_simulation/presentation/dispatch_gate_screen.dart';
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
const jobsRoutePath = '/jobs';
const jobsRouteName = 'jobs';
const shiftRoutePath = '/shift';
const shiftRouteName = 'shift';
const shiftAvailabilityRoutePath = '/shift/availability';
const shiftAvailabilityRouteName = 'shift-availability';
const myShiftsRoutePath = '/shift/my-shifts';
const myShiftsRouteName = 'my-shifts';
const shiftPayoutRoutePath = '/shift/payouts';
const shiftPayoutRouteName = 'shift-payouts';
const shiftGrievanceRoutePath = '/shift/support';
const shiftGrievanceRouteName = 'shift-support';
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
const workplaceProcessingEntryRouteName =
    'workplace-simulation-processing-entry';
const workplaceProcessingEntryRoutePattern =
    '/practise/workplace-simulation/:missionId/processing-entry';
const workplacePackingStationRouteName = 'workplace-simulation-packing-station';
const workplacePackingStationRoutePattern =
    '/practise/workplace-simulation/:missionId/packing-station';
const workplaceQualityCheckRouteName = 'workplace-simulation-quality-check';
const workplaceQualityCheckRoutePattern =
    '/practise/workplace-simulation/:missionId/quality-check';
const workplaceProcessingOfficeRouteName =
    'workplace-simulation-processing-office';
const workplaceProcessingOfficeRoutePattern =
    '/practise/workplace-simulation/:missionId/processing-office';
const workplacePickingStationRouteName = 'workplace-simulation-picking-station';
const workplacePickingStationRoutePattern =
    '/practise/workplace-simulation/:missionId/picking-station';
const workplaceConsolidationBayRouteName =
    'workplace-simulation-consolidation-bay';
const workplaceConsolidationBayRoutePattern =
    '/practise/workplace-simulation/:missionId/consolidation-bay';
const workplaceVehicleCheckRouteName = 'workplace-simulation-vehicle-check';
const workplaceVehicleCheckRoutePattern =
    '/practise/workplace-simulation/:missionId/vehicle-check';
const workplaceDispatchGateRouteName = 'workplace-simulation-dispatch-gate';
const workplaceDispatchGateRoutePattern =
    '/practise/workplace-simulation/:missionId/dispatch-gate';
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
String workplaceProcessingEntryPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/processing-entry';
String workplacePackingStationPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/packing-station';
String workplaceQualityCheckPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/quality-check';
String workplaceProcessingOfficePath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/processing-office';
String workplacePickingStationPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/picking-station';
String workplaceConsolidationBayPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/consolidation-bay';
String workplaceVehicleCheckPath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/vehicle-check';
String workplaceDispatchGatePath(String missionId) =>
    '${workplaceSimulationPath(missionId)}/dispatch-gate';

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
      'processing-entry' => workplaceProcessingEntryPath(missionId),
      'packing-station' => workplacePackingStationPath(missionId),
      'quality-check' => workplaceQualityCheckPath(missionId),
      'processing-office' => workplaceProcessingOfficePath(missionId),
      'picking-station' => workplacePickingStationPath(missionId),
      'consolidation-bay' => workplaceConsolidationBayPath(missionId),
      'vehicle-check' => workplaceVehicleCheckPath(missionId),
      'dispatch-gate' => workplaceDispatchGatePath(missionId),
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
    // Available in any non-production build, including one wired to a real
    // Supabase project. It used to be switched off as soon as Supabase was
    // configured, which meant a correctly configured review build had no way
    // in at all when sign-in was unavailable -- and reviewing the UI is
    // exactly what a review build is for. See _skipToHomeForDev for what
    // does and does not work once inside.
    allowDevSkipToHome: !ref.watch(appConfigProvider).isProduction,
  );
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter({
  required AnalyticsTracker analyticsTracker,
  required CandidateSessionRepository candidateSessionRepository,
  required CandidateOnboardingRepository candidateOnboardingRepository,
  required bool showDevelopmentTools,
  bool allowDevSkipToHome = true,
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
      allowDevSkipToHome: allowDevSkipToHome,
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
          onSkipToHome: showDevelopmentTools && allowDevSkipToHome
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
          onGoogleAuthenticated: () => context.go(authenticatedRoutePath),
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
                  onOpenDiagnostic: () => context.push(diagnosticRoutePath),
                  onOpenVoiceInterview: () =>
                      context.push(voiceInterviewRoutePath),
                  onOpenPathway: () => context.go(learnRoutePath),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: learnRoutePath,
                name: learnRouteName,
                builder: (context, state) => LearnAndPracticeScreen(
                  startOnPractice: (state.extra as Map?)?['tab'] == 'practise',
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
                path: shiftRoutePath,
                name: shiftRouteName,
                builder: (context, state) => ShiftScreen(
                  onOpenAvailability: () =>
                      context.push(shiftAvailabilityRoutePath),
                  onOpenMyShifts: () => context.push(myShiftsRoutePath),
                  onOpenPayouts: () => context.push(shiftPayoutRoutePath),
                  onOpenGrievances: () => context.push(shiftGrievanceRoutePath),
                  onOpenSkillGap: () => context.go(learnRoutePath),
                ),
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
                  onOpenDiagnostic: () => context.push(diagnosticRoutePath),
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
        path: shiftAvailabilityRoutePath,
        name: shiftAvailabilityRouteName,
        builder: (context, state) => const ShiftAvailabilityScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: myShiftsRoutePath,
        name: myShiftsRouteName,
        builder: (context, state) => const MyShiftsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: shiftPayoutRoutePath,
        name: shiftPayoutRouteName,
        builder: (context, state) => const ShiftPayoutScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: shiftGrievanceRoutePath,
        name: shiftGrievanceRouteName,
        builder: (context, state) => const ShiftGrievanceScreen(),
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
            onExit: () =>
                context.go(learnRoutePath, extra: const {'tab': 'practise'}),
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
            onReturnToPractice: () =>
                context.go(learnRoutePath, extra: const {'tab': 'practise'}),
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
            onReturnToPractice: () =>
                context.go(learnRoutePath, extra: const {'tab': 'practise'}),
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
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceProcessingEntryRoutePattern,
        name: workplaceProcessingEntryRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return ProcessingEntryScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenPackingStation: () =>
                context.go(workplacePackingStationPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplacePackingStationRoutePattern,
        name: workplacePackingStationRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return PackingStationScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenQualityCheck: () =>
                context.go(workplaceQualityCheckPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceQualityCheckRoutePattern,
        name: workplaceQualityCheckRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return QualityCheckScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenProcessingOffice: () =>
                context.go(workplaceProcessingOfficePath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceProcessingOfficeRoutePattern,
        name: workplaceProcessingOfficeRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return ProcessingOfficeScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onMissionComplete: () =>
                context.go(workplacePerformanceFeedbackPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplacePickingStationRoutePattern,
        name: workplacePickingStationRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return PickingStationScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenConsolidationBay: () =>
                context.go(workplaceConsolidationBayPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceConsolidationBayRoutePattern,
        name: workplaceConsolidationBayRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return ConsolidationBayScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenVehicleCheck: () =>
                context.go(workplaceVehicleCheckPath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceVehicleCheckRoutePattern,
        name: workplaceVehicleCheckRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return VehicleCheckScreen(
            missionId: missionId,
            onBack: () => context.go(workplaceOverviewPath(missionId)),
            onOpenDispatchGate: () =>
                context.go(workplaceDispatchGatePath(missionId)),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: workplaceDispatchGateRoutePattern,
        name: workplaceDispatchGateRouteName,
        builder: (context, state) {
          final missionId = state.pathParameters['missionId']!;
          return DispatchGateScreen(
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

/// The candidate id the dev skip signs in as. Fixed, obviously synthetic, and
/// hex-valid in every group so it passes Postgres's UUID type check rather
/// than erroring. The redirect recognises it and treats onboarding as done.
const devSkipCandidateId = '00000000-0000-4000-8000-00000000dead';

/// Dev-tools-only shortcut: saves a local authenticated session and a
/// completed onboarding draft directly, then lets the normal redirect
/// logic carry the router to Home. Exists so screens past onboarding can be
/// reviewed without re-typing the whole candidate profile form, and without
/// depending on phone OTP or Google sign-in being reachable.
///
/// What works after skipping: everything backed locally or by a mock
/// repository -- Home, the workplace simulation, micro-lessons, the
/// certification exam, saved jobs, the design system gallery.
///
/// What does not: anything that queries Supabase. The id below is a
/// well-formed UUID so it survives Postgres's type check rather than
/// erroring, but there is no matching `auth.users` row, so RLS denies the
/// read and those screens show their empty or error state. That is the
/// intended, legible failure -- this shortcut reviews the UI, it does not
/// impersonate a candidate.
Future<void> _skipToHomeForDev({
  required BuildContext context,
  required CandidateSessionRepository candidateSessionRepository,
  required CandidateOnboardingRepository candidateOnboardingRepository,
}) async {
  const session = CandidateSession(
    candidateId: devSkipCandidateId,
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

/// Test seam for the redirect rule. Driving a full GoRouter to assert one
/// branch pulls in the whole widget tree; the rule itself is a pure function
/// of two repositories and a flag, so expose it directly.
@visibleForTesting
Future<String?> redirectForCandidateStateForTest({
  required String location,
  required CandidateSessionRepository candidateSessionRepository,
  required CandidateOnboardingRepository candidateOnboardingRepository,
  bool allowDevSkipToHome = false,
}) => _redirectForCandidateState(
  location: location,
  candidateSessionRepository: candidateSessionRepository,
  candidateOnboardingRepository: candidateOnboardingRepository,
  allowDevSkipToHome: allowDevSkipToHome,
);

Future<String?> _redirectForCandidateState({
  required String location,
  required CandidateSessionRepository candidateSessionRepository,
  required CandidateOnboardingRepository candidateOnboardingRepository,
  bool allowDevSkipToHome = false,
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

  // The dev session's onboarding draft lives wherever the configured
  // onboarding repository put it -- and against a real Supabase project that
  // is nowhere, because RLS rejects a candidate id with no auth.users row.
  // Reading it back therefore always reports "onboarding incomplete" and the
  // redirect bounces to the profile form, which is precisely the screen the
  // skip exists to get past. Treat this one known id as already onboarded.
  if (allowDevSkipToHome && session.candidateId == devSkipCandidateId) {
    return location == authenticatedRoutePath ? homeRoutePath : null;
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
  jobsRoutePath,
  shiftRoutePath,
  profileRoutePath,
  aiCoachRoutePath,
  notificationsRoutePath,
  diagnosticRoutePath,
  voiceInterviewRoutePath,
  shiftAvailabilityRoutePath,
  myShiftsRoutePath,
  shiftPayoutRoutePath,
  shiftGrievanceRoutePath,
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
