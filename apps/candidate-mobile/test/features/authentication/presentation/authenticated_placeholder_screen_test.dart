import 'package:candidate_mobile/core/config/app_environment.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/authentication/data/mock_development_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'shows plain "Sign-in complete" copy, without development framing, '
    'once a real backend is configured',
    (tester) async {
      final sessions = InMemoryCandidateSessionRepository(
        session: const CandidateSession(
          candidateId: 'dev-candidate-candidate',
          isAuthenticated: true,
        ),
      );

      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        // hasSupabaseConfiguration reads SupabaseEmailAuthRepository off
        // this provider once configured -- override it so the test never
        // touches the real (uninitialized) Supabase client.
        developmentAuthRepository: MockDevelopmentAuthRepository(false),
        config: const AppConfig(
          environment: AppEnvironment.production,
          enableLogging: false,
          supabaseUrl: 'https://example.supabase.co',
          supabasePublishableKey: 'sb_publishable_test',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign-in complete'), findsOneWidget);
      expect(find.text('Development sign-in complete'), findsNothing);
    },
  );

  testWidgets(
    'keeps "Development sign-in complete" copy on the local/mock path',
    (tester) async {
      final sessions = InMemoryCandidateSessionRepository(
        session: const CandidateSession(
          candidateId: 'dev-candidate-candidate',
          isAuthenticated: true,
        ),
      );

      await tester.pumpCandidateApp(candidateSessionRepository: sessions);
      await tester.pumpAndSettle();

      expect(find.text('Development sign-in complete'), findsOneWidget);
      expect(find.text('Sign-in complete'), findsNothing);
    },
  );
}
