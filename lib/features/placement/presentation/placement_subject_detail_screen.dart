import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/domain/auth_providers.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/placement_providers.dart';
import '../../../shared/widgets/responsive_layout.dart';

class PlacementSubjectDetailScreen extends ConsumerWidget {
  final String subjectId;
  final String subjectName;

  const PlacementSubjectDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: ResponsiveLayout(
        padding: EdgeInsets.zero,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildModuleTile(
              context,
              icon: Icons.auto_stories_rounded,
              title: 'Course Material',
              subtitle: 'Syllabus, Notes and PDFs',
              color: Colors.blue,
              onTap: () => context.push(
                '/placement/subject/$subjectId/materials',
                extra: subjectName,
              ),
            ),
            const SizedBox(height: 12),
            _buildModuleTile(
              context,
              icon: Icons.quiz_rounded,
              title: 'Practice MCQs',
              subtitle: 'Test your knowledge',
              color: Colors.orange,
              onTap: () => context.push(
                '/placement/subject/$subjectId/mcqs',
                extra: subjectName,
              ),
            ),
            const SizedBox(height: 12),
            _buildModuleTile(
              context,
              icon: Icons.question_answer_rounded,
              title: 'Interview Q&A PDFs',
              subtitle: 'Subject-wise interview prep',
              color: Colors.purple,
              onTap: () => context.push(
                '/placement/subject/$subjectId/interview-qs',
                extra: subjectName,
              ),
            ),
            const SizedBox(height: 12),
            _buildModuleTile(
              context,
              icon: Icons.business_center_rounded,
              title: 'Legacy Interview Questions',
              subtitle: 'Commonly asked questions (List)',
              color: Colors.green,
              onTap: () => _showInterviewQuestions(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  void _showInterviewQuestions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 800),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _InterviewQuestionsList(subjectId: subjectId),
        ),
      ),
    );
  }
}

class _InterviewQuestionsList extends ConsumerWidget {
  final String subjectId;
  const _InterviewQuestionsList({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(interviewQuestionsProvider(subjectId));
    final bookmarks = ref.watch(placementBookmarksProvider).valueOrNull ?? [];
    final user = ref.watch(currentUserStreamProvider).valueOrNull;

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Interview Questions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: questionsAsync.when(
              data: (questions) => questions.isEmpty
                  ? const Center(child: Text('No questions added yet'))
                  : ListView.builder(
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        final q = questions[index];
                        final isBookmarked = bookmarks.contains(q.id);
                        return ExpansionTile(
                          title: Text(
                            q.question,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isBookmarked
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: isBookmarked ? Colors.amber : null,
                            ),
                            onPressed: user == null
                                ? null
                                : () => ref
                                      .read(placementRepositoryProvider)
                                      .toggleBookmark(user.uid, q.id),
                          ),
                          subtitle: Wrap(
                            spacing: 4,
                            children: q.companyTags
                                .map(
                                  (t) => Chip(
                                    label: Text(
                                      t,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(q.answer),
                            ),
                          ],
                        );
                      },
                    ),
              loading: () => ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => const QuestionTileSkeleton(),
              ),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
