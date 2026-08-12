import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../onboarding/domain/candidate_onboarding_draft.dart';
import 'discover_candidates_screen.dart';
import 'my_connections_screen.dart';

/// Entry point for candidate-to-candidate networking, shown alongside
/// `ProfessionalPersonaCard` on the Profile screen. Publishing here is
/// the one deliberate exception to the persona card's own data staying
/// on-device -- see `NetworkingProfile`'s doc comment.
class NetworkingSection extends ConsumerStatefulWidget {
  const NetworkingSection({required this.draft, super.key});

  final CandidateOnboardingDraft draft;

  @override
  ConsumerState<NetworkingSection> createState() => _NetworkingSectionState();
}

class _NetworkingSectionState extends ConsumerState<NetworkingSection> {
  bool _discoverable = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Find other candidates',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Turn this on to see and be found by other candidates in the '
            'same roles -- off by default. Nothing here is shared until '
            'someone connects with you, and it never includes anyone '
            'browsing or searching outside this feature.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _discoverable,
            onChanged: _isSaving ? null : _setDiscoverable,
            title: const Text('Make my profile discoverable'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Discover candidates',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DiscoverCandidatesScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'My connections',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyConnectionsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setDiscoverable(bool value) async {
    setState(() => _isSaving = true);
    final draft = widget.draft;
    final result = await ref
        .read(networkingRepositoryProvider)
        .publishProfile(
          fullName: draft.fullName,
          headline: draft.headline,
          city: draft.city,
          state: draft.state,
          preferredRoles: [for (final role in draft.preferredRoles) role.id],
          discoverable: value,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    result.when(
      success: (_) => setState(() => _discoverable = value),
      failure: (failure) => showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      ),
    );
  }
}
