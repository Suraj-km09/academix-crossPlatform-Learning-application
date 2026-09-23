import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../domain/ai_mock_data.dart';

class AiRoadmapScreen extends StatefulWidget {
  const AiRoadmapScreen({super.key});

  @override
  State<AiRoadmapScreen> createState() => _AiRoadmapScreenState();
}

class _AiRoadmapScreenState extends State<AiRoadmapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<StudyPlanDay> _studyPlan;
  bool _reassessed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _studyPlan = AiMockData.get7DayPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double get _completionRatio {
    int total = 0;
    int completed = 0;
    for (final day in _studyPlan) {
      for (final task in day.tasks) {
        total++;
        if (task.isDone) completed++;
      }
    }
    return total == 0 ? 0 : completed / total;
  }

  void _simulateReassessment() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Simulating AI Reassessment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evaluating candidate responses across 15 questions on Functional Dependencies, 3NF & BCNF Decomposition...',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Normalization Score:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '41% ➔ 84% (+43%)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF16A34A),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Status: Critical Gap Successfully Resolved! Topic upgraded to Strong/Mastered.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '🔄 Adaptive Engine Update: Week 2 plan automatically redirected to Operating Systems (Semaphores) & Tree Graphs.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _reassessed = true;
              });
            },
            child: const Text('Apply Adaptive Plan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study & Career Roadmap'),
        actions: [
          IconButton(
            tooltip: 'Skill-Gap Analyzer',
            onPressed: () => context.push('/ai/skill-gap'),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'AI Copilot',
            onPressed: () => context.push('/ai/copilot'),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: '7-Day Study Plan'),
            Tab(text: 'SDE Career Roadmap'),
          ],
        ),
      ),
      body: ResponsiveLayout(
        maxWidthDesktop: 960,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Student Context Card
            _buildProfileBanner(theme, primaryColor),

            // Adaptive Flow Stepper Indicator
            _buildFlowStepper(theme, primaryColor),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStudyPlanTab(theme, primaryColor),
                  _buildCareerRoadmapTab(theme, primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBanner(ThemeData theme, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(color: primaryColor.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_rounded,
              size: 20,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AiMockData.studentBranch} • ${AiMockData.studentSemester}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  'Goal: ${AiMockData.studentGoal} • Study Time: ${AiMockData.dailyStudyTime}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStepper(ThemeData theme, Color primaryColor) {
    final steps = [
      'Assessment',
      'Skill Gap',
      'Resources',
      'Study Plan',
      'Reassessment',
      'Adaptive Plan',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Personalization Loop',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Text(
                _reassessed ? 'Loop: Adaptive Stage 2' : 'Loop: Stage 4 (Active Plan)',
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(steps.length, (idx) {
                final isPassed = _reassessed ? idx <= 5 : idx <= 3;
                final isCurrent = _reassessed ? idx == 5 : idx == 3;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? primaryColor
                            : (isPassed
                                ? primaryColor.withValues(alpha: 0.15)
                                : theme.dividerColor.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        steps[idx],
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent
                              ? Colors.white
                              : (isPassed
                                  ? primaryColor
                                  : theme.textTheme.bodySmall?.color),
                        ),
                      ),
                    ),
                    if (idx < steps.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 11,
                          color: primaryColor.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyPlanTab(ThemeData theme, Color primaryColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '7-Day Plan Completion',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  Text(
                    '${(_completionRatio * 100).toInt()}% Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _completionRatio,
                  minHeight: 7,
                  backgroundColor: primaryColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(primaryColor),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _reassessed
                        ? '✨ Adaptive update: DBMS Normalization master status achieved!'
                        : '🎯 Focus Topic: Normalization in DBMS (Priority: High)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _reassessed
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _simulateReassessment,
                    child: const Text(
                      'Reassess →',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Day by Day Items
        ..._studyPlan.map((day) => _buildDayTile(day, theme, primaryColor)),
        const SizedBox(height: 20),

        // Bottom Simulated Reassessment Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _reassessed
                ? const Color(0xFF16A34A)
                : primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _simulateReassessment,
          icon: Icon(
            _reassessed ? Icons.check_circle_rounded : Icons.quiz_rounded,
            size: 20,
          ),
          label: Text(
            _reassessed
                ? 'Reassessment Completed (84% Score) — Recalculate'
                : 'Take AI Reassessment Quiz (Closes Adaptive Loop)',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDayTile(
    StudyPlanDay day,
    ThemeData theme,
    Color primaryColor,
  ) {
    final isDone = day.tasks.every((t) => t.isDone);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: day.dayNumber <= 2,
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                : primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            'D${day.dayNumber}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: isDone ? const Color(0xFF16A34A) : primaryColor,
            ),
          ),
        ),
        title: Text(
          day.dayTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        subtitle: Text(
          day.focusTheme,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: day.tasks.map((task) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: task.isDone,
                        activeColor: primaryColor,
                        onChanged: (val) {
                          setState(() {
                            task.isDone = val ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                decoration: task.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    task.tag,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.timer_outlined,
                                  size: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${task.durationMinutes} mins',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (task.resource != null)
                        IconButton(
                          tooltip: 'Open ${task.resource!.title}',
                          icon: Icon(
                            task.resource!.icon,
                            size: 18,
                            color: task.resource!.color,
                          ),
                          onPressed: () {
                            context.push(task.resource!.targetRoute);
                          },
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareerRoadmapTab(ThemeData theme, Color primaryColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // SDE Track Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Software Development Engineer (SDE)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tailored for Tier-1 & Tier-2 Campus Placements',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Academix AI synchronizes your semester coursework (DBMS, OS, CN) directly with coding interviews and resume preparation.',
                style: TextStyle(fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Milestones
        ...AiMockData.careerRoadmap.map(
          (milestone) => _buildCareerMilestoneCard(milestone, theme, primaryColor),
        ),
        const SizedBox(height: 20),

        // Academix placement integrations row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/placement/dsa'),
                icon: const Icon(Icons.code_rounded, size: 16),
                label: const Text('DSA Practice'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/resume/templates'),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Resume Builder'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCareerMilestoneCard(
    CareerMilestone milestone,
    ThemeData theme,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: milestone.isTargetForSemester
              ? primaryColor.withValues(alpha: 0.35)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      milestone.phase,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    milestone.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              Text(
                '${milestone.progressPercent}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: milestone.progressPercent / 100,
              minHeight: 5,
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            milestone.description,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: milestone.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
