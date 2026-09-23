import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/domain/auth_providers.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/placement_providers.dart';
import '../domain/placement_models.dart';
import '../domain/recently_viewed_provider.dart';
import '../../../shared/widgets/responsive_layout.dart';

class DsaQuestionsScreen extends ConsumerWidget {
  const DsaQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(dsaTopicsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSA Practice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => _showProgress(context, ref),
          ),
        ],
      ),
      body: topicsAsync.when(
        data: (topics) => ResponsiveLayout(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, 'DSA Sheets'),
              const SizedBox(height: 12),
              _buildSheetsRow(context, ref),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Topics'),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topics.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  return _TopicTile(topic: topic);
                },
              ),
            ],
          ),
        ),
        loading: () => ResponsiveLayout(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, 'DSA Sheets'),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Topics'),
              const SizedBox(height: 12),
              ...List.generate(6, (index) => const TopicTileSkeleton()),
            ],
          ),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSheetsRow(BuildContext context, WidgetRef ref) {
    final sheetsAsync = ref.watch(dsaSheetsProvider);

    return sheetsAsync.when(
      data: (sheets) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: sheets
              .map(
                (sheet) => Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.description_outlined, size: 18),
                    label: Text(sheet.title),
                    onPressed: () {
                      ref
                          .read(recentlyViewedProvider.notifier)
                          .addItem(
                            RecentItem(
                              id: sheet.id,
                              title: sheet.title,
                              type: 'sheet',
                              route: sheet.link,
                            ),
                          );
                      _launchURL(sheet.link);
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (err, _) => const Text('Failed to load sheets'),
    );
  }

  void _showProgress(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _DsaProgressSheet(),
    );
  }
}

class _TopicTile extends ConsumerWidget {
  final DsaTopic topic;
  const _TopicTile({required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(dsaQuestionsByTopicProvider(topic.id));
    final completed = ref.watch(completedItemsProvider).valueOrNull ?? [];

    return questionsAsync.when(
      data: (questions) {
        final completedCount = questions
            .where((q) => completed.contains(q.id))
            .length;
        final progress = questions.isEmpty
            ? 0.0
            : completedCount / questions.length;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: ExpansionTile(
            leading: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            title: Text(
              topic.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('$completedCount / ${questions.length} Completed'),
            children: [_QuestionList(questions: questions)],
          ),
        );
      },
      loading: () => const TopicTileSkeleton(),
      error: (err, _) => const ListTile(title: Text('Error loading questions')),
    );
  }
}

class _QuestionList extends ConsumerWidget {
  final List<DsaQuestion> questions;
  const _QuestionList({required this.questions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(completedItemsProvider).valueOrNull ?? [];
    final bookmarks = ref.watch(placementBookmarksProvider).valueOrNull ?? [];
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (questions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No questions added to this topic yet.'),
      );
    }

    final sortedQuestions = [...questions];
    final difficultyMap = {'easy': 0, 'medium': 1, 'hard': 2};
    sortedQuestions.sort(
      (a, b) => difficultyMap[a.difficulty.toLowerCase()]!.compareTo(
        difficultyMap[b.difficulty.toLowerCase()]!,
      ),
    );

    return Column(
      children: sortedQuestions.map((q) {
        final isCompleted = completed.contains(q.id);
        final isBookmarked = bookmarks.contains(q.id);

        Color diffColor = Colors.green;
        if (q.difficulty.toLowerCase() == 'medium') diffColor = Colors.orange;
        if (q.difficulty.toLowerCase() == 'hard') diffColor = Colors.red;

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: Checkbox(
            visualDensity: VisualDensity.compact,
            value: isCompleted,
            onChanged: user == null
                ? null
                : (v) => ref
                      .read(placementRepositoryProvider)
                      .toggleCompletion(user.uid, q.id),
          ),
          title: Text(
            q.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: diffColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  q.difficulty,
                  style: TextStyle(
                    color: diffColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  q.platform,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: isBookmarked
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: user == null
                    ? null
                    : () => ref
                          .read(placementRepositoryProvider)
                          .toggleBookmark(user.uid, q.id),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                onPressed: () {
                  ref
                      .read(recentlyViewedProvider.notifier)
                      .addItem(
                        RecentItem(
                          id: q.id,
                          title: q.title,
                          type: 'question',
                          route: q.link,
                        ),
                      );
                  _launchURL(q.link);
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DsaProgressSheet extends ConsumerWidget {
  const _DsaProgressSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(completedItemsProvider).valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your DSA Progress',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
            ),
            title: const Text('Total Questions Solved'),
            trailing: Text(
              '${completed.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Keep grinding! Consistency is key to cracking placements. 🔥',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _launchURL(String urlString) async {
  final Uri url = Uri.parse(urlString);
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}
