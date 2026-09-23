import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/services/cache_policy.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/bulletin_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/bulletin_model.dart';
import '../domain/bulletin_providers.dart';

class BulletinScreen extends ConsumerStatefulWidget {
  const BulletinScreen({super.key});

  @override
  ConsumerState<BulletinScreen> createState() => _BulletinScreenState();
}

class _BulletinScreenState extends ConsumerState<BulletinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime? _lastManualRefreshAt;
  final Set<String> _locallyDeletedBulletinIds = <String>{};

  static const List<String> _tabs = <String>[
    'all',
    'notice',
    'event',
    'deadline',
    'placement',
    'holiday',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
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
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/login');
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final streamParams = (
          collegeId: user.collegeId,
          semester: user.semester,
          course: user.course,
          role: user.role,
        );

        final bulletinsAsync = ref.watch(bulletinStreamProvider(streamParams));

        final selectedCategory = _tabs[_tabController.index];
        final canPost =
            user.role.trim().toLowerCase() == 'teacher' ||
            user.role.trim().toLowerCase() == 'admin';

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: const Text('Bulletin Board'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Notices'),
                Tab(text: 'Events'),
                Tab(text: 'Deadlines'),
                Tab(text: 'Placements'),
                Tab(text: 'Holidays'),
              ],
            ),
          ),
          body: ResponsiveLayout(
            maxWidthDesktop: 960,
            padding: EdgeInsets.zero,
            child: bulletinsAsync.when(
            data: (allItems) {
              final visibleItems = allItems
                  .where(
                    (item) =>
                        !_locallyDeletedBulletinIds.contains(item.bulletinId),
                  )
                  .toList();
              final filtered = _filterByCategory(
                visibleItems,
                selectedCategory,
              );
              if (filtered.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => _refresh(streamParams),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      const EmptyState(
                        title: 'No bulletins yet',
                        subtitle: 'You will see notices and events here.',
                        icon: Icons.campaign_outlined,
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => _refresh(streamParams),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final item = filtered[index];
                    return BulletinCard(
                      bulletin: item,
                      currentUid: user.uid,
                      onTap: () async {
                        final result = await context.push(
                          '/bulletin/${item.bulletinId}',
                          extra: item,
                        );

                        if (!mounted) {
                          return;
                        }

                        if (result is String && result.trim().isNotEmpty) {
                          setState(() {
                            _locallyDeletedBulletinIds.add(result.trim());
                          });
                          await _refresh(streamParams, force: true);
                        }
                      },
                    );
                  },
                ),
              );
            },
            loading: () => ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => const BulletinCardSkeleton(),
            ),
            error: (error, _) => EmptyState(
              title: 'Unable to load bulletins',
              subtitle: '$error',
            ),
          ),
        ),
          floatingActionButton: canPost
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final result = await context.push('/bulletin/post');
                    if (result == true) {
                      await _refresh(streamParams, force: true);
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Post'),
                )
              : null,
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Bulletin Board')),
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  List<BulletinModel> _filterByCategory(
    List<BulletinModel> items,
    String category,
  ) {
    if (category == 'all') {
      return items;
    }
    return items.where((item) => item.category == category).toList();
  }

  Future<void> _refresh(
    ({String collegeId, int? semester, String? course, String? role}) streamParams, {
    bool force = false,
  }) async {
    if (!force) {
      final now = DateTime.now();
      final last = _lastManualRefreshAt;
      if (last != null &&
          now.difference(last) < CachePolicy.manualRefreshMinInterval) {
        return;
      }
      _lastManualRefreshAt = now;
    }

    ref.invalidate(bulletinStreamProvider(streamParams));
    await Future<void>.delayed(const Duration(milliseconds: 240));
  }
}
