import 'package:candidate_mobile/core/widgets/app_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  testWidgets(
    'AppSkeletonGroup wraps its children in a shimmer sweep by default',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppSkeletonGroup(
            child: Column(
              children: [AppSkeleton(height: 20), AppSkeleton(height: 20)],
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(AppSkeleton), findsNWidgets(2));
    },
  );

  testWidgets('AppSkeletonGroup skips the shimmer when the OS reduces motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: AppSkeletonGroup(child: AppSkeleton(height: 20)),
        ),
      ),
    );

    expect(find.byType(Shimmer), findsNothing);
    expect(find.byType(AppSkeleton), findsOneWidget);
  });
}
