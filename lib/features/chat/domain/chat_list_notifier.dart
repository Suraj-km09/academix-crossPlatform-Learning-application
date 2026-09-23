import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_model.dart';
import '../data/chat_repository.dart';

class ChatListNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  ChatListNotifier({required this.repo, required this.uid, this.pageSize = 30})
    : super(const AsyncValue.loading()) {
    _init();
  }

  final ChatRepository repo;
  final String uid;
  final int pageSize;
  StreamSubscription? _subscription;

  void _init() {
    _subscription?.cancel();
    // Use real-time snapshot listener for the chat list
    _subscription = repo.getUserChats(uid).listen((chats) {
      // For the chat list, we want real-time updates when messages arrive
      // or new chats are created. snapshots() provides this.
      state = AsyncValue.data(chats);
    }, onError: (e, st) {
      state = AsyncValue.error(e, st);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    _init();
  }

  Future<void> loadMore() async {
    // Snapshots listener already provides updates for the whole collection (or limited set).
    // If the user has many hundreds of chats, we might need a more complex
    // paged-stream approach, but for most users this is sufficient and real-time.
  }
}
