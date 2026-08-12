import 'package:candidate_mobile/core/widgets/reduced_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prefersReducedMotion reads the OS reduce-motion setting', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(prefersReducedMotion(capturedContext), isTrue);
  });

  testWidgets(
    'prefersReducedMotion is false when the OS has not requested it',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(prefersReducedMotion(capturedContext), isFalse);
    },
  );

  testWidgets(
    'forwardUnlessReducedMotion jumps straight to the end value under '
    'reduce-motion instead of animating there',
    (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: _ControllerHost(
              onReady: (vsync, context) {
                controller = AnimationController(
                  vsync: vsync,
                  duration: const Duration(milliseconds: 220),
                );
                controller.forwardUnlessReducedMotion(context);
              },
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);

      // No settling pump needed -- if this were animating it would still
      // be at (or near) 0 on the very next frame.
      await tester.pump();
      expect(controller.value, 1.0);
    },
  );

  testWidgets(
    'forwardUnlessReducedMotion animates normally when motion is allowed',
    (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(
            onReady: (vsync, context) {
              controller = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 220),
              );
              controller.forwardUnlessReducedMotion(context);
            },
          ),
        ),
      );
      addTearDown(controller.dispose);

      await tester.pump();
      expect(controller.value, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(controller.value, 1.0);
    },
  );
}

/// Minimal `TickerProvider` + `BuildContext` host so this test can build a
/// real [AnimationController] without pulling in a whole feature screen.
class _ControllerHost extends StatefulWidget {
  const _ControllerHost({required this.onReady});

  final void Function(TickerProvider vsync, BuildContext context) onReady;

  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<_ControllerHost>
    with SingleTickerProviderStateMixin {
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    widget.onReady(this, context);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
