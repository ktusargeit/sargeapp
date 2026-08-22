import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/custom_delete_button.dart';
import '../../team/providers/team_providers.dart';
import '../models/task_models.dart';
import '../providers/task_providers.dart';
import 'task_detail_panel.dart';

// ═══════════════════════════════════════════════════════════════════════
// TASKS BODY (stable provider stream + client filters)
// ═══════════════════════════════════════════════════════════════════════

class TasksBody extends ConsumerWidget {
  final TasksViewKey viewKey;
  final List<TaskModel> Function(List<TaskModel>, String?) applyClientFilters;
  final String searchQuery;
  final bool showHistory;
  final Color Function(TaskStatus) statusColor;
  final Color Function(TaskStatus) pointsColor;
  final String? currentUid;
  final bool isAdmin;
  final bool isUnitLead;

  const TasksBody({
    super.key,
    required this.viewKey,
    required this.applyClientFilters,
    required this.searchQuery,
    required this.showHistory,
    required this.statusColor,
    required this.pointsColor,
    required this.currentUid,
    required this.isAdmin,
    required this.isUnitLead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksScreenProvider(viewKey));

    return tasksAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.tasksAccent)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Görevler yüklenemedi: $e',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (allTasks) {
        var tasks = applyClientFilters(allTasks, currentUid);

        final filtered = searchQuery.isEmpty
            ? tasks
            : tasks.where((t) {
                return t.title.toLowerCase().contains(searchQuery) ||
                    t.assignedByName.toLowerCase().contains(searchQuery) ||
                    (t.unitName?.toLowerCase().contains(searchQuery) ?? false) ||
                    (t.teamName?.toLowerCase().contains(searchQuery) ?? false);
              }).toList();

        final taskList = showHistory
            ? filtered
            : filtered
                .where((t) =>
                    t.status == TaskStatus.assigned ||
                    t.status == TaskStatus.inProgress ||
                    t.status == TaskStatus.pendingApproval)
                .toList();

        if (taskList.isEmpty) {
          return Center(
            child: Text('Gösterilecek görev yok.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          itemCount: taskList.length,
          itemBuilder: (_, i) {
            final task = taskList[i];
            return TaskCard(
              key: ValueKey(task.id),
              task: task,
              isAdmin: isAdmin,
              isUnitLead: isUnitLead,
              currentUid: currentUid,
              statusColor: statusColor(task.status),
              pointsColor: pointsColor(task.status),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TASK CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════

class TaskCard extends ConsumerWidget {
  final TaskModel task;
  final bool isAdmin;
  final bool isUnitLead;
  final String? currentUid;
  final Color statusColor;
  final Color pointsColor;

  const TaskCard({
    super.key,
    required this.task,
    required this.isAdmin,
    this.isUnitLead = false,
    required this.currentUid,
    required this.statusColor,
    this.pointsColor = AppColors.tasksAccent,
  });

  bool _canApprove(BuildContext context, WidgetRef ref) {
    if (isAdmin || isUnitLead) return true;
    if (currentUid == null || task.teamId == null) return false;
    final teams = ref.watch(clubTeamsProvider).valueOrNull ?? [];
    try {
      final team = teams.firstWhere((t) => t.id == task.teamId);
      return team.leadUid == currentUid;
    } catch (_) {
      return false;
    }
  }

  bool _canDelete() {
    return isAdmin || (currentUid != null && task.assignedBy == currentUid);
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görevi Sil'),
        content: Text('"${task.title}" silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await runDeleteWithFeedback(
      context: context,
      successMessage: 'Görev başarıyla silindi.',
      operation: () async {
        final firestore = ref.read(firestoreProvider);

        final taskIds = <String>{task.id};
        final bulkGroupId = task.bulkGroupId;
        if (bulkGroupId != null && bulkGroupId.isNotEmpty) {
          final bulkSnap = await firestore
              .collection('tasks')
              .where('bulkGroupId', isEqualTo: bulkGroupId)
              .get();
          for (final doc in bulkSnap.docs) {
            taskIds.add(doc.id);
          }
        }

        final refsToDelete = <DocumentReference<Map<String, dynamic>>>[];
        for (final taskId in taskIds) {
          final taskDoc = firestore.collection('tasks').doc(taskId);
          final commentsSnap = await taskDoc.collection('comments').get();
          refsToDelete.addAll(commentsSnap.docs.map((c) => c.reference));
          refsToDelete.add(taskDoc);
        }

        for (var i = 0; i < refsToDelete.length; i += 500) {
          final end = (i + 500 > refsToDelete.length)
              ? refsToDelete.length
              : i + 500;
          final batch = firestore.batch();
          for (final ref in refsToDelete.sublist(i, end)) {
            batch.delete(ref);
          }
          await batch.commit();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canApprove = _canApprove(context, ref);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        onTap: () => _openDetailSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(task.title,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  TaskCommentCountBadge(taskId: task.id),
                  if (_canDelete()) ...[
                    const SizedBox(width: 2),
                    CustomDeleteButton(
                      onPressed: () => _deleteTask(context, ref),
                    ),
                  ],
                  const SizedBox(width: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(task.statusLabel,
                        style: TextStyle(
                            color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pointsColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: pointsColor.withValues(alpha: 0.4)),
                    ),
                    child: Text('${task.points} puan',
                        style: TextStyle(
                            color: pointsColor, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskMetaRow(
                    label: 'Atanan',
                    value: task.assignedToName.isNotEmpty ? task.assignedToName : '—',
                  ),
                  TaskMetaRow(
                    label: 'Atayan',
                    value: task.assignedByName.isNotEmpty ? task.assignedByName : '—',
                  ),
                  if (task.teamName != null)
                    TaskMetaRow(label: 'Takım', value: task.teamName!),
                  if (task.unitName != null)
                    TaskMetaRow(label: 'Birim', value: task.unitName!),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Spacer(),
                  if (task.status == TaskStatus.pendingApproval && canApprove)
                    ..._approveButtons(context, ref),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _approveButtons(BuildContext ctx, WidgetRef ref) => [
        TaskActionButton(
          label: 'Onayla',
          color: AppColors.success,
          onTap: () => _approveTask(ctx, ref, true),
        ),
        const SizedBox(width: 6),
        TaskActionButton(
          label: 'Reddet',
          color: AppColors.error,
          onTap: () => _approveTask(ctx, ref, false),
        ),
      ];

  Future<void> _approveTask(
      BuildContext ctx, WidgetRef ref, bool approve) async {
    final uid = ref.read(authStateProvider).value?.uid;
    try {
      if (approve) {
        final taskDoc = await ref
            .read(firestoreProvider)
            .collection('tasks')
            .doc(task.id)
            .get();
        final alreadyAwarded = (taskDoc.data()?['pointsAwarded'] as bool?) ?? false;

        final batch = ref.read(firestoreProvider).batch();
        batch.update(
            ref.read(firestoreProvider).collection('tasks').doc(task.id), {
          'status': 'completed',
          'approvedBy': uid,
        });
        if (!alreadyAwarded && !task.pointsAwarded) {
          batch.update(
              ref.read(firestoreProvider).collection('users').doc(task.assignedTo), {
            'points': FieldValue.increment(task.points),
            'weeklyPoints': FieldValue.increment(task.points),
            if (task.teamId != null && task.teamId!.isNotEmpty)
              'teamPoints.${task.teamId}': FieldValue.increment(task.points),
          });
          batch.update(
              ref.read(firestoreProvider).collection('tasks').doc(task.id), {
            'pointsAwarded': true,
          });
        }
        await batch.commit();

        // Best-effort points history (admin-only per rules), so the team-scoped
        // contribution is auditable too. Non-admin approvers simply skip this.
        if (!alreadyAwarded && !task.pointsAwarded) {
          try {
            await ref
                .read(firestoreProvider)
                .collection('points_history')
                .add({
              'targetUid': task.assignedTo,
              'targetName': task.assignedToName,
              'delta': task.points,
              'changedBy': uid,
              if (task.teamId != null) 'teamId': task.teamId,
              if (task.teamName != null) 'teamName': task.teamName,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }

        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
              content: Text('Görev onaylandı, puan verildi.'),
              backgroundColor: AppColors.success));
        }
      } else {
        await ref
            .read(firestoreProvider)
            .collection('tasks')
            .doc(task.id)
            .update({
          'status': 'rejected',
          'approvedBy': uid,
        });
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
              content: Text('Görev reddedildi.'),
              backgroundColor: AppColors.warning));
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _openDetailSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TaskDetailSheet(taskId: task.id),
    );
  }
}

/// Aligned fixed-width label + value row for task cards.
class TaskMetaRow extends StatelessWidget {
  final String label;
  final String value;
  const TaskMetaRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live comment count badge from the comments subcollection.
class TaskCommentCountBadge extends ConsumerWidget {
  final String taskId;
  const TaskCommentCountBadge({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.tasksGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.tasksGreen.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💬', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 3),
              Text('$count',
                  style: const TextStyle(
                      color: AppColors.tasksGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

/// Small text button for task actions.
class TaskActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const TaskActionButton(
      {super.key, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}