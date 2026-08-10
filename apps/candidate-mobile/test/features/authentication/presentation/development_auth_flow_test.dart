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
    await _openEmailEntry(tester);

    await tester.enterText(
      find.bySemanticsLabel('Email address'),
      'candidate@example.com',
    );
    await tester.tap(find.text('Send development code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Development code for ca***@example.com'), findsOneWidget);
    await tester.enterText(
      find.bySemanticsLabel('Six digit one time password'),
      '000000',
    );
    await tester.tap(find.text('Verify and continue'));
    await tester.pump();
    expect(find.textContaining('code is incorrect'), findsWidgets);

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
        candidateId: 'dev-candidate-candidate',
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

  testWidgets('invalid email and resend states are explicit', (tester) async {
    final clock = DateTime.now().subtract(const Duration(seconds: 31));
    await tester.pumpCandidateApp(
      developmentAuthRepository: MockDevelopmentAuthRepository(
        true,
        clock: () => clock,
      ),
    );
    await tester.pumpAndSettle();
    await _openEmailEntry(tester);

    await tester.enterText(
      find.bySemanticsLabel('Email address'),
      'not-an-email',
    );
    await tester.tap(find.text('Send development code'));
    await tester.pump();
    expect(find.textContaining('valid email'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsLabel('Email address'),
      'candidate@example.com',
    );
    await tester.tap(find.text('Send development code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Resend OTP'), findsOneWidget);
    await tester.tap(find.text('Resend OTP'));
    await tester.pump();
    expect(find.text('Development code for ca***@example.com'), findsOneWidget);
    await tester.tap(find.text('Change email address'));
    await tester.pumpAndSettle();
  });
}

Future<void> _openEmailEntry(WidgetTester tester) async {
  await tester.tap(find.text('Choose your language'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('English'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
  expect(find.text('Enter your email address'), findsOneWidget);
}
