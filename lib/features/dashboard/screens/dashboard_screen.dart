import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/platform_image.dart';
import '../../announcements/models/announcement_models.dart';
import '../../announcements/providers/announcement_providers.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../../tasks/models/task_models.dart';

/// Home / Panel screen - kulüp merkezli dashboard.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
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
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
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
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
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

class _MyTasksCard extends ConsumerStatefulWidget {
  const _MyTasksCard();

  @override
  ConsumerState<_MyTasksCard> createState() => _MyTasksCardState();
}

class _MyTasksCardState extends ConsumerState<_MyTasksCard> {
  String? _selectedTeamId;

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final teamsAsync = ref.watch(clubTeamsProvider);
    // Get teams the current user is a member of
    final userTeams = teamsAsync.valueOrNull
            ?.where((t) => t.memberIds.contains(uid))
            .toList() ??
        [];

    // Build query
    Query<Map<String, dynamic>> taskQuery =
        ref.read(firestoreProvider).collection('tasks').where(
              'assignedTo',
              isEqualTo: uid,
            );

    if (_selectedTeamId != null && _selectedTeamId!.isNotEmpty) {
      taskQuery =
          taskQuery.where('teamId', isEqualTo: _selectedTeamId);
    }

    taskQuery = taskQuery
        .where('status',
            whereIn: ['assigned', 'inProgress', 'pendingApproval'])
        .orderBy('createdAt', descending: true)
        .limit(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team picker
        if (userTeams.length > 1) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedTeamId,
                isDense: true,
                dropdownColor: AppColors.surface2,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12),
                hint: const Text('Takım seçin',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12)),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tüm Takımlar',
                        style: TextStyle(
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                            fontSize: 12)),
                  ),
                  ...userTeams.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name,
                          style:
                              const TextStyle(fontSize: 12)))),
                ],
                onChanged: (v) =>
                    setState(() => _selectedTeamId = v),
              ),
            ),
          ),
        ],
        // Task stream
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: taskQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const SizedBox(
                height: 60,
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.tasksGreen,
                        strokeWidth: 2)),
              );
            }
            final tasks = snapshot.data?.docs
                    .map((d) => TaskModel.fromDoc(d))
                    .toList() ??
                [];
            if (tasks.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      AppColors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(
                      AppConstants.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.task_alt,
                        color: AppColors.textSecondary,
                        size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Aktif göreviniz yok. Görevleriniz burada görünecek.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4),
                          minimumSize: const Size(0, 40),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => context.push('/tasks'),
                        child: const Text(
                          'Git →',
                          style: TextStyle(
                              color: AppColors.tasksGreen,
                              fontSize: 12),
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
                        margin:
                            const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusMd),
                          border: Border.all(
                              color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 32,
                              decoration: BoxDecoration(
                                color: task.status ==
                                        TaskStatus
                                            .pendingApproval
                                    ? AppColors.warning
                                    : AppColors.tasksGreen,
                                borderRadius:
                                    BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(task.title,
                                      style: const TextStyle(
                                          color: AppColors
                                              .textPrimary,
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    task.status ==
                                            TaskStatus
                                                .pendingApproval
                                        ? 'Onay bekliyor'
                                        : 'Atandı',
                                    style: TextStyle(
                                      color: task.status ==
                                              TaskStatus
                                                  .pendingApproval
                                          ? AppColors.warning
                                          : AppColors
                                              .textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.tasksGreen
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(4),
                                border: Border.all(
                                    color: AppColors.tasksGreen
                                        .withValues(
                                            alpha: 0.4)),
                              ),
                              child: Text('${task.points} puan',
                                  style: const TextStyle(
                                      color:
                                          AppColors.tasksGreen,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w700)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right,
                                size: 16,
                                color: AppColors.border),
                          ],
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
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
        child: const Row(
          children: [
            Icon(Icons.rocket_launch_outlined,
                color: AppColors.panelBlue, size: 18),
            SizedBox(width: 10),
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
          const Row(
            children: [
              Icon(Icons.emoji_events_outlined,
                  color: AppColors.panelBlue, size: 20),
              SizedBox(width: 8),
              Text('SARGE Topluluğuna Katıl',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatted,
                  style: const TextStyle(
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
            child: const Icon(Icons.person_outline,
                size: 22, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends ConsumerWidget {
  const _LeaderboardCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius:
            BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: leaderboardAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Henüz puan verisi yok.',
                    style: TextStyle(
                        color: AppColors.textSecondary)),
              ),
            );
          }
          final top5 = entries.take(5).toList();
          return Column(
            children: [
              ...top5.asMap().entries.map((e) {
                final isLast = e.key == top5.length - 1;
                return Column(
                  children: [
                    _LeaderboardRow(
                        rank: e.key + 1, entry: e.value),
                    if (!isLast)
                      const Divider(
                          height: 1,
                          color: AppColors.border),
                  ],
                );
              }),
              const Divider(height: 1, color: AppColors.border),
              InkWell(
                onTap: () => context.push('/team'),
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
                          size: 14,
                          color: AppColors.panelBlue),
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
              child: CircularProgressIndicator(
                  color: AppColors.panelBlue)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Hata: $e',
              style:
                  const TextStyle(color: AppColors.error)),
        ),
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
                  ? const Icon(Icons.person_outline,
                      size: 12,
                      color: AppColors.textSecondary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.displayName,
                style: const TextStyle(
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

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool isAdmin;

  const _AnnouncementCard(
      {required this.announcement, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(
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
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (status.isNotEmpty && statusColor != null) ...[
                      const SizedBox(width: 8),
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
                      const Icon(Icons.event_outlined,
                          size: 13,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy', 'tr_TR')
                            .format(announcement.eventDate!),
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  announcement.description,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      announcement.createdByName,
                      style: const TextStyle(
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
                      GestureDetector(
                        onTap: () => _editAnnouncement(
                            context, announcement),
                        child: const Icon(Icons.edit_outlined,
                            size: 16,
                            color: AppColors.panelBlue),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _deleteAnnouncement(
                            context, announcement),
                        child: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duyuruyu Sil'),
        content: Text(
            '"${announcement.title}" silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final container =
                  ProviderScope.containerOf(context);
              await container
                  .read(announcementRepositoryProvider)
                  .deleteAnnouncement(announcement.id);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
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

  @override
  void initState() {
    super.initState();
    _eventDate = widget.existing?.eventDate;
    _notifyAll = widget.existing?.notifyAll ?? false;
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
    if (picked != null)
      setState(() => _eventDate = picked);
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
                style: const TextStyle(
                    color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Başlık *',
                    hintText: 'Duyuru başlığı'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                style: const TextStyle(
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
              Row(
                children: [
                  const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: AppColors.panelBlue),
                  const SizedBox(width: 8),
                  const Flexible(
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