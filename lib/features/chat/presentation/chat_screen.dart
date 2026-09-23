import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/services/storage_image_cache_service.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/message_bubble.dart';
import '../data/chat_model.dart';
import '../data/message_model.dart';
import '../domain/chat_providers.dart';
import 'group_settings_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId, this.initialChat});

  final String chatId;
  final ChatModel? initialChat;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const int _recentMessageLimit = 50;
  static const int _olderMessagePageSize = 40;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  MessageModel? _replyTo;
  bool _isSending = false;
  int _lastRecentMessageCount = 0;

  bool _typingState = false;
  Timer? _typingTimer;
  String? _typingUid;
  String? _typingChatId;
  String? _currentUid;
  String? _activeChatSetFor;

  List<MessageModel> _recentMessages = const <MessageModel>[];
  final List<MessageModel> _olderMessages = <MessageModel>[];
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;

  final Set<String> _readMarked = <String>{};
  final Set<String> _pendingReadMessageIds = <String>{};
  final Set<String> _primedAvatarPaths = <String>{};
  Timer? _readFlushTimer;
  String? _lastUnreadResetToken;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId == widget.chatId) {
      return;
    }

    // If chat changed, clear any previously-set activeChat marker for
    // the old chat so server-side presence does not remain stale.
    if (_currentUid != null &&
        _activeChatSetFor != null &&
        _activeChatSetFor == oldWidget.chatId) {
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .setActiveChat(uid: _currentUid!, chatId: null),
      );
      _activeChatSetFor = null;
    }

    _lastRecentMessageCount = 0;
    _recentMessages = const <MessageModel>[];
    _olderMessages.clear();
    _hasMoreOlder = true;
    _isLoadingOlder = false;
    _readMarked.clear();
    _pendingReadMessageIds.clear();
    _lastUnreadResetToken = null;
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _readFlushTimer?.cancel();
    if (_typingState && _typingUid != null && _typingChatId != null) {
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .setTyping(
              chatId: _typingChatId!,
              uid: _typingUid!,
              isTyping: false,
            ),
      );
    }
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    if (_activeChatSetFor != null && _currentUid != null) {
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .setActiveChat(uid: _currentUid!, chatId: null),
      );
      _activeChatSetFor = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserStreamProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/login');
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final chatAsync = ref.watch(chatByIdProvider(widget.chatId));
        final chat = chatAsync.asData?.value ?? widget.initialChat;

        if (chat == null) {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/chats'),
              title: const Text('Chat'),
            ),
            body: chatAsync.when(
              data: (_) => const EmptyState(
                title: 'Chat not found',
                subtitle: 'This chat may have been removed.',
              ),
              loading: () => const LoadingWidget(message: 'Opening chat...'),
              error: (error, _) =>
                  EmptyState(title: 'Unable to open chat', subtitle: '$error'),
            ),
          );
        }

        // Mark this chat as active for the current user so server-side
        // functions can decide whether to suppress push notifications.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final curUid = user.uid;
          _currentUid ??= curUid;
          if (_activeChatSetFor != widget.chatId) {
            unawaited(
              ref
                  .read(chatRepositoryProvider)
                  .setActiveChat(uid: curUid, chatId: widget.chatId),
            );
            _activeChatSetFor = widget.chatId;
          }
        });

        final otherUid = chat.participants.firstWhere(
          (uid) => uid != user.uid,
          orElse: () => '',
        );
        final isDirectLike = chat.isDirect || chat.isReferral;

        final otherUserAsync = otherUid.isEmpty
            ? const AsyncValue.data(null)
            : ref.watch(chatUserProvider(otherUid));

        final myBlockedAsync = ref.watch(blockedUsersProvider(user.uid));
        final otherBlockedAsync = otherUid.isEmpty
            ? const AsyncValue.data(<String>{})
            : ref.watch(blockedUsersProvider(otherUid));

        final iBlockedOther =
            myBlockedAsync.asData?.value.contains(otherUid) ?? false;
        final otherBlockedMe =
            otherBlockedAsync.asData?.value.contains(user.uid) ?? false;
        final blockedConversation =
            isDirectLike && (iBlockedOther || otherBlockedMe);

        // Compute online state using the user's `isOnline` flag OR whether
        // they're actively viewing this chat (`activeChatId`). This keeps the
        // UI consistent with server-side presence-aware push suppression.
        final onlineAsync = otherUid.isEmpty
            ? const AsyncValue.data(false)
            : otherUserAsync.whenData(
                (u) =>
                    u != null &&
                    (u.isOnline == true || u.activeChatId == widget.chatId),
              );

        final messagesAsync = ref.watch(
          chatMessagesProvider((
            chatId: chat.chatId,
            limit: _recentMessageLimit,
          )),
        );
        final canManageGroupAdmin = _isGroupAdmin(
          chat: chat,
          uid: user.uid,
          role: user.role,
        );
        final groupMessagingRestricted =
            chat.isGroup &&
            (chat.onlyAdminsCanMessage || chat.broadcastOnly) &&
            !canManageGroupAdmin;
        final inputDisabled = blockedConversation || groupMessagingRestricted;
        _maybeResetUnreadCount(chat: chat, uid: user.uid);

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/chats'),
            titleSpacing: 0,
            title: _ChatHeader(
              chat: chat,
              otherName: otherUserAsync.asData?.value?.name,
              onlineAsync: onlineAsync,
            ),
            actions: [
              PopupMenuButton<_ChatAction>(
                onSelected: (action) => _handleChatAction(
                  action: action,
                  chat: chat,
                  currentUid: user.uid,
                  currentRole: user.role,
                  otherUid: otherUid,
                  iBlockedOther: iBlockedOther,
                ),
                itemBuilder: (_) {
                  final items = <PopupMenuEntry<_ChatAction>>[];

                  if (chat.isGroup && canManageGroupAdmin) {
                    items.add(
                      const PopupMenuItem(
                        value: _ChatAction.groupSettings,
                        child: Text('Group Settings'),
                      ),
                    );
                  }

                  if (chat.isGroup && !canManageGroupAdmin) {
                    items.add(
                      const PopupMenuItem(
                        value: _ChatAction.leaveGroup,
                        child: Text('Leave Group'),
                      ),
                    );
                  }

                  if (isDirectLike && otherUid.isNotEmpty) {
                    items.add(
                      PopupMenuItem(
                        value: iBlockedOther
                            ? _ChatAction.unblockUser
                            : _ChatAction.blockUser,
                        child: Text(
                          iBlockedOther ? 'Unblock User' : 'Block User',
                        ),
                      ),
                    );
                  }

                  if (isDirectLike) {
                    items.add(
                      const PopupMenuItem(
                        value: _ChatAction.deleteChat,
                        child: Text('Delete Chat'),
                      ),
                    );
                  }

                  if (!chat.isGroup || canManageGroupAdmin) {
                    items.add(
                      const PopupMenuItem(
                        value: _ChatAction.clearChat,
                        child: Text('Clear Chat'),
                      ),
                    );
                  }

                  items.add(
                    PopupMenuItem(
                      value: _ChatAction.report,
                      child: Text(
                        chat.isGroup ? 'Report Group' : 'Report User',
                      ),
                    ),
                  );

                  return items;
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  data: (recentMessages) {
                    _recentMessages = recentMessages;
                    final messages = _mergeMessages(
                      older: _olderMessages,
                      recent: recentMessages,
                    );
                    _markUnreadAsRead(chat.chatId, user.uid, messages);
                    _autoScrollOnNewMessages(recentMessages.length);

                    final rows = _buildMessageRows(
                      context,
                      ref,
                      chat,
                      user.uid,
                      canManageGroupAdmin,
                      messages,
                    );

                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: rows,
                    );
                  },
                  loading: () =>
                      const LoadingWidget(message: 'Loading messages...'),
                  error: (error, _) => EmptyState(
                    title: 'Unable to load messages',
                    subtitle: '$error',
                  ),
                ),
              ),
              _TypingIndicator(chat: chat, currentUid: user.uid),
              if (chat.isGroup && (chat.pinnedMessageId ?? '').isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (chat.pinnedMessageContent ?? '').trim().isEmpty
                              ? 'Pinned message'
                              : chat.pinnedMessageContent!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (canManageGroupAdmin)
                        IconButton(
                          tooltip: 'Unpin',
                          onPressed: () async {
                            try {
                              await ref
                                  .read(chatRepositoryProvider)
                                  .unpinMessage(
                                    chatId: chat.chatId,
                                    requestedByUid: user.uid,
                                  );
                              _showSnackBar('Message unpinned');
                            } catch (error) {
                              _showSnackBar('Unable to unpin: $error');
                            }
                          },
                          icon: const Icon(Icons.close_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              if (blockedConversation)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.6),
                  ),
                  child: Text(
                    iBlockedOther
                        ? 'You blocked this user. Unblock to send messages.'
                        : 'You cannot send messages because this user blocked you.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (groupMessagingRestricted)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    'Only group admins can send messages right now.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_replyTo != null)
                _ReplyBar(
                  message: _replyTo!,
                  onCancel: () => setState(() => _replyTo = null),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Attach file',
                        onPressed: _isSending || inputDisabled
                            ? null
                            : () => _pickAndSendFile(chat, user.uid, user.name),
                        icon: const Icon(Icons.attach_file_rounded),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !inputDisabled,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                          ),
                          onChanged: (value) => _onTypingChanged(
                            chatId: chat.chatId,
                            uid: user.uid,
                            value: value,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _isSending || inputDisabled
                            ? null
                            : () => _sendText(chat, user.uid, user.name),
                        icon: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  List<Widget> _buildMessageRows(
    BuildContext context,
    WidgetRef ref,
    ChatModel chat,
    String currentUid,
    bool canManageGroup,
    List<MessageModel> messages,
  ) {
    final rows = <Widget>[];
    DateTime? previousDate;

    if (_isLoadingOlder) {
      rows.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    } else if (_hasMoreOlder && messages.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: Text(
              'Scroll up to load older messages',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    final senderAvatarByUid = <String, String?>{};
    if (chat.isGroup) {
      final uniqueSenderIds = messages
          .where((message) => message.senderId != currentUid)
          .map((message) => message.senderId)
          .toSet();

      for (final senderId in uniqueSenderIds) {
        final pathOrUrl = ref
            .watch(chatUserProvider(senderId))
            .asData
            ?.value
            ?.photoUrl;
        senderAvatarByUid[senderId] = pathOrUrl;

        final trimmed = (pathOrUrl ?? '').trim();
        if (trimmed.isNotEmpty && _primedAvatarPaths.add(trimmed)) {
          unawaited(StorageImageCacheService.resolveDownloadUrl(trimmed));
        }
      }
    }

    for (final message in messages) {
      final messageDay = DateTime(
        message.timestamp.year,
        message.timestamp.month,
        message.timestamp.day,
      );

      if (previousDate == null || messageDay != previousDate) {
        rows.add(_DateSeparator(date: message.timestamp));
        previousDate = messageDay;
      }

      final isMe = message.senderId == currentUid;
      final others = chat.participants.where((uid) => uid != currentUid);
      final isRead =
          isMe && others.every((uid) => message.readBy.contains(uid));
      final showSenderInfo = chat.isGroup && !isMe;

      final senderAvatar = showSenderInfo
          ? senderAvatarByUid[message.senderId]
          : null;

      rows.add(
        MessageBubble(
          message: message,
          isMe: isMe,
          isRead: isRead,
          showSenderInfo: showSenderInfo,
          senderAvatarUrl: senderAvatar,
          onLongPress: () => _onMessageLongPress(
            chat: chat,
            currentUid: currentUid,
            canManageGroup: canManageGroup,
            message: message,
          ),
        ),
      );
    }

    rows.add(const SizedBox(height: 8));
    return rows;
  }

  Future<void> _onMessageLongPress({
    required ChatModel chat,
    required String currentUid,
    required bool canManageGroup,
    required MessageModel message,
  }) async {
    final canDelete = message.senderId == currentUid && !message.isDeleted;
    final canModerateSender =
        message.senderId != currentUid && !message.isDeleted;
    final canPinOrUnpin = chat.isGroup && canManageGroup && !message.isDeleted;
    final pinnedThisMessage = chat.pinnedMessageId == message.messageId;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() => _replyTo = message);
                  },
                ),
              if (canDelete)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Delete',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      await ref
                          .read(chatRepositoryProvider)
                          .deleteMessage(chat.chatId, message.messageId);
                    } catch (error) {
                      _showSnackBar('Delete failed: $error');
                    }
                  },
                ),
              if (canPinOrUnpin)
                ListTile(
                  leading: Icon(
                    pinnedThisMessage
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                  ),
                  title: Text(
                    pinnedThisMessage ? 'Unpin Message' : 'Pin Message',
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      if (pinnedThisMessage) {
                        await ref
                            .read(chatRepositoryProvider)
                            .unpinMessage(
                              chatId: chat.chatId,
                              requestedByUid: currentUid,
                            );
                        _showSnackBar('Message unpinned');
                      } else {
                        await ref
                            .read(chatRepositoryProvider)
                            .pinMessage(
                              chatId: chat.chatId,
                              requestedByUid: currentUid,
                              messageId: message.messageId,
                            );
                        _showSnackBar('Message pinned');
                      }
                    } catch (error) {
                      _showSnackBar('Unable to update pin: $error');
                    }
                  },
                ),
              if (canModerateSender)
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: const Text('Block User'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _blockUser(
                      currentUid: currentUid,
                      targetUid: message.senderId,
                    );
                  },
                ),
              if (canModerateSender)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report User'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _reportSpecificMessage(
                      chat: chat,
                      reporterUid: currentUid,
                      targetUid: message.senderId,
                      messageId: message.messageId,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendText(ChatModel chat, String uid, String senderName) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      return;
    }

    setState(() => _isSending = true);

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            chat.chatId,
            uid,
            senderName,
            content,
            'text',
            replyTo: _replyTo?.messageId,
            replyToContent: _replyTo?.content,
          );

      _messageController.clear();
      setState(() => _replyTo = null);
      await _stopTyping();
      _scrollToBottom();
    } catch (error) {
      _showSnackBar('Send failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendFile(
    ChatModel chat,
    String uid,
    String senderName,
  ) async {
    final selectedType = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Send Image'),
                onTap: () => Navigator.of(sheetContext).pop('image'),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('Send File'),
                onTap: () => Navigator.of(sheetContext).pop('file'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedType == null) {
      return;
    }

    FilePickerResult? result;
    if (selectedType == 'image') {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: false,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    }

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;

    setState(() => _isSending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendFile(chat.chatId, uid, senderName, file, selectedType);
      _scrollToBottom();
    } catch (error) {
      _showSnackBar('File send failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _showMakeAdminDialog({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    try {
      final users = await ref
          .read(chatRepositoryProvider)
          .getUsersByIds(chat.participants);
      final admins = _groupAdminUids(chat);
      if (!mounted) {
        return;
      }

      final selectedUid = await showDialog<String>(
        context: context,
        builder: (_) {
          return SimpleDialog(
            title: const Text('Make Group Admin'),
            children: users
                .map(
                  (user) => SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(user.uid),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (admins.contains(user.uid))
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.verified_rounded, size: 18),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      );

      if (selectedUid == null || admins.contains(selectedUid)) {
        return;
      }

      await ref
          .read(chatRepositoryProvider)
          .makeGroupAdmin(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            newAdminUid: selectedUid,
          );
      _showSnackBar('Group admin updated');
    } catch (error) {
      _showSnackBar('Unable to update admin: $error');
    }
  }

  Future<void> _handleChatAction({
    required _ChatAction action,
    required ChatModel chat,
    required String currentUid,
    required String currentRole,
    required String otherUid,
    required bool iBlockedOther,
  }) async {
    switch (action) {
      case _ChatAction.groupSettings:
        await _openGroupSettings(
          chat: chat,
          currentUid: currentUid,
          currentRole: currentRole,
        );
      case _ChatAction.editGroupInfo:
        await _editGroupInfo(chat: chat, requestedByUid: currentUid);
      case _ChatAction.updateGroupIcon:
        await _updateGroupIcon(chat: chat, requestedByUid: currentUid);
      case _ChatAction.manageMembers:
        await _manageMembers(chat: chat, requestedByUid: currentUid);
      case _ChatAction.toggleMessagingRestriction:
        await _toggleMessagingRestriction(
          chat: chat,
          requestedByUid: currentUid,
        );
      case _ChatAction.toggleEditInfoRestriction:
        await _toggleEditInfoRestriction(
          chat: chat,
          requestedByUid: currentUid,
        );
      case _ChatAction.toggleJoinApproval:
        await _toggleJoinApproval(chat: chat, requestedByUid: currentUid);
      case _ChatAction.changeGroupAdmin:
        await _showMakeAdminDialog(chat: chat, requestedByUid: currentUid);
      case _ChatAction.inviteLink:
        await _manageInviteLink(chat: chat, requestedByUid: currentUid);
      case _ChatAction.clearChat:
        await _clearChat(chat: chat, requestedByUid: currentUid);
      case _ChatAction.deleteChat:
        await _confirmDeleteChat(chat: chat, requestedByUid: currentUid);
      case _ChatAction.deleteGroup:
        await _confirmDeleteGroup(chat: chat, requestedByUid: currentUid);
      case _ChatAction.leaveGroup:
        await _leaveGroup(chat: chat, uid: currentUid);
      case _ChatAction.blockUser:
        await _blockUser(currentUid: currentUid, targetUid: otherUid);
      case _ChatAction.unblockUser:
        await _unblockUser(currentUid: currentUid, targetUid: otherUid);
      case _ChatAction.report:
        await _reportChatOrUser(
          chat: chat,
          reporterUid: currentUid,
          targetUid: otherUid,
          currentRole: currentRole,
          iBlockedOther: iBlockedOther,
        );
    }
  }

  Future<void> _openGroupSettings({
    required ChatModel chat,
    required String currentUid,
    required String currentRole,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupSettingsScreen(
          chatId: chat.chatId,
          currentUid: currentUid,
          currentRole: currentRole,
        ),
      ),
    );
  }

  Future<void> _editGroupInfo({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final nameController = TextEditingController(text: chat.groupName ?? '');
    final descriptionController = TextEditingController(
      text: chat.groupDescription ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Edit Group Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Group name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Group description',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .updateGroupInfo(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            name: nameController.text.trim(),
            description: descriptionController.text.trim(),
          );
      _showSnackBar('Group info updated');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Failed to update group: $error');
    }
  }

  Future<void> _updateGroupIcon({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    try {
      await ref
          .read(chatRepositoryProvider)
          .uploadGroupIcon(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            file: file,
          );
      _showSnackBar('Group icon updated');
    } catch (error) {
      _showSnackBar('Unable to update icon: $error');
    }
  }

  Future<void> _manageMembers({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final users = await ref
        .read(chatRepositoryProvider)
        .getUsersByIds(chat.participants);
    final pendingUsers = await ref
        .read(chatRepositoryProvider)
        .getUsersByIds(chat.pendingJoinUids);

    if (!mounted) {
      return;
    }

    final adminUids = _groupAdminUids(chat);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_rounded),
                  title: const Text('Add Member'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _addMemberToGroup(
                      chat: chat,
                      requestedByUid: requestedByUid,
                    );
                  },
                ),
                if (pendingUsers.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        top: 6,
                        bottom: 6,
                      ),
                      child: Text(
                        'Pending Join Requests',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                if (pendingUsers.isNotEmpty)
                  ...pendingUsers.map(
                    (item) => ListTile(
                      leading: const Icon(Icons.hourglass_top_rounded),
                      title: Text(item.name),
                      subtitle: Text(item.uid),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: 'Approve',
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _approveJoinRequest(
                                chat: chat,
                                requestedByUid: requestedByUid,
                                joiningUid: item.uid,
                              );
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Reject',
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _rejectJoinRequest(
                                chat: chat,
                                requestedByUid: requestedByUid,
                                joiningUid: item.uid,
                              );
                            },
                            icon: const Icon(Icons.cancel_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                    child: Text(
                      'Members',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, index) {
                      final item = users[index];
                      final isAdmin = adminUids.contains(item.uid);

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            item.name.isEmpty
                                ? '?'
                                : item.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(item.name),
                        subtitle: Text(isAdmin ? 'Admin' : 'Member'),
                        trailing: PopupMenuButton<_MemberAction>(
                          onSelected: (action) async {
                            Navigator.of(sheetContext).pop();
                            switch (action) {
                              case _MemberAction.promote:
                                await _promoteAdmin(
                                  chat: chat,
                                  requestedByUid: requestedByUid,
                                  targetUid: item.uid,
                                );
                              case _MemberAction.demote:
                                await _demoteAdmin(
                                  chat: chat,
                                  requestedByUid: requestedByUid,
                                  targetUid: item.uid,
                                );
                              case _MemberAction.remove:
                                await _removeMember(
                                  chat: chat,
                                  requestedByUid: requestedByUid,
                                  targetUid: item.uid,
                                );
                            }
                          },
                          itemBuilder: (_) {
                            final actions = <PopupMenuEntry<_MemberAction>>[];
                            if (!isAdmin) {
                              actions.add(
                                const PopupMenuItem(
                                  value: _MemberAction.promote,
                                  child: Text('Promote to Admin'),
                                ),
                              );
                            }
                            if (isAdmin) {
                              actions.add(
                                const PopupMenuItem(
                                  value: _MemberAction.demote,
                                  child: Text('Demote Admin'),
                                ),
                              );
                            }
                            actions.add(
                              const PopupMenuItem(
                                value: _MemberAction.remove,
                                child: Text('Remove Member'),
                              ),
                            );
                            return actions;
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addMemberToGroup({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final allUsers = await ref
        .read(chatRepositoryProvider)
        .searchUsersInCollege(
          collegeId: chat.collegeId,
          query: '',
          currentUid: '',
        );
    final existing = chat.participants.toSet();
    final candidates = allUsers
        .where((user) => !existing.contains(user.uid))
        .toList();
    if (candidates.isEmpty) {
      _showSnackBar('No more users available to add');
      return;
    }

    if (!mounted) {
      return;
    }

    final selectedUid = await showDialog<String>(
      context: context,
      builder: (_) {
        return SimpleDialog(
          title: const Text('Add Member'),
          children: candidates
              .take(40)
              .map(
                (user) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(user.uid),
                  child: Text(user.name),
                ),
              )
              .toList(),
        );
      },
    );

    if (selectedUid == null) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .addGroupMemberByAdmin(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            memberUid: selectedUid,
          );
      _showSnackBar('Member added');
    } catch (error) {
      _showSnackBar('Unable to add member: $error');
    }
  }

  Future<void> _removeMember({
    required ChatModel chat,
    required String requestedByUid,
    required String targetUid,
  }) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .removeGroupMemberByAdmin(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            memberUid: targetUid,
          );
      _showSnackBar('Member removed');
    } catch (error) {
      _showSnackBar('Unable to remove member: $error');
    }
  }

  Future<void> _promoteAdmin({
    required ChatModel chat,
    required String requestedByUid,
    required String targetUid,
  }) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .makeGroupAdmin(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            newAdminUid: targetUid,
          );
      _showSnackBar('Member promoted to admin');
    } catch (error) {
      _showSnackBar('Unable to promote admin: $error');
    }
  }

  Future<void> _demoteAdmin({
    required ChatModel chat,
    required String requestedByUid,
    required String targetUid,
  }) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .demoteGroupAdmin(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            adminUid: targetUid,
          );
      _showSnackBar('Admin demoted');
    } catch (error) {
      _showSnackBar('Unable to demote admin: $error');
    }
  }

  Future<void> _approveJoinRequest({
    required ChatModel chat,
    required String requestedByUid,
    required String joiningUid,
  }) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .approveJoinRequest(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            joiningUid: joiningUid,
          );
      _showSnackBar('Join request approved');
    } catch (error) {
      _showSnackBar('Unable to approve request: $error');
    }
  }

  Future<void> _rejectJoinRequest({
    required ChatModel chat,
    required String requestedByUid,
    required String joiningUid,
  }) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .rejectJoinRequest(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            joiningUid: joiningUid,
          );
      _showSnackBar('Join request rejected');
    } catch (error) {
      _showSnackBar('Unable to reject request: $error');
    }
  }

  Future<void> _toggleMessagingRestriction({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final next = !(chat.onlyAdminsCanMessage || chat.broadcastOnly);
    try {
      await ref
          .read(chatRepositoryProvider)
          .setGroupMessagingRestriction(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            onlyAdminsCanMessage: next,
            broadcastOnly: next,
          );
      _showSnackBar(
        next ? 'Group locked for admin-only posts' : 'All members can post now',
      );
    } catch (error) {
      _showSnackBar('Unable to update messaging restriction: $error');
    }
  }

  Future<void> _toggleEditInfoRestriction({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final next = !chat.onlyAdminsCanEditInfo;
    try {
      await ref
          .read(chatRepositoryProvider)
          .setGroupInfoEditingRestriction(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            onlyAdminsCanEditInfo: next,
          );
      _showSnackBar(
        next
            ? 'Only admins can edit group info'
            : 'All members can edit group info',
      );
    } catch (error) {
      _showSnackBar('Unable to update edit restriction: $error');
    }
  }

  Future<void> _toggleJoinApproval({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final next = !chat.joinApprovalRequired;
    try {
      await ref
          .read(chatRepositoryProvider)
          .setJoinApprovalRequirement(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
            joinApprovalRequired: next,
          );
      _showSnackBar(next ? 'Join approval enabled' : 'Join approval disabled');
    } catch (error) {
      _showSnackBar('Unable to update join approval: $error');
    }
  }

  Future<void> _clearChat({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Clear Chat'),
          content: const Text('Remove all messages in this chat?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (confirm != true) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .clearChatMessages(
            chatId: chat.chatId,
            requestedByUid: requestedByUid,
          );
      _showSnackBar('Chat cleared');
    } catch (error) {
      _showSnackBar('Unable to clear chat: $error');
    }
  }

  Future<void> _leaveGroup({
    required ChatModel chat,
    required String uid,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Leave Group'),
          content: const Text('Do you want to leave this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    if (confirm != true) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .leaveGroup(chatId: chat.chatId, uid: uid);
      if (!mounted) {
        return;
      }
      context.go('/chats');
    } catch (error) {
      _showSnackBar('Unable to leave group: $error');
    }
  }

  Future<void> _manageInviteLink({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text(
                  (chat.inviteCode ?? '').isEmpty
                      ? 'Generate Invite Link'
                      : 'Regenerate Invite Link',
                ),
                onTap: () => Navigator.of(sheetContext).pop('generate'),
              ),
              if ((chat.inviteCode ?? '').isNotEmpty && chat.inviteEnabled)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy Invite Link'),
                  onTap: () => Navigator.of(sheetContext).pop('copy'),
                ),
              if ((chat.inviteCode ?? '').isNotEmpty && chat.inviteEnabled)
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share Invite Link'),
                  onTap: () => Navigator.of(sheetContext).pop('share'),
                ),
              if ((chat.inviteCode ?? '').isNotEmpty && chat.inviteEnabled)
                ListTile(
                  leading: const Icon(Icons.link_off_rounded),
                  title: const Text('Disable Invite Link'),
                  onTap: () => Navigator.of(sheetContext).pop('disable'),
                ),
            ],
          ),
        );
      },
    );

    if (action == null) {
      return;
    }

    try {
      switch (action) {
        case 'generate':
          final code = await ref
              .read(chatRepositoryProvider)
              .generateGroupInviteCode(
                chatId: chat.chatId,
                requestedByUid: requestedByUid,
              );
          final link = _buildInviteLink(code);
          await Clipboard.setData(ClipboardData(text: link));
          _showSnackBar('Invite link generated and copied');
        case 'copy':
          final code = chat.inviteCode;
          if (code == null || code.trim().isEmpty) {
            _showSnackBar('Invite link not available');
            return;
          }
          await Clipboard.setData(ClipboardData(text: _buildInviteLink(code)));
          _showSnackBar('Invite link copied');
        case 'share':
          final code = chat.inviteCode;
          if (code == null || code.trim().isEmpty) {
            _showSnackBar('Invite link not available');
            return;
          }
          await Share.share(_buildInviteLink(code));
        case 'disable':
          await ref
              .read(chatRepositoryProvider)
              .disableGroupInviteCode(
                chatId: chat.chatId,
                requestedByUid: requestedByUid,
              );
          _showSnackBar('Invite link disabled');
      }
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Invite link action failed: $error');
    }
  }

  Future<void> _confirmDeleteGroup({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete Group'),
          content: const Text(
            'Delete this group for all members? Messages and media history will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteGroup(chatId: chat.chatId, requestedByUid: requestedByUid);
      if (!mounted) {
        return;
      }
      context.go('/chats');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Delete failed: $error');
    }
  }

  Future<void> _confirmDeleteChat({
    required ChatModel chat,
    required String requestedByUid,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text(
            'Delete this chat for everyone? Messages and files will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteChat(chatId: chat.chatId, requestedByUid: requestedByUid);
      if (!mounted) {
        return;
      }
      context.go('/chats');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Delete failed: $error');
    }
  }

  Future<void> _blockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (targetUid.trim().isEmpty) {
      return;
    }
    try {
      await ref
          .read(chatRepositoryProvider)
          .blockUser(blockerUid: currentUid, blockedUid: targetUid);
      _showSnackBar('User blocked');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Unable to block user: $error');
    }
  }

  Future<void> _unblockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (targetUid.trim().isEmpty) {
      return;
    }
    try {
      await ref
          .read(chatRepositoryProvider)
          .unblockUser(blockerUid: currentUid, blockedUid: targetUid);
      _showSnackBar('User unblocked');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Unable to unblock user: $error');
    }
  }

  Future<void> _reportChatOrUser({
    required ChatModel chat,
    required String reporterUid,
    required String targetUid,
    required String currentRole,
    required bool iBlockedOther,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(chat.isGroup ? 'Report Group' : 'Report User'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write reason for report',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .reportChat(
            reporterUid: reporterUid,
            chatId: chat.chatId,
            reason: reason,
            targetUid: chat.isGroup ? null : targetUid,
          );
      _showSnackBar('Report submitted');
    } catch (error) {
      _showSnackBar('Report failed: $error');
    }
  }

  Future<void> _reportSpecificMessage({
    required ChatModel chat,
    required String reporterUid,
    required String targetUid,
    required String messageId,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Report Message/User'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write reason for report',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .reportChat(
            reporterUid: reporterUid,
            chatId: chat.chatId,
            reason: reason,
            targetUid: targetUid,
            messageId: messageId,
          );
      _showSnackBar('Report submitted');
    } catch (error) {
      _showSnackBar('Report failed: $error');
    }
  }

  String _buildInviteLink(String code) {
    return 'https://academix.app/chat/join-group?code=$code';
  }

  bool _isGroupAdmin({
    required ChatModel chat,
    required String uid,
    required String role,
  }) {
    if (!chat.isGroup) {
      return false;
    }
    if (role.trim().toLowerCase() == 'admin') {
      return true;
    }
    final admins = _groupAdminUids(chat);
    return admins.contains(uid);
  }

  Set<String> _groupAdminUids(ChatModel chat) {
    final participants = chat.participants
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();

    final admins = chat.groupAdminUids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .where((item) => participants.contains(item))
        .toSet();
    final primary = (chat.groupAdminUid ?? '').trim();
    if (primary.isNotEmpty && participants.contains(primary)) {
      admins.add(primary);
    }

    if (admins.isEmpty && participants.isNotEmpty) {
      admins.add(participants.first);
    }

    return admins;
  }

  void _onTypingChanged({
    required String chatId,
    required String uid,
    required String value,
  }) {
    _typingUid = uid;
    _typingChatId = chatId;

    final hasText = value.trim().isNotEmpty;

    if (hasText && !_typingState) {
      _typingState = true;
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .setTyping(chatId: chatId, uid: uid, isTyping: true),
      );
    }

    _typingTimer?.cancel();

    if (!hasText) {
      unawaited(_stopTyping());
      return;
    }

    _typingTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_stopTyping());
    });
  }

  Future<void> _stopTyping() async {
    if (!_typingState || _typingUid == null || _typingChatId == null) {
      return;
    }
    _typingState = false;
    await ref
        .read(chatRepositoryProvider)
        .setTyping(chatId: _typingChatId!, uid: _typingUid!, isTyping: false);
  }

  List<MessageModel> _mergeMessages({
    required List<MessageModel> older,
    required List<MessageModel> recent,
  }) {
    final byId = <String, MessageModel>{};
    for (final message in older) {
      byId[message.messageId] = message;
    }
    for (final message in recent) {
      byId[message.messageId] = message;
    }

    final merged = byId.values.toList();
    merged.sort((a, b) {
      final timeCompare = a.timestamp.compareTo(b.timestamp);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return a.messageId.compareTo(b.messageId);
    });
    return merged;
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingOlder || !_hasMoreOlder) {
      return;
    }

    if (_scrollController.position.pixels <= 48) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreOlder) {
      return;
    }

    final loaded = _mergeMessages(
      older: _olderMessages,
      recent: _recentMessages,
    );
    if (loaded.isEmpty) {
      return;
    }

    setState(() => _isLoadingOlder = true);
    final before = loaded.first.timestamp;

    try {
      final fetched = await ref
          .read(chatRepositoryProvider)
          .getOlderMessages(
            widget.chatId,
            before: before,
            limit: _olderMessagePageSize,
          );

      if (!mounted) {
        return;
      }

      final knownIds = loaded.map((item) => item.messageId).toSet();
      final uniqueFetched = fetched
          .where((item) => !knownIds.contains(item.messageId))
          .toList();

      setState(() {
        if (uniqueFetched.isNotEmpty) {
          _olderMessages.insertAll(0, uniqueFetched);
        }
        _hasMoreOlder =
            uniqueFetched.isNotEmpty && fetched.length >= _olderMessagePageSize;
        _isLoadingOlder = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOlder = false);
      }
    }
  }

  void _maybeResetUnreadCount({required ChatModel chat, required String uid}) {
    final unreadCount = chat.unreadCountFor(uid);
    if (unreadCount <= 0) {
      return;
    }

    final token = '${chat.chatId}:$uid:$unreadCount';
    if (_lastUnreadResetToken == token) {
      return;
    }
    _lastUnreadResetToken = token;

    unawaited(
      ref
          .read(chatRepositoryProvider)
          .markMessagesAsRead(
            chatId: chat.chatId,
            uid: uid,
            messageIds: const <String>[],
          )
          .catchError((_) {
            if (_lastUnreadResetToken == token) {
              _lastUnreadResetToken = null;
            }
          }),
    );
  }

  void _markUnreadAsRead(
    String chatId,
    String currentUid,
    List<MessageModel> messages,
  ) {
    var hasPending = false;
    for (final message in messages) {
      final shouldMark =
          message.senderId != currentUid &&
          !message.readBy.contains(currentUid);
      if (!shouldMark || !_readMarked.add(message.messageId)) {
        continue;
      }
      _pendingReadMessageIds.add(message.messageId);
      hasPending = true;
    }

    if (hasPending) {
      _readFlushTimer?.cancel();
      _readFlushTimer = Timer(const Duration(milliseconds: 240), () {
        _flushPendingReadMarks(chatId: chatId, uid: currentUid);
      });
    }
  }

  Future<void> _flushPendingReadMarks({
    required String chatId,
    required String uid,
  }) async {
    if (_pendingReadMessageIds.isEmpty) {
      return;
    }

    final pendingIds = _pendingReadMessageIds.toList();
    _pendingReadMessageIds.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .markMessagesAsRead(chatId: chatId, uid: uid, messageIds: pendingIds);
    } catch (_) {
      for (final id in pendingIds) {
        _readMarked.remove(id);
      }
    }
  }

  void _autoScrollOnNewMessages(int count) {
    if (count <= 0 || count == _lastRecentMessageCount) {
      return;
    }
    _lastRecentMessageCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 100,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _ChatAction {
  groupSettings,
  editGroupInfo,
  updateGroupIcon,
  manageMembers,
  toggleMessagingRestriction,
  toggleEditInfoRestriction,
  toggleJoinApproval,
  changeGroupAdmin,
  inviteLink,
  clearChat,
  deleteChat,
  deleteGroup,
  leaveGroup,
  blockUser,
  unblockUser,
  report,
}

enum _MemberAction { promote, demote, remove }

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.chat,
    required this.otherName,
    required this.onlineAsync,
  });

  final ChatModel chat;
  final String? otherName;
  final AsyncValue<bool> onlineAsync;

  @override
  Widget build(BuildContext context) {
    final title = chat.isGroup
        ? (chat.groupName?.trim().isNotEmpty == true
              ? chat.groupName!
              : 'Group Chat')
        : (otherName?.trim().isNotEmpty == true ? otherName! : 'Chat');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (chat.isGroup)
          Text(
            '${chat.participants.length} members',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          onlineAsync.when(
            data: (isOnline) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'online' : 'offline',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            loading: () =>
                Text('...', style: Theme.of(context).textTheme.bodySmall),
            error: (_, _) =>
                Text('offline', style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              DateFormat('dd MMM yyyy').format(date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.message, required this.onCancel});

  final MessageModel message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content.isEmpty ? 'Replying to message' : message.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends ConsumerWidget {
  const _TypingIndicator({required this.chat, required this.currentUid});

  final ChatModel chat;
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatByIdProvider(chat.chatId));
    final liveChat = chatAsync.asData?.value ?? chat;

    final typingOthers = liveChat.typingUids.where((uid) => uid != currentUid);
    if (typingOthers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      alignment: Alignment.centerLeft,
      child: Text('typing...', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
