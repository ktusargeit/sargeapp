 import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import 'profile_common.dart';

// ---------------------------------------------------------------------------
// HERO / COVER — Instagram/Twitter style cover that extends behind the name,
// with the avatar overlapping the bottom edge and a dark gradient overlay.
// ---------------------------------------------------------------------------

class ProfileHero extends ConsumerStatefulWidget {
  final AppUser user;
  final bool isOwnProfile;
  const ProfileHero({
    super.key,
    required this.user,
    required this.isOwnProfile,
  });

  @override
  ConsumerState<ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends ConsumerState<ProfileHero> {
  bool _uploadingCover = false;

  Future<void> _pickCover() async {
    if (!widget.isOwnProfile) return;
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploadingCover = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('cover_photos/${widget.user.uid}.jpg');
      if (kIsWeb && picked.bytes != null) {
        await storageRef.putData(picked.bytes!);
      } else if (picked.dartFile != null) {
        await storageRef.putFile(picked.dartFile!);
      }
      final url = await storageRef.getDownloadURL();
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.user.uid)
          .update({'coverPhotoUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kapak fotoğrafı güncellendi.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Kapak fotoğrafı yüklenemedi: $e'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final headline = [
      if (user.department != null && user.department!.isNotEmpty)
        user.department!,
      if (user.className != null && user.className!.isNotEmpty)
        user.className!,
    ].join(' · ');

    final activeTitles = user.activeTitles;
    final hasCover =
        user.coverPhotoUrl != null && user.coverPhotoUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover image / fallback gradient
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                    child: hasCover
                        ? Image.network(
                            user.coverPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ProfileCoverFallback(),
                          )
                        : const ProfileCoverFallback(),
                  ),
                ),
                // Dark gradient overlay so the name/titles stay readable
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0x26000000),
                            Color(0xB3000000),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Cover change button (own profile only)
                if (widget.isOwnProfile)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _pickCover,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: _uploadingCover
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.sargeGold),
                              )
                            : const Icon(Icons.camera_alt_outlined,
                                size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                // Avatar overlapping the cover's bottom edge
                Positioned(
                  left: 20,
                  bottom: -40,
                  child: _buildAvatar(),
                ),
                // Name + titles + headline, beside the avatar over gradient
                Positioned(
                  left: 138,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),
                      if (activeTitles.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: activeTitles
                              .map((t) => ProfileTitleChip(title: t))
                              .toList(),
                        ),
                      ],
                      if (headline.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD6DDE7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Space for the avatar overflow below the cover
          const SizedBox(height: 52),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final photoUrl = widget.user.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return GestureDetector(
      // Tapping the avatar always opens the full-screen viewer; editing is
      // only reached via the top-right "Düzenle" button.
      onTap: hasPhoto ? () => openNetworkImageViewer(context, photoUrl) : null,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.sargeGold, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 46,
          backgroundColor: AppColors.surface2,
          backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
          child: !hasPhoto
              ? Icon(Icons.person_outline,
                  size: 46, color: AppColors.textSecondary)
              : null,
        ),
      ),
    );
  }
}

class ProfileCoverFallback extends StatelessWidget {
  const ProfileCoverFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF2A2450),
            Color(0xFF0D0D0D),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.landscape_outlined,
            size: 44, color: Color(0x66FFFFFF)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// IDENTITY SHOWCASE (rank + stats) — redesigned as an achievement "vitrin".
// ---------------------------------------------------------------------------

class ProfileIdentityShowcase extends StatelessWidget {
  final AppUser user;
  const ProfileIdentityShowcase({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final top = highestProfileTitle(user);
    final rankLabel = top?.displayLabel ?? 'Normal Üye';
    final rankType = top?.titleType ?? TitleType.member;
    final rankColor = profileTitleColor(rankType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          ProfileRankBadge(
            label: rankLabel,
            color: rankColor,
          ),
        ],
      ),
    );
  }
}

class ProfileRankBadge extends StatelessWidget {
  final String label;
  final Color color;
  const ProfileRankBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.06),
            AppColors.surface2,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF2D57E), AppColors.sargeGold],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sargeGold.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.military_tech,
                color: Color(0xFF1E1E1E), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AKTİF RÜTBE',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.workspace_premium, color: color, size: 28),
        ],
      ),
    );
  }
}

class ProfileStatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const ProfileStatBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            AppColors.surface2,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BASIC INFO — "Temel Bilgiler": bio + personal info rows.
// ---------------------------------------------------------------------------

class ProfileBasicInfoSection extends StatelessWidget {
  final AppUser user;
  const ProfileBasicInfoSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitleWithCard(
          header: const ProfileSectionHeader(title: 'HAKKINDA'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              user.bio != null && user.bio!.isNotEmpty
                  ? user.bio!
                  : 'Henüz bir biyografi eklenmemiş.',
              style: TextStyle(
                color: (user.bio == null || user.bio!.isEmpty)
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingLg),
        ProfileSectionTitleWithCard(
          header: const ProfileSectionHeader(title: 'BİLGİLER'),
          child: Column(
            children: [
              ProfileInfoRow(
                  icon: Icons.person_outline,
                  label: 'Ad Soyad',
                  value: user.displayName,
                  color: AppColors.info),
              ProfileInfoRow(
                  icon: Icons.school_outlined,
                  label: 'Bölüm',
                  value: user.department ?? '—',
                  color: AppColors.teamAccent),
              ProfileInfoRow(
                  icon: Icons.class_outlined,
                  label: 'Sınıf',
                  value: user.className ?? '—',
                  color: AppColors.depoAccent),
              ProfileInfoRow(
                  icon: Icons.mail_outline,
                  label: 'E-posta',
                  value: user.email,
                  color: AppColors.primaryGreen,
                  isLast: true),
            ],
          ),
        ),
      ],
    );
  }
}