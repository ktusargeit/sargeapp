import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../tasks/models/task_models.dart';
import '../../tasks/providers/task_providers.dart';
import '../../team/providers/team_providers.dart';

class AdminPendingTab extends ConsumerWidget {
  const AdminPendingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(teamApplicationsProvider);
    final reportsAsync = ref.watch(bugReportsProvider);
    final tasksAsync =
        ref.watch(tasksScreenProvider((uid: null, isAdmin: true)));

    final pendingApps = (appsAsync.valueOrNull ?? const [])
        .where((a) => a['status'] == 'pending')
        .length;
    final openReports = (reportsAsync.valueOrNull ?? const [])
        .where((r) => r.status != 'done')
        .length;
    final pendingApprovalTasks = (tasksAsync.valueOrNull ?? const [])
        .where((t) => t.status == TaskStatus.pendingApproval)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Aksiyon gerektiren öğeler',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        AdminPendingCard(
          icon: Icons.how_to_reg_outlined,
          title: 'Bekleyen Başvuru',
          value: '$pendingApps',
          color: AppColors.teamAccent,
          onTap: () => DefaultTabController.of(context).animateTo(2),
        ),
        const SizedBox(height: 10),
        AdminPendingCard(
          icon: Icons.bug_report_outlined,
          title: 'Çözülmemiş Hata Bildirimi',
          value: '$openReports',
          color: AppColors.error,
        ),
        const SizedBox(height: 10),
        AdminPendingCard(
          icon: Icons.task_alt,
          title: 'Onay Bekleyen Görev',
          value: '$pendingApprovalTasks',
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class AdminPendingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const AdminPendingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  style:
                      TextStyle(color: AppColors.textPrimary, fontSize: 15),
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
        ),
      ),
    );
  }
}