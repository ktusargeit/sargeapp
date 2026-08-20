import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/platform_image.dart';
import '../../../core/widgets/comment_tile.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/custom_delete_button.dart';
import '../../announcements/models/announcement_models.dart';
import '../../announcements/providers/announcement_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../../tasks/models/task_models.dart';
import '../../tasks/providers/task_providers.dart';

/// Home / Panel screen - kulüp merkezli dashboard.
class DashboardScreen extends ConsumerStatefulWidget {
  final String? initialAnnouncementId;
  const DashboardScreen({super.key, this.initialAnnouncementId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final targetId = widget.initialAnnouncementId;
    if (targetId != null && targetId.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openAnnouncement(targetId));
    }
  }

  Future<void> _openAnnouncement(String id) async {
    if (!mounted) return;
    final announcements = ref.read(announcementsProvider).valueOrNull ?? [];
    Announcement? found;
    for (final a in announcements) {
      if (a.id == id) {
        found = a;
        break;
      }
    }
    if (found == null || !mounted) return;
    final target = found;

    final uid = ref.read(authStateProvider).value?.uid;
    final isAdminUser = ref.read(isAdminProvider);
    bool canComment = isAdminUser;
    if (!canComment && uid != null) {
      if (target.isClubWide) {
        canComment = true;
      } else {
        final allTeams = ref.read(clubTeamsProvider).valueOrNull ?? [];
        for (final teamId in target.targetTeamIds) {
          try {
            final team = allTeams.firstWhere((t) => t.id == teamId);
            if (team.memberIds.contains(uid)) {
              canComment = true;
              break;
            }
          } catch (_) {}
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AnnouncementDetailSheet(
        announcement: target,
        canComment: canComment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(announcementsProvider);
    final appUser = ref.watch(currentAppUserProvider).value;
    final isAdmin = appUser?.isAdmin ?? false;
    final authState = ref.watch(authStateProvider);
    final isGuest = authState.value == null;

    return Scaffold(
      backgroundColor: AppColors.panelBg,
      body: Column(
        children: [
          _Header(
              userName: appUser?.displayName,
              isAdmin: isAdmin,
              isGuest: isGuest),
          if (isGuest) const _GuestBanner(),
          const Divider(height: 1, color: Color(0xFF1E3A5F)),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.panelBlue,
              onRefresh: () async =>
                  ref.refresh(announcementsProvider.future),
              child: ListView(
                padding:
                    const EdgeInsets.all(AppConstants.spacingMd),
                children: [
                   Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'HAFTALIK LİDERLİK TABLOSU',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const _LeaderboardCard(),
                  const SizedBox(height: AppConstants.spacingLg),
                  if (!isGuest && appUser != null) ...[
                     Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'GÖREVLERİM',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const _MyTasksCard(),
                    const SizedBox(height: AppConstants.spacingLg),
                  ],
                   Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'DUYURULAR & ETKİNLİKLER',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  announcements.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return EmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'Henüz duyuru yok',
                          subtitle: isAdmin
                              ? 'İlk duyuruyu siz oluşturun!'
                              : 'Yeni duyurular burada görünecek.',
                          actionLabel:
                              isAdmin ? 'Duyuru Oluştur' : null,
                          onAction: isAdmin
                              ? () => _showAnnouncementDialog(
                                  context, ref)
                              : null,
                        );
                      }
                      return Column(
                        children: items
                            .take(5)
                            .map((a) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 12),
                                  child: _AnnouncementCard(
                                    announcement: a,
                                    isAdmin: isAdmin,
                                  ),
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(
                            color: AppColors.panelBlue),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                            'Duyurular yüklenemedi: $e',
                            style: const TextStyle(
                                color: AppColors.error)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isGuest) const _JoinCtaCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _showAnnouncementDialog(context, ref),
              backgroundColor: AppColors.panelBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Duyuru',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            )
          : null,
    );
  }

  void _showAnnouncementDialog(
      BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AnnouncementDialog(),
    );
  }
}

class _MyTasksCard extends ConsumerWidget {
  const _MyTasksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Single source of truth — Riverpod caches this AsyncValue so the
    // widget no longer flickers/vanishes when the parent rebuilds.
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
                      onTap: () =>
                          context.push('/tasks', extra: task.id),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 32,
                              decoration: BoxDecoration(
                                color: task.status ==
                                        TaskStatus.pendingApproval
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(task.title,
                                      style:  TextStyle(
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
                                          : task.status ==
                                                  TaskStatus.inProgress
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

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/register'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.panelBlue.withValues(alpha: 0.25),
              AppColors.panelBg
            ],
          ),
          border: Border(
            bottom: BorderSide(
                color:
                    AppColors.panelBlue.withValues(alpha: 0.4)),
          ),
        ),
        child:  Row(
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

class _JoinCtaCard extends StatelessWidget {
  const _JoinCtaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius:
            BorderRadius.circular(AppConstants.radiusMd),
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
              Text('SARGE Topluluğuna Katıl',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
           Text(
            'Depo erişimi, görevler, takım çalışması ve daha fazlası için ücretsiz üye olun!',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4),
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

class _Header extends ConsumerWidget {
  final String? userName;
  final bool isAdmin;
  final bool isGuest;
  const _Header(
      {this.userName, this.isAdmin = false, this.isGuest = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final formatted =
        DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(now);
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
                  firstName != null
                      ? 'Merhaba, $firstName'
                      : 'SARGE Panel',
                  style:  TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatted,
                  style:  TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              final uid =
                  ref.read(authStateProvider).value?.uid;
              if (uid != null) context.push('/profile/$uid');
            },
            child:  Icon(Icons.person_outline,
                size: 22, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends ConsumerStatefulWidget {
  const _LeaderboardCard();

  @override
  ConsumerState<_LeaderboardCard> createState() => _LeaderboardCardState();
}

class _LeaderboardCardState extends ConsumerState<_LeaderboardCard> {
  String? _teamId;

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final teamsAsync = ref.watch(clubTeamsProvider);
    final currentUid = ref.watch(currentAppUserProvider).value?.uid;
    final allTeams = teamsAsync.valueOrNull ?? [];
    // Yalnızca kullanıcının üye olduğu gerçek takımlar seçilebilir.
    final teams = currentUid == null
        ? const <ClubTeam>[]
        : allTeams.where((t) => t.memberIds.contains(currentUid)).toList();
    // İlk takım otomatik seçilir; böylece "Tüm Takımlar" yokken liderlik
    // tablosu her zaman somut bir takıma göre filtrelenir.
    final selectedTeamId = _teamId ?? (teams.isNotEmpty ? teams.first.id : null);

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
          // Team filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                 Text('Takım',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                      value: selectedTeamId,
                      isDense: true,
                      dropdownColor: AppColors.surface2,
                      style:  TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      hint:  Text('Takım Seç',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      items: [
                        ...teams.map((t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(t.name, style: const TextStyle(fontSize: 12)),
                            )),
                      ],
                      onChanged: (v) => setState(() => _teamId = v),
                    ),
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
                return  Padding(
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
                        _LeaderboardRow(rank: e.key + 1, entry: e.value),
                        if (!isLast)
                           Divider(height: 1, color: AppColors.border),
                      ],
                    );
                  }),
                   Divider(height: 1, color: AppColors.border),
                  InkWell(
                    // Seçili takımın doğrudan puan tablosu ekranına git.
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

class _LeaderboardRow extends ConsumerWidget {
  final int rank;
  final LeaderboardEntry entry;

  const _LeaderboardRow(
      {required this.rank, required this.entry});

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
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
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
              backgroundImage:
                  entry.photoUrl != null &&
                          entry.photoUrl!.isNotEmpty
                      ? NetworkImage(entry.photoUrl!)
                      : null,
              child: entry.photoUrl == null ||
                      entry.photoUrl!.isEmpty
                  ?  Icon(Icons.person_outline,
                      size: 12,
                      color: AppColors.textSecondary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.displayName,
                style:  TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${entry.points} puan',
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

class _AnnouncementCard extends ConsumerWidget {
  final Announcement announcement;
  final bool isAdmin;

  const _AnnouncementCard(
      {required this.announcement, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = announcement.eventStatus;
    final Color? statusColor = switch (status) {
      'Geçti' => AppColors.textSecondary,
      'Çok Yakında' => AppColors.warning,
      'Yakında' => AppColors.success,
      _ => null,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius:
            BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (announcement.imageUrl != null &&
                announcement.imageUrl!.isNotEmpty)
              ClipRRect(
                child: Image.network(
                  announcement.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: AppColors.surface2,
                    child:  Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          style:  TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _AnnouncementCommentBadge(announcementId: announcement.id),
                      if (status.isNotEmpty && statusColor != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor
                                .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(4),
                            border: Border.all(
                                color: statusColor
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (announcement.eventDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                         Icon(Icons.event_outlined,
                            size: 13,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy', 'tr_TR')
                              .format(announcement.eventDate!),
                          style:  TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    announcement.description,
                    style:  TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                       Icon(Icons.person_outline,
                          size: 13,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        announcement.createdByName,
                        style:  TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('dd MMM yyyy', 'tr_TR')
                            .format(announcement.createdAt),
                        style: TextStyle(
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                            fontSize: 11),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        AppIconButton(
                          icon: Icons.edit_outlined,
                          iconSize: 16,
                          color: AppColors.panelBlue,
                          tooltip: 'Düzenle',
                          onTap: () => _editAnnouncement(
                              context, announcement),
                        ),
                        CustomDeleteButton(
                          onPressed: () => _deleteAnnouncement(
                              context, announcement),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authStateProvider).value?.uid;
    final isAdminUser = ref.read(isAdminProvider);

    // Determine if user can comment: admin + targeted users
    bool canComment = isAdminUser;
    if (!canComment && uid != null) {
      if (announcement.isClubWide) {
        canComment = true; // all users can comment on club-wide posts
      } else {
        final teamsAsync = ref.watch(clubTeamsProvider);
        final allTeams = teamsAsync.valueOrNull ?? [];
        for (final teamId in announcement.targetTeamIds) {
          try {
            final team = allTeams.firstWhere((t) => t.id == teamId);
            if (team.memberIds.contains(uid)) {
              canComment = true;
              break;
            }
          } catch (_) {}
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AnnouncementDetailSheet(
        announcement: announcement,
        canComment: canComment,
      ),
    );
  }

  void _editAnnouncement(
      BuildContext context, Announcement announcement) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _AnnouncementDialog(existing: announcement),
    );
  }

  void _deleteAnnouncement(
      BuildContext context, Announcement announcement) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duyuruyu Sil'),
        content: Text(
            '"${announcement.title}" silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      if (!context.mounted) return;
      final container = ProviderScope.containerOf(context);
      await runDeleteWithFeedback(
        context: context,
        successMessage: 'Duyuru başarıyla silindi.',
        operation: () => container
            .read(announcementRepositoryProvider)
            .deleteAnnouncement(announcement.id),
      );
    });
  }
}

class _AnnouncementDialog extends ConsumerStatefulWidget {
  final Announcement? existing;

  const _AnnouncementDialog({this.existing});

  @override
  ConsumerState<_AnnouncementDialog> createState() =>
      _AnnouncementDialogState();
}

class _AnnouncementDialogState
    extends ConsumerState<_AnnouncementDialog> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _descCtrl = TextEditingController(
      text: widget.existing?.description ?? '');
  PickedImage? _pickedImage;
  DateTime? _eventDate;
  bool _notifyAll = false;
  bool _loading = false;
  String _targetType = 'club';
  List<String> _targetTeamIds = const [];

  @override
  void initState() {
    super.initState();
    _eventDate = widget.existing?.eventDate;
    _notifyAll = widget.existing?.notifyAll ?? false;
    _targetType = widget.existing?.targetType ?? 'club';
    _targetTeamIds = widget.existing?.targetTeamIds ?? const [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked =
        await PickedImage.pick(ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = picked);
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _eventDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Başlık ve açıklama zorunludur'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final user =
          ref.read(authStateProvider).value;
      final repo =
          ref.read(announcementRepositoryProvider);
      String? imageUrl = widget.existing?.imageUrl;
      if (_pickedImage != null) {
        final tempId = DateTime.now()
            .millisecondsSinceEpoch
            .toString();
        imageUrl = await repo.uploadImage(
          tempId,
          file: _pickedImage!.dartFile,
          bytes: _pickedImage!.bytes,
        );
      }

      if (widget.existing == null) {
        await repo.addAnnouncement(
          title: _titleCtrl.text,
          description: _descCtrl.text,
          imageUrl: imageUrl,
          eventDate: _eventDate,
          createdBy: user?.uid ?? '',
          createdByName:
              user?.displayName ?? 'Kullanıcı',
          notifyAll: _notifyAll,
          targetType: _targetType,
          targetTeamIds: _targetTeamIds,
        );
      } else {
        await repo.updateAnnouncement(
          widget.existing!.id,
          title: _titleCtrl.text,
          description: _descCtrl.text,
          imageUrl: imageUrl,
          eventDate: _eventDate,
          notifyAll: _notifyAll,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Yeni Duyuru'
          : 'Duyuruyu Düzenle'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                style:  TextStyle(
                    color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Başlık *',
                    hintText: 'Duyuru başlığı'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                style:  TextStyle(
                    color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Açıklama *',
                    hintText: 'Duyuru detayı'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(
                          Icons.photo_outlined, size: 18),
                      label: Text(_pickedImage != null
                          ? 'Görsel Seçildi'
                          : (widget.existing?.imageUrl != null
                              ? 'Görsel Değiştir'
                              : 'Görsel Ekle')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: _pickEventDate,
                      icon: const Icon(
                          Icons.event_outlined, size: 18),
                      label: Text(
                        _eventDate != null
                            ? DateFormat('dd MMM yyyy',
                                    'tr_TR')
                                .format(_eventDate!)
                            : 'Etkinlik Tarihi',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 8),
              _TargetAudienceSelector(
                targetType: _targetType,
                targetTeamIds: _targetTeamIds,
                onChanged: (type, teamIds) => setState(() {
                  _targetType = type;
                  _targetTeamIds = teamIds;
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: AppColors.panelBlue),
                  const SizedBox(width: 8),
                   Flexible(
                    child: Text('Herkese bildirim gönder',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13)),
                  ),
                  Switch(
                    value: _notifyAll,
                    activeThumbColor: AppColors.panelBlue,
                    onChanged: (v) =>
                        setState(() => _notifyAll = v),
                  ),
                ],
              ),
              if (_pickedImage != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: PlatformImageFile(
                      bytes: _pickedImage!.bytes,
                      file: _pickedImage!.dartFile,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2))
              : const Text('Yayınla'),
        ),
      ],
    );
  }
}

/// Multi-team target audience selector.
class _TargetAudienceSelector extends ConsumerWidget {
  final String targetType;
  final List<String> targetTeamIds;
  final void Function(String type, List<String> teamIds) onChanged;

  const _TargetAudienceSelector({
    required this.targetType,
    required this.targetTeamIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final teams = teamsAsync.valueOrNull ?? [];

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.public, size: 16, color: AppColors.panelBlue),
            const SizedBox(width: 8),
             Text('Hedef Kitle',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: targetType,
                  isDense: true,
                  dropdownColor: AppColors.surface2,
                  style:  TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'club', child: Text('Tüm Kulübe')),
                    DropdownMenuItem(value: 'team', child: Text('Belirli Takımlara')),
                  ],
                  onChanged: (v) => onChanged(v ?? 'club', const []),
                ),
              ),
            ),
          ],
        ),
        if (targetType == 'team') ...[
          const SizedBox(height: 8),
          teamsAsync.when(
            data: (_) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: teams.map((t) => FilterChip(
                  label: Text(t.name, style: const TextStyle(fontSize: 11)),
                  selected: targetTeamIds.contains(t.id),
                  selectedColor: AppColors.panelBlue.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.panelBlue,
                  onSelected: (selected) {
                    final newList = List<String>.from(targetTeamIds);
        if (selected) {
          newList.add(t.id);
        } else {
          newList.remove(t.id);
        }
        onChanged('team', newList);
      },
    )).toList(),
              ),
            ),
            loading: () => const SizedBox(height: 20,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ANNOUNCEMENT COMMENT BADGE (subcollection count)
// ═══════════════════════════════════════════════════════════════════════

class _AnnouncementCommentBadge extends ConsumerWidget {
  final String announcementId;
  const _AnnouncementCommentBadge({required this.announcementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('announcements')
          .doc(announcementId)
          .collection('comments')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.panelBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.panelBlue.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💬', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text('$count',
                  style: const TextStyle(
                      color: AppColors.panelBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ANNOUNCEMENT DETAIL SHEET (full screen + subcollection comments)
// ═══════════════════════════════════════════════════════════════════════

class _AnnouncementDetailSheet extends ConsumerStatefulWidget {
  final Announcement announcement;
  final bool canComment;

  const _AnnouncementDetailSheet({
    required this.announcement,
    required this.canComment,
  });

  @override
  ConsumerState<_AnnouncementDetailSheet> createState() =>
      _AnnouncementDetailSheetState();
}

class _AnnouncementDetailSheetState
    extends ConsumerState<_AnnouncementDetailSheet> {
  final _commentCtrl = TextEditingController();
  List<PickedImage> _commentImages = [];
  bool _sending = false;
  Map<String, dynamic>? _replyTo;

  String get _threadKey =>
      threadKeyFor('announcement_comment', widget.announcement.id);

  @override
  void initState() {
    super.initState();
    // Presence: mark this announcement thread as open.
    ref.read(presenceServiceProvider).setActiveThread(_threadKey);
    // Opening the thread resets its unread counter.
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      ref.read(notificationServiceProvider).resetThread(
            uid,
            'announcement_comment',
            widget.announcement.id,
          );
    }
  }

  @override
  void dispose() {
    ref.read(presenceServiceProvider).clearActiveThread(_threadKey);
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty && _commentImages.isEmpty) return;

    setState(() => _sending = true);
    try {
      final user = ref.read(authStateProvider).value;
      final uid = user?.uid ?? '';
      final name = user?.displayName ?? 'Kullanıcı';
      final isAdmin = ref.read(isAdminProvider);
      final firestore = ref.read(firestoreProvider);
      final replyTo = _replyTo;

      final imageUrls = <String>[];
      for (final img in _commentImages) {
        final tempId = 'announcement_comment_${DateTime.now().microsecondsSinceEpoch}';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('announcement_comments/$tempId.jpg');
        // Client-side compression: max-1280px JPEG at ~75% quality.
        final compressed = await img.compressedUploadBytes();
        if (compressed.isNotEmpty) {
          await storageRef.putData(compressed);
        } else if (img.bytes != null) {
          await storageRef.putData(img.bytes!);
        } else if (img.dartFile != null) {
          await storageRef.putFile(img.dartFile!);
        }
        imageUrls.add(await storageRef.getDownloadURL());
      }

      await firestore
          .collection('announcements')
          .doc(widget.announcement.id)
          .collection('comments')
          .add({
        'senderUid': uid,
        'senderName': name,
        'text': text,
        'imageUrls': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'isAdmin': isAdmin,
        'replyToId': replyTo?['id'],
        'replyToText': replyTo?['text'],
        'replyToAuthor': replyTo?['senderName'],
        'replyToUid': replyTo?['senderUid'],
      });

      // Notifications are created server-side by `notifyAnnouncementComment`
      // (grouped per thread + presence-aware), so the client only persists the
      // comment here.

      _commentCtrl.clear();
      setState(() {
        _commentImages = [];
        _replyTo = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Yorum gönderilemedi: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcement = widget.announcement;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final status = announcement.eventStatus;
    final Color? statusColor = switch (status) {
      'Geçti' => AppColors.textSecondary,
      'Çok Yakında' => AppColors.warning,
      'Yakında' => AppColors.success,
      _ => null,
    };

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.9,
      maxChildSize: 1.0,
      expand: true,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Title + status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          style:  TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (status.isNotEmpty && statusColor != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Author + date
                  Row(
                    children: [
                       Icon(Icons.person_outline,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(announcement.createdByName,
                          style:  TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 12),
                       Icon(Icons.access_time,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm', 'tr_TR')
                            .format(announcement.createdAt),
                        style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                    ],
                  ),
                  if (announcement.eventDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.event_outlined,
                            size: 13, color: AppColors.panelBlue),
                        const SizedBox(width: 4),
                        Text(
                          'Etkinlik: ${DateFormat('dd MMM yyyy', 'tr_TR').format(announcement.eventDate!)}',
                          style: const TextStyle(
                              color: AppColors.panelBlue, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    announcement.description,
                    style:  TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  if (announcement.imageUrl != null &&
                      announcement.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        announcement.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                   Divider(color: AppColors.border),
                  // Comments header
                   Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          'Yorumlar',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Comments list (subcollection stream)
                  _AnnouncementCommentsList(
                    announcementId: announcement.id,
                    currentUid: ref.read(authStateProvider).value?.uid,
                    onReply: (data) => setState(() => _replyTo = data),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Comment input (only if user can comment)
            if (widget.canComment)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration:  BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyTo != null) ...[
                      ReplyPreviewBar(
                        author: _replyTo!['senderName'] as String? ?? 'Bilinmeyen',
                        text: _replyTo!['text'] as String? ?? '',
                        onClear: () => setState(() => _replyTo = null),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_commentImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _commentImages.asMap().entries.map((e) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: PlatformImageFile(
                                    bytes: e.value.bytes,
                                    file: e.value.dartFile,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _commentImages.removeAt(e.key)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                          color: AppColors.error, shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image_outlined, size: 20),
                          color: AppColors.textSecondary,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            final imgs = await PickedImage.pickMultiple();
                            if (imgs.isNotEmpty && mounted) {
                              setState(() =>
                                  _commentImages = [..._commentImages, ...imgs]);
                            }
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            style:  TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Yorum yaz...',
                              hintStyle:  TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                              filled: true,
                              fillColor: AppColors.surface2,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sending ? null : _sendComment,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _sending
                                  ? AppColors.panelBlue.withValues(alpha: 0.5)
                                  : AppColors.panelBlue,
                              shape: BoxShape.circle,
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded,
                                    size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Live comments list from the subcollection.
class _AnnouncementCommentsList extends ConsumerWidget {
  final String announcementId;
  final String? currentUid;
  final void Function(Map<String, dynamic>) onReply;
  const _AnnouncementCommentsList({
    required this.announcementId,
    this.currentUid,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('announcements')
          .doc(announcementId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.panelBlue),
            ),
          );
        }
        final comments = snapshot.data?.docs ?? [];
        if (comments.isEmpty) {
          return  Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('Henüz yorum yapılmadı.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          );
        }
        return Column(
          children: comments.map((doc) {
            final data = doc.data();
            return CommentTile(
              data: data,
              isMine: data['senderUid'] == currentUid,
              onReply: () => onReply({
                'id': doc.id,
                'text': data['text'] as String? ?? '',
                'senderName': data['senderName'] as String? ?? '',
                'senderUid': data['senderUid'] as String? ?? '',
              }),
            );
          }).toList(),
        );
      },
    );
  }
}
