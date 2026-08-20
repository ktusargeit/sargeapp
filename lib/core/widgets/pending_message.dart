import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/image_utils.dart';
import 'comment_tile.dart';
import 'platform_image.dart';

/// A locally attached image that has not yet been uploaded to Storage.
class PendingAttachedImage {
  final PickedImage image;

  /// True after the upload failed; the bubble shows a small retry affordance.
  final bool failed;

  const PendingAttachedImage(this.image, {this.failed = false});
}

/// An optimistically-rendered outgoing message.
///
/// It is shown immediately (with its locally-picked images) before the image
/// upload + Firestore write finish, then is swapped for the persisted message
/// once the Firestore stream delivers it. This mirrors WhatsApp's "send now,
/// sync in the background" behavior and never leaves a blank/black bubble.
class PendingMessage {
  final String localId;
  final String text;
  final String senderUid;
  final String senderName;
  final bool isAdmin;
  final List<PendingAttachedImage> images;
  final String? replyToId;
  final String? replyToText;
  final String? replyToAuthor;
  final String? replyToUid;

  /// True when the upload/persist step failed, so the bubble can offer a
  /// small "gönderilemedi, tekrar dene" action instead of a full-screen error.
  bool failed;

  PendingMessage({
    required this.localId,
    required this.text,
    required this.senderUid,
    required this.senderName,
    this.isAdmin = false,
    this.images = const [],
    this.replyToId,
    this.replyToText,
    this.replyToAuthor,
    this.replyToUid,
    this.failed = false,
  });
}

/// A WhatsApp-style outgoing bubble for a [PendingMessage].
///
/// Local images stay visible at all times; while uploading, a translucent
/// overlay + small spinner is drawn on top (never hiding the image). On
/// failure, a compact error/retry indicator is shown on the bubble.
class PendingMessageBubble extends StatelessWidget {
  final PendingMessage message;
  final bool uploading;
  final VoidCallback? onRetry;

  const PendingMessageBubble({
    super.key,
    required this.message,
    required this.uploading,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = AppColors.ownBubble;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.replyToAuthor != null &&
                      message.replyToAuthor!.isNotEmpty) ...[
                    ReplyQuoteBlock(
                      author: message.replyToAuthor!,
                      text: message.replyToText != null &&
                              message.replyToText!.isNotEmpty
                          ? message.replyToText!
                          : '📎 Ek',
                      color: Colors.white70,
                    ),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  if (message.images.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: message.images.map((attached) {
                        return _LocalImageThumb(
                          attached: attached,
                          uploading: uploading,
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.failed && !uploading)
                        GestureDetector(
                          onTap: onRetry,
                          behavior: HitTestBehavior.opaque,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                'Gönderilemedi · Tekrar Dene',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      else if (uploading) ...[
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white70),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Gönderiliyor…',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          UserAvatar(
            uid: message.senderUid,
            name: message.senderName,
            radius: 14,
            isAdmin: message.isAdmin,
          ),
        ],
      ),
    );
  }
}

class _LocalImageThumb extends StatelessWidget {
  final PendingAttachedImage attached;
  final bool uploading;

  const _LocalImageThumb({required this.attached, required this.uploading});

  @override
  Widget build(BuildContext context) {
    final img = attached.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          PlatformImageFile(
            bytes: img.bytes,
            file: img.dartFile,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            borderRadius: 0,
          ),
          if (uploading && !attached.failed)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
            ),
          if (attached.failed)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(
                  child: Icon(Icons.error_outline,
                      size: 20, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}