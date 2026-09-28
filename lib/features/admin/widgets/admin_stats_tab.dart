import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../tasks/models/task_models.dart';
import '../../tasks/providers/task_providers.dart';
import '../../team/providers/team_providers.dart';

class AdminStatsTab extends ConsumerWidget {
  const AdminStatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final teamsAsync = ref.watch(clubTeamsProvider);
    final tasksAsync =
        ref.watch(tasksScreenProvider((uid: null, isAdmin: true)));
    final appsAsync = ref.watch(teamApplicationsProvider);

    final totalUsers = usersAsync.valueOrNull?.length ?? 0;
    final totalTeams = teamsAsync.valueOrNull?.length ?? 0;
    final tasks = tasksAsync.valueOrNull ?? const <TaskModel>[];

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final completedThisWeek = tasks
        .where((t) =>
            t.status == TaskStatus.completed &&
            t.completedAt != null &&
            t.completedAt!.isAfter(weekAgo))
        .length;
    final totalTasks = tasks.length;
    final activeTeams =
        (teamsAsync.valueOrNull ?? const []).where((t) => t.isActive).length;
    final pendingApps = (appsAsync.valueOrNull ?? const [])
        .where((a) => a['status'] == 'pending')
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminStatCard(
          icon: Icons.people_outline,
          title: 'Toplam Üye',
          value: '$totalUsers',
          color: AppColors.panelBlue,
        ),
        const SizedBox(height: 10),
        AdminStatCard(
          icon: Icons.groups_outlined,
          title: 'Toplam Takım',
          value: '$totalTeams',
          color: AppColors.teamAccent,
        ),
        const SizedBox(height: 10),
        AdminStatCard(
          icon: Icons.check_circle_outline,
          title: 'Aktif Takım',
          value: '$activeTeams',
          color: AppColors.success,
        ),
        const SizedBox(height: 10),
        AdminStatCard(
          icon: Icons.task_alt,
          title: 'Toplam Görev',
          value: '$totalTasks',
          color: AppColors.tasksGreen,
        ),
        const SizedBox(height: 10),
        AdminStatCard(
          icon: Icons.event_available_outlined,
          title: 'Bu Hafta Tamamlanan Görev',
          value: '$completedThisWeek',
          color: AppColors.warning,
        ),
        const SizedBox(height: 10),
        AdminStatCard(
          icon: Icons.how_to_reg_outlined,
          title: 'Bekleyen Başvuru',
          value: '$pendingApps',
          color: AppColors.sargeGold,
        ),
      ],
    );
  }
}

class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
