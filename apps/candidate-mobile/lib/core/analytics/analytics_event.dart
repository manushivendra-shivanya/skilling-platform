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
}
