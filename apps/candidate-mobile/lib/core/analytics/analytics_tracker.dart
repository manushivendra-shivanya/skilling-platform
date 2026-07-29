import 'analytics_event.dart';

abstract interface class AnalyticsTracker {
  Future<void> track(AnalyticsEvent event);
}

/// A local-only implementation for the Phase 1 shell.
///
/// This intentionally does not send candidate data to a provider. A production
/// adapter will be selected with the platform analytics decision.
class InMemoryAnalyticsTracker implements AnalyticsTracker {
  final List<AnalyticsEvent> _events = [];

  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  @override
  Future<void> track(AnalyticsEvent event) async {
    _events.add(event);
  }
}
