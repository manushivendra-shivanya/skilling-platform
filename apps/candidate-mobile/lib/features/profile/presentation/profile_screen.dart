import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_gradient_hero.dart';
import '../../../core/widgets/app_initials_avatar.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/presentation/candidate_session_controller.dart';
import '../../authentication/presentation/development_auth_controller.dart';
import '../../career_passport/presentation/career_passport_section.dart';
import '../../career_passport/presentation/role_readiness_section.dart';
import '../../intelligence/domain/candidate_intelligence.dart';
import '../../intelligence/presentation/candidate_intelligence_controller.dart';
import '../../networking/presentation/networking_section.dart';
import '../../onboarding/domain/candidate_onboarding_draft.dart';
import '../../onboarding/presentation/candidate_onboarding_controller.dart';
import '../../onboarding/presentation/candidate_onboarding_labels.dart';
import '../../persona/presentation/professional_persona_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    required this.onLoggedOut,
    required this.onOpenDiagnostic,
    super.key,
  });

  final VoidCallback onLoggedOut;

  /// The diagnostic is a one-off setup task that re-scores readiness, so it
  /// belongs beside the career profile it feeds rather than on Home.
  final VoidCallback onOpenDiagnostic;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = false;
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(candidateOnboardingControllerProvider);
    return draft.when(
      loading: () => const _ProfileLoadingView(),
      error: (error, stackTrace) => AppErrorState(
        title: l10n.profileLoadErrorTitle,
        message: error is AppFailure
            ? error.localizedMessage(l10n)
            : l10n.profileLoadErrorFallback,
        onAction: () =>
            ref.read(candidateOnboardingControllerProvider.notifier).retry(),
      ),
      data: (draft) => _buildProfile(l10n, draft),
    );
  }

  Widget _buildProfile(AppLocalizations l10n, CandidateOnboardingDraft draft) {
    final intelligence = ref
        .watch(candidateIntelligenceControllerProvider)
        .valueOrNull;
    return Column(
      children: [
        _IdentityHeader(draft: draft),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              112,
            ),
            children: [
              if (intelligence != null &&
                  intelligence.pendingSyncCount > 0) ...[
                AppPendingSyncBanner(
                  pendingCount: intelligence.pendingSyncCount,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: l10n.profileEditDetailsButton,
                variant: AppButtonVariant.secondary,
                onPressed: () => _editDetails(l10n, draft),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: l10n.profileCareerSectionTitle,
                children: [
                  _DetailRow(
                    label: l10n.profileGoalLabel,
                    value: draft.goal == null
                        ? l10n.profileNotSet
                        : candidateGoalLabel(draft.goal!, l10n),
                  ),
                  _DetailRow(
                    label: l10n.profileEducationLabel,
                    value: draft.education == null
                        ? l10n.profileNotSet
                        : educationLevelLabel(draft.education!, l10n),
                  ),
                  _DetailRow(
                    label: l10n.profileExperienceLabel,
                    value: draft.experience == null
                        ? l10n.profileNotSet
                        : experienceLevelLabel(draft.experience!, l10n),
                  ),
                  _DetailRow(
                    label: l10n.profilePreferredRolesLabel,
                    value: draft.preferredRoles
                        .map((role) => logisticsRoleLabel(role, l10n))
                        .join(', '),
                  ),
                  _DetailRow(
                    label: l10n.profileEvidenceLabel,
                    value: intelligence == null || intelligence.evidence.isEmpty
                        ? l10n.profileNoEvidenceYet
                        : l10n.profileEvidenceCount(
                            intelligence.evidence.length,
                          ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(l10n.profileCareerDiagnosticTitle),
                    subtitle: Text(l10n.profileCareerDiagnosticSubtitle),
                    trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                    onTap: widget.onOpenDiagnostic,
                  ),
                ],
              ),
              if (draft.headline.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ProfessionalPersonaCard(draft: draft),
                const SizedBox(height: AppSpacing.md),
                NetworkingSection(draft: draft),
              ],
              if (intelligence != null && intelligence.evidence.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: l10n.profileReadinessEvidenceTitle,
                  children: [
                    for (final item in intelligence.evidence.reversed.take(4))
                      _EvidenceRow(item: item),
                    Text(l10n.profileEvidenceDisclaimer),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const RoleReadinessSection(),
              const SizedBox(height: AppSpacing.md),
              const CareerPassportSection(),
              const SizedBox(height: AppSpacing.md),
              _Section(
                title: l10n.profilePrivacySectionTitle,
                children: [
                  _DetailRow(
                    label: l10n.profilePlatformTermsLabel,
                    value:
                        draft
                            .consents[OnboardingConsentVersions.termsPurpose]
                            ?.version ??
                        l10n.profileNotAccepted,
                  ),
                  _DetailRow(
                    label: l10n.profilePrivacyNoticeLabel,
                    value:
                        draft
                            .consents[OnboardingConsentVersions.privacyPurpose]
                            ?.version ??
                        l10n.profileNotAccepted,
                  ),
                  _DetailRow(
                    label: l10n.profileVoiceSharingLabel,
                    value: l10n.profileVoiceSharingValue,
                  ),
                  _DetailRow(
                    label: l10n.profileEmployerSharingLabel,
                    value: l10n.profileEmployerSharingValue,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Section(
                title: l10n.profilePreferencesSectionTitle,
                children: [
                  _DetailRow(
                    label: l10n.profileLanguageLabel,
                    value: _currentLanguageLabel(context, l10n),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _notificationsEnabled,
                    onChanged: (value) =>
                        setState(() => _notificationsEnabled = value),
                    title: Text(l10n.profileNotificationPrefTitle),
                    subtitle: Text(l10n.profileNotificationPrefSubtitle),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_outline),
                    title: Text(l10n.profileHelpSupportTitle),
                    onTap: () => showAppSnackBar(
                      context: context,
                      message: l10n.profileSupportSnackbar,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    title: Text(l10n.profileDeleteAccountTitle),
                    subtitle: Text(l10n.profileDeleteAccountSubtitle),
                    onTap: () => _showDeletionPlaceholder(l10n),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.profileLogoutButton,
                variant: AppButtonVariant.secondary,
                isLoading: _loggingOut,
                onPressed: _loggingOut ? null : () => _logout(l10n),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _currentLanguageLabel(BuildContext context, AppLocalizations l10n) {
    final locale = ref.watch(appLocaleProvider);
    return switch (locale.scriptCode) {
      'Latn' => l10n.languageHinglish,
      _ when locale.languageCode == 'hi' => l10n.languageHindi,
      _ => l10n.languageEnglish,
    };
  }

  Future<void> _editDetails(
    AppLocalizations l10n,
    CandidateOnboardingDraft draft,
  ) async {
    final updated = await showAppBottomSheet<CandidateOnboardingDraft>(
      context: context,
      title: l10n.profileEditDetailsButton,
      child: _EditProfileForm(draft: draft),
    );
    if (updated == null || !mounted) return;
    final failure = await ref
        .read(candidateOnboardingControllerProvider.notifier)
        .save(updated);
    if (!mounted) return;
    showAppSnackBar(
      context: context,
      message: failure?.localizedMessage(l10n) ?? l10n.profileSavedSnackbar,
      tone: failure == null ? AppMessageTone.success : AppMessageTone.error,
    );
  }

  Future<void> _showDeletionPlaceholder(AppLocalizations l10n) async {
    await showAppConfirmationDialog(
      context: context,
      title: l10n.profileDeletionDialogTitle,
      message: l10n.profileDeletionDialogMessage,
      confirmLabel: l10n.profileDeletionConfirmLabel,
      cancelLabel: l10n.profileDeletionCancelLabel,
      isDestructive: true,
    );
  }

  Future<void> _logout(AppLocalizations l10n) async {
    setState(() => _loggingOut = true);
    final failure = await ref
        .read(candidateSessionControllerProvider.notifier)
        .logout();
    if (!mounted) return;
    if (failure == null) {
      ref.read(developmentAuthControllerProvider.notifier).clear();
      ref.invalidate(candidateOnboardingControllerProvider);
      widget.onLoggedOut();
    } else {
      setState(() => _loggingOut = false);
      showAppSnackBar(
        context: context,
        message: failure.localizedMessage(l10n),
        tone: AppMessageTone.error,
      );
    }
  }
}

/// The gradient hero header atop the profile screen: an avatar built from
/// the candidate's initials, their name, and their city/state -- all read
/// from the same [CandidateOnboardingDraft] the sections below already use.
///
/// Sits outside the ListView's horizontal padding so the gradient runs
/// edge-to-edge, matching a full-bleed hero rather than a padded card.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.draft});

  final CandidateOnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    // Tinted white rather than a fixed grey: it keeps its relationship with
    // the gradient at every point down the header.
    final onBrandMuted = Colors.white.withValues(alpha: 0.82);

    return AppGradientHero(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: AppInitialsAvatar(
              name: draft.fullName,
              background: AppColors.brandDark,
              foreground: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            draft.fullName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${draft.city}, ${draft.state}',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: onBrandMuted),
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.item});

  final EvidenceRecord item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.verified_outlined),
      title: Text(
        LogisticsIntelligenceCatalog.competencyName(item.competencyCode),
      ),
      subtitle: Text('${item.sourceType} • ${item.explanation}'),
      trailing: Text('${item.score}%'),
    );
  }
}

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({required this.draft});

  final CandidateOnboardingDraft draft;

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.fullName);
    _city = TextEditingController(text: widget.draft.city);
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: l10n.profileFullNameLabel),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _city,
          decoration: InputDecoration(labelText: l10n.profileCityLabel),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: l10n.profileSaveChangesButton, onPressed: _submit),
        const SizedBox(height: AppSpacing.sm),
        const AppBottomSheetCloseButton(),
      ],
    );
  }

  void _submit() {
    if (_name.text.trim().length < 2 || _city.text.trim().length < 2) {
      setState(
        () => _error = AppLocalizations.of(context).profileNameCityValidation,
      );
      return;
    }
    Navigator.of(context).pop(
      widget.draft.copyWith(
        fullName: _name.text.trim(),
        city: _city.text.trim(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value.isEmpty ? AppLocalizations.of(context).profileNotSet : value,
          ),
        ],
      ),
    );
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppSkeleton(height: 80),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 200),
        ],
      ),
    );
  }
}
