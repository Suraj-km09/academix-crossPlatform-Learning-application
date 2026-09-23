import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_model.dart';
import '../data/chat_model.dart';
import '../data/chat_repository.dart';
import 'chat_list_notifier.dart';
import 'chat_search_notifier.dart';
import '../data/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final userChatsProvider = StateNotifierProvider.family
    .autoDispose<ChatListNotifier, AsyncValue<List<ChatModel>>, String>((
      ref,
      uid,
    ) {
      final repository = ref.watch(chatRepositoryProvider);
      return ChatListNotifier(repo: repository, uid: uid, pageSize: 20);
    });

final chatByIdProvider = StreamProvider.family<ChatModel?, String>((
  ref,
  chatId,
) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getChatById(chatId);
});

final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, ({String chatId, int limit})>((
      ref,
      params,
    ) {
      final repository = ref.watch(chatRepositoryProvider);
      return repository.getRecentMessages(params.chatId, limit: params.limit);
    });

final collegeGroupsProvider = StreamProvider.family<List<ChatModel>, String>((
  ref,
  collegeId,
) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getCollegeGroups(collegeId);
});

final chatUserProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchUser(uid);
});

final chatUserOnlineProvider = StreamProvider.family<bool, String>((ref, uid) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchUserOnline(uid);
});

final blockedUsersProvider = StreamProvider.family<Set<String>, String>((
  ref,
  uid,
) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchBlockedUsers(uid);
});

final directUserSearchProvider = StateNotifierProvider.autoDispose
    .family<
      SearchUsersNotifier,
      AsyncValue<List<UserModel>>,
      ({String collegeId, String currentUid})
    >((ref, params) {
      final repository = ref.watch(chatRepositoryProvider);
      return SearchUsersNotifier(
        repo: repository,
        collegeId: params.collegeId,
        currentUid: params.currentUid,
      );
    });
