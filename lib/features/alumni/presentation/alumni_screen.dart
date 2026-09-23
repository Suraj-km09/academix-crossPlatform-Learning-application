import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/ad_service.dart';
import '../../../shared/widgets/alumni_card.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/alumni_providers.dart';

class AlumniScreen extends ConsumerStatefulWidget {
  const AlumniScreen({super.key});

  @override
  ConsumerState<AlumniScreen> createState() => _AlumniScreenState();
}

class _AlumniScreenState extends ConsumerState<AlumniScreen> {
  final TextEditingController _searchController = TextEditingController();
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  String _companyFilter = '';
  String _roleFilter = '';
  int? _batchYearFilter;
  bool _openToReferOnly = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to access alumni network.',
            ),
          );
        }

        final alumniAsync = ref.watch(alumniStreamProvider(user.collegeId));

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }

            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/home'),
              title: const Text('Alumni Network'),
              actions: [
                IconButton(
                  tooltip: 'My Referrals',
                  onPressed: () => context.push('/my-referrals'),
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
                if (user.role == 'alumni')
                  IconButton(
                    tooltip: 'Alumni Dashboard',
                    onPressed: () => context.push('/alumni-dashboard'),
                    icon: const Icon(Icons.dashboard_outlined),
                  ),
              ],
            ),
            body: alumniAsync.when(
              data: (allAlumni) {
                final filtered = _applyFilters(allAlumni, user.uid);
                final batchYears = _extractBatchYears(allAlumni);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(alumniStreamProvider(user.collegeId));
                    await Future<void>.delayed(
                      const Duration(milliseconds: 250),
                    );
                  },
                  child: ResponsiveLayout(
                    maxWidthDesktop: 1050,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: ListView(
                      padding: EdgeInsets.zero,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name, company, role',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: Text(
                                _companyFilter.isEmpty
                                    ? 'Company'
                                    : 'Company: $_companyFilter',
                              ),
                              selected: _companyFilter.isNotEmpty,
                              onSelected: (_) => _setTextFilter(
                                title: 'Filter By Company',
                                initialValue: _companyFilter,
                                onApply: (value) =>
                                    setState(() => _companyFilter = value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(
                                _roleFilter.isEmpty
                                    ? 'Role'
                                    : 'Role: $_roleFilter',
                              ),
                              selected: _roleFilter.isNotEmpty,
                              onSelected: (_) => _setTextFilter(
                                title: 'Filter By Role',
                                initialValue: _roleFilter,
                                onApply: (value) =>
                                    setState(() => _roleFilter = value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 140,
                              child: DropdownButtonFormField<int?>(
                                initialValue: _batchYearFilter,
                                decoration: const InputDecoration(
                                  labelText: 'Batch Year',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('All'),
                                  ),
                                  ...batchYears.map(
                                    (year) => DropdownMenuItem<int?>(
                                      value: year,
                                      child: Text('$year'),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _batchYearFilter = value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Open to Refer'),
                              selected: _openToReferOnly,
                              onSelected: (value) =>
                                  setState(() => _openToReferOnly = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: EmptyState(
                            title: 'No alumni found',
                            subtitle:
                                'Try changing your filters or search query.',
                          ),
                        )
                      else
                        ...filtered.map(
                          (alumni) => AlumniCard(
                            alumni: alumni,
                            onTap: () =>
                                context.push('/alumni-profile/${alumni.uid}'),
                          ),
                        ),
                      if (_bannerAd != null && _bannerLoaded) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: _bannerAd!.size.height.toDouble(),
                          width: _bannerAd!.size.width.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      ],
                    ],
                  ),
                ),
              );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: 6,
                itemBuilder: (context, index) => const AlumniCardSkeleton(),
              ),
              error: (error, stackTrace) => EmptyState(
                title: 'Unable to load alumni',
                subtitle: '$error',
                action: TextButton(
                  onPressed: () =>
                      ref.invalidate(alumniStreamProvider(user.collegeId)),
                  child: const Text('Retry'),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  List<UserModel> _applyFilters(List<UserModel> alumni, String currentUid) {
    final search = _searchController.text.trim().toLowerCase();

    return alumni.where((item) {
      if (item.uid == currentUid) {
        return false;
      }

      if (_companyFilter.trim().isNotEmpty) {
        final ok =
            item.currentCompany?.toLowerCase().contains(
              _companyFilter.trim().toLowerCase(),
            ) ??
            false;
        if (!ok) {
          return false;
        }
      }

      if (_roleFilter.trim().isNotEmpty) {
        final ok =
            item.currentRole?.toLowerCase().contains(
              _roleFilter.trim().toLowerCase(),
            ) ??
            false;
        if (!ok) {
          return false;
        }
      }

      if (_batchYearFilter != null && item.batchYear != _batchYearFilter) {
        return false;
      }

      if (_openToReferOnly && !item.openToRefer) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final haystack = [
        item.name,
        item.currentCompany ?? '',
        item.currentRole ?? '',
        item.batchYear?.toString() ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(search);
    }).toList();
  }

  List<int> _extractBatchYears(List<UserModel> alumni) {
    final years =
        alumni.map((item) => item.batchYear).whereType<int>().toSet().toList()
          ..sort((a, b) => b.compareTo(a));
    return years;
  }

  Future<void> _setTextFilter({
    required String title,
    required String initialValue,
    required ValueChanged<String> onApply,
  }) async {
    final controller = TextEditingController(text: initialValue);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter value'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                onApply('');
                Navigator.of(context).pop();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onApply(controller.text.trim());
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  void _loadBanner() {
    _bannerAd = AdService.loadBannerAd(
      null,
      onLoaded: () {
        if (!mounted) {
          return;
        }
        setState(() => _bannerLoaded = true);
      },
    );
  }
}
