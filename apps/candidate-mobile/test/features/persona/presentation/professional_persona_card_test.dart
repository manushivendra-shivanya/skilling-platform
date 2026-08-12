import 'package:candidate_mobile/core/widgets/app_chip.dart';
import 'package:candidate_mobile/core/widgets/app_initials_avatar.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:candidate_mobile/features/persona/presentation/professional_persona_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'renders an initials avatar beside the candidate name, and gives the '
    'Self-reported chip an active tone',
    (tester) async {
      const draft = CandidateOnboardingDraft(
        fullName: 'Ravi Kumar',
        city: 'Lucknow',
        state: 'Uttar Pradesh',
        headline: 'Warehouse Associate at ABC Logistics',
      );

      await tester.pumpThemedWidget(
        const ProfessionalPersonaCard(draft: draft),
      );

      expect(find.byType(AppInitialsAvatar), findsOneWidget);
      final avatar = tester.widget<AppInitialsAvatar>(
        find.byType(AppInitialsAvatar),
      );
      expect(avatar.name, 'Ravi Kumar');
      expect(find.text('RK'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);

      final chip = tester.widget<AppStatusChip>(
        find.widgetWithText(AppStatusChip, 'Self-reported'),
      );
      expect(chip.tone, AppChipTone.info);
    },
  );
}
