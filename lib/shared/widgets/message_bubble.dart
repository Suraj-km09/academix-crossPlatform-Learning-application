import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/chat/data/message_model.dart';
import '../services/storage_image_cache_service.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isRead,
    required this.showSenderInfo,
    this.senderAvatarUrl,
    this.onLongPress,
  });

  final MessageModel message;
  final bool isMe;
  final bool isRead;
  final bool showSenderInfo;
  final String? senderAvatarUrl;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? Colors.blue.shade600
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isMe
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth > 0) ? screenWidth * 0.78 : 320.0;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSenderInfo && !isMe) ...[
                  Row(
                    children: [
                      _Avatar(url: senderAvatarUrl, name: message.senderName),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if ((message.replyTo ?? '').isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (message.replyToContent ?? '').trim().isEmpty
                          ? 'Reply'
                          : message.replyToContent!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor.withValues(alpha: 0.9)),
                    ),
                  ),
                _MessageBody(message: message, textColor: textColor),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Icon(
                        isRead ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 14,
                        color: isRead
                            ? Colors.lightBlue.shade100
                            : textColor.withValues(alpha: 0.85),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.message, required this.textColor});

  final MessageModel message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: textColor.withValues(alpha: 0.9),
        ),
      );
    }

    if (message.isImage && (message.fileUrl ?? '').isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: message.fileUrl!,
          fit: BoxFit.cover,
          width: 220,
          height: 160,
          placeholder: (_, _) => Container(
            width: 220,
            height: 160,
            alignment: Alignment.center,
            color: Colors.black.withValues(alpha: 0.06),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          errorWidget: (_, _, _) => Container(
            width: 220,
            height: 120,
            alignment: Alignment.center,
            color: Colors.black.withValues(alpha: 0.06),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }

    if (message.isFile) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black.withValues(alpha: 0.09),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: textColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                (message.fileName ?? message.content).trim(),
                style: TextStyle(color: textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      message.content,
      style: TextStyle(color: textColor, height: 1.3),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = (url ?? '').trim();
    if (trimmed.isNotEmpty) {
      final initialResolved = StorageImageCacheService.peekResolvedDownloadUrl(
        trimmed,
      );
      return FutureBuilder<String?>(
        future: StorageImageCacheService.resolveDownloadUrl(trimmed),
        initialData: initialResolved,
        builder: (_, snapshot) {
          final resolved = snapshot.data;
          if (resolved != null && resolved.trim().isNotEmpty) {
            return CircleAvatar(
              radius: 10,
              backgroundImage: CachedNetworkImageProvider(resolved),
            );
          }
          return CircleAvatar(
            radius: 10,
            child: Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 10),
            ),
          );
        },
      );
    }

    return CircleAvatar(
      radius: 10,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
}
