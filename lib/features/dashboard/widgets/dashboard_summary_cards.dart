import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/safe_date.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../../tasks/models/task_models.dart';
import '../../tasks/providers/task_providers.dart';

class DashboardHeader extends ConsumerWidget {
  final String? userName;
  final bool isAdmin;
  final bool isGuest;
  const DashboardHeader(
      {super.key, this.userName, this.isAdmin = false, this.isGuest = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    // SafeDate: `DateFormat(..., 'tr_TR')` throws LocaleDataException when the
    // locale data is missing — which used to abort the AppShell Scaffold build
    // and make the bottom navigation bar vanish.
    final formatted = SafeDate.longWithWeekday(now);
    final firstName = userName?.split(' ').first;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: AppColors.panelBg,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.panelBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName != null ? 'Merhaba, $firstName' : 'SARGE Panel',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatted,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              final uid = ref.read(authStateProvider).valueOrNull?.uid;
              if (uid != null) context.push('/profile/$uid');
            },
            child: Icon(Icons.person_outline,
                size: 22, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class DashboardMyTasksCard extends ConsumerWidget {
  const DashboardMyTasksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) return const SizedBox.shrink();

    final tasksAsync = ref.watch(myActiveTasksProvider(uid));

    return tasksAsync.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.tasksGreen, strokeWidth: 2)),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        child: Text('Görevler yüklenemedi: $e',
            style: const TextStyle(color: AppColors.error)),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.task_alt,
                    color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aktif göreviniz yok. Görevleriniz burada görünecek.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                Flexible(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => context.push('/tasks'),
                    child: const Text(
                      'Git →',
                      style: TextStyle(
                          color: AppColors.tasksGreen, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: tasks
              .map((task) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.6),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd),
                      onTap: () => context.push('/tasks', extra: task.id),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 32,
                              decoration: BoxDecoration(
                                color: task.status == TaskStatus.pendingApproval
                                    ? AppColors.warning
                                    : task.status == TaskStatus.inProgress
                                        ? AppColors.panelBlue
                                        : AppColors.tasksGreen,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(task.title,
                                      style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    task.statusLabel,
                                    style: TextStyle(
                                      color: task.status ==
                                              TaskStatus.pendingApproval
                                          ? AppColors.warning
                                          : task.status == TaskStatus.inProgress
                                              ? AppColors.panelBlue
                                              : AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.tasksGreen
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: AppColors.tasksGreen
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Text('${task.points} puan',
                                  style: const TextStyle(
                                      color: AppColors.tasksGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 16, color: AppColors.border),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class DashboardGuestBanner extends StatelessWidget {
  const DashboardGuestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/register'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.panelBlue.withValues(alpha: 0.25),
              AppColors.panelBg
            ],
          ),
          border: Border(
            bottom: BorderSide(
                color: AppColors.panelBlue.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.rocket_launch_outlined,
                color: AppColors.panelBlue, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "SARGE'a Katıl! Ücretsiz üye ol →",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class DashboardJoinCtaCard extends StatelessWidget {
  const DashboardJoinCtaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
            color: AppColors.panelBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined,
                  color: AppColors.panelBlue, size: 20),
              const SizedBox(width: 8),
              // Flexible + ellipsis: this Row has no other flexible child, so a
              // long title on a narrow phone would overflow horizontally.
              Flexible(
                child: Text('SARGE Topluluğuna Katıl',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Depo erişimi, görevler, takım çalışması ve daha fazlası için ücretsiz üye olun!',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/register'),
              icon: const Icon(Icons.person_add_alt, size: 16),
              label: const Text('Ücretsiz Üye Ol'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.panelBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardLeaderboardCard extends ConsumerStatefulWidget {
  const DashboardLeaderboardCard({super.key});

  @override
  ConsumerState<DashboardLeaderboardCard> createState() =>
      _DashboardLeaderboardCardState();
}

class _DashboardLeaderboardCardState
    extends ConsumerState<DashboardLeaderboardCard> {
  String? _teamId;

  /// Null => current (live) week; otherwise a past archived week key.
  String? _weekKey;

  static String _weekLabel(String weekKey) {
    try {
      final parts = weekKey.split('-');
      if (parts.length != 3) return weekKey;
      final monday = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final sunday = monday.add(const Duration(days: 6));
      return '${SafeDate.dayMonth(monday)} – ${SafeDate.dayMonth(sunday)}';
    } catch (_) {
      return weekKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = _weekKey == null
        ? ref.watch(leaderboardProvider)
        : ref.watch(weeklyArchiveLeaderboardProvider(_weekKey!));
    final teamsAsync = ref.watch(clubTeamsProvider);
    final archiveWeeksAsync = ref.watch(weeklyArchiveWeeksProvider);
    final metaAsync = ref.watch(weeklyMetaProvider);
    final currentUid = ref.watch(currentAppUserProvider).valueOrNull?.uid;
    final allTeams = teamsAsync.valueOrNull ?? [];
    final teams = currentUid == null
        ? const <ClubTeam>[]
        : allTeams.where((t) => t.memberIds.contains(currentUid)).toList();
    final selectedTeamId = _teamId ?? (teams.isNotEmpty ? teams.first.id : null);
    final validTeamId = (selectedTeamId != null && teams.any((t) => t.id == selectedTeamId))
        ? selectedTeamId
        : (teams.isNotEmpty ? teams.first.id : null);
    final archiveWeeks = archiveWeeksAsync.valueOrNull ?? const <String>[];
    final meta = metaAsync.valueOrNull ?? const <String, dynamic>{};

    final weekItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('Bu Hafta')),
      ...archiveWeeks.map((wk) => DropdownMenuItem<String?>(
            value: wk,
            child: Text(_weekLabel(wk)),
          )),
    ];

    String? resetText;
    final lastReset = meta['lastResetAt'];
    if (lastReset is Timestamp) {
      final dt = SafeDate.dayMonthCommaTime(lastReset.toDate());
      resetText = "Bu hafta: $dt'de sıfırlandı";
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Takım',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: validTeamId,
                          isDense: true,
                          dropdownColor: AppColors.surface2,
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 12),
                          hint: Text('Takım Seç',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          items: [
                            ...teams.map((t) => DropdownMenuItem<String?>(
                                  value: t.id,
                                  child: Text(t.name,
                                      style: const TextStyle(fontSize: 12)),
                                )),
                          ],
                          onChanged: (v) => setState(() => _teamId = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Hafta',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _weekKey,
                          isDense: true,
                          dropdownColor: AppColors.surface2,
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 12),
                          items: weekItems,
                          onChanged: (v) => setState(() => _weekKey = v),
                        ),
                      ),
                    ),
                  ],
                ),
                if (resetText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      resetText,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          leaderboardAsync.when(
            data: (entries) {
              ClubTeam? selectedTeam;
              if (selectedTeamId != null) {
                for (final t in teams) {
                  if (t.id == selectedTeamId) {
                    selectedTeam = t;
                    break;
                  }
                }
              }
              final selectedMemberUids =
                  selectedTeam?.memberIds.toSet() ?? <String>{};
              final filtered = selectedTeamId == null
                  ? entries
                  : entries
                      .where((e) => selectedMemberUids.contains(e.uid))
                      .toList();
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('Henüz puan verisi yok.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                );
              }
              final top5 = filtered.take(5).toList();
              return Column(
                children: [
                  ...top5.asMap().entries.map((e) {
                    final isLast = e.key == top5.length - 1;
                    return Column(
                      children: [
                        DashboardLeaderboardRow(
                          rank: e.key + 1,
                          entry: e.value,
                          pointsLabel: _weekKey == null
                              ? 'Bu Hafta: ${e.value.weeklyPoints} puan'
                              : '${e.value.points} puan',
                        ),
                        if (!isLast)
                          Divider(height: 1, color: AppColors.border),
                      ],
                    );
                  }),
                  Divider(height: 1, color: AppColors.border),
                  InkWell(
                    onTap: () => selectedTeamId != null
                        ? context.push('/team/$selectedTeamId')
                        : context.push('/team'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Tümünü Gör',
                              style: TextStyle(
                                  color: AppColors.panelBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward,
                              size: 14, color: AppColors.panelBlue),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.panelBlue)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Hata: $e',
                  style: const TextStyle(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardLeaderboardRow extends ConsumerWidget {
  final int rank;
  final LeaderboardEntry entry;
  final String? pointsLabel;

  const DashboardLeaderboardRow(
      {super.key,
      required this.rank,
      required this.entry,
      this.pointsLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medalColor = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.textSecondary,
    };

    return InkWell(
      onTap: () => context.push('/profile/${entry.uid}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: medalColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surface2,
              backgroundImage: entry.photoUrl != null &&
                      entry.photoUrl!.isNotEmpty
                  ? NetworkImage(entry.photoUrl!)
                  : null,
              child: entry.photoUrl == null || entry.photoUrl!.isEmpty
                  ? Icon(Icons.person_outline,
                      size: 12, color: AppColors.textSecondary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.displayName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              pointsLabel ?? '${entry.points} puan',
              style: const TextStyle(
                color: AppColors.panelBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}