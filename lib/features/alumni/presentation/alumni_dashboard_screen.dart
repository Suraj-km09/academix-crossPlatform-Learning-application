import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/alumni_qa_model.dart';
import '../data/referral_request_model.dart';
import '../domain/alumni_providers.dart';

class AlumniDashboardScreen extends ConsumerWidget {
  const AlumniDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to access alumni dashboard.',
            ),
          );
        }

        if (user.role != 'alumni') {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/alumni'),
              title: const Text('Alumni Dashboard'),
            ),
            body: const EmptyState(
              title: 'Alumni only',
              subtitle: 'This dashboard is available for alumni accounts only.',
            ),
          );
        }

        final pendingReferralsAsync = ref.watch(
          alumniPendingReferralsProvider(user.uid),
        );
        final unansweredAsync = ref.watch(
          alumniUnansweredQuestionsProvider(user.uid),
        );

        final contributionScore =
            (user.referralsGiven * 2) +
            user.questionsAnswered +
            user.avgRating.round();

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/alumni'),
            title: const Text('Alumni Dashboard'),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(alumniPendingReferralsProvider(user.uid));
              ref.invalidate(alumniUnansweredQuestionsProvider(user.uid));
              ref.invalidate(currentUserProvider);
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatsCard(
                  referralsGiven: user.referralsGiven,
                  avgRating: user.avgRating,
                  contributionScore: contributionScore,
                ),
                const SizedBox(height: 12),
                Text(
                  'Pending Referral Requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                pendingReferralsAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No pending referral requests.'),
                        ),
                      );
                    }

                    return Column(
                      children: items
                          .map((item) => _PendingReferralTile(item: item))
                          .toList(),
                    );
                  },
                  loading: () => Column(
                    children: List.generate(2, (index) => const ReferralCardSkeleton()),
                  ),
                  error: (error, stackTrace) => Text('$error'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Unanswered Questions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                unansweredAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No unanswered questions.'),
                        ),
                      );
                    }

                    return Column(
                      children: items
                          .map((item) => _UnansweredQuestionTile(item: item))
                          .toList(),
                    );
                  },
                  loading: () => Column(
                    children: List.generate(2, (index) => const QuestionTileSkeleton()),
                  ),
                  error: (error, stackTrace) => Text('$error'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/alumni'),
          title: const Text('Alumni Dashboard'),
        ),
        body: const AlumniDashboardSkeleton(),
      ),
      error: (error, stackTrace) => Scaffold(
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.referralsGiven,
    required this.avgRating,
    required this.contributionScore,
  });

  final int referralsGiven;
  final double avgRating;
  final int contributionScore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _Stat(label: 'Referrals', value: '$referralsGiven'),
            ),
            Expanded(
              child: _Stat(
                label: 'Avg Rating',
                value: avgRating.toStringAsFixed(1),
              ),
            ),
            Expanded(
              child: _Stat(label: 'Contribution', value: '$contributionScore'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PendingReferralTile extends ConsumerStatefulWidget {
  const _PendingReferralTile({required this.item});

  final ReferralRequestModel item;

  @override
  ConsumerState<_PendingReferralTile> createState() =>
      _PendingReferralTileState();
}

class _PendingReferralTileState extends ConsumerState<_PendingReferralTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.targetCompany} • ${item.targetRole}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text('From: ${item.studentName}'),
            const SizedBox(height: 4),
            Text(item.message),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Accept',
                    isLoading: _loading,
                    onPressed: _loading
                        ? null
                        : () => _acceptReferral(item.requestId, item.alumniUid),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    isLoading: _loading,
                    backgroundColor: Theme.of(context).colorScheme.error,
                    onPressed: _loading
                        ? null
                        : () => _rejectReferral(item.requestId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptReferral(String requestId, String alumniUid) async {
    setState(() => _loading = true);
    try {
      final repository = ref.read(alumniRepositoryProvider);
      await repository.acceptReferral(requestId, alumniUid);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Referral accepted')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to accept: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _rejectReferral(String requestId) async {
    final reasonController = TextEditingController();
    String? reason;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Referral'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason for rejection'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              reason = reasonController.text.trim();
              Navigator.of(context).pop();
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if ((reason ?? '').isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final repository = ref.read(alumniRepositoryProvider);
      await repository.rejectReferral(requestId, reason!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Referral rejected')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to reject: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class _UnansweredQuestionTile extends ConsumerStatefulWidget {
  const _UnansweredQuestionTile({required this.item});

  final AlumniQAModel item;

  @override
  ConsumerState<_UnansweredQuestionTile> createState() =>
      _UnansweredQuestionTileState();
}

class _UnansweredQuestionTileState
    extends ConsumerState<_UnansweredQuestionTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.question, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 6),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Answer',
              isLoading: _loading,
              onPressed: _loading ? null : () => _answerQuestion(item.threadId),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _answerQuestion(String threadId) async {
    final answerController = TextEditingController();
    var isPublic = true;
    String? answer;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Answer Question'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: answerController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write your answer',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: isPublic,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Make Public'),
                    onChanged: (value) =>
                        setDialogState(() => isPublic = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    answer = answerController.text.trim();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    answerController.dispose();

    if ((answer ?? '').isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final repository = ref.read(alumniRepositoryProvider);
      await repository.answerQuestion(threadId, answer!, isPublic);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Answer submitted')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to answer: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
