import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/authentication/data/mock_development_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('candidate completes development login with failure recovery', (
    tester,
  ) async {
    final sessions = InMemoryCandidateSessionRepository();
    final analytics = InMemoryAnalyticsTracker();

    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      analyticsTracker: analytics,
    );
    await tester.pumpAndSettle();
    await _openPhoneEntry(tester);

    await tester.enterText(
      find.bySemanticsLabel('Indian mobile number, 10 digits'),
      '9876543210',
    );
    await tester.tap(find.text('Send development OTP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Development OTP: 123456\nNo SMS has been sent.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.bySemanticsLabel('Six digit one time password'),
      '000000',
    );
    await tester.tap(find.text('Verify and continue'));
    await tester.pump();
    expect(find.textContaining('OTP is incorrect'), findsWidgets);

    await tester.enterText(
      find.bySemanticsLabel('Six digit one time password'),
      '123456',
    );
    await tester.tap(find.text('Verify and continue'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Development sign-in complete'), findsOneWidget);
    expect(
      (await sessions.readSession()).when(
        success: (session) => session?.isAuthenticated,
        failure: (_) => false,
      ),
      isTrue,
    );
    expect(
      analytics.events.map((event) => event.name),
      containsAll(['development_otp_requested', 'development_login_completed']),
    );
  });

  testWidgets('restored session skips sign-in and logout clears it', (
    tester,
  ) async {
    final sessions = InMemoryCandidateSessionRepository(
      session: const CandidateSession(
        candidateId: 'dev-candidate-3210',
        isAuthenticated: true,
      ),
    );

    await tester.pumpCandidateApp(candidateSessionRepository: sessions);
    await tester.pumpAndSettle();

    expect(find.text('Development sign-in complete'), findsOneWidget);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    expect(
      (await sessions.readSession()).when(
        success: (session) => session,
        failure: (_) => const CandidateSession(
          candidateId: 'failure',
          isAuthenticated: true,
        ),
      ),
      isNull,
    );
  });

  testWidgets('invalid phone and resend states are explicit', (tester) async {
    final clock = DateTime.now().subtract(const Duration(seconds: 31));
    await tester.pumpCandidateApp(
      developmentAuthRepository: MockDevelopmentAuthRepository(
        true,
        clock: () => clock,
      ),
    );
    await tester.pumpAndSettle();
    await _openPhoneEntry(tester);

    await tester.enterText(
      find.bySemanticsLabel('Indian mobile number, 10 digits'),
      '123',
    );
    await tester.tap(find.text('Send development OTP'));
    await tester.pump();
    expect(find.textContaining('valid 10-digit'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsLabel('Indian mobile number, 10 digits'),
      '9876543210',
    );
    await tester.tap(find.text('Send development OTP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Resend OTP'), findsOneWidget);
    await tester.tap(find.text('Resend OTP'));
    await tester.pump();
    expect(
      find.text('Development OTP: 123456\nNo SMS has been sent.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Change phone number'));
    await tester.pumpAndSettle();
  });
}

Future<void> _openPhoneEntry(WidgetTester tester) async {
  await tester.tap(find.text('Choose your language'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('English'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with phone'));
  await tester.pumpAndSettle();
  expect(find.text('Enter your mobile number'), findsOneWidget);
}
