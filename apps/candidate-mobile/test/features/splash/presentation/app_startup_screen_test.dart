import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/features/splash/data/mock_app_startup_repository.dart';
import 'package:candidate_mobile/features/splash/domain/app_startup_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('shows a recoverable startup error and retries', (tester) async {
    final repository = MockAppStartupRepository(
      response: const ResultFailure(
        NetworkFailure('You appear to be offline.'),
      ),
    );

    await tester.pumpCandidateApp(startupRepository: repository);
    await tester.pumpAndSettle();

    expect(find.text('We could not prepare the app'), findsOneWidget);
    expect(find.text('You appear to be offline.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.setResponse(const Success(AppStartupState(isLowDataMode: true)));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
  });
}
