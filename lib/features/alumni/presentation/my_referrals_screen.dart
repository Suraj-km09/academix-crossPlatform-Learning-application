import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/referral_request_model.dart';
import '../domain/alumni_providers.dart';

class MyReferralsScreen extends ConsumerWidget {
  const MyReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to view referrals.',
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/alumni'),
              title: const Text('My Referrals'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Sent'),
                  Tab(text: 'Received'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _SentReferralsTab(studentUid: user.uid),
                _ReceivedReferralsTab(
                  isAlumni: user.role == 'alumni',
                  alumniUid: user.uid,
                ),
              ],
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
}

class _SentReferralsTab extends ConsumerWidget {
  const _SentReferralsTab({required this.studentUid});

  final String studentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentAsync = ref.watch(studentReferralsProvider(studentUid));

    return sentAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            title: 'No referrals sent',
            subtitle:
                'Send your first referral request from an alumni profile.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: items.map((item) => _ReferralCard(item: item)).toList(),
        );
      },
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 5,
        itemBuilder: (context, index) => const ReferralCardSkeleton(),
      ),
      error: (error, stackTrace) => EmptyState(
        title: 'Unable to load sent referrals',
        subtitle: '$error',
      ),
    );
  }
}

class _ReceivedReferralsTab extends ConsumerWidget {
  const _ReceivedReferralsTab({
    required this.isAlumni,
    required this.alumniUid,
  });

  final bool isAlumni;
  final String alumniUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isAlumni) {
      return const EmptyState(
        title: 'Alumni only',
        subtitle: 'Received referrals are visible for alumni accounts.',
      );
    }

    final receivedAsync = ref.watch(alumniAllReferralsProvider(alumniUid));

    return receivedAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            title: 'No received referrals',
            subtitle: 'Requests sent to you will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: items.map((item) => _ReferralCard(item: item)).toList(),
        );
      },
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 5,
        itemBuilder: (context, index) => const ReferralCardSkeleton(),
      ),
      error: (error, stackTrace) => EmptyState(
        title: 'Unable to load received referrals',
        subtitle: '$error',
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.item});

  final ReferralRequestModel item;

  @override
  Widget build(BuildContext context) {
    final status = item.status.trim().toLowerCase();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: (status == 'accepted' && (item.chatId ?? '').trim().isNotEmpty)
            ? () => context.push('/chat/${item.chatId}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.targetCompany} • ${item.targetRole}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Text('Student: ${item.studentName}'),
              Text('Alumni: ${item.alumniName}'),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (status == 'accepted' && (item.chatId ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Tap to open referral chat',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'accepted' => (
        Colors.green.withValues(alpha: 0.12),
        Colors.green.shade800,
      ),
      'rejected' => (
        Theme.of(context).colorScheme.errorContainer,
        Theme.of(context).colorScheme.onErrorContainer,
      ),
      'completed' => (
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        Theme.of(context).colorScheme.primary,
      ),
      _ => (
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}
