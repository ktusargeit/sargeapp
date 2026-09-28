import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/app_colors.dart';
import 'profile_common.dart';

// ---------------------------------------------------------------------------
// EXPERIENCE TAB — merged timeline + awards.
// ---------------------------------------------------------------------------

class ProfileExperienceSection extends StatelessWidget {
  final AppUser user;
  const ProfileExperienceSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final entries = buildProfileTimeline(user);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSectionHeader(title: 'DENEYİM'),
          if (entries.isEmpty)
            const ProfileEmptyCard(
              'Henüz geçmiş kaydı yok — kulüpteki yolculuğun burada birikecek.',
              icon: Icons.auto_awesome,
            )
          else
            ProfileTimeline(entries: entries),
          const SizedBox(height: AppConstants.spacingLg),
          const ProfileSectionHeader(title: 'ÖDÜLLER & BAŞARILAR'),
          if (user.awards.isEmpty)
            const ProfileEmptyCard('Henüz ödül eklenmemiş.',
                icon: Icons.emoji_events_outlined)
          else
            ProfileAwardsGrid(awards: user.awards),
        ],
      ),
    );
  }
}

class ProfileExperienceEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int sortMillis;
  const ProfileExperienceEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.sortMillis,
  });
}

List<ProfileExperienceEntry> buildProfileTimeline(AppUser user) {
  final entries = <ProfileExperienceEntry>[];

  for (final t in user.formerTitles) {
    entries.add(ProfileExperienceEntry(
      icon: Icons.workspace_premium_outlined,
      color: profileTitleColor(t.titleType),
      title: t.displayLabel,
      subtitle: _formatProfileRange(t.startDate, t.endDate),
      sortMillis: t.startDate.millisecondsSinceEpoch,
    ));
  }

  // NOTE: Eski serbest metin "Geçmiş Takımlar" kaynağı (`users.pastTeams`)
  // UI'dan kaldırıldı — geçmiş deneyim artık TEK kaynaktan, yapısal
  // `pastExperiences` array'inden okunur (aşağıdaki döngü).

  // AŞAMA 4.3 — user-authored structured entries (`pastExperiences`), merged
  // with the automatically retired titles above into one timeline.
  for (final e in user.pastExperiences) {
    entries.add(ProfileExperienceEntry(
      icon:
          e.isBoard ? Icons.workspace_premium_outlined : Icons.groups_outlined,
      color: e.isBoard ? AppColors.sargeGold : AppColors.teamAccent,
      title: e.headline,
      subtitle: e.periodLabel,
      sortMillis: DateTime(e.startYear).millisecondsSinceEpoch,
    ));
  }

  entries.sort((a, b) => b.sortMillis.compareTo(a.sortMillis));
  return entries;
}

String _formatProfileRange(DateTime start, DateTime? end) {
  final startStr = profileDateFormat.format(start);
  final endStr = end != null ? profileDateFormat.format(end) : 'Devam ediyor';
  return '$startStr - $endStr';
}

class ProfileTimeline extends StatelessWidget {
  final List<ProfileExperienceEntry> entries;
  const ProfileTimeline({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: entries.asMap().entries.map((e) {
        final idx = e.key;
        final entry = e.value;
        final isLast = idx == entries.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            entry.color.withValues(alpha: 0.3),
                            entry.color.withValues(alpha: 0.12),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: entry.color),
                      ),
                      child: Icon(entry.icon, size: 15, color: entry.color),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(width: 2, color: AppColors.border),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.surface2, AppColors.surface],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: entry.color.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(entry.subtitle,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ProfileAwardsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> awards;
  const ProfileAwardsGrid({super.key, required this.awards});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: awards.map((a) {
        final title = a['title'] as String? ?? '';
        final desc = a['description'] as String? ?? '';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface2, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.sargeGold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.sargeGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_outlined,
                    color: AppColors.sargeGold, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              if (desc.isNotEmpty)
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
