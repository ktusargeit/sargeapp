import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_colors.dart';
import 'full_screen_image_view.dart';

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

/// Shared comment tile used across tasks / announcements / etc.
///
/// [data] is the raw comment document map. The author photo is always fetched
/// from [UserAvatar] so the profile picture appears consistently everywhere.
class CommentTile extends ConsumerWidget {
  final Map<String, dynamic> data;

  const CommentTile({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderUid = data['senderUid'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? 'Bilinmeyen';
    final text = data['text'] as String? ?? '';
    final isAdminComment = data['isAdmin'] as bool? ?? false;
    final timestamp = data['createdAt'] as Timestamp?;
    // Resolve the author's live profile so the name/avatar are always pulled
    // from Firebase (not a possibly-stale value copied into the comment).
    final profile = senderUid.isEmpty
        ? null
        : ref.watch(userProfileProvider(senderUid)).valueOrNull;
    final liveName = profile?.displayName ?? senderName;
    final liveIsAdmin = (profile?.isAdmin ?? false) || isAdminComment;
    final imageUrls = (data['imageUrls'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    final timeStr = timestamp != null
        ? '${timestamp.toDate().day}/${timestamp.toDate().month} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            uid: senderUid,
            name: liveName,
            radius: 14,
            isAdmin: liveIsAdmin,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(liveName,
                        style:  TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (liveIsAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
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
                    const Spacer(),
                    Text(timeStr,
                        style:  TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 2),
                if (text.isNotEmpty)
                  Text(text,
                      style:  TextStyle(
                          color: AppColors.textPrimary, fontSize: 13)),
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}