import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/auth_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../data/admin_log_model.dart';
import '../domain/admin_providers.dart';

class AdminLogsScreen extends ConsumerStatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  ConsumerState<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends ConsumerState<AdminLogsScreen> {
  static const int _logsPageSize = 5;

  final List<AdminLogModel> _logs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastLogDocument;
  bool _hasMoreLogs = true;
  bool _isLoadingLogs = false;
  bool _isLoadingMoreLogs = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadLogs(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null || profile.role != 'admin') {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/admin'),
              title: const Text('Admin Logs'),
            ),
            body: const Center(
              child: Text('Only admins can access admin logs.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/admin'),
            title: const Text('Admin Logs'),
          ),
          body: _buildLogsSection(),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/admin'),
          title: const Text('Admin Logs'),
        ),
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }

  Widget _buildLogsSection() {
    if (_isLoadingLogs && _logs.isEmpty) {
      return const LoadingWidget(message: 'Loading admin logs...');
    }

    if (_loadError != null && _logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_loadError!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _loadLogs(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return const Center(child: Text('No admin logs found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _logs.length + 1,
      itemBuilder: (context, index) {
        if (index == _logs.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Column(
              children: [
                if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_loadError!),
                  ),
                if (_hasMoreLogs)
                  OutlinedButton.icon(
                    onPressed: _isLoadingMoreLogs
                        ? null
                        : () => _loadLogs(reset: false),
                    icon: _isLoadingMoreLogs
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      _isLoadingMoreLogs ? 'Loading...' : 'Load More Logs',
                    ),
                  ),
              ],
            ),
          );
        }

        final log = _logs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.shield_rounded),
            title: Text(log.action),
            subtitle: Text(
              'Admin: ${log.adminUid}\n'
              'Target: ${log.targetType} • ${log.targetId}\n'
              '${DateFormat('dd MMM yyyy, hh:mm a').format(log.timestamp)}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Future<void> _loadLogs({required bool reset}) async {
    if (!reset && (!_hasMoreLogs || _isLoadingMoreLogs)) {
      return;
    }

    setState(() {
      if (reset) {
        _isLoadingLogs = true;
        _isLoadingMoreLogs = false;
        _hasMoreLogs = true;
        _lastLogDocument = null;
      } else {
        _isLoadingMoreLogs = true;
      }
      _loadError = null;
    });

    try {
      final page = await ref
          .read(adminRepositoryProvider)
          .fetchAdminLogsPage(
            pageSize: _logsPageSize,
            startAfter: reset ? null : _lastLogDocument,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastLogDocument = page.lastDocument;
        _hasMoreLogs = page.hasMore;

        if (reset) {
          _logs
            ..clear()
            ..addAll(page.logs);
        } else {
          final existingIds = _logs.map((item) => item.logId).toSet();
          for (final log in page.logs) {
            if (existingIds.add(log.logId)) {
              _logs.add(log);
            }
          }
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = 'Failed to load admin logs: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLogs = false;
          _isLoadingMoreLogs = false;
        });
      }
    }
  }
}
