import 'package:candidate_mobile/core/widgets/app_progress.dart';
import 'package:candidate_mobile/core/widgets/app_skeleton.dart';
import 'package:candidate_mobile/core/widgets/app_state_view.dart';
import 'package:candidate_mobile/core/widgets/app_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'shared loading, progress, empty, error, and offline states render',
    (tester) async {
      var retryCount = 0;

      await tester.pumpThemedWidget(
        SingleChildScrollView(
          child: Column(
            children: [
              const AppSkeletonCard(),
              const AppProgress(value: 0.5, label: 'Learning progress'),
              AppEmptyState(
                title: 'No lessons downloaded',
                message: 'Download a lesson to study offline.',
                actionLabel: 'Browse lessons',
                onAction: () {},
              ),
              AppErrorState(
                title: 'Could not load lessons',
                message: 'Your progress is safe.',
                onAction: () => retryCount++,
              ),
              const AppOfflineBanner(),
              const AppPendingSyncBanner(pendingCount: 2),
            ],
          ),
        ),
      );

      expect(find.byType(AppSkeleton), findsNWidgets(4));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('No lessons downloaded'), findsOneWidget);
      expect(find.text('Could not load lessons'), findsOneWidget);
      expect(find.textContaining('You are offline'), findsOneWidget);
      expect(find.text('2 items waiting to sync.'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Try again'), 300);
      await tester.tap(find.text('Try again'));
      expect(retryCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
