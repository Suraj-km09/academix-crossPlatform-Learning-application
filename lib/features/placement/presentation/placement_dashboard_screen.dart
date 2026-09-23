import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/domain/auth_providers.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/placement_providers.dart';
import '../domain/placement_models.dart';
import '../domain/recently_viewed_provider.dart';
import '../../../shared/widgets/responsive_layout.dart';

class PlacementDashboardScreen extends ConsumerWidget {
  const PlacementDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(placementSubjectsProvider);
    final userAsync = ref.watch(currentUserStreamProvider);
    final recentlyViewed = ref.watch(recentlyViewedProvider);
    final completedItems = ref.watch(completedItemsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement Prep'),
        actions: [
          userAsync.when(
            data: (user) => user?.role == 'admin'
                ? IconButton(
                    icon: const Icon(Icons.cloud_upload_rounded),
                    tooltip: 'Admin Upload',
                    onPressed: () => context.push('/admin/placement-upload'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (err, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(placementSubjectsProvider.future),
        child: ResponsiveLayout(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProgressCard(context, completedItems.length),
              const SizedBox(height: 24),

              if (recentlyViewed.isNotEmpty) ...[
                _buildSectionHeader(context, '🔥 Recently Viewed'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentlyViewed.length,
                    itemBuilder: (context, index) {
                      final item = recentlyViewed[index];
                      return _RecentItemCard(item: item);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              _buildSectionHeader(context, 'Core Practice'),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCoreCard(
                            context,
                            title: 'DSA Practice',
                            subtitle: 'Data Structures & Algorithms',
                            icon: Icons.code_rounded,
                            color: Colors.blue,
                            onTap: () => context.push('/placement/dsa'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCoreCard(
                            context,
                            title: 'Aptitude',
                            subtitle: 'Logic & Math',
                            icon: Icons.functions_rounded,
                            color: Colors.orange,
                            onTap: () => context.push(
                              '/placement/subject/aptitude',
                              extra: 'Aptitude',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCoreCard(
                            context,
                            title: 'Verbal',
                            subtitle: 'Grammar & English',
                            icon: Icons.translate_rounded,
                            color: Colors.green,
                            onTap: () => context.push(
                              '/placement/subject/verbal',
                              extra: 'Verbal',
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildCoreCard(
                        context,
                        title: 'DSA Practice',
                        subtitle: 'Data Structures & Algorithms',
                        icon: Icons.code_rounded,
                        color: Colors.blue,
                        onTap: () => context.push('/placement/dsa'),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCoreCard(
                              context,
                              title: 'Aptitude',
                              subtitle: 'Logic & Math',
                              icon: Icons.functions_rounded,
                              color: Colors.orange,
                              onTap: () => context.push(
                                '/placement/subject/aptitude',
                                extra: 'Aptitude',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCoreCard(
                              context,
                              title: 'Verbal',
                              subtitle: 'Grammar & English',
                              icon: Icons.translate_rounded,
                              color: Colors.green,
                              onTap: () => context.push(
                                '/placement/subject/verbal',
                                extra: 'Verbal',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'CS Subjects'),
              const SizedBox(height: 12),
              subjectsAsync.when(
                data: (subjects) {
                  final displaySubjects = subjects.isNotEmpty
                      ? subjects
                      : _getInitialSubjects();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final crossAxisCount = w >= 800 ? 4 : (w >= 600 ? 3 : 2);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: displaySubjects.length,
                        itemBuilder: (context, index) {
                          final subject = displaySubjects[index];
                          return _SubjectCard(subject: subject);
                        },
                      );
                    },
                  );
                },
                loading: () => LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final crossAxisCount = w >= 800 ? 4 : (w >= 600 ? 3 : 2);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) => const SubjectCardSkeleton(),
                    );
                  },
                ),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, int totalSolved) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$totalSolved',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questions',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    'Solved',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.amber,
                size: 48,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Consistency is the key to success. 🔥',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  List<PlacementSubject> _getInitialSubjects() {
    return [
      PlacementSubject(id: 'ds', name: 'Data Structures', order: 1),
      PlacementSubject(id: 'algo', name: 'Algorithms', order: 2),
      PlacementSubject(id: 'dbms', name: 'DBMS', order: 3),
      PlacementSubject(id: 'os', name: 'Operating System', order: 4),
      PlacementSubject(id: 'cn', name: 'Computer Networks', order: 5),
    ];
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

  Widget _buildCoreCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    Widget card = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      color: color.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: card);
    }
    return card;
  }
}

class _SubjectCard extends StatelessWidget {
  final PlacementSubject subject;

  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(
          '/placement/subject/${subject.id}',
          extra: subject.name,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.book_outlined, size: 32),
              const SizedBox(height: 8),
              Text(
                subject.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentItemCard extends StatelessWidget {
  final RecentItem item;
  const _RecentItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _launchURL(item.route),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.type == 'question'
                      ? Icons.code_rounded
                      : Icons.description_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
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
