import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/theme/app_colors.dart';

final profileDateFormat = DateFormat('dd.MM.yyyy');

/// Rank priority used for the "highest active title" showcase.
/// Lower number = higher priority.
const Map<String, int> profileTitlePriority = {
  TitleType.boardPresident: 0,
  TitleType.boardMember: 1,
  TitleType.captain: 2,
  TitleType.admin: 3,
  TitleType.unitLead: 4,
  TitleType.honoraryMember: 5,
  TitleType.member: 6,
};

int profileTitleRank(String titleType) => profileTitlePriority[titleType] ?? 99;

UserTitle? highestProfileTitle(AppUser user) {
  final active = user.activeTitles;
  if (active.isEmpty) return null;
  final list = [...active];
  list.sort(
      (a, b) => profileTitleRank(a.titleType).compareTo(profileTitleRank(b.titleType)));
  return list.first;
}

Color profileTitleColor(String titleType) {
  switch (titleType) {
    case TitleType.boardPresident:
      return AppColors.sargeGold;
    case TitleType.boardMember:
      return AppColors.teamAccent;
    case TitleType.captain:
      return AppColors.info;
    case TitleType.admin:
      return AppColors.error;
    case TitleType.unitLead:
      return AppColors.warning;
    case TitleType.honoraryMember:
      return AppColors.primaryGreen;
    case TitleType.member:
    default:
      return AppColors.depoAccent;
  }
}

class ProfileSectionHeader extends StatelessWidget {
  final String title;
  const ProfileSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class ProfileSectionTitleWithCard extends StatelessWidget {
  final Widget header;
  final Widget child;
  const ProfileSectionTitleWithCard({
    super.key,
    required this.header,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class ProfileEmptyCard extends StatelessWidget {
  final String text;
  final IconData icon;
  const ProfileEmptyCard(
    this.text, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isLast;
  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.settingsAccent,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))),
          const SizedBox(width: 12),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class ProfileTitleChip extends StatelessWidget {
  final UserTitle title;
  const ProfileTitleChip({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final color = profileTitleColor(title.titleType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            title.displayLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}