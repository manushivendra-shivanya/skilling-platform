import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_feedback.dart';
import '../../features/onboarding/domain/candidate_language.dart';
import '../../features/onboarding/presentation/language_selection_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opened from Home's language chip. Two choices, not three: this drives
/// [appLocaleProvider] (see its own doc comment for why Hinglish isn't a
/// third option here even though [CandidateLanguage] has one) -- picking
/// either writes straight back through the same
/// `languageSelectionControllerProvider` onboarding's own language screen
/// uses, so there is exactly one saved preference, not two that could
/// disagree.
Future<void> showLanguagePickerSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppBottomSheet<void>(
    context: context,
    title: l10n.languagePickerTitle,
    child: const _LanguagePickerOptions(),
  );
}

class _LanguagePickerOptions extends ConsumerWidget {
  const _LanguagePickerOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(languageSelectionControllerProvider).valueOrNull;

    Future<void> select(CandidateLanguage language) async {
      await ref
          .read(languageSelectionControllerProvider.notifier)
          .select(language);
      if (context.mounted) Navigator.of(context).pop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageOption(
          label: l10n.languageEnglish,
          selected: selected == CandidateLanguage.english,
          onTap: () => select(CandidateLanguage.english),
        ),
        const SizedBox(height: AppSpacing.xs),
        _LanguageOption(
          label: l10n.languageHindi,
          selected: selected == CandidateLanguage.hindi,
          onTap: () => select(CandidateLanguage.hindi),
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandSoft : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.brand : AppColors.ink,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.brand,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
