import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/coach_mark.dart';

/// The small, recurring brand mark for every pre-onboarding screen after
/// Welcome: Language, Sign-in choice, Email entry, OTP entry. Welcome shows
/// `CoachMark` once, prominently (52px inside a 104px circle), then nothing
/// -- so the app's own identity read as a one-time flourish rather than
/// something that follows the candidate through the flow. This widget is
/// that identity carried forward, at one small, consistent scale, so it
/// recurs instead of vanishing -- without competing with Welcome's own
/// hero treatment, which this fix deliberately leaves untouched.
///
/// Not built from `AppIconPlate`: that widget only accepts an `IconData`
/// (see its own doc comment on why `icon`/`label` aren't optional slots for
/// an arbitrary child), and `CoachMark` is deliberately not a Material
/// `IconData` -- it is a custom-painted mark (see `coach_mark.dart`'s doc
/// comment). This hand-rolls the same "colored circle behind a centered
/// mark" shape `AppIconPlate` uses for its square version, sized for
/// `CoachMark` instead.
class PreOnboardingBrandMark extends StatelessWidget {
  const PreOnboardingBrandMark({super.key});

  /// Outer circle diameter.
  static const double circleSize = 60;

  /// CoachMark size inside the circle -- within the 32-36px range a small,
  /// consistent recurring mark calls for; well below Welcome's 52px hero
  /// treatment so the two never compete.
  static const double markSize = 34;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: circleSize,
        height: circleSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.brandSoft,
          shape: BoxShape.circle,
        ),
        child: const CoachMark(size: markSize, color: AppColors.brand),
      ),
    );
  }
}

/// Step-count constants for the pre-onboarding progress indicator shown on
/// Language, Email, and OTP (Sign-in choice deliberately shows none -- see
/// below). Confirmed from `app_router.dart`, not assumed: after Sign-in
/// choice, Google sign-in goes straight to `authenticatedRoutePath`,
/// skipping Email/OTP entirely, while the email path visits both. That is
/// two genuinely different totals for the same pre-onboarding flow, and a
/// single shared indicator cannot show one honest number across both
/// without either misrepresenting whichever path the candidate is *not* on,
/// or silently rewriting the total the moment they choose. Rather than
/// force one indicator to cover both, this flow shows a total only where
/// one is already knowable at that point, and shows none where it is not:
///
/// - Language is the one screen genuinely shared, unconditionally, by every
///   candidate before the fork, so it shows its position within that known
///   2-step prefix (Language, Sign-in choice) -- [sharedPrefixSteps].
/// - Sign-in choice's own total is genuinely undecided until the candidate
///   taps a button on it, so `SignInChoiceScreen` shows no step indicator
///   at all rather than a number that would have to be quietly rewritten a
///   moment later.
/// - Email and OTP are only ever reached by a candidate who has already
///   committed to the email path -- Google's route goes straight past both
///   -- so by the time either renders, the real total for their path,
///   [emailPathSteps], is no longer a guess.
abstract final class PreOnboardingProgress {
  /// Steps common to every candidate before the Google/email fork:
  /// Language, then Sign-in choice.
  static const int sharedPrefixSteps = 2;

  /// Total pre-onboarding steps on the email path: Language, Sign-in
  /// choice, Email, OTP.
  static const int emailPathSteps = 4;
}
