import 'package:flutter/material.dart';

import '../../../app/theme/app_icons.dart';
import '../../../core/widgets/app_state_view.dart';

class GlobalPlaceholderScreen extends StatelessWidget {
  const GlobalPlaceholderScreen({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  factory GlobalPlaceholderScreen.aiCoach({Key? key}) {
    return GlobalPlaceholderScreen(
      key: key,
      icon: AppIcons.coach,
      title: 'AI Career Coach',
      message:
          'The Coach route is ready. Local text conversation arrives in Phase 1.8. No AI provider, microphone, or upload is active yet.',
    );
  }

  factory GlobalPlaceholderScreen.notifications({Key? key}) {
    return GlobalPlaceholderScreen(
      key: key,
      icon: Icons.notifications_none_outlined,
      title: 'No notifications yet',
      message:
          'This notification centre is a Phase 1.6 placeholder. Notification preferences and delivery will be added in a later milestone.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: AppStateView(
          icon: icon,
          title: title,
          message: message,
          actionLabel: null,
        ),
      ),
    );
  }
}
