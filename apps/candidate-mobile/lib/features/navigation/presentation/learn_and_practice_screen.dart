import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../learning/presentation/learning_screen.dart';
import '../../practice/presentation/practice_screen.dart';

/// Combines the former separate "Learn" and "Practise" tabs into one
/// destination with an internal Lessons/Practise switch. Both screens are
/// embedded unmodified -- this is purely a navigation-level merge, not a
/// rewrite of either feature.
///
/// Uses [TabBar] purely for the segmented control UI, paired with
/// [IndexedStack] rather than [TabBarView] -- [TabBarView] wraps a
/// [PageView], which is itself a [Scrollable], and that extra scrollable in
/// the tree broke every test that located "the" scrollable via
/// `find.byType(Scrollable).first`. [IndexedStack] adds no such ancestor and
/// keeps both screens' state alive when switching, same as before.
class LearnAndPracticeScreen extends StatefulWidget {
  const LearnAndPracticeScreen({
    required this.onOpenWorkplaceSimulation,
    this.startOnPractice = false,
    super.key,
  });

  final void Function(String missionId) onOpenWorkplaceSimulation;

  /// True when arriving here from a workplace-simulation exit route, so the
  /// candidate lands back on Practise rather than Lessons (matches the exact
  /// tab they left, same as when Practise was its own bottom-nav tab).
  final bool startOnPractice;

  @override
  State<LearnAndPracticeScreen> createState() => _LearnAndPracticeScreenState();
}

class _LearnAndPracticeScreenState extends State<LearnAndPracticeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.startOnPractice ? 1 : 0;
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: _selectedIndex)
          ..addListener(() {
            if (_tabController.index != _selectedIndex) {
              setState(() => _selectedIndex = _tabController.index);
            }
          });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.brand,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            indicatorColor: AppColors.brand,
            tabs: const [
              Tab(text: 'Lessons'),
              Tab(text: 'Practise'),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              const LearningScreen(),
              PracticeScreen(
                onOpenWorkplaceSimulation: widget.onOpenWorkplaceSimulation,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
