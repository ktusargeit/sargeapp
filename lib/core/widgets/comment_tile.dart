import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../theme/app_colors.dart';
import 'full_screen_image_view.dart';
import 'linkified_text.dart';

/// A single reusable comment/author avatar.
///
/// Fetches the author's profile photo live from Firestore. Falls back to a
/// default avatar (initial letter) when the user has no photo. This keeps
/// avatars consistent across every comment area (tasks, announcements,
/// reports, suggestions).
class UserAvatar extends ConsumerWidget {
  final String uid;
  final String name;
  final double radius;
  final bool isAdmin;

  const UserAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.radius = 14,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = uid.isEmpty
        ? null
        : ref.watch(userProfileProvider(uid)).valueOrNull;
    final photoUrl = profile?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    // Prefer the live Firebase role over the `isAdmin` flag persisted on the
    // comment at write time. The persisted flag can become stale if a user's
    // role changes, so the avatar always reflects current reality.
    final isAdminUser = (profile?.isAdmin ?? false) || isAdmin;
    final displayName = profile?.displayName ?? name;
    final displayInitial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: isAdminUser
          ? AppColors.sargeGold.withValues(alpha: 0.2)
          : AppColors.surface2,
      backgroundImage:
          hasPhoto ? CachedNetworkImageProvider(photoUrl) : null,
      child: hasPhoto
          ? null
          : Text(
              displayInitial,
              style: TextStyle(
                color: isAdminUser
                    ? AppColors.sargeGold
                    : AppColors.textSecondary,
                fontSize: radius * 0.78,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

/// Avatar + name row that opens the user's profile when tapped.
///
/// Used consistently across every chat/comment area (task comments,
/// announcement comments, report messages) so tapping a profile picture or
/// name always navigates to that user's profile page.
class UserAvatarWithName extends ConsumerWidget {
  final String uid;
  final String name;
  final double avatarRadius;
  final bool isAdmin;
  final TextStyle? nameStyle;
  final Widget? trailing;

  const UserAvatarWithName({
    super.key,
    required this.uid,
    required this.name,
    this.avatarRadius = 12,
    this.isAdmin = false,
    this.nameStyle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the live profile so the displayed name/avatar match Firebase.
    final profile = uid.isEmpty
        ? null
        : ref.watch(userProfileProvider(uid)).valueOrNull;
    final liveName = profile?.displayName ?? name;
    final liveIsAdmin = (profile?.isAdmin ?? false) || isAdmin;
    final displayName = liveName.isNotEmpty ? liveName : 'Bilinmeyen';

    return GestureDetector(
      onTap: uid.isEmpty
          ? null
          : () => context.push('/profile/$uid'),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            uid: uid,
            name: displayName,
            radius: avatarRadius,
            isAdmin: liveIsAdmin,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nameStyle ??
                  TextStyle(
                    color: liveIsAdmin
                        ? AppColors.sargeGold
                        : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (liveIsAdmin) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.sargeGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('Admin',
                  style: TextStyle(
                      color: AppColors.sargeGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A small preview card shown above the compose input while replying.
///
/// Displays "Yanıtlıyorsunuz: <author>" and a short snippet of the original
/// message, with a close (X) button to cancel the reply.
class ReplyPreviewBar extends StatelessWidget {
  final String author;
  final String text;
  final VoidCallback? onClear;

  const ReplyPreviewBar({
    super.key,
    required this.author,
    required this.text,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final snippet = text.replaceAll('\n', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panelBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppColors.panelBlue, width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 14, color: AppColors.panelBlue),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yanıtlıyorsunuz: ${author.isEmpty ? 'Bilinmeyen' : author}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.panelBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (snippet.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    snippet.length > 60
                        ? '${snippet.substring(0, 60)}...'
                        : snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// WhatsApp-style quote block shown inside a message bubble.
///
/// Displays the author of the replied-to message plus a short snippet of its
/// text. Tapping it scrolls to / highlights the original message (handled by
/// the parent list when `onTap` is provided).
class ReplyQuoteBlock extends StatelessWidget {
  final String author;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const ReplyQuoteBlock({
    super.key,
    required this.author,
    required this.text,
    this.color = AppColors.panelBlue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final snippet = text.replaceAll('\n', ' ');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A WhatsApp-style chat bubble.
///
/// [data] is the raw comment/message document map. The bubble is:
///  * right-aligned + greenish when [isMine] is true (the current user wrote it)
///  * left-aligned + gray when another user wrote it
///  * includes the sender's avatar/name (tappable → opens profile), the text,
///    a reply quote when the message is itself a reply, an optional time, and
///    any attached images (tappable → full screen).
class ChatBubble extends ConsumerWidget {
  final Map<String, dynamic> data;
  final bool isMine;
  final void Function()? onReplyQuoteTap;

  /// Called when the user taps the "Yanıtla" (reply) action on this message.
  final void Function()? onReply;

  const ChatBubble({
    super.key,
    required this.data,
    required this.isMine,
    this.onReplyQuoteTap,
    this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderUid = data['senderUid'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? 'Bilinmeyen';
    final text = data['text'] as String? ?? '';
    final isAdminComment = data['isAdmin'] as bool? ?? false;
    final timestamp = data['createdAt'] as Timestamp?;
    final replyToText = data['replyToText'] as String? ?? '';
    final replyToAuthor = data['replyToAuthor'] as String? ?? '';

    // Resolve the author's live profile.
    final profile = senderUid.isEmpty
        ? null
        : ref.watch(userProfileProvider(senderUid)).valueOrNull;
    final liveName = profile?.displayName ?? senderName;
    final liveIsAdmin = (profile?.isAdmin ?? false) || isAdminComment;

    final imageUrls = (data['imageUrls'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    final singleImage = data['imageUrl'] as String?;

    final timeStr = timestamp != null
        ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    // Own bubbles: greenish tint. Others: neutral surface.
    final bubbleColor = isMine
        ? AppColors.ownBubble
        : AppColors.surface2;
    final textColor = AppColors.textPrimary;
    final timeColor = AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            GestureDetector(
              onTap: senderUid.isEmpty
                  ? null
                  : () => context.push('/profile/$senderUid'),
              child: UserAvatar(
                uid: senderUid,
                name: liveName,
                radius: 14,
                isAdmin: liveIsAdmin,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMine ? 14 : 4),
                  topRight: Radius.circular(isMine ? 4 : 14),
                  bottomLeft: const Radius.circular(14),
                  bottomRight: const Radius.circular(14),
                ),
                border: isMine
                    ? null
                    : Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply quote block (WhatsApp-style).
                  if (replyToAuthor.isNotEmpty || replyToText.isNotEmpty) ...[
                    ReplyQuoteBlock(
                      author: replyToAuthor.isNotEmpty
                          ? replyToAuthor
                          : 'Bilinmeyen',
                      text: replyToText.isNotEmpty
                          ? replyToText
                          : '📎 Ek',
                      color: isMine ? Colors.white70 : AppColors.panelBlue,
                      onTap: onReplyQuoteTap,
                    ),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (liveName.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            liveName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMine
                                  ? Colors.white
                                  : (liveIsAdmin
                                      ? AppColors.sargeGold
                                      : AppColors.textPrimary),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (text.isNotEmpty)
                        Flexible(
                          child: LinkifiedText(
                            text: text,
                            style: TextStyle(
                              color: isMine ? Colors.white : textColor,
                              fontSize: 13,
                            ),
                            linkColor: AppColors.panelBlue,
                          ),
                        ),
                    ],
                  ),
                  if (text.isNotEmpty) const SizedBox(height: 2),
                  // Images.
                  if (imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: imageUrls.asMap().entries.map((e) {
                        return GestureDetector(
                          onTap: () => showFullScreenImageViewer(
                            context,
                            urls: imageUrls,
                            initialIndex: e.key,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: e.value,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 80,
                                height: 80,
                                color: AppColors.surface2,
                              ),
                              errorWidget: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else if (singleImage != null &&
                      singleImage.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => openNetworkImageViewer(context, singleImage),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: singleImage,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 140,
                            height: 140,
                            color: AppColors.surface2,
                          ),
                          errorWidget: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                  // Time + reply action.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isMine
                              ? Colors.white70
                              : timeColor.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ],
                      if (onReply != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onReply,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply,
                                size: 12,
                                color: isMine
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Yanıtla',
                                style: TextStyle(
                                  color: isMine
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: senderUid.isEmpty
                  ? null
                  : () => context.push('/profile/$senderUid'),
              child: UserAvatar(
                uid: senderUid,
                name: liveName,
                radius: 14,
                isAdmin: liveIsAdmin,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Legacy shared comment tile kept for API compatibility.
///
/// Tasks/announcements/reports all use [ChatBubble] for the WhatsApp-style UI.
/// This wrapper is kept so any existing callers (e.g. optimistic pending tiles)
/// continue to compile and render as bubbles.
class CommentTile extends ConsumerWidget {
  final Map<String, dynamic> data;
  final bool isMine;
  final void Function()? onReplyQuoteTap;
  final void Function()? onReply;

  const CommentTile({
    super.key,
    required this.data,
    this.isMine = false,
    this.onReplyQuoteTap,
    this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChatBubble(
      data: data,
      isMine: isMine,
      onReplyQuoteTap: onReplyQuoteTap,
      onReply: onReply,
    );
  }
}
