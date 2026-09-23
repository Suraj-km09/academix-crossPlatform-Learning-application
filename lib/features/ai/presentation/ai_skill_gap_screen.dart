import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../domain/ai_mock_data.dart';
import 'widgets/academic_resource_card.dart';

class AiSkillGapScreen extends StatefulWidget {
  const AiSkillGapScreen({super.key});

  @override
  State<AiSkillGapScreen> createState() => _AiSkillGapScreenState();
}

class _AiSkillGapScreenState extends State<AiSkillGapScreen> {
  String _selectedSubject = 'DBMS (CS501)';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Skill-Gap Analyzer'),
        actions: [
          IconButton(
            tooltip: 'Study Roadmap',
            onPressed: () => context.push('/ai/roadmap'),
            icon: const Icon(Icons.alt_route_rounded),
          ),
          IconButton(
            tooltip: 'AI Copilot',
            onPressed: () => context.push('/ai/copilot'),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),
      body: ResponsiveLayout(
        maxWidthDesktop: 1050,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 850;
            final topics = AiMockData.dbmsTopics;

            return ListView(
              children: [
                // Student Context Banner
                _buildStudentBanner(theme, primaryColor),
                const SizedBox(height: 16),

                // Subject Selector Pills
                _buildSubjectSelector(theme, primaryColor),
                const SizedBox(height: 16),

                // Academic Readiness & Critical Gap (Side-by-side on wide screens)
                if (isWide) ...[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildReadinessCard(theme, primaryColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildCriticalGapCard(theme),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildReadinessCard(theme, primaryColor),
                  const SizedBox(height: 14),
                  _buildCriticalGapCard(theme),
                ],
                const SizedBox(height: 20),

                // Topic Performance Breakdown Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Topic-wise Diagnostics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${topics.length} Topics Evaluated',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Topic performance cards (2-column on desktop, 1-column on mobile)
                if (isWide) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: topics.map((topic) {
                      return SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: _buildTopicTile(topic, theme, primaryColor),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  ...topics.map(
                    (topic) => _buildTopicTile(topic, theme, primaryColor),
                  ),
                ],
                const SizedBox(height: 16),

                // Recommended Recovery Resources
                _buildRecommendedResources(theme, primaryColor),
                const SizedBox(height: 24),

                // Main CTA to Study Plan
                ElevatedButton.icon(
                  onPressed: () => context.push('/ai/roadmap'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.alt_route_rounded, size: 20),
                  label: const Text(
                    'Generate 7-Day Recovery Plan →',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentBanner(ThemeData theme, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryColor.withValues(alpha: 0.15),
            foregroundColor: primaryColor,
            child: const Icon(Icons.person_outline_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AiMockData.studentName} • ${AiMockData.studentSemester}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Goal: ${AiMockData.studentGoal} • ${AiMockData.dailyStudyTime}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector(ThemeData theme, Color primaryColor) {
    final subjects = ['DBMS (CS501)', 'Operating Systems', 'Computer Networks'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: subjects.map((subj) {
          final isSelected = subj == _selectedSubject;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(subj),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedSubject = subj);
              },
              selectedColor: primaryColor.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected
                    ? primaryColor
                    : theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReadinessCard(ThemeData theme, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Gauge / score circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: AiMockData.overallReadinessScore / 100,
                  strokeWidth: 8,
                  backgroundColor: primaryColor.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    '${AiMockData.overallReadinessScore}%',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Score',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Academic Readiness',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'GRADE B',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '1 Critical Learning Gap identified in Normalization. Closing this can boost your predicted grade to A (84%).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicTile(
    TopicPerformance topic,
    ThemeData theme,
    Color primaryColor,
  ) {
    final isCritical = topic.status == TopicStatus.criticalGap;
    final isWeak = topic.status == TopicStatus.moderateGap;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical
            ? const Color(0xFFDC2626).withValues(alpha: 0.05)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical
              ? const Color(0xFFDC2626).withValues(alpha: 0.4)
              : (isWeak
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                  : theme.dividerColor.withValues(alpha: 0.15)),
          width: isCritical ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isCritical)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 17,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        topic.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isCritical ? const Color(0xFFDC2626) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: topic.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  topic.statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: topic.statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${topic.scorePercentage}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: topic.statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: topic.scorePercentage / 100,
              minHeight: 6,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(topic.statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            topic.aiDiagnosticInsight,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalGapCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.psychology_alt_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'AI Diagnostic Recommendation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your test answers show repeated confusion in Candidate Key calculation during BCNF and Transitive Dependencies in 3NF. '
            'Because Normalization carries 14 marks in AKTU End-Sem and is heavily asked in SDE interviews, we have generated an expedited 7-day plan.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    context.push(
                      '/ai/copilot',
                      extra: 'Explain normalization in DBMS in simple Hindi.',
                    );
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                  ),
                  label: const Text(
                    'Ask Copilot in Hindi',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => context.push('/ai/roadmap'),
                  icon: const Icon(Icons.alt_route_rounded, size: 15),
                  label: const Text(
                    'View 7-Day Plan',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedResources(ThemeData theme, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark_added_rounded, size: 16, color: primaryColor),
            const SizedBox(width: 6),
            Text(
              'Targeted Academix Resources for Normalization',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const AcademicResourceCard(resource: AiMockData.noteNormalization),
        const AcademicResourceCard(resource: AiMockData.pyqNormalization),
        const AcademicResourceCard(resource: AiMockData.mcqNormalization),
      ],
    );
  }
}
