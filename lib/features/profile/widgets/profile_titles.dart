import 'package:flutter/material.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/theme/app_colors.dart';
import 'profile_common.dart';

// ---------------------------------------------------------------------------
// TITLES — "Ünvanlar": list of the user's active titles.
// ---------------------------------------------------------------------------

class ProfileTitlesSection extends StatelessWidget {
  final AppUser user;
  const ProfileTitlesSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionTitleWithCard(
      header: const ProfileSectionHeader(title: 'ÜNVANLAR'),
      child: user.activeTitles.isEmpty
          ? const ProfileEmptyCard(
              'Aktif ünvan bulunmuyor.',
              icon: Icons.workspace_premium_outlined,
            )
          : Column(
              children: [
                for (var i = 0; i < user.activeTitles.length; i++)
                  ProfileTitleRow(
                    title: user.activeTitles[i],
                    isLast: i == user.activeTitles.length - 1,
                  ),
              ],
            ),
    );
  }
}

class ProfileTitleRow extends StatelessWidget {
  final UserTitle title;
  final bool isLast;
  const ProfileTitleRow({super.key, required this.title, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = profileTitleColor(title.titleType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.workspace_premium, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.displayLabel,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                    'Başlangıç: ${profileDateFormat.format(title.startDate)}',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}