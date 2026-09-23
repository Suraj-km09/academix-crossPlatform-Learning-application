import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/services/ad_service.dart';
import '../../../shared/services/cache_policy.dart';
import '../../../shared/services/security_config_service.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/note_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/note_model.dart';
import '../domain/notes_providers.dart';
import 'note_detail_screen.dart';
import 'upload_note_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  static const int _recentNotesLimit = 60;
  static const int _olderNotesPageSize = 40;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  String _selectedFilter = 'all';
  String _selectedYear = 'all';
  String _selectedSemester = 'all';
  String _selectedSubject = 'all';
  String _selectedBranchFilter = 'all';

  List<NoteModel> _recentNotes = const <NoteModel>[];
  final List<NoteModel> _olderNotes = <NoteModel>[];
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _isRefreshing = false;
  String? _lastFeedToken;
  String? _activeCollegeId;
  String? _activeServerType;
  String? _activeServerUploader;
  DateTime? _lastManualRefreshAt;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBanner();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserStreamProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to access notes.',
            ),
          );
        }

        final bookmarksAsync = ref.watch(bookmarksProvider(user.uid));
        final serverType = _serverTypeFilter();
        final serverUploaderUid = _serverUploaderFilter(user.uid);
        final shouldUsePagedFeed = _selectedFilter != 'bookmarks';

        final normalizedRole = user.role.trim().toLowerCase();
        bool roleAllowedForNotes = true;
        try {
          roleAllowedForNotes = SecurityConfigService.instance(
            FirebaseFirestore.instance,
          ).isRoleResourceAllowed(normalizedRole, 'notes');
        } catch (_) {
          roleAllowedForNotes = true;
        }
        final canUpload =
            normalizedRole == 'admin' ||
            (user.canUploadNotesPyqs && roleAllowedForNotes);

        _activeCollegeId = user.collegeId;
        _activeServerType = shouldUsePagedFeed ? serverType : null;
        _activeServerUploader = shouldUsePagedFeed ? serverUploaderUid : null;

        final feedToken =
            '${user.collegeId}|${serverType ?? ''}|${serverUploaderUid ?? ''}|$shouldUsePagedFeed';
        if (_lastFeedToken != feedToken) {
          _lastFeedToken = feedToken;
          _recentNotes = const <NoteModel>[];
          _olderNotes.clear();
          _isLoadingOlder = false;
          _hasMoreOlder = true;
          _selectedYear = 'all';
          _selectedSemester = 'all';
          _selectedSubject = 'all';
          _selectedBranchFilter = 'all';
        }

        final notesAsync = shouldUsePagedFeed
            ? ref.watch(
                recentNotesStreamProvider((
                  collegeId: user.collegeId,
                  limit: _recentNotesLimit,
                  type: serverType,
                  uploadedBy: serverUploaderUid,
                  course: null,
                  branch: null,
                )),
              )
            : const AsyncValue<List<NoteModel>>.data(<NoteModel>[]);

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search notes, subject, tags...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                ),
              ),
            ),
          ),
          body: notesAsync.when(
            data: (notes) {
              _recentNotes = notes;
              final mergedNotes = _mergeNotesDescending(
                older: _olderNotes,
                recent: _recentNotes,
              );

              final bookmarkedIds = bookmarksAsync.maybeWhen(
                data: (bookmarkNotes) =>
                    bookmarkNotes.map((item) => item.noteId).toSet(),
                orElse: () => <String>{},
              );
              final bookmarkedNotes = bookmarksAsync.maybeWhen(
                data: (items) => items,
                orElse: () => const <NoteModel>[],
              );

              final visibleSource = _selectedFilter == 'bookmarks'
                  ? bookmarkedNotes
                  : mergedNotes;

              final filtered = _applyFilters(
                visibleSource,
                user.uid,
                bookmarkedIds,
                user.role,
                user.course,
                user.branch,
                user.semester,
              );
              final subjects = _buildSubjects(visibleSource);
              final years = _buildYears(visibleSource);
              final semesters = _buildSemesters(visibleSource);
              final branches = _buildBranches(visibleSource);

              return RefreshIndicator(
                onRefresh: () => _refresh(user.uid),
                child: ResponsiveLayout(
                  maxWidthDesktop: 1080,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      _filterChips(),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 720;

                          final yearField = DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: years.contains(_selectedYear)
                                ? _selectedYear
                                : 'all',
                            decoration: const InputDecoration(
                              labelText: 'Year',
                            ),
                            items: years
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item == 'all' ? 'All' : item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedYear = value);
                            },
                          );

                          final semesterField = DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: semesters.contains(_selectedSemester)
                                ? _selectedSemester
                                : 'all',
                            decoration: const InputDecoration(
                              labelText: 'Semester',
                            ),
                            items: semesters
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item == 'all' ? 'All' : item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedSemester = value);
                            },
                          );

                          final branchField = DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue:
                                branches.contains(_selectedBranchFilter)
                                    ? _selectedBranchFilter
                                    : 'all',
                            decoration: const InputDecoration(
                              labelText: 'Branch Filter',
                            ),
                            items: branches
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(
                                      b == 'all' ? 'All Branches' : b,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => setState(
                              () => _selectedBranchFilter = val ?? 'all',
                            ),
                          );

                          if (isDesktop) {
                            return Row(
                              children: [
                                Expanded(child: yearField),
                                const SizedBox(width: 10),
                                Expanded(child: semesterField),
                                const SizedBox(width: 10),
                                Expanded(child: branchField),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: yearField),
                                  const SizedBox(width: 10),
                                  Expanded(child: semesterField),
                                ],
                              ),
                              const SizedBox(height: 10),
                              branchField,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final subject = subjects[index];
                          final selected = _selectedSubject == subject;
                          return ChoiceChip(
                            label: Text(subject == 'all' ? 'All' : subject),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedSubject = subject),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemCount: subjects.length,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: EmptyState(
                          title: 'No notes found',
                          subtitle:
                              'Try changing filters or upload a new note.',
                          icon: Icons.search_off_rounded,
                        ),
                      )
                    else
                      ...filtered.map(
                        (note) => NoteCard(
                          note: note,
                          isBookmarked: bookmarkedIds.contains(note.noteId),
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NoteDetailScreen(
                                  noteId: note.noteId,
                                  initialNote: note,
                                ),
                              ),
                            );
                            if (!mounted) {
                              return;
                            }
                            if (result is String && result.trim().isNotEmpty) {
                              _removeNoteFromLocalState(result.trim());
                              await _refresh(user.uid, force: true);
                            } else if (result == true) {
                              _removeNoteFromLocalState(note.noteId);
                              await _refresh(user.uid, force: true);
                            } else {
                              await _refresh(user.uid);
                            }
                          },
                        ),
                      ),
                    if (_selectedFilter != 'bookmarks' && _isLoadingOlder)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: NoteCardSkeleton(),
                      )
                    else if (_selectedFilter != 'bookmarks' &&
                        filtered.isNotEmpty &&
                        _hasMoreOlder)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: Text(
                            'Scroll to load older notes',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
              itemBuilder: (context, index) => const NoteCardSkeleton(),
            ),
            error: (error, stackTrace) => EmptyState(
              title: 'Unable to load notes',
              subtitle: '$error',
              action: TextButton(
                onPressed: () => _refresh(user.uid),
                child: const Text('Retry'),
              ),
            ),
          ),
          floatingActionButton: canUpload
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final normRole = user.role.trim().toLowerCase();
                    final allowed =
                        normRole == 'admin' ||
                        (user.canUploadNotesPyqs &&
                            SecurityConfigService.instance(
                              FirebaseFirestore.instance,
                            ).isRoleResourceAllowed(normRole, 'notes'));
                    if (!allowed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Your notes and PYQ upload access is disabled by admin.',
                          ),
                        ),
                      );
                      return;
                    }
                    final uploaded = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => UploadNoteScreen(
                          collegeId: user.collegeId,
                          uploaderUid: user.uid,
                          uploaderName: user.name,
                          uploaderRole: user.role,
                          uploaderCourse: user.course,
                          uploaderBranch: user.branch,
                        ),
                      ),
                    );

                    if (uploaded == true && mounted) {
                      await _refresh(user.uid);
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    user.role == 'student'
                        ? 'Community Upload'
                        : 'Upload Note',
                  ),
                )
              : null,
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/home'),
          title: const Text('Notes'),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: 6,
          itemBuilder: (context, index) => const NoteCardSkeleton(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: EmptyState(
          title: 'Unable to load profile',
          subtitle: '$error',
          action: TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Go to Login'),
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    final chips = const [
      ('all', 'All'),
      ('notes', 'Notes'),
      ('pyq', 'PYQs'),
      ('faculty', 'Faculty'),
      ('sessional', 'Sessional'),
      ('put', 'PUT'),
      ('my_uploads', 'My Uploads'),
      ('bookmarks', 'Bookmarks'),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final chip = chips[index];
          return ChoiceChip(
            selected: _selectedFilter == chip.$1,
            label: Text(chip.$2),
            onSelected: (_) {
              setState(() => _selectedFilter = chip.$1);
            },
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: chips.length,
      ),
    );
  }

  List<String> _buildSubjects(List<NoteModel> notes) {
    final subjects =
        notes
            .map((note) => note.subject.trim())
            .where((subject) => subject.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return <String>['all', ...subjects];
  }

  List<String> _buildSemesters(List<NoteModel> notes) {
    final semesters =
        notes
            .map((note) => note.semester.trim())
            .where((semester) => semester.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ??
                a.compareTo(b),
          );
    return <String>['all', ...semesters];
  }

  List<String> _buildYears(List<NoteModel> notes) {
    final years =
        notes
            .map((note) => note.year.trim())
            .where((year) => year.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ??
                a.compareTo(b),
          );
    return <String>['all', ...years];
  }

  List<String> _buildBranches(List<NoteModel> notes) {
    final branches = notes
        .map((note) => note.branch.trim())
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['all', ...branches];
  }

  List<NoteModel> _applyFilters(
    List<NoteModel> notes,
    String uid,
    Set<String> bookmarkedIds,
    String userRole,
    String userCourse,
    String userBranch,
    int? userSemester,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final isStudent = userRole.trim().toLowerCase() == 'student';
    
    // Mapping 1st -> 1,2 | 2nd -> 3,4 | 3rd -> 5,6 | 4th -> 7,8
    List<int> allowedSemesters = [];
    if (isStudent && userSemester != null && userSemester > 0) {
      int userYear = ((userSemester - 1) ~/ 2) + 1;
      allowedSemesters = [(userYear * 2) - 1, userYear * 2];
    }

    return notes.where((note) {
      final normalizedUserCourse = userCourse.trim().toLowerCase();
      final normalizedNoteCourse = note.course.trim().toLowerCase();
      final normalizedNoteBranch = note.branch.trim().toLowerCase();
      final noteSection = note.section.trim().toLowerCase();

      // Course filtering (Relaxed matching)
      if (isStudent &&
          normalizedUserCourse.isNotEmpty &&
          normalizedNoteCourse.isNotEmpty) {
        if (!(normalizedNoteCourse.contains(normalizedUserCourse) ||
            normalizedUserCourse.contains(normalizedNoteCourse))) {
          final aUserCourse = _acronym(normalizedUserCourse);
          final aNoteCourse = _acronym(normalizedNoteCourse);
          if (!(aUserCourse.isNotEmpty &&
              aNoteCourse.isNotEmpty &&
              (aNoteCourse.contains(aUserCourse) ||
                  aUserCourse.contains(aNoteCourse)))) {
            return false;
          }
        }
      }

      // 3. Shared Academic Content Visibility: PYQs, PUT, sessionals visible regardless of branch
      bool isSharedContent = noteSection == 'pyq' || noteSection == 'put' || noteSection == 'sessional';

      if (isStudent && !isSharedContent) {
          // For general notes, we still might want some relevance, 
          // but the requirement says "Remove strict branch filtering"
          // "Show notes of all branches for those semesters"
          // So we skip strict branch check here.
      }

      // Optional manual branch filter
      if (_selectedBranchFilter != 'all' && normalizedNoteBranch != _selectedBranchFilter.toLowerCase()) {
        return false;
      }

      // 2. Notes Filtering: Mapping years to semesters
      if (isStudent && allowedSemesters.isNotEmpty && note.semester.isNotEmpty) {
        int? noteSem = int.tryParse(note.semester);
        if (noteSem != null) {
          if (!allowedSemesters.contains(noteSem)) {
            return false;
          }
        }
      }

      if (_selectedSemester != 'all' && note.semester != _selectedSemester) {
        return false;
      }

      if (_selectedYear != 'all' && note.year != _selectedYear) {
        return false;
      }

      if (_selectedSubject != 'all' && note.subject != _selectedSubject) {
        return false;
      }

      switch (_selectedFilter) {
        case 'notes':
          if (note.type != 'notes') {
            return false;
          }
          break;
        case 'pyq':
          if (note.type != 'pyq') {
            return false;
          }
          break;
        case 'faculty':
          if (!_hasTag(note, const ['faculty'])) {
            return false;
          }
          break;
        case 'my_uploads':
          if (note.uploadedBy != uid) {
            return false;
          }
          break;
        case 'bookmarks':
          if (!bookmarkedIds.contains(note.noteId)) {
            return false;
          }
          break;
        case 'sessional':
          if (note.section != 'sessional' &&
              !_hasTag(note, const ['sessional', 'sessionals'])) {
            return false;
          }
          break;
        case 'put':
          if (note.section != 'put' && !_hasTag(note, const ['put', 'puts'])) {
            return false;
          }
          break;
        case 'all':
        default:
          break;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = <String>[
        note.title,
        note.subject,
        note.course,
        note.branch,
        note.year,
        note.section,
        note.uploaderName,
        note.tags.join(' '),
        note.fileName,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  bool _hasTag(NoteModel note, List<String> expected) {
    final tags = note.tags.map((tag) => tag.trim().toLowerCase()).toSet();
    for (final tag in expected) {
      if (tags.contains(tag)) {
        return true;
      }
    }
    return false;
  }

  String _acronym(String raw) {
    final parts = raw
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return parts.map((p) => p[0]).join().toLowerCase();
  }

  String? _serverTypeFilter() {
    if (_selectedFilter == 'notes') {
      return 'notes';
    }
    if (_selectedFilter == 'pyq') {
      return 'pyq';
    }
    return null;
  }

  String? _serverUploaderFilter(String uid) {
    if (_selectedFilter == 'my_uploads') {
      final normalized = uid.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  List<NoteModel> _mergeNotesDescending({
    required List<NoteModel> older,
    required List<NoteModel> recent,
  }) {
    final byId = <String, NoteModel>{};
    for (final note in older) {
      byId[note.noteId] = note;
    }
    for (final note in recent) {
      byId[note.noteId] = note;
    }

    final merged = byId.values.toList();
    merged.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return merged;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    const threshold = 220.0;
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining <= threshold) {
      _loadOlderNotes();
    }
  }

  Future<void> _loadOlderNotes() async {
    if (_selectedFilter == 'bookmarks' || _isLoadingOlder || !_hasMoreOlder) {
      return;
    }

    final collegeId = _activeCollegeId;
    if (collegeId == null || collegeId.trim().isEmpty) {
      return;
    }

    final merged = _mergeNotesDescending(
      older: _olderNotes,
      recent: _recentNotes,
    );
    if (merged.isEmpty) {
      return;
    }

    setState(() => _isLoadingOlder = true);

    try {
      final older = await ref
          .read(notesRepositoryProvider)
          .getOlderNotesPage(
            collegeId,
            before: merged.last.uploadedAt,
            limit: _olderNotesPageSize,
            type: _activeServerType,
            uploadedBy: _activeServerUploader,
            course: null,
            branch: null,
          );

      if (!mounted) {
        return;
      }

      final knownIds = merged.map((item) => item.noteId).toSet();
      final uniqueOlder = older
          .where((item) => !knownIds.contains(item.noteId))
          .toList();

      setState(() {
        if (uniqueOlder.isNotEmpty) {
          _olderNotes.addAll(uniqueOlder);
        }
        _hasMoreOlder =
            uniqueOlder.isNotEmpty && older.length >= _olderNotesPageSize;
        _isLoadingOlder = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOlder = false);
      }
    }
  }

  Future<void> _refresh(String uid, {bool force = false}) async {
    if (_isRefreshing) {
      return;
    }

    if (!force) {
      final now = DateTime.now();
      final last = _lastManualRefreshAt;
      if (last != null &&
          now.difference(last) < CachePolicy.manualRefreshMinInterval) {
        return;
      }
      _lastManualRefreshAt = now;
    }

    _isRefreshing = true;

    if (mounted) {
      setState(() {
        _olderNotes.clear();
        _hasMoreOlder = true;
        _isLoadingOlder = false;
      });
    }

    if (force) {
      final collegeId = _activeCollegeId;
      if (_selectedFilter != 'bookmarks' &&
          collegeId != null &&
          collegeId.trim().isNotEmpty) {
        ref.invalidate(
          recentNotesStreamProvider((
            collegeId: collegeId,
            limit: _recentNotesLimit,
            type: _activeServerType,
            uploadedBy: _activeServerUploader,
            course: null,
            branch: null,
          )),
        );
      }
      ref.invalidate(bookmarksProvider(uid));
    } else if (_selectedFilter == 'bookmarks') {
      ref.invalidate(bookmarksProvider(uid));
    }
    _isRefreshing = false;
  }

  void _removeNoteFromLocalState(String noteId) {
    final normalizedId = noteId.trim();
    if (normalizedId.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _recentNotes = _recentNotes
          .where((item) => item.noteId != normalizedId)
          .toList();
      _olderNotes.removeWhere((item) => item.noteId == normalizedId);
    });
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
