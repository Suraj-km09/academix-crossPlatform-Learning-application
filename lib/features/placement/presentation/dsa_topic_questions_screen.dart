import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/placement_providers.dart';
import '../domain/placement_models.dart';
import '../../../shared/widgets/responsive_layout.dart';

class DsaTopicQuestionsScreen extends ConsumerWidget {
  final String topicId;
  final String topicName;

  const DsaTopicQuestionsScreen({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(dsaQuestionsByTopicProvider(topicId));
    final completed = ref.watch(completedItemsProvider).valueOrNull ?? [];
    final bookmarks = ref.watch(placementBookmarksProvider).valueOrNull ?? [];
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(topicName),
      ),
      body: questionsAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(child: Text('No questions added yet.'));
          }

          // Group by difficulty
          final easy = questions.where((q) => q.difficulty.toLowerCase() == 'easy').toList();
          final medium = questions.where((q) => q.difficulty.toLowerCase() == 'medium').toList();
          final hard = questions.where((q) => q.difficulty.toLowerCase() == 'hard').toList();

          return ResponsiveLayout(
            padding: EdgeInsets.zero,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (easy.isNotEmpty) ...[
                  _buildDifficultyHeader(context, 'Easy', Colors.green),
                  ...easy.map((q) => _QuestionTile(
                    question: q,
                    isCompleted: completed.contains(q.id),
                    isBookmarked: bookmarks.contains(q.id),
                    onToggleComplete: () => user != null ? ref.read(placementRepositoryProvider).toggleCompletion(user.uid, q.id) : null,
                    onToggleBookmark: () => user != null ? ref.read(placementRepositoryProvider).toggleBookmark(user.uid, q.id) : null,
                  )),
                  const SizedBox(height: 20),
                ],
                if (medium.isNotEmpty) ...[
                  _buildDifficultyHeader(context, 'Medium', Colors.orange),
                  ...medium.map((q) => _QuestionTile(
                    question: q,
                    isCompleted: completed.contains(q.id),
                    isBookmarked: bookmarks.contains(q.id),
                    onToggleComplete: () => user != null ? ref.read(placementRepositoryProvider).toggleCompletion(user.uid, q.id) : null,
                    onToggleBookmark: () => user != null ? ref.read(placementRepositoryProvider).toggleBookmark(user.uid, q.id) : null,
                  )),
                  const SizedBox(height: 20),
                ],
                if (hard.isNotEmpty) ...[
                  _buildDifficultyHeader(context, 'Hard', Colors.red),
                  ...hard.map((q) => _QuestionTile(
                    question: q,
                    isCompleted: completed.contains(q.id),
                    isBookmarked: bookmarks.contains(q.id),
                    onToggleComplete: () => user != null ? ref.read(placementRepositoryProvider).toggleCompletion(user.uid, q.id) : null,
                    onToggleBookmark: () => user != null ? ref.read(placementRepositoryProvider).toggleBookmark(user.uid, q.id) : null,
                  )),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDifficultyHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final DsaQuestion question;
  final bool isCompleted;
  final bool isBookmarked;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onToggleBookmark;

  const _QuestionTile({
    required this.question,
    required this.isCompleted,
    required this.isBookmarked,
    this.onToggleComplete,
    this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: isCompleted,
          onChanged: (_) => onToggleComplete?.call(),
        ),
        title: Text(
          question.title,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(question.platform),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 20,
                color: isBookmarked ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: onToggleBookmark,
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              onPressed: () => _launchURL(question.link),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
