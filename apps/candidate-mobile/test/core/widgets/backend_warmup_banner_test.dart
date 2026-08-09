import 'dart:async';

import 'package:candidate_mobile/core/network/backend_warmup_controller.dart';
import 'package:candidate_mobile/core/widgets/backend_warmup_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows nothing once the ping settles inside the grace period', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeBackendWarmupController(Future.value(true))),
    );
    await tester.pump();
    // Past the 1200ms grace period, but the fake ping already resolved.
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Getting things ready'), findsNothing);
  });

  testWidgets(
    'shows the ticking banner once still pending past the grace period',
    (tester) async {
      final completer = Completer<bool>();
      await tester.pumpWidget(
        _app(_FakeBackendWarmupController(completer.future)),
      );
      await tester.pump();
      // Still well within the grace period -- nothing yet.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Getting things ready'), findsNothing);

      // Past the grace period, still pending.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.textContaining('Getting things ready'), findsOneWidget);

      completer.complete(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Getting things ready'), findsNothing);
    },
  );
}

Widget _app(BackendWarmupController controller) => UncontrolledProviderScope(
  container: ProviderContainer(
    overrides: [backendWarmupControllerProvider.overrideWith(() => controller)],
  ),
  child: const MaterialApp(home: Scaffold(body: BackendWarmupBanner())),
);

class _FakeBackendWarmupController extends BackendWarmupController {
  _FakeBackendWarmupController(this._future);

  final Future<bool> _future;

  @override
  Future<bool> build() => _future;
}
