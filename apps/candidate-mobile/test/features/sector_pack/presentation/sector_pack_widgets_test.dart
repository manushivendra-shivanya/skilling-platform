import 'package:candidate_mobile/features/sector_pack/domain/sector_pack.dart';
import 'package:candidate_mobile/features/sector_pack/presentation/sector_credential_card.dart';
import 'package:candidate_mobile/features/sector_pack/presentation/sector_index_row.dart';
import 'package:candidate_mobile/features/sector_pack/presentation/sector_pack_icons.dart';
import 'package:candidate_mobile/features/sector_pack/presentation/sector_signal_dot.dart';
import 'package:candidate_mobile/features/sector_pack/presentation/sector_task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

const _pack = SectorPacks.warehouseLogistics;

void main() {
  group('SectorSignalDot', () {
    testWidgets('reads its colour from the pack signal palette per state', (
      tester,
    ) async {
      await tester.pumpThemedWidget(
        const Column(
          children: [
            SectorSignalDot(pack: _pack, state: SectorSignalState.locked),
            SectorSignalDot(pack: _pack, state: SectorSignalState.active),
            SectorSignalDot(pack: _pack, state: SectorSignalState.cleared),
          ],
        ),
      );

      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .toList();
      final colors = containers
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
      expect(colors, contains(_pack.signalPalette.locked));
      expect(colors, contains(_pack.signalPalette.active));
      expect(colors, contains(_pack.signalPalette.cleared));
      expect(tester.takeException(), isNull);
    });
  });

  group('SectorIndexRow', () {
    testWidgets('shows title, status text, and invokes onTap on the row', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpThemedWidget(
        SectorIndexRow(
          pack: _pack,
          indexLabel: 'L-01',
          glyph: SectorGlyph.play,
          title: 'Receiving Dock Safety Walkthrough',
          statusText: '8 min · Content v3 · Tap to open',
          onTap: () => tapped = true,
        ),
      );

      expect(find.text('L-01'), findsOneWidget);
      expect(find.text('Receiving Dock Safety Walkthrough'), findsOneWidget);
      expect(find.text('8 min · Content v3 · Tap to open'), findsOneWidget);

      await tester.tap(find.text('Receiving Dock Safety Walkthrough'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a trailing utility button is independently tappable', (
      tester,
    ) async {
      var rowTapped = false;
      var trailingTapped = false;
      await tester.pumpThemedWidget(
        SectorIndexRow(
          pack: _pack,
          indexLabel: 'L-02',
          glyph: SectorGlyph.play,
          title: 'Putaway Zone Numbering',
          statusText: '6 min · Content v1 · Tap to open',
          onTap: () => rowTapped = true,
          trailing: Tooltip(
            message: 'Download for offline',
            child: GestureDetector(
              onTap: () => trailingTapped = true,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.download_outlined),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Download for offline'));
      expect(trailingTapped, isTrue);
      expect(
        rowTapped,
        isFalse,
        reason: 'tapping the trailing action must not also fire the row tap',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('locked rows show a lock glyph instead of a signal dot', (
      tester,
    ) async {
      await tester.pumpThemedWidget(
        const SectorIndexRow(
          pack: _pack,
          indexLabel: 'L-03',
          glyph: SectorGlyph.lock,
          title: 'Dispatch & Loading',
          statusText: 'unlocks after L-02',
          locked: true,
        ),
      );

      expect(find.text('unlocks after L-02'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders at 2x text scale on a narrow surface without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpThemedWidget(
          const SectorIndexRow(
            pack: _pack,
            indexLabel: 'L-01',
            glyph: SectorGlyph.play,
            title: 'Receiving Dock Safety Walkthrough and Manifest Checks',
            statusText: '8 min · Content v3 · Downloaded',
            signalState: SectorSignalState.active,
            missionLabel: "TODAY'S MISSION",
          ),
          textScaler: TextScaler.linear(2),
        );

        expect(
          find.text('Receiving Dock Safety Walkthrough and Manifest Checks'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('SectorTaskCard', () {
    testWidgets('shows work order, tag, title, and tear label; taps the card', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpThemedWidget(
        SectorTaskCard(
          pack: _pack,
          workOrderLabel: 'WM-01',
          tagLabel: 'Beginner',
          tone: SectorTaskTone.emphasis,
          title: 'Receive an Incoming Shipment',
          description: 'Logistics · Warehouse Associate · ~20 min',
          statLeft: 'Not started',
          tearLabel: 'START',
          onTap: () => tapped = true,
        ),
      );

      expect(find.text('WM-01'), findsOneWidget);
      expect(find.text('BEGINNER'), findsOneWidget);
      expect(find.text('Receive an Incoming Shipment'), findsOneWidget);
      expect(find.text('START'), findsOneWidget);

      await tester.tap(find.text('Receive an Incoming Shipment'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unavailable cards still render their tear label, dimmed', (
      tester,
    ) async {
      await tester.pumpThemedWidget(
        const SectorTaskCard(
          pack: _pack,
          workOrderLabel: 'WM-04',
          tagLabel: 'Unavailable',
          tone: SectorTaskTone.muted,
          title: 'Dispatch Delivery Route',
          description: 'Logistics · Warehouse Associate · ~24 min',
          statLeft: 'Content unavailable',
          tearLabel: 'N/A',
          unavailable: true,
        ),
      );

      expect(find.text('N/A'), findsOneWidget);
      expect(find.text('Content unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 2x text scale on a narrow surface without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpThemedWidget(
        const SectorTaskCard(
          pack: _pack,
          workOrderLabel: 'WM-03',
          tagLabel: 'Intermediate',
          tone: SectorTaskTone.cleared,
          title: 'Process Incoming Batch of Mixed Pallets',
          description:
              'Logistics · Warehouse Associate · Intermediate · Approximately 22 minutes',
          statLeft: 'Completed',
          tearLabel: 'RETRY',
        ),
        textScaler: TextScaler.linear(2),
      );

      expect(
        find.text('Process Incoming Batch of Mixed Pallets'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SectorCredentialCard', () {
    testWidgets('locked state shows the eligibility bar and disabled CTA', (
      tester,
    ) async {
      var ctaPressed = false;
      await tester.pumpThemedWidget(
        SectorCredentialCard(
          pack: _pack,
          orgLine: 'WAREHOUSE & LOGISTICS · 24Q · ~30 MIN',
          levelLabel: 'PASS 70%',
          glyph: SectorGlyph.lock,
          credentialName: 'Warehouse Ops Certification',
          subtitle: 'Warehouse Operations Associate',
          statusLabel: 'LOCKED',
          statusState: SectorSignalState.locked,
          barcodeSeed: 'exam-1-none',
          eligibilityLabel: '2 / 4 LESSONS CLEARED',
          eligibilityFraction: 0.5,
          ctaLabel: 'Clear all lessons to unlock',
          ctaEnabled: false,
          onCta: () => ctaPressed = true,
        ),
      );

      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('2 / 4 LESSONS CLEARED'), findsOneWidget);
      expect(find.text('Clear all lessons to unlock'), findsOneWidget);

      await tester.tap(find.text('Clear all lessons to unlock'));
      expect(
        ctaPressed,
        isFalse,
        reason: 'ctaEnabled: false must not invoke onCta',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'eligible state omits the eligibility bar and enables the CTA',
      (tester) async {
        var ctaPressed = false;
        await tester.pumpThemedWidget(
          SectorCredentialCard(
            pack: _pack,
            orgLine: 'WAREHOUSE & LOGISTICS · 24Q · ~30 MIN',
            levelLabel: 'PASS 70%',
            glyph: SectorGlyph.check,
            credentialName: 'Warehouse Ops Certification',
            subtitle: 'Warehouse Operations Associate',
            statusLabel: 'ELIGIBLE',
            statusState: SectorSignalState.cleared,
            barcodeSeed: 'exam-1-none',
            ctaLabel: 'Start certification exam',
            onCta: () => ctaPressed = true,
          ),
        );

        expect(find.text('ELIGIBILITY'), findsNothing);
        await tester.tap(find.text('Start certification exam'));
        expect(ctaPressed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders at 2x text scale on a narrow surface without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Wrapped in a SingleChildScrollView, matching how
      // certification_exam_section.dart actually hosts this card in
      // learn_and_practice_screen.dart -- pumpThemedWidget's bare
      // Scaffold body gives a fixed, non-scrollable height, which the
      // card's full content (eligibility bar + attempt band + barcode +
      // CTA) can legitimately exceed at 2x text scale.
      await tester.pumpThemedWidget(
        SingleChildScrollView(
          child: SectorCredentialCard(
            pack: _pack,
            orgLine: 'WAREHOUSE & LOGISTICS · 24Q · ~30 MIN',
            levelLabel: 'PASS 70%',
            glyph: SectorGlyph.lock,
            credentialName: 'Warehouse Ops Certification',
            subtitle: 'Warehouse Operations Associate',
            statusLabel: 'LOCKED',
            statusState: SectorSignalState.locked,
            barcodeSeed: 'exam-1-none',
            eligibilityLabel: '0 / 3 LESSONS CLEARED',
            eligibilityFraction: 0,
            attemptText:
                'Last attempt: 61%, below the 70% pass mark. Retake unlocks at 14:20.',
            attemptState: SectorSignalState.locked,
            ctaLabel: 'Clear all lessons to unlock',
            ctaEnabled: false,
            onCta: () {},
          ),
        ),
        textScaler: TextScaler.linear(2),
      );

      expect(find.text('LOCKED'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'semanticLabel is exposed as a group without hiding the CTA button',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var ctaPressed = false;
        await tester.pumpThemedWidget(
          SectorCredentialCard(
            pack: _pack,
            orgLine: 'WAREHOUSE & LOGISTICS · 24Q · ~30 MIN',
            levelLabel: 'PASS 70%',
            glyph: SectorGlyph.lock,
            credentialName: 'Warehouse Ops Certification',
            subtitle: 'Warehouse Operations Associate',
            statusLabel: 'LOCKED',
            statusState: SectorSignalState.locked,
            barcodeSeed: 'exam-1-none',
            eligibilityLabel: '2 / 4 LESSONS CLEARED',
            eligibilityFraction: 0.5,
            ctaLabel: 'Clear all lessons to unlock',
            ctaEnabled: false,
            onCta: () => ctaPressed = true,
            semanticLabel:
                'Warehouse Ops Certification. Locked. 2 of 4 lessons cleared.',
          ),
        );

        expect(
          find.bySemanticsLabel(
            'Warehouse Ops Certification. Locked. 2 of 4 lessons cleared.',
          ),
          findsOneWidget,
        );
        // The overall group label must not swallow the CTA's own semantics
        // node -- it needs to stay independently reachable and announced,
        // same rationale as SectorIndexRow's trailing utility button.
        expect(
          find.bySemanticsLabel('Clear all lessons to unlock'),
          findsOneWidget,
        );
        await tester.tap(find.text('Clear all lessons to unlock'));
        expect(ctaPressed, isFalse, reason: 'ctaEnabled: false still holds');
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  });
}
