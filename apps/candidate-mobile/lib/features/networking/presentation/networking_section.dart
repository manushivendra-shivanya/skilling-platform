import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../onboarding/domain/candidate_onboarding_draft.dart';
import '../domain/networking_repository.dart';
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
  // `_discoverable` used to be hardcoded to `false` here and only ever set
  // inside `_setDiscoverable`'s own success handler -- meaning a candidate
  // who had already turned discoverability on would see the switch render
  // OFF on every fresh build of this widget (app restart, returning from
  // an onboarding edit, any parent rebuild), a false assertion about their
  // own privacy setting.
  //
  // Investigated before fixing: `NetworkingRepository` had no read path
  // for a candidate's own profile, and neither did the backend --
  // `NetworkingService` only ever looked up a candidate's own row
  // internally (`getProfileRow`, used by `discover`/
  // `sendConnectionRequest`), never exposed it. Persisting `_discoverable`
  // to local device storage instead was considered and rejected: it would
  // just mask a real mismatch with the server's row rather than fix it.
  // Since exposing the existing row is a small, obviously-correct
  // extension of this same module (same controller, same
  // `CandidateAuthGuard`, reusing the existing query), a real
  // `GET /networking/profile` endpoint was added
  // (`NetworkingService.getMyProfile`) and this widget now fetches it,
  // instead of guessing.
  late Future<Result<NetworkingProfile>> _profileFuture;
  bool? _discoverable;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = ref.read(networkingRepositoryProvider).getMyProfile();
    _profileFuture.then((result) {
      if (!mounted) return;
      result.when(
        success: (profile) =>
            setState(() => _discoverable = profile.discoverable),
        // Leave `_discoverable` null (unknown) rather than guessing --
        // the switch stays disabled and the caption explains why, same
        // "don't assert something we don't know" reasoning as the initial
        // loading state below.
        failure: (_) {},
      );
    });
  }

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
          FutureBuilder<Result<NetworkingProfile>>(
            future: _profileFuture,
            builder: (context, snapshot) => _buildSwitch(context, snapshot),
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

  Widget _buildSwitch(
    BuildContext context,
    AsyncSnapshot<Result<NetworkingProfile>> snapshot,
  ) {
    final isLoading = snapshot.connectionState != ConnectionState.done;
    final hasFailed =
        !isLoading && (snapshot.data is ResultFailure || snapshot.hasError);

    String? caption;
    if (isLoading) {
      caption = 'Checking your settings…';
    } else if (hasFailed) {
      caption = 'Could not check your current setting. Try again.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          // While the real value is unknown (still loading, or the fetch
          // failed) the switch renders off but disabled -- an honest
          // "unconfirmed" affordance, not a confident (and possibly wrong)
          // "off". See the class-level doc comment for why there's no
          // safe local default to fall back on here.
          value: _discoverable ?? false,
          onChanged: (_isSaving || _discoverable == null)
              ? null
              : _setDiscoverable,
          title: const Text('Make my profile discoverable'),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hasFailed
                          ? AppColors.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasFailed)
                  TextButton(
                    onPressed: () => setState(_loadProfile),
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
      ],
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
