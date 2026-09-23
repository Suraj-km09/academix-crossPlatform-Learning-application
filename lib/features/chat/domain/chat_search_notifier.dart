import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_model.dart';
import '../data/chat_repository.dart';

class SearchUsersNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  SearchUsersNotifier({
    required this.repo,
    required this.collegeId,
    required this.currentUid,
    this.pageSize = 25,
  }) : super(const AsyncValue.data(<UserModel>[]));

  final ChatRepository repo;
  final String collegeId;
  final String currentUid;
  final int pageSize;

  Timer? _debounce;
  String _query = '';
  String? _lastName;
  bool _hasMore = true;

  void setQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await _executeSearch(q.trim());
    });
  }

  Future<void> _executeSearch(String q) async {
    _query = q;
    _lastName = null;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final results = await repo.searchUsersInCollege(
        collegeId: collegeId,
        query: _query,
        currentUid: currentUid,
        limit: pageSize,
      );
      if (results.isNotEmpty) {
        _lastName = results.last.name;
        _hasMore = results.length >= pageSize;
      } else {
        _hasMore = false;
      }
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || state is AsyncLoading) return;
    final current = state.asData?.value ?? <UserModel>[];
    try {
      final next = await repo.searchUsersInCollege(
        collegeId: collegeId,
        query: _query,
        currentUid: currentUid,
        limit: pageSize,
        startAfterName: _lastName,
      );
      if (next.isNotEmpty) {
        _lastName = next.last.name;
      }
      _hasMore = next.length >= pageSize;
      final merged = [...current, ...next];
      merged.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      state = AsyncValue.data(merged);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _executeSearch(_query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
