import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/simulation_content.dart';

/// One entry from a `person` resource's `content['dialogue']` array.
class NpcDialogueLine {
  const NpcDialogueLine({
    required this.id,
    required this.trigger,
    required this.lines,
    this.topic,
  });

  final String id;
  final String trigger;
  final String? topic;
  final List<String> lines;
}

List<NpcDialogueLine> npcDialogueLines(SimulationResource resource) {
  final raw = resource.content['dialogue'];
  if (raw is! List) return const [];
  return [
    for (final entry in raw.cast<Map<String, Object?>>())
      NpcDialogueLine(
        id: entry['id']! as String,
        trigger: entry['trigger']! as String,
        topic: entry['topic'] as String?,
        lines: (entry['lines']! as List).cast<String>(),
      ),
  ];
}

/// Shows the supervisor's spoken lines in a bottom sheet.
Future<void> showSupervisorLines(
  BuildContext context, {
  required String supervisorTitle,
  required List<String> lines,
}) {
  return showAppBottomSheet<void>(
    context: context,
    title: supervisorTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.supervisor_account_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(line)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const AppBottomSheetCloseButton(),
      ],
    ),
  );
}

/// Shows a menu of `learner_asks` topics; tapping one shows that topic's
/// lines. Guidance-only — asking a question never reveals a finding.
Future<void> showAskSupervisorMenu(
  BuildContext context, {
  required String supervisorTitle,
  required List<NpcDialogueLine> topics,
}) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'Ask the $supervisorTitle',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final topic in topics)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: Text(_topicLabel(topic.topic)),
            onTap: () {
              Navigator.of(context).pop();
              showSupervisorLines(
                context,
                supervisorTitle: supervisorTitle,
                lines: topic.lines,
              );
            },
          ),
      ],
    ),
  );
}

String _topicLabel(String? topic) => switch (topic) {
  'near_expiry_policy' => 'What if a carton is near expiry?',
  'skip_inspection' => 'Can I skip inspecting a carton that looks fine?',
  _ => topic ?? 'Ask a question',
};
