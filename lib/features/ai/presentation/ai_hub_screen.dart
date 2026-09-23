import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/responsive_layout.dart';

class AcademixAiHubScreen extends StatelessWidget {
  const AcademixAiHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            const Text('Academix AI'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PROTOTYPE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
      body: ResponsiveLayout(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Hackathon Demo Walkthrough Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: primaryColor.withValues(alpha: 0.08),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lightbulb_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hackathon Demo Journey',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Experience how Academix AI unifies academic doubt resolution, syllabus diagnostic gap tracking, and adaptive placement roadmaps:',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildJourneyChip('1. Student Dashboard', true, primaryColor),
                      _buildJourneyChip('2. Ask Academix', true, primaryColor),
                      _buildJourneyChip('3. Skill-Gap Analysis', true, primaryColor),
                      _buildJourneyChip('4. Weak Topic (Normalization)', true, const Color(0xFFDC2626)),
                      _buildJourneyChip('5. Study Plan & Career Roadmap', true, primaryColor),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      context.push(
                        '/ai/copilot',
                        extra: 'Explain normalization in DBMS in simple Hindi.',
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'Start Guided Demo Journey',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Feature Highlights (Multi-column on desktop)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 920;

                final card1 = _buildFeatureModuleCard(
                  context: context,
                  icon: Icons.chat_bubble_outline_rounded,
                  tag: 'FEATURE 1',
                  title: 'AI Academic Copilot',
                  subtitle:
                      'Curriculum-aware contextual assistant explaining concepts in Hindi & English, linked to university notes.',
                  bullets: [
                    'Contextual to B.Tech CSE Semester 5 syllabus',
                    'Demonstrates "Explain normalization in DBMS in simple Hindi"',
                    'Attaches recommended Academix lecture notes & PYQs',
                  ],
                  buttonLabel: 'Open AI Copilot',
                  onTap: () => context.push('/ai/copilot'),
                );

                final card2 = _buildFeatureModuleCard(
                  context: context,
                  icon: Icons.analytics_outlined,
                  tag: 'FEATURE 2',
                  title: 'AI Skill-Gap Analyzer',
                  subtitle:
                      'Diagnostic intelligence engine that analyzes quiz & exam history to isolate critical learning gaps before exams.',
                  bullets: [
                    'Topic breakdown: SQL (85%), Indexing (79%), Normalization (41% Gap)',
                    'Overall Academic Readiness score calculation (68%)',
                    'Actionable AI diagnostic recommendations',
                  ],
                  buttonLabel: 'Launch Skill-Gap Diagnostics',
                  onTap: () => context.push('/ai/skill-gap'),
                );

                final card3 = _buildFeatureModuleCard(
                  context: context,
                  icon: Icons.alt_route_rounded,
                  tag: 'FEATURE 3',
                  title: 'Study & Career Roadmap',
                  subtitle:
                      'Adaptive 7-day study planner focused on closing subject gaps while advancing Software Engineer placement preparation.',
                  bullets: [
                    'Student Context: CSE Sem 5 • Software Engineer • 2 hrs/day',
                    '7-Day priority task timeline with progress tracking',
                    'Interactive Reassessment simulation (41% ➔ 84% score upgrade)',
                  ],
                  buttonLabel: 'Explore Personalized Roadmap',
                  onTap: () => context.push('/ai/roadmap'),
                );

                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 14),
                        Expanded(child: card2),
                        const SizedBox(width: 14),
                        Expanded(child: card3),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    card1,
                    const SizedBox(height: 14),
                    card2,
                    const SizedBox(height: 14),
                    card3,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyChip(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFeatureModuleCard({
    required BuildContext context,
    required IconData icon,
    required String tag,
    required String title,
    required String subtitle,
    required List<String> bullets,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
