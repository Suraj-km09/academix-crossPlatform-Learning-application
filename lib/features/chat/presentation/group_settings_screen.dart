import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../data/chat_model.dart';
import '../domain/chat_providers.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.chatId,
    required this.currentUid,
    required this.currentRole,
  });

  final String chatId;
  final String currentUid;
  final String currentRole;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _busyMessaging = false;
  bool _busyInfoEdit = false;
  bool _busyJoinApproval = false;

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatByIdProvider(widget.chatId));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/chats'),
        title: const Text('Group Settings'),
      ),
      body: chatAsync.when(
        data: (chat) {
          if (chat == null || !chat.isGroup) {
            return const EmptyState(
              title: 'Group not found',
              subtitle: 'This group may have been removed.',
            );
          }

          final canManage = _isGroupAdmin(chat);
          if (!canManage) {
            return const EmptyState(
              title: 'No access',
              subtitle: 'Only group admins can open group settings.',
            );
          }

          final adminOnlyPosts =
              chat.onlyAdminsCanMessage || chat.broadcastOnly;

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _SectionCard(
                title: 'Group Info',
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit Name & Description'),
                    subtitle: Text(
                      (chat.groupDescription ?? '').trim().isEmpty
                          ? 'Update group title and details'
                          : chat.groupDescription!,
                    ),
                    onTap: () => _editGroupInfo(chat),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: const Text('Update Group Icon'),
                    subtitle: const Text('Upload a new image icon for group'),
                    onTap: () => _updateGroupIcon(chat),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    value: chat.onlyAdminsCanEditInfo,
                    onChanged: _busyInfoEdit
                        ? null
                        : (value) => _toggleEditInfoRestriction(chat, value),
                    title: const Text('Only Admins Can Edit Group Info'),
                    subtitle: const Text(
                      'Restrict editing name/description/icon to admins only.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Messaging & Announcements',
                children: [
                  SwitchListTile.adaptive(
                    value: adminOnlyPosts,
                    onChanged: _busyMessaging
                        ? null
                        : (value) => _toggleMessagingRestriction(chat, value),
                    title: const Text('Admin-Only Posting (Announcements)'),
                    subtitle: const Text(
                      'When enabled, only admins can send messages.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Membership',
                children: [
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('Manage Members & Admins'),
                    subtitle: const Text(
                      'Add/remove members, promote/demote admins, approve requests.',
                    ),
                    onTap: () => _manageMembers(chat),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Change Primary Group Admin'),
                    subtitle: const Text(
                      'Assign another member as group admin.',
                    ),
                    onTap: () => _showMakeAdminDialog(chat),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Privacy',
                children: [
                  SwitchListTile.adaptive(
                    value: chat.joinApprovalRequired,
                    onChanged: _busyJoinApproval
                        ? null
                        : (value) => _toggleJoinApproval(chat, value),
                    title: const Text('Require Admin Approval For Joining'),
                    subtitle: const Text(
                      'New members must be approved by admin.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.link_outlined),
                    title: const Text('Invite Link Settings'),
                    subtitle: Text(
                      chat.inviteEnabled && (chat.inviteCode ?? '').isNotEmpty
                          ? 'Invite link is enabled'
                          : 'Invite link is disabled',
                    ),
                    onTap: () => _manageInviteLink(chat),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Danger Zone',
                children: [
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('Clear Group Chat'),
                    subtitle: const Text('Remove all messages in this group.'),
                    onTap: () => _clearChat(chat),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Delete Group',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: const Text('Deletes group and all chat history.'),
                    onTap: () => _deleteGroup(chat),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () =>
            const LoadingWidget(message: 'Loading group settings...'),
        error: (error, _) =>
            EmptyState(title: 'Unable to load settings', subtitle: '$error'),
      ),
    );
  }

  bool _isGroupAdmin(ChatModel chat) {
    if (!chat.isGroup) {
      return false;
    }
    if (widget.currentRole.trim().toLowerCase() == 'admin') {
      return true;
    }
    return _groupAdminUids(chat).contains(widget.currentUid);
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

  Future<void> _editGroupInfo(ChatModel chat) async {
    final nameController = TextEditingController(text: chat.groupName ?? '');
    final descriptionController = TextEditingController(
      text: chat.groupDescription ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
              decoration: const InputDecoration(hintText: 'Group description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .updateGroupInfo(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            name: nameController.text.trim(),
            description: descriptionController.text.trim(),
          );
      _showSnack('Group info updated');
    } catch (error) {
      _showSnack('Failed to update group info: $error');
    }
  }

  Future<void> _updateGroupIcon(ChatModel chat) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .uploadGroupIcon(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            file: result.files.first,
          );
      _showSnack('Group icon updated');
    } catch (error) {
      _showSnack('Unable to update icon: $error');
    }
  }

  Future<void> _toggleMessagingRestriction(ChatModel chat, bool value) async {
    setState(() => _busyMessaging = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .setGroupMessagingRestriction(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            onlyAdminsCanMessage: value,
            broadcastOnly: value,
          );
      _showSnack(
        value
            ? 'Group locked for admin-only posts'
            : 'All members can post now',
      );
    } catch (error) {
      _showSnack('Unable to update messaging settings: $error');
    } finally {
      if (mounted) {
        setState(() => _busyMessaging = false);
      }
    }
  }

  Future<void> _toggleEditInfoRestriction(ChatModel chat, bool value) async {
    setState(() => _busyInfoEdit = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .setGroupInfoEditingRestriction(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            onlyAdminsCanEditInfo: value,
          );
      _showSnack(
        value
            ? 'Only admins can edit group info'
            : 'All members can edit group info',
      );
    } catch (error) {
      _showSnack('Unable to update info permission: $error');
    } finally {
      if (mounted) {
        setState(() => _busyInfoEdit = false);
      }
    }
  }

  Future<void> _toggleJoinApproval(ChatModel chat, bool value) async {
    setState(() => _busyJoinApproval = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .setJoinApprovalRequirement(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            joinApprovalRequired: value,
          );
      _showSnack(value ? 'Join approval enabled' : 'Join approval disabled');
    } catch (error) {
      _showSnack('Unable to update join approval: $error');
    } finally {
      if (mounted) {
        setState(() => _busyJoinApproval = false);
      }
    }
  }

  Future<void> _manageInviteLink(ChatModel chat) async {
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
                requestedByUid: widget.currentUid,
              );
          final link = _buildInviteLink(code);
          await Clipboard.setData(ClipboardData(text: link));
          _showSnack('Invite link generated and copied');
        case 'copy':
          final code = chat.inviteCode;
          if (code == null || code.trim().isEmpty) {
            _showSnack('Invite link not available');
            return;
          }
          await Clipboard.setData(ClipboardData(text: _buildInviteLink(code)));
          _showSnack('Invite link copied');
        case 'share':
          final code = chat.inviteCode;
          if (code == null || code.trim().isEmpty) {
            _showSnack('Invite link not available');
            return;
          }
          await Share.share(_buildInviteLink(code));
        case 'disable':
          await ref
              .read(chatRepositoryProvider)
              .disableGroupInviteCode(
                chatId: chat.chatId,
                requestedByUid: widget.currentUid,
              );
          _showSnack('Invite link disabled');
      }
    } catch (error) {
      _showSnack('Invite link action failed: $error');
    }
  }

  Future<void> _manageMembers(ChatModel chat) async {
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
                    await _addMemberToGroup(chat);
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
                              await _approveJoinRequest(chat, item.uid);
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Reject',
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _rejectJoinRequest(chat, item.uid);
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
                                await _promoteAdmin(chat, item.uid);
                              case _MemberAction.demote:
                                await _demoteAdmin(chat, item.uid);
                              case _MemberAction.remove:
                                await _removeMember(chat, item.uid);
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

  Future<void> _addMemberToGroup(ChatModel chat) async {
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
      _showSnack('No more users available to add');
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
            requestedByUid: widget.currentUid,
            memberUid: selectedUid,
          );
      _showSnack('Member added');
    } catch (error) {
      _showSnack('Unable to add member: $error');
    }
  }

  Future<void> _removeMember(ChatModel chat, String targetUid) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .removeGroupMemberByAdmin(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            memberUid: targetUid,
          );
      _showSnack('Member removed');
    } catch (error) {
      _showSnack('Unable to remove member: $error');
    }
  }

  Future<void> _promoteAdmin(ChatModel chat, String targetUid) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .makeGroupAdmin(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            newAdminUid: targetUid,
          );
      _showSnack('Member promoted to admin');
    } catch (error) {
      _showSnack('Unable to promote admin: $error');
    }
  }

  Future<void> _demoteAdmin(ChatModel chat, String targetUid) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .demoteGroupAdmin(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            adminUid: targetUid,
          );
      _showSnack('Admin demoted');
    } catch (error) {
      _showSnack('Unable to demote admin: $error');
    }
  }

  Future<void> _approveJoinRequest(ChatModel chat, String joiningUid) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .approveJoinRequest(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            joiningUid: joiningUid,
          );
      _showSnack('Join request approved');
    } catch (error) {
      _showSnack('Unable to approve request: $error');
    }
  }

  Future<void> _rejectJoinRequest(ChatModel chat, String joiningUid) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .rejectJoinRequest(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            joiningUid: joiningUid,
          );
      _showSnack('Join request rejected');
    } catch (error) {
      _showSnack('Unable to reject request: $error');
    }
  }

  Future<void> _showMakeAdminDialog(ChatModel chat) async {
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
        builder: (_) => SimpleDialog(
          title: const Text('Change Group Admin'),
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
        ),
      );

      if (selectedUid == null || admins.contains(selectedUid)) {
        return;
      }

      await ref
          .read(chatRepositoryProvider)
          .makeGroupAdmin(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
            newAdminUid: selectedUid,
          );
      _showSnack('Primary group admin updated');
    } catch (error) {
      _showSnack('Unable to update admin: $error');
    }
  }

  Future<void> _clearChat(ChatModel chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Group Chat'),
        content: const Text('Remove all messages in this group?'),
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
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .clearChatMessages(
            chatId: chat.chatId,
            requestedByUid: widget.currentUid,
          );
      _showSnack('Chat cleared');
    } catch (error) {
      _showSnack('Unable to clear chat: $error');
    }
  }

  Future<void> _deleteGroup(ChatModel chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteGroup(chatId: chat.chatId, requestedByUid: widget.currentUid);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      _showSnack('Delete failed: $error');
    }
  }

  String _buildInviteLink(String code) {
    return 'https://academix.app/chat/join-group?code=$code';
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _MemberAction { promote, demote, remove }

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
