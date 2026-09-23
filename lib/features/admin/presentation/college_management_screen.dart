import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../../../shared/models/college_model.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/admin_providers.dart';

class CollegeManagementScreen extends ConsumerStatefulWidget {
  const CollegeManagementScreen({super.key});

  @override
  ConsumerState<CollegeManagementScreen> createState() =>
      _CollegeManagementScreenState();
}

class _CollegeManagementScreenState
    extends ConsumerState<CollegeManagementScreen> {
  static const int _collegesPageSize = 25;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailDomainController = TextEditingController();

  final List<CollegeModel> _colleges = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastCollegeDocument;
  bool _hasMoreColleges = true;
  bool _isLoadingColleges = false;
  bool _isLoadingMoreColleges = false;
  String? _collegeLoadError;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadColleges(reset: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _emailDomainController.dispose();
    super.dispose();
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
              title: const Text('College Management'),
            ),
            body: const Center(child: Text('Only admins can manage colleges.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/admin'),
            title: const Text('College Management'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Add New College',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'College Name',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter college name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailDomainController,
                      decoration: const InputDecoration(
                        labelText: 'Email Domain (optional)',
                        hintText: 'example.edu',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _addCollege(profile.uid),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: Text(_isSaving ? 'Adding...' : 'Add College'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'All Colleges',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildCollegesSection(adminUid: profile.uid),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/admin'),
          title: const Text('College Management'),
        ),
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }

  Future<void> _addCollege(String adminUid) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .addCollege(
            _nameController.text,
            _stateController.text,
            _cityController.text,
            _emailDomainController.text,
            adminUid: adminUid,
          );

      _nameController.clear();
      _stateController.clear();
      _cityController.clear();
      _emailDomainController.clear();
      await _loadColleges(reset: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('College added successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add college: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showEditCollegeDialog({
    required String adminUid,
    required CollegeModel college,
  }) async {
    final nameController = TextEditingController(text: college.name);
    final stateController = TextEditingController(text: college.state);
    final cityController = TextEditingController(text: college.city);
    final domainController = TextEditingController(text: college.emailDomain);
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit College'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'College Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'College name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: stateController,
                  decoration: const InputDecoration(labelText: 'State'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: domainController,
                  decoration: const InputDecoration(labelText: 'Email Domain'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) {
      nameController.dispose();
      stateController.dispose();
      cityController.dispose();
      domainController.dispose();
      return;
    }

    try {
      await ref
          .read(adminRepositoryProvider)
          .updateCollege(
            collegeId: college.collegeId,
            name: nameController.text,
            state: stateController.text,
            city: cityController.text,
            emailDomain: domainController.text,
            adminUid: adminUid,
          );

      await _loadColleges(reset: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('College updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update college: $error')),
      );
    } finally {
      nameController.dispose();
      stateController.dispose();
      cityController.dispose();
      domainController.dispose();
    }
  }

  Future<void> _deleteCollege({
    required String adminUid,
    required CollegeModel college,
  }) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete College'),
        content: Text(
          'Delete ${college.name}? This action is blocked if users or content are linked to this college.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete != true) {
      return;
    }

    try {
      await ref
          .read(adminRepositoryProvider)
          .deleteCollege(college.collegeId, adminUid: adminUid);
      await _loadColleges(reset: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('College deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete college: $error')),
      );
    }
  }

  Future<void> _loadColleges({required bool reset}) async {
    if (!reset && (!_hasMoreColleges || _isLoadingMoreColleges)) {
      return;
    }

    setState(() {
      if (reset) {
        _isLoadingColleges = true;
        _hasMoreColleges = true;
        _lastCollegeDocument = null;
      } else {
        _isLoadingMoreColleges = true;
      }
      _collegeLoadError = null;
    });

    try {
      final page = await ref
          .read(adminRepositoryProvider)
          .fetchCollegesPage(
            pageSize: _collegesPageSize,
            startAfter: reset ? null : _lastCollegeDocument,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastCollegeDocument = page.lastDocument;
        _hasMoreColleges = page.hasMore;
        if (reset) {
          _colleges
            ..clear()
            ..addAll(page.colleges);
        } else {
          final existingIds = _colleges.map((item) => item.collegeId).toSet();
          for (final college in page.colleges) {
            if (existingIds.add(college.collegeId)) {
              _colleges.add(college);
            }
          }
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _collegeLoadError = 'Failed to load colleges: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingColleges = false;
          _isLoadingMoreColleges = false;
        });
      }
    }
  }

  Widget _buildCollegesSection({required String adminUid}) {
    if (_isLoadingColleges && _colleges.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LoadingWidget(message: 'Loading colleges...'),
      );
    }

    if (_collegeLoadError != null && _colleges.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_collegeLoadError!),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _loadColleges(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_colleges.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text('No colleges found'),
          subtitle: Text('Add your first college above.'),
        ),
      );
    }

    return Column(
      children: [
        ..._colleges.map((college) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.school_rounded),
              title: Text(college.name),
              subtitle: Text(
                'ID: ${college.collegeId}\n'
                '${college.city.isEmpty ? '-' : college.city}, '
                '${college.state.isEmpty ? '-' : college.state}\n'
                'Domain: ${college.emailDomain.isEmpty ? '-' : college.emailDomain}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _showEditCollegeDialog(
                      adminUid: adminUid,
                      college: college,
                    );
                  } else if (value == 'delete') {
                    await _deleteCollege(adminUid: adminUid, college: college);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit College')),
                  PopupMenuItem(value: 'delete', child: Text('Delete College')),
                ],
              ),
            ),
          );
        }),
        if (_collegeLoadError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(_collegeLoadError!),
          ),
        if (_hasMoreColleges)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OutlinedButton.icon(
              onPressed: _isLoadingMoreColleges
                  ? null
                  : () => _loadColleges(reset: false),
              icon: _isLoadingMoreColleges
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                _isLoadingMoreColleges ? 'Loading...' : 'Load More Colleges',
              ),
            ),
          ),
      ],
    );
  }
}
