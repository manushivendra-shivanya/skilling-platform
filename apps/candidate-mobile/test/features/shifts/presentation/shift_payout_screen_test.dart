import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/shifts/domain/shift_payout.dart';
import 'package:candidate_mobile/features/shifts/presentation/shift_payout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an empty state when there are no payouts yet', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeShiftPayoutRepository(const [])));
    await tester.pumpAndSettle();

    expect(find.text('No payouts yet'), findsOneWidget);
  });

  testWidgets('lists payouts with status, and never claims to move money', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeShiftPayoutRepository([
          const ShiftPayout(
            shiftApplicationId: 'app-1',
            basePay: 650,
            bonus: 50,
            deductions: 0,
            total: 700,
            status: ShiftPayoutStatus.paid,
            expectedPayoutDate: null,
          ),
          const ShiftPayout(
            shiftApplicationId: 'app-2',
            basePay: 500,
            bonus: 0,
            deductions: 20,
            total: 480,
            status: ShiftPayoutStatus.pendingApproval,
            expectedPayoutDate: null,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('₹700'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Bonus: ₹50'), findsOneWidget);
    expect(find.text('₹480'), findsOneWidget);
    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.text('Deductions: ₹20'), findsOneWidget);
    expect(find.textContaining('not a wallet'), findsOneWidget);
  });

  testWidgets('a load failure shows the error state with retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeShiftPayoutRepository(const [], loadFails: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payouts could not be loaded'), findsOneWidget);
  });
}

Widget _app(ShiftPayoutRepository repository) => UncontrolledProviderScope(
  container: ProviderContainer(
    overrides: [
      candidateSessionRepositoryProvider.overrideWithValue(
        InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'candidate-1',
            isAuthenticated: true,
          ),
        ),
      ),
      shiftPayoutRepositoryProvider.overrideWithValue(repository),
    ],
  ),
  child: MaterialApp(theme: buildAppTheme(), home: const ShiftPayoutScreen()),
);

class _FakeShiftPayoutRepository implements ShiftPayoutRepository {
  _FakeShiftPayoutRepository(this._payouts, {this.loadFails = false});

  final List<ShiftPayout> _payouts;
  final bool loadFails;

  @override
  Future<Result<List<ShiftPayout>>> loadPayouts(String candidateId) async {
    if (loadFails) {
      return const ResultFailure(
        StorageFailure('Payouts could not be loaded.'),
      );
    }
    return Success(_payouts);
  }
}
