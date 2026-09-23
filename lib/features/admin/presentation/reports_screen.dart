import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/auth_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../data/report_model.dart';
import '../domain/admin_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProvider);
    final reportsAsync = ref.watch(adminPendingReportsProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null || profile.role != 'admin') {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/admin'),
              title: const Text('Reports Queue'),
            ),
            body: const Center(child: Text('Only admins can review reports.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/admin'),
            title: const Text('Reports Queue'),
          ),
          body: reportsAsync.when(
            data: (reports) {
              if (reports.isEmpty) {
                return const Center(
                  child: Text('No pending reports right now.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return _ReportCard(report: report, adminUid: profile.uid);
                },
              );
            },
            loading: () => const LoadingWidget(message: 'Loading reports...'),
            error: (error, _) =>
                Center(child: Text('Failed to load reports: $error')),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/admin'),
          title: const Text('Reports Queue'),
        ),
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }
}

class _ReportCard extends ConsumerStatefulWidget {
  const _ReportCard({required this.report, required this.adminUid});

  final ReportModel report;
  final String adminUid;

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.report_problem_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.report.targetType.toUpperCase()} Report',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  DateFormat('dd MMM, hh:mm a').format(widget.report.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Reason: ${widget.report.reason}'),
            const SizedBox(height: 6),
            Text('Target ID: ${widget.report.targetId}'),
            const SizedBox(height: 6),
            Text('Reporter UID: ${widget.report.reporterUid}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _isProcessing ? null : () => _resolve('dismiss'),
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _resolve('remove_content'),
                  child: const Text('Remove Content'),
                ),
                OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _resolve('ban_target_user'),
                  child: const Text('Ban Target User'),
                ),
              ],
            ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(String action) async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveReport(
            widget.report.reportId,
            action,
            adminUid: widget.adminUid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report resolved using "$action" action.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve report: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
