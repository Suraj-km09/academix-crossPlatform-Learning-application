import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/storage_image_cache_service.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/alumni_qa_model.dart';
import '../domain/alumni_providers.dart';

class AlumniProfileScreen extends ConsumerWidget {
  const AlumniProfileScreen({super.key, required this.alumniUid});

  final String alumniUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to view alumni profile.',
            ),
          );
        }

        final repository = ref.watch(alumniRepositoryProvider);
        final alumniFuture = repository.getUserById(alumniUid);

        return FutureBuilder<UserModel?>(
          future: alumniFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(
                  leading: const AppBackButton(fallbackRoute: '/alumni'),
                  title: const Text('Alumni Profile'),
                ),
                body: const AlumniProfileSkeleton(),
              );
            }

            final alumni = snapshot.data;
            if (alumni == null) {
              return Scaffold(
                appBar: AppBar(
                  leading: const AppBackButton(fallbackRoute: '/alumni'),
                  title: const Text('Alumni Profile'),
                ),
                body: const EmptyState(
                  title: 'Alumni not found',
                  subtitle: 'This profile is unavailable right now.',
                ),
              );
            }

            final publicQaAsync = ref.watch(
              publicQaProvider(currentUser.collegeId),
            );
            final completedReferralsAsync = ref.watch(
              completedReferralsBetweenProvider((
                studentUid: currentUser.uid,
                alumniUid: alumni.uid,
              )),
            );

            return Scaffold(
              appBar: AppBar(
                leading: const AppBackButton(fallbackRoute: '/alumni'),
                title: const Text('Alumni Profile'),
                actions: [
                  IconButton(
                    onPressed: () => context.push('/my-referrals'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    tooltip: 'My Referrals',
                  ),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(publicQaProvider(currentUser.collegeId));
                  ref.invalidate(
                    completedReferralsBetweenProvider((
                      studentUid: currentUser.uid,
                      alumniUid: alumni.uid,
                    )),
                  );
                  await Future<void>.delayed(const Duration(milliseconds: 250));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeaderCard(alumni: alumni),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'About',
                      child: Text(
                        (alumni.customBio ?? '').trim().isEmpty
                            ? 'No bio added yet.'
                            : alumni.customBio!.trim(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Skills',
                      child: alumni.skills.isEmpty
                          ? const Text('No skills listed')
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: alumni.skills
                                  .map(
                                    (skill) => Chip(
                                      label: Text(skill),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 12),
                    _ActionButtons(
                      onRequestReferral: () =>
                          context.push('/referral-request/${alumni.uid}'),
                      onAskQuestion: () =>
                          _askQuestion(context, ref, currentUser, alumni),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Public Q&A',
                      child: publicQaAsync.when(
                        data: (threads) {
                          final alumniThreads = threads
                              .where((thread) => thread.alumniUid == alumni.uid)
                              .toList();

                          if (alumniThreads.isEmpty) {
                            return const Text('No public answers yet.');
                          }

                          return Column(
                            children: alumniThreads
                                .map((thread) => _QaTile(thread: thread))
                                .toList(),
                          );
                        },
                        loading: () => const QuestionTileSkeleton(),
                        error: (error, stackTrace) => Text('$error'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Rate Alumni',
                      child: completedReferralsAsync.when(
                        data: (completed) {
                          if (completed.isEmpty ||
                              currentUser.uid == alumni.uid) {
                            return const Text(
                              'Rating unlocks after completing at least one referral with this alumni.',
                            );
                          }

                          return _RatingForm(
                            alumniUid: alumni.uid,
                            referralIds: completed
                                .map((item) => item.requestId)
                                .toList(),
                          );
                        },
                        loading: () => const SkeletonLoader(child: SizedBox(height: 100, width: double.infinity)),
                        error: (error, stackTrace) => Text('$error'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

  Future<void> _askQuestion(
    BuildContext context,
    WidgetRef ref,
    UserModel student,
    UserModel alumni,
  ) async {
    final controller = TextEditingController();
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask ${alumni.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Type your question here...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Submit Question',
                    isLoading: isSubmitting,
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final question = controller.text.trim();
                            if (question.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Question cannot be empty'),
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            try {
                              final repository = ref.read(
                                alumniRepositoryProvider,
                              );
                              await repository.askAlumni(
                                student.uid,
                                alumni.uid,
                                question,
                                student.collegeId,
                              );

                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Question submitted'),
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setSheetState(() => isSubmitting = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.alumni});

  final UserModel alumni;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(pathOrUrl: alumni.photoUrl, name: alumni.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alumni.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_safe(alumni.currentCompany)} • ${_safe(alumni.currentRole)}',
                      ),
                      Text('Batch ${alumni.batchYear?.toString() ?? '-'}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(context, 'Referrals ${alumni.referralsGiven}'),
                _chip(context, 'Answers ${alumni.questionsAnswered}'),
                _chip(context, 'Rating ${alumni.avgRating.toStringAsFixed(1)}'),
                if (alumni.openToRefer) _chip(context, 'Open to Refer'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < alumni.avgRating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber.shade700,
                  size: 18,
                ),
              ),
            ),
            if ((alumni.linkedinUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('LinkedIn: ${alumni.linkedinUrl!.trim()}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      ),
      child: Text(label),
    );
  }

  String _safe(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }
    return value.trim();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onRequestReferral,
    required this.onAskQuestion,
  });

  final VoidCallback onRequestReferral;
  final VoidCallback onAskQuestion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        if (compact) {
          return Column(
            children: [
              AppButton(
                label: 'Request Referral',
                onPressed: onRequestReferral,
                icon: Icons.send_rounded,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Ask a Question',
                onPressed: onAskQuestion,
                icon: Icons.question_answer_rounded,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Request Referral',
                onPressed: onRequestReferral,
                icon: Icons.send_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Ask a Question',
                onPressed: onAskQuestion,
                icon: Icons.question_answer_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QaTile extends StatelessWidget {
  const _QaTile({required this.thread});

  final AlumniQAModel thread;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q: ${thread.question}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text('A: ${thread.answer}'),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd MMM yyyy').format(thread.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RatingForm extends ConsumerStatefulWidget {
  const _RatingForm({required this.alumniUid, required this.referralIds});

  final String alumniUid;
  final List<String> referralIds;

  @override
  ConsumerState<_RatingForm> createState() => _RatingFormState();
}

class _RatingFormState extends ConsumerState<_RatingForm> {
  int _rating = 5;
  String _selectedReferralId = '';
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.referralIds.isNotEmpty) {
      _selectedReferralId = widget.referralIds.first;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedReferralId,
          decoration: const InputDecoration(labelText: 'Referral'),
          items: widget.referralIds
              .map((id) => DropdownMenuItem<String>(value: id, child: Text(id)))
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedReferralId = value);
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: List.generate(5, (index) {
            final star = index + 1;
            return ChoiceChip(
              label: Text('$star'),
              selected: _rating == star,
              onSelected: (_) => setState(() => _rating = star),
            );
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Comment',
            hintText: 'Share your experience',
          ),
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Submit Rating',
          isLoading: _submitting,
          onPressed: _submitting
              ? null
              : () async {
                  if (_selectedReferralId.trim().isEmpty) {
                    return;
                  }

                  setState(() => _submitting = true);
                  try {
                    final repository = ref.read(alumniRepositoryProvider);
                    await repository.rateAlumni(
                      currentUser.uid,
                      widget.alumniUid,
                      _selectedReferralId,
                      _rating,
                      _commentController.text.trim(),
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rating submitted')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _submitting = false);
                    }
                  }
                },
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.pathOrUrl, required this.name});

  final String? pathOrUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (pathOrUrl == null || pathOrUrl!.trim().isEmpty) {
      return CircleAvatar(radius: 32, child: Text(_initials(name)));
    }

    return FutureBuilder<String?>(
      future: _resolveDownloadUrl(pathOrUrl!),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return CircleAvatar(radius: 32, child: Text(_initials(name)));
        }
        return CircleAvatar(
          radius: 32,
          backgroundImage: CachedNetworkImageProvider(url),
        );
      },
    );
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'A';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

Future<String?> _resolveDownloadUrl(String pathOrUrl) async {
  return StorageImageCacheService.resolveDownloadUrl(pathOrUrl);
}
