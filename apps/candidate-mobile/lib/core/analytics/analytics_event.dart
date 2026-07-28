class AnalyticsEvent {
  const AnalyticsEvent({required this.name, this.properties = const {}});

  final String name;

  /// Event properties must not contain phone numbers, names, or other PII.
  final Map<String, Object?> properties;

  factory AnalyticsEvent.appOpened() =>
      const AnalyticsEvent(name: 'app_opened');

  factory AnalyticsEvent.screenViewed(String screenName) => AnalyticsEvent(
    name: 'screen_viewed',
    properties: {'screen_name': screenName},
  );

  factory AnalyticsEvent.languageSelected(String languageCode) =>
      AnalyticsEvent(
        name: 'language_selected',
        properties: {'language_code': languageCode},
      );

  factory AnalyticsEvent.otpRequested() =>
      const AnalyticsEvent(name: 'development_otp_requested');

  factory AnalyticsEvent.developmentLoginCompleted() =>
      const AnalyticsEvent(name: 'development_login_completed');

  factory AnalyticsEvent.onboardingStarted() =>
      const AnalyticsEvent(name: 'candidate_onboarding_started');

  factory AnalyticsEvent.onboardingStepSaved(int step) => AnalyticsEvent(
    name: 'candidate_onboarding_step_saved',
    properties: {'step': step},
  );

  factory AnalyticsEvent.onboardingCompleted() =>
      const AnalyticsEvent(name: 'candidate_onboarding_completed');

  factory AnalyticsEvent.mainTabSelected(String tabName) => AnalyticsEvent(
    name: 'main_tab_selected',
    properties: {'tab_name': tabName},
  );

  factory AnalyticsEvent.globalActionOpened(String actionName) =>
      AnalyticsEvent(
        name: 'global_action_opened',
        properties: {'action_name': actionName},
      );

  factory AnalyticsEvent.homeDashboardRefreshed() =>
      const AnalyticsEvent(name: 'home_dashboard_refreshed');

  factory AnalyticsEvent.coachMessageSent() =>
      const AnalyticsEvent(name: 'local_coach_message_sent');

  factory AnalyticsEvent.mockApplicationCreated() =>
      const AnalyticsEvent(name: 'mock_job_application_created');

  factory AnalyticsEvent.diagnosticCompleted(String definitionVersion) =>
      AnalyticsEvent(
        name: 'diagnostic_completed',
        properties: {'definition_version': definitionVersion},
      );

  factory AnalyticsEvent.learningProgressSaved(String unitId) => AnalyticsEvent(
    name: 'learning_progress_saved',
    properties: {'unit_id': unitId},
  );

  factory AnalyticsEvent.simulationSubmitted(String simulationVersion) =>
      AnalyticsEvent(
        name: 'simulation_submitted',
        properties: {'simulation_version': simulationVersion},
      );

  factory AnalyticsEvent.voiceConsentGranted() =>
      const AnalyticsEvent(name: 'voice_consent_granted');

  factory AnalyticsEvent.voiceTurnRecorded(int turn) =>
      AnalyticsEvent(name: 'voice_turn_recorded', properties: {'turn': turn});

  factory AnalyticsEvent.voiceFeedbackReady(String rubricVersion) =>
      AnalyticsEvent(
        name: 'voice_feedback_ready',
        properties: {'rubric_version': rubricVersion},
      );

  factory AnalyticsEvent.voiceHumanReviewRequested() =>
      const AnalyticsEvent(name: 'voice_human_review_requested');
}
