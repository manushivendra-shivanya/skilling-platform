import 'package:candidate_mobile/features/home/presentation/today_services_carousel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldAutoScroll', () {
    // Regression coverage for the reduce-motion gap this app's own
    // audit found: the auto-scroll timer previously started under any
    // real (non-test) binding regardless of the OS Reduce Motion
    // setting. `_TodayServicesCarouselState` always runs under the test
    // binding in a widget test, which independently disables
    // auto-scroll for pumpAndSettle reasons -- so this pure function is
    // the only way to exercise the reduce-motion branch in isolation.
    test('runs under a real binding with motion allowed', () {
      expect(
        shouldAutoScroll(isTestBinding: false, reducedMotion: false),
        isTrue,
      );
    });

    test('is skipped under a real binding when the OS reduces motion', () {
      expect(
        shouldAutoScroll(isTestBinding: false, reducedMotion: true),
        isFalse,
      );
    });

    test('is skipped under the test binding regardless of motion setting', () {
      expect(
        shouldAutoScroll(isTestBinding: true, reducedMotion: false),
        isFalse,
      );
      expect(
        shouldAutoScroll(isTestBinding: true, reducedMotion: true),
        isFalse,
      );
    });
  });
}
