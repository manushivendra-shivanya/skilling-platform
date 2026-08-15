import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_initials_avatar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../profile_assistant/domain/profile_gap.dart';
import '../domain/detailed_candidate_profile.dart';
import 'detailed_profile_labels.dart';

/// The credential-first header the detailed profile now opens with.
///
/// Replaces a bare progress meter above a stack of identical white form
/// cards. What leads is what a recruiter -- and the candidate -- actually
/// care about: who they are, what they've proven, and the three facts
/// (experience, notice period, expected salary) every logistics employer
/// screens on. Editing still lives in the cards below; this header is
/// read-only apart from its one call to action.
///
/// Passport-*inspired*, not passport-costumed: the certification seal and
/// the strength meter carry the Career Passport metaphor the rest of the
/// app already uses by name, while type, spacing, and controls stay in
/// the app's existing Material language.
class ProfileHeroHeader extends StatelessWidget {
  const ProfileHeroHeader({
    required this.profile,
    required this.fullName,
    required this.location,
    required this.certificationCount,
    required this.onFinishProfile,
    super.key,
  });

  final DetailedCandidateProfile profile;

  /// From the onboarding draft -- `DetailedCandidateProfile` deliberately
  /// holds no name of its own (see its `headline` doc comment on the two
  /// sources of identity today).
  final String fullName;
  final String location;

  /// Both platform-issued and self-reported certifications, counted
  /// together for the seal -- the candidate earned both.
  final int certificationCount;
  final VoidCallback onFinishProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gapCount = findProfileGaps(profile).length;
    final strength = profileFieldCompletionPercent(profile);
    final preferences = profile.careerPreferences;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandDark],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.extraLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppInitialsAvatar(
                name: fullName.isEmpty ? '?' : fullName,
                size: 56,
                circular: false,
                background: AppColors.brandSoft,
                foreground: AppColors.brandDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fullName.isNotEmpty)
                      Text(
                        fullName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    if (profile.headline.isNotEmpty)
                      Text(
                        profile.headline,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    if (location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          location,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (certificationCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _Seal(label: l10n.profileHeroCertifiedSeal(certificationCount)),
          ],

          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Stat(
                label: l10n.profileHeroExperienceStat,
                value: profile.totalExperience,
              ),
              const SizedBox(width: AppSpacing.xs),
              _Stat(
                label: l10n.profileHeroNoticeStat,
                value: preferences.noticePeriod == null
                    ? ''
                    : noticePeriodLabel(preferences.noticePeriod!, l10n),
              ),
              const SizedBox(width: AppSpacing.xs),
              _Stat(
                label: l10n.profileHeroExpectedStat,
                value: preferences.expectedCtcAmount == null
                    ? ''
                    : '₹${(preferences.expectedCtcAmount! / 100000).toStringAsFixed(1)}L',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: AppRadius.mediumBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.profileHeroReadinessLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      '$strength%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.highlight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: strength / 100,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.highlight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (gapCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            // A plain filled button would read as the same brand green as
            // the header it sits on -- this stays legible against the
            // gradient without inventing a new accent.
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey('profile-hero-finish-button'),
                onPressed: onFinishProfile,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(
                  '${l10n.profileHeroFinishButton} · '
                  '${l10n.profileHeroGapsRemaining(gapCount)}',
                  textAlign: TextAlign.center,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brandDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Seal extends StatelessWidget {
  const _Seal({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.highlight.withValues(alpha: 0.18),
        border: Border.all(color: AppColors.highlight.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 14,
            color: AppColors.highlight,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.highlight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the three facts every logistics employer screens on. Renders a
/// muted "Not set" rather than collapsing when empty -- a missing notice
/// period is information the candidate should see, not a gap in the
/// layout they'd never notice.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSet = value.isNotEmpty;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: AppRadius.mediumBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSet ? value : l10n.profileHeroNotSet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSet
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
