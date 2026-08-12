import 'package:flutter/material.dart';

/// Semantic icon choices shared across the candidate application.
///
/// Icons reinforce labels and status; they must never be the only indication
/// of meaning.
abstract final class AppIcons {
  static const IconData home = Icons.home_outlined;
  static const IconData learn = Icons.menu_book_outlined;
  static const IconData practise = Icons.inventory_2_outlined;
  static const IconData jobs = Icons.work_outline;
  static const IconData shift = Icons.bolt_outlined;
  static const IconData profile = Icons.person_outline;
  // No `coach` entry: the AI Coach's identity is `CoachMark`
  // (`app/theme/coach_mark.dart`), a custom-drawn mark, not a bare
  // Material icon -- see that file's doc comment for why.

  static const IconData success = Icons.check_circle_outline;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_outline;
  static const IconData info = Icons.info_outline;
  static const IconData offline = Icons.cloud_off_outlined;
  static const IconData pendingSync = Icons.sync_outlined;
}
