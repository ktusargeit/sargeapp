import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/platform_image.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/comment_tile.dart';
import '../../../core/widgets/custom_delete_button.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../models/task_models.dart';
import '../providers/task_providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  final String? initialTaskId;
  const TasksScreen({super.key, this.initialTaskId});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _filterTeamId;
  String? _filterUnitId;
  TaskStatus? _filterStatus;
  bool _showHistory = false;
  String? _filterPersonId;
  bool _filterMyTasks = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // When navigated from Dashboard "Görevlerim", auto-open the task detail.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra;
      final taskId = widget.initialTaskId ?? (extra is String ? extra : null);
      if (taskId != null && taskId.isNotEmpty) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => _TaskDetailSheet(taskId: taskId),
        );
      }
    });
  }

  List<TaskModel> _applyClientFilters(List<TaskModel> tasks, String? currentUid) {
    if (_filterTeamId != null && _filterTeamId!.isNotEmpty) {
      tasks = tasks.where((t) => t.teamId == _filterTeamId).toList();
    }
    if (_filterUnitId != null && _filterUnitId!.isNotEmpty) {
      tasks = tasks.where((t) => t.unitId == _filterUnitId).toList();
    }
    if (_filterStatus != null) {
      tasks = tasks.where((t) => t.status == _filterStatus!).toList();
    }
    if (_filterPersonId != null && _filterPersonId!.isNotEmpty) {
      tasks = tasks.where((t) => t.assignedTo == _filterPersonId).toList();
    }
    if (_filterMyTasks && currentUid != null) {
      tasks = tasks.where((t) => t.assignedTo == currentUid).toList();
    }
    return tasks;
  }

  Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return AppColors.success;
      case TaskStatus.inProgress:
        return AppColors.panelBlue;
      case TaskStatus.pendingApproval:
        return AppColors.panelBlue;
      case TaskStatus.rejected:
        return AppColors.error;
      case TaskStatus.cancelled:
        return AppColors.textSecondary;
      case TaskStatus.assigned:
        return AppColors.warning;
    }
  }

  Color _pointsColor(TaskStatus status) => _statusColor(status);

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    final appUserAsync = ref.watch(currentAppUserProvider);
    final appUser = appUserAsync.value;
    final isAdmin = ref.watch(isAdminProvider);
    // Use the auth uid (available as soon as auth resolves) so the task query
    // starts with the correct uid immediately. Previously `currentUid` came from
    // the Firestore profile document, which loads after auth, so the provider
    // briefly built an empty "(null, false)" query and made existing tasks flash
    // then vanish — most noticeable on normal (non-admin) accounts.
    final currentUid = authUser?.uid ?? appUser?.uid;
    // While a signed-in user's profile document is still loading we show a loader
    // instead of falling back to an empty/wrong list (prevents the admin
    // "own tasks → all tasks" flash and the member "empty → tasks" flash).
    final profileStillLoading = authUser != null && appUser == null;
    final teamsAsync = ref.watch(clubTeamsProvider);
    final visibleTeams = teamsAsync.valueOrNull ?? [];
    final isUnitLead = appUser?.isUnitLead ?? false;
    // A captain is whoever leads at least one team (`teams/{id}.leadUid`),
    // mirroring the Firestore rules.
    final isCaptain =
        currentUid != null && visibleTeams.any((t) => t.leadUid == currentUid);

    return Scaffold(
      backgroundColor: AppColors.tasksBg,
      appBar: AppBar(
        title: const Text('Tüm Görevler'),
        backgroundColor: AppColors.tasksBg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 80),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  style:  TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Görev ara...',
                    hintStyle:  TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon:  Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Aktif', style: TextStyle(fontSize: 12)),
                      selected: !_showHistory,
                      selectedColor: AppColors.tasksAccent.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.tasksAccent,
                      onSelected: (_) => setState(() => _showHistory = false),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Geçmiş', style: TextStyle(fontSize: 12)),
                      selected: _showHistory,
                      selectedColor: AppColors.textSecondary.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _showHistory = true),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Benim Görevlerim', style: TextStyle(fontSize: 12)),
                      selected: _filterMyTasks,
                      selectedColor: AppColors.tasksGreen.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.tasksGreen,
                      avatar: Icon(
                        Icons.person,
                        size: 16,
                        color: _filterMyTasks ? AppColors.tasksGreen : AppColors.textSecondary,
                      ),
                      onSelected: (_) => setState(() => _filterMyTasks = !_filterMyTasks),
                    ),
                    const SizedBox(width: 12),
                    _FilterDropdown<ClubTeam>(
                      hint: 'Takım',
                      value: _filterTeamId != null
                          ? visibleTeams.firstWhere(
                              (t) => t.id == _filterTeamId,
                              orElse: () => visibleTeams.first)
                          : null,
                      items: visibleTeams,
                      labelFn: (t) => t.name,
                      idFn: (t) => t.id,
                      onChanged: (t) => setState(() {
                        _filterTeamId = t?.id;
                        _filterUnitId = null;
                        _filterPersonId = null;
                      }),
                      onClear: () => setState(() {
                        _filterTeamId = null;
                        _filterUnitId = null;
                        _filterPersonId = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    if (_filterTeamId != null)
                      _TeamUnitDropdown(
                        teamId: _filterTeamId!,
                        value: _filterUnitId,
                        onChanged: (u) => setState(() => _filterUnitId = u),
                      ),
                    const SizedBox(width: 8),
                    if (_filterTeamId != null)
                      _PersonFilterDropdown(
                        teamId: _filterTeamId!,
                        value: _filterPersonId,
                        onChanged: (uid) => setState(() => _filterPersonId = uid),
                      ),
                    const SizedBox(width: 8),
                    _FilterDropdown<TaskStatus>(
                      hint: 'Durum',
                      value: _filterStatus,
                      items: TaskStatus.values,
                      labelFn: (s) => s.name == 'inProgress'
                          ? 'Üzerinde Çalışılıyor'
                          : s.name == 'pendingApproval'
                              ? 'Onay Bekliyor'
                              : s.name == 'assigned'
                                  ? 'Yeni Görev'
                                  : s.name == 'completed'
                                      ? 'Onaylandı'
                                      : s.name == 'rejected'
                                          ? 'Reddedildi'
                                          : s.name == 'cancelled'
                                              ? 'İptal'
                                              : s.name,
                      idFn: (s) => s.name,
                      onChanged: (s) => setState(() => _filterStatus = s),
                      onClear: () => setState(() => _filterStatus = null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: profileStillLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.tasksAccent))
          : _TasksBody(
              viewKey: (uid: currentUid, isAdmin: isAdmin),
              applyClientFilters: _applyClientFilters,
              searchQuery: _searchQuery,
              showHistory: _showHistory,
              statusColor: _statusColor,
              pointsColor: _pointsColor,
              currentUid: currentUid,
              isAdmin: isAdmin,
              isUnitLead: isUnitLead,
            ),
      floatingActionButton: (isAdmin || isUnitLead || isCaptain)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTaskDialog(context),
              backgroundColor: AppColors.tasksAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Görev Ekle',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            )
          : null,
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AddTaskDialog(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TASKS BODY (stable provider stream + client filters)
// ═══════════════════════════════════════════════════════════════════════

class _TasksBody extends ConsumerWidget {
  final TasksViewKey viewKey;
  final List<TaskModel> Function(List<TaskModel>, String?) applyClientFilters;
  final String searchQuery;
  final bool showHistory;
  final Color Function(TaskStatus) statusColor;
  final Color Function(TaskStatus) pointsColor;
  final String? currentUid;
  final bool isAdmin;
  final bool isUnitLead;

  const _TasksBody({
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
          return  Center(
            child: Text('Gösterilecek görev yok.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          itemCount: taskList.length,
          itemBuilder: (_, i) {
            final task = taskList[i];
            return _TaskCard(
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

class _TaskCard extends ConsumerWidget {
  final TaskModel task;
  final bool isAdmin;
  final bool isUnitLead;
  final String? currentUid;
  final Color statusColor;
  final Color pointsColor;

  const _TaskCard({
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
    // Only admins or the task creator (atayan) can delete a task.
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

        // Toplu atamada (Takım/Birim) aynı bulkGroupId'yi paylaşan TÜM görev
        // dokümanları silinir. Aksi halde silinen "görev" yalnızca bir kişiye
        // ait kopyaydı ve gruptaki diğer görevler geride kalıyordu.
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

        // Görev dokümanları + onların comments alt koleksiyonlarını topla.
        // Tek tek silmek yerine batch delete kullanılır; böylece yüzlerce
        // yorum olsa bile birkaç batch commit ile işlem tamamlanır.
        final refsToDelete = <DocumentReference<Map<String, dynamic>>>[];
        for (final taskId in taskIds) {
          final taskDoc = firestore.collection('tasks').doc(taskId);
          final commentsSnap = await taskDoc.collection('comments').get();
          refsToDelete.addAll(commentsSnap.docs.map((c) => c.reference));
          refsToDelete.add(taskDoc);
        }

        // Firestore batch limiti 500 işlemdir — gerekirse parçalara böl.
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
          side:  BorderSide(color: AppColors.border)),
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
                        style:  TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  _CommentCountBadge(taskId: task.id),
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
                    style:  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaRow(
                    label: 'Atanan',
                    value: task.assignedToName.isNotEmpty ? task.assignedToName : '—',
                  ),
                  _MetaRow(
                    label: 'Atayan',
                    value: task.assignedByName.isNotEmpty ? task.assignedByName : '—',
                  ),
                  if (task.teamName != null)
                    _MetaRow(label: 'Takım', value: task.teamName!),
                  if (task.unitName != null)
                    _MetaRow(label: 'Birim', value: task.unitName!),
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
        _ActionButton(
          label: 'Onayla',
          color: AppColors.success,
          onTap: () => _approveTask(ctx, ref, true),
        ),
        const SizedBox(width: 6),
        _ActionButton(
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
          });
          batch.update(
              ref.read(firestoreProvider).collection('tasks').doc(task.id), {
            'pointsAwarded': true,
          });
        }
        await batch.commit();
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
      builder: (ctx) => _TaskDetailSheet(taskId: task.id),
    );
  }
}

/// Aligned fixed-width label + value row for task cards.
class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

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
              style:  TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live comment count badge from the comments subcollection.
class _CommentCountBadge extends ConsumerWidget {
  final String taskId;
  const _CommentCountBadge({required this.taskId});

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
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.onTap});

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

/// Reusable dropdown filter for any type.
class _FilterDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelFn;
  final String Function(T) idFn;
  final ValueChanged<T?> onChanged;
  final VoidCallback? onClear;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.labelFn,
    required this.idFn,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          dropdownColor: AppColors.surface2,
          style:  TextStyle(color: AppColors.textPrimary, fontSize: 12),
          hint: Text(hint,
              style:  TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          items: [
            if (value != null)
              DropdownMenuItem<T?>(
                value: null,
                child: Text('Tümü',
                    style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 12)),
              ),
            ...items.map((item) => DropdownMenuItem<T?>(
                  value: item,
                  child: Text(labelFn(item), style: const TextStyle(fontSize: 12)),
                )),
          ],
          onChanged: (v) {
            if (v == null) {
              onClear?.call();
            } else {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }
}

/// Dropdown populated from team-scoped units provider.
class _TeamUnitDropdown extends ConsumerWidget {
  final String teamId;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _TeamUnitDropdown({required this.teamId, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(teamUnitsProvider(teamId));
    return unitsAsync.when(
      data: (units) => _FilterDropdown<Map<String, dynamic>>(
        hint: 'Birim',
        value: value != null
            ? units.firstWhere((u) => u['id'] == value,
                orElse: () => <String, dynamic>{})
            : null,
        items: units,
        labelFn: (u) => u['name'] as String? ?? '',
        idFn: (u) => u['id'] as String,
        onChanged: (u) => onChanged(u?['id'] as String?),
        onClear: () => onChanged(null),
      ),
      loading: () => const SizedBox(width: 16, child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Kişi filtresi dropdown.
class _PersonFilterDropdown extends ConsumerWidget {
  final String teamId;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _PersonFilterDropdown({required this.teamId, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider(teamId));
    return membersAsync.when(
      data: (members) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            isDense: true,
            dropdownColor: AppColors.surface2,
            style:  TextStyle(color: AppColors.textPrimary, fontSize: 12),
            hint:  Text('Kişi',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            items: [
              if (value != null)
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tümü',
                      style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12)),
                ),
              ...members.map((u) => DropdownMenuItem<String?>(
                    value: u.uid,
                    child: Text(u.displayName, style: const TextStyle(fontSize: 12)),
                  )),
            ],
            onChanged: (v) => onChanged(v),
          ),
        ),
      ),
      loading: () => const SizedBox(width: 16, child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TASK DETAIL SHEET (stream-based + full screen + multi-image comments)
// ═══════════════════════════════════════════════════════════════════════

class _TaskDetailSheet extends ConsumerStatefulWidget {
  final String taskId;

  const _TaskDetailSheet({required this.taskId});

  @override
  ConsumerState<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<_TaskDetailSheet> {
  final _commentCtrl = TextEditingController();
  List<PickedImage> _commentImages = [];
  bool _sending = false;
  Map<String, dynamic>? _replyTo;

  // Optimistically rendered comments while their images are still uploading.
  final List<_PendingComment> _pendingComments = [];

  String get _threadKey => threadKeyFor('task_comment', widget.taskId);

  @override
  void initState() {
    super.initState();
    // Presence: mark this task thread as open so the Cloud Function and
    // senders do not create notifications while the user is viewing it.
    ref.read(presenceServiceProvider).setActiveThread(_threadKey);
    // Opening the thread also resets its unread counter.
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      ref.read(notificationServiceProvider).resetThread(
            uid,
            'task_comment',
            widget.taskId,
          );
    }
  }

  @override
  void dispose() {
    ref.read(presenceServiceProvider).clearActiveThread(_threadKey);
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<List<String>> _uploadCommentImages(List<PickedImage> images) async {
    final urls = <String>[];
    for (final img in images) {
      final tempId = 'task_comment_${DateTime.now().microsecondsSinceEpoch}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('task_comments/$tempId.jpg');
      debugPrint(
          '[task-comment-upload] path=${storageRef.fullPath} uid=${ref.read(authStateProvider).value?.uid}');
      // Client-side compression: always upload a max-1280px JPEG at ~75% quality.
      final compressed = await img.compressedUploadBytes();
      if (compressed.isNotEmpty) {
        await storageRef.putData(compressed);
      } else if (img.bytes != null) {
        await storageRef.putData(img.bytes!);
      } else if (img.dartFile != null) {
        await storageRef.putFile(img.dartFile!);
      }
      urls.add(await storageRef.getDownloadURL());
    }
    return urls;
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty && _commentImages.isEmpty) return;

    final user = ref.read(authStateProvider).value;
    final uid = user?.uid ?? '';
    final name = user?.displayName ?? 'Kullanıcı';
    final isAdmin = ref.read(isAdminProvider);
    final firestore = ref.read(firestoreProvider);
    final replyTo = _replyTo;

    // Optimistic UI: show the comment (with its locally-selected images)
    // immediately, then upload + persist in the background. This removes the
    // "nothing happens until upload finishes, then it suddenly appears" lag.
    final pending = _PendingComment(
      text: text,
      senderUid: uid,
      senderName: name,
      isAdmin: isAdmin,
      images: List<PickedImage>.from(_commentImages),
      replyToId: replyTo?['id'] as String?,
      replyToText: replyTo?['text'] as String?,
      replyToAuthor: replyTo?['senderName'] as String?,
      replyToUid: replyTo?['senderUid'] as String?,
    );
    setState(() {
      _pendingComments.add(pending);
      _commentImages = [];
      _replyTo = null;
      _sending = true;
    });
    _commentCtrl.clear();

    try {
      final imageUrls = await _uploadCommentImages(pending.images);

      await firestore
          .collection('tasks')
          .doc(widget.taskId)
          .collection('comments')
          .add({
        'senderUid': uid,
        'senderName': name,
        'text': text,
        'imageUrls': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'isAdmin': isAdmin,
        'replyToId': pending.replyToId,
        'replyToText': pending.replyToText,
        'replyToAuthor': pending.replyToAuthor,
        'replyToUid': pending.replyToUid,
      });

      // Notifications are created server-side by `notifyTaskComment`
      // (grouped per thread + presence-aware), so the client only persists the
      // comment here.

    } catch (e) {
      if (mounted) {
        setState(() => _pendingComments.remove(pending));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorum gönderilemedi: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          // The Firestore stream now owns the persisted comment; drop the
          // optimistic copy so it isn't rendered twice.
          _pendingComments.remove(pending);
          _sending = false;
        });
      }
    }
  }

  Future<void> _updateStatus(TaskStatus newStatus) async {
    try {
      await ref
          .read(firestoreProvider)
          .collection('tasks')
          .doc(widget.taskId)
          .update({'status': newStatus.name});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  /// Whether the current user can approve this task (admin / unit lead /
  /// team lead). Referenced from the detail sheet which no longer receives
  /// the flag from the card.
  bool _computeCanApprove(TaskModel task) {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser?.isAdmin ?? false) return true;
    if (appUser?.isUnitLead ?? false) return true;
    final uid = appUser?.uid;
    if (uid != null && task.teamId != null) {
      final teams = ref.read(clubTeamsProvider).valueOrNull ?? [];
      try {
        final team = teams.firstWhere((t) => t.id == task.teamId);
        return team.leadUid == uid;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<void> _submitForApproval() async {
    final firestore = ref.read(firestoreProvider);
    try {
      final taskDoc = await firestore.collection('tasks').doc(widget.taskId).get();
      final data = taskDoc.data() ?? {};
      final creatorId = data['assignedBy'] as String?;
      final title = data['title'] as String? ?? 'Görev';
      final assigneeName = data['assignedToName'] as String? ?? 'Kullanıcı';

      await firestore.collection('tasks').doc(widget.taskId).update({
        'status': 'pendingApproval',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Notify the task creator/approver that the assignee submitted for approval.
      try {
        final uid = ref.read(authStateProvider).value?.uid;
        if (creatorId != null && creatorId.isNotEmpty && creatorId != uid) {
          await ref.read(notificationServiceProvider).send(
                recipientId: creatorId,
                title: 'Görev onaya gönderildi: $title',
                body: '$assigneeName görevi teslim etti, onay bekliyor.',
                type: 'task_submitted',
                relatedId: widget.taskId,
              );
        }
      } catch (_) {
        // Notification is best-effort; never block the submission.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Görev teslim edildi, onay bekleniyor.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görevi Teslim Et'),
        content: const Text('Görevi teslim etmek istediğinize emin misiniz?\n\n'
            'Teslim edildiğinde görev onay beklemeye alınacaktır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitForApproval();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Evet, teslim et'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.read(authStateProvider).value?.uid;
    final taskAsync = ref.watch(taskDocProvider(widget.taskId));

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.9,
      maxChildSize: 1.0,
      expand: true,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: taskAsync.when(
          data: (task) {
            final isAssignee = task.assignedTo == currentUid;
            final canApprove = _computeCanApprove(task);
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(task.title,
                            style:  TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (task.status == TaskStatus.completed
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(task.statusLabel,
                            style: TextStyle(
                              color: task.status == TaskStatus.completed
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.description.isNotEmpty) ...[
                        Text(task.description,
                            style:  TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 10),
                      ],
                      _MetaRow(
                          label: 'Atanan',
                          value: task.assignedToName.isNotEmpty ? task.assignedToName : '—'),
                      _MetaRow(
                          label: 'Atayan',
                          value: task.assignedByName.isNotEmpty ? task.assignedByName : '—'),
                      _MetaRow(label: 'Durum', value: task.statusLabel),
                      if (task.teamName != null) _MetaRow(label: 'Takım', value: task.teamName!),
                      if (task.unitName != null) _MetaRow(label: 'Birim', value: task.unitName!),
                      _MetaRow(label: 'Puan', value: '${task.points}'),
                      if (task.pointsAwarded) const _MetaRow(label: 'Puan Durumu', value: 'Verildi ✓'),
                      if (task.imageUrl != null && task.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => openNetworkImageViewer(context, task.imageUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              task.imageUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      if (isAssignee && task.status == TaskStatus.assigned)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus(TaskStatus.inProgress),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Göreve Başla'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.tasksAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (isAssignee && task.status == TaskStatus.inProgress)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmSubmit,
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: const Text('Görevi Teslim Et'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (task.status == TaskStatus.pendingApproval && canApprove) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _approve(false),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reddet'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approve(true),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Onayla'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                 Divider(color: AppColors.border, height: 1),
                 Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('Yorumlar',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Expanded(
                  child: _TaskCommentsList(
                    taskId: widget.taskId,
                    pendingComments: _pendingComments,
                    currentUid: currentUid,
                    onReply: (data) => setState(() => _replyTo = data),
                  ),
                ),
                _CommentInputBar(
                  controller: _commentCtrl,
                  images: _commentImages,
                  sending: _sending,
                  replyTo: _replyTo,
                  onClearReply: () => setState(() => _replyTo = null),
                  onPickImages: () async {
                    final imgs = await PickedImage.pickMultiple();
                    if (imgs.isNotEmpty && mounted) {
                      setState(() => _commentImages = [..._commentImages, ...imgs]);
                    }
                  },
                  onRemoveImage: (i) => setState(() => _commentImages.removeAt(i)),
                  onSend: _sendComment,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Görev yüklenemedi: $e')),
        ),
      ),
    );
  }

  Future<void> _approve(bool approve) async {
    final uid = ref.read(authStateProvider).value?.uid;
    final firestore = ref.read(firestoreProvider);
    try {
      final taskDoc = await firestore.collection('tasks').doc(widget.taskId).get();
      final data = taskDoc.data() ?? {};
      final assignedTo = data['assignedTo'] as String? ?? '';
      final points = (data['points'] as num?)?.toInt() ?? 0;
      final alreadyAwarded = (data['pointsAwarded'] as bool?) ?? false;

      if (approve) {
        final batch = firestore.batch();
        batch.update(firestore.collection('tasks').doc(widget.taskId), {
          'status': 'completed',
          'approvedBy': uid,
        });
        if (!alreadyAwarded && assignedTo.isNotEmpty) {
          batch.update(firestore.collection('users').doc(assignedTo), {
            'points': FieldValue.increment(points),
            'weeklyPoints': FieldValue.increment(points),
          });
          batch.update(firestore.collection('tasks').doc(widget.taskId), {
            'pointsAwarded': true,
          });
        }
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Görev onaylandı, puan verildi.'),
              backgroundColor: AppColors.success));
        }
      } else {
        await firestore.collection('tasks').doc(widget.taskId).update({
          'status': 'rejected',
          'approvedBy': uid,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Görev reddedildi.'), backgroundColor: AppColors.warning));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}

/// An in-flight comment whose images are still uploading to Storage.
///
/// Rendered optimistically so the author sees instant feedback instead of a
/// silent delay until the upload completes.
class _PendingComment {
  final String text;
  final String senderUid;
  final String senderName;
  final bool isAdmin;
  final List<PickedImage> images;
  final String? replyToId;
  final String? replyToText;
  final String? replyToAuthor;
  final String? replyToUid;

  const _PendingComment({
    required this.text,
    required this.senderUid,
    required this.senderName,
    required this.isAdmin,
    required this.images,
    this.replyToId,
    this.replyToText,
    this.replyToAuthor,
    this.replyToUid,
  });
}

/// Comments list for a task (subcollection).
///
/// Rendered with `reverse: true` so the newest message is pinned to the bottom
/// (index 0). New messages (including optimistic pending ones) therefore appear
/// at the bottom automatically when they arrive, instead of the list jumping to
/// the oldest message — the same behavior WhatsApp uses.
class _TaskCommentsList extends ConsumerWidget {
  final String taskId;
  final List<_PendingComment> pendingComments;
  final String? currentUid;
  final void Function(Map<String, dynamic>) onReply;
  const _TaskCommentsList({
    required this.taskId,
    this.pendingComments = const [],
    this.currentUid,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.tasksAccent));
        }
        final comments = snapshot.data?.docs ?? [];
        if (comments.isEmpty && pendingComments.isEmpty) {
          return  Center(
              child: Text('Henüz yorum yapılmadı.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)));
        }

        // reverse:true means index 0 is at the bottom, so build the list
        // newest-first: pending (currently being sent) first, then persisted
        // comments newest → oldest.
        final orderedComments = comments.reversed.toList();
        final totalCount = pendingComments.length + orderedComments.length;
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: totalCount,
          itemBuilder: (_, i) {
            if (i < pendingComments.length) {
              return _PendingCommentTile(comment: pendingComments[i]);
            }
            final doc = orderedComments[i - pendingComments.length];
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
          },
        );
      },
    );
  }
}

/// Renders an optimistic comment using locally-available image bytes/files.
class _PendingCommentTile extends StatelessWidget {
  final _PendingComment comment;
  const _PendingCommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            uid: comment.senderUid,
            name: comment.senderName,
            radius: 14,
            isAdmin: comment.isAdmin,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.senderName,
                        style:  TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.tasksAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (comment.text.isNotEmpty)
                  Text(
                    comment.text,
                    style:  TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                  ),
                if (comment.images.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: comment.images.map((img) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: PlatformImageFile(
                          bytes: img.bytes,
                          file: img.dartFile,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared comment input bar (text + multi-image + send).
class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final List<PickedImage> images;
  final bool sending;
  final VoidCallback onPickImages;
  final void Function(int) onRemoveImage;
  final VoidCallback onSend;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onClearReply;

  const _CommentInputBar({
    required this.controller,
    required this.images,
    required this.sending,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onSend,
    this.replyTo,
    this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration:  BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyTo != null) ...[
            ReplyPreviewBar(
              author: replyTo!['senderName'] as String? ?? 'Bilinmeyen',
              text: replyTo!['text'] as String? ?? '',
              onClear: onClearReply,
            ),
            const SizedBox(height: 8),
          ],
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: images.asMap().entries.map((e) {
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
                          onTap: () => onRemoveImage(e.key),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                color: AppColors.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
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
                onPressed: onPickImages,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style:  TextStyle(color: AppColors.textPrimary, fontSize: 14),
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
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: sending ? null : onSend,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sending
                        ? AppColors.tasksAccent.withValues(alpha: 0.5)
                        : AppColors.tasksAccent,
                    shape: BoxShape.circle,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ADD TASK DIALOG — Takım → Birim → Kişi (+ görsel)
// ═══════════════════════════════════════════════════════════════════════

class _AddTaskDialog extends ConsumerStatefulWidget {
  const _AddTaskDialog();

  @override
  ConsumerState<_AddTaskDialog> createState() => _AddTaskDialogState();
}

enum _AssignmentMode { single, team, unit }

class _AddTaskDialogState extends ConsumerState<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '10');

  ClubTeam? _selectedTeam;
  Map<String, dynamic>? _selectedUnit;
  String? _selectedUid;
  String? _selectedName;
  PickedImage? _pickedImage;
  bool _loading = false;
  _AssignmentMode _mode = _AssignmentMode.single;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await PickedImage.pick(ImageSource.gallery);
    if (img != null && mounted) setState(() => _pickedImage = img);
  }

  /// Teams the current user is allowed to assign tasks into.
  ///
  /// Mirrors the Firestore rules:
  ///  * Admin → every team.
  ///  * Captain (teams/{id}.leadUid == uid) → teams they lead.
  ///  * Unit lead (units/{id}.unitLeadUid == uid) → teams that contain one of
  ///    the units they lead.
  List<ClubTeam> _visibleTeams(List<ClubTeam> teams) {
    final uid = ref.read(authStateProvider).value?.uid;
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser?.isAdmin ?? false) return teams;
    if (uid == null) return const [];

    final led = teams.where((t) => t.leadUid == uid).toList();
    if (led.isNotEmpty) return led;

    final allUnits = ref.read(teamUnitListProvider).valueOrNull ?? const [];
    final ledTeamIds = allUnits
        .where((u) => u['unitLeadUid'] == uid)
        .map((u) => u['teamId'] as String)
        .toSet();
    return teams.where((t) => ledTeamIds.contains(t.id)).toList();
  }

  /// Units the current user may target within [teamId].
  Set<String> _allowedUnitIdsFor(String teamId) {
    final uid = ref.read(authStateProvider).value?.uid;
    final appUser = ref.read(currentAppUserProvider).value;
    final allUnits = ref.read(teamUnitListProvider).valueOrNull ?? const [];
    final teamScoped =
        allUnits.where((u) => u['teamId'] == teamId).toList();

    if (appUser?.isAdmin ?? false) {
      return teamScoped.map((u) => u['id'] as String).toSet();
    }
    if (uid == null) return const {};

    final isCaptain = ref
        .read(clubTeamsProvider)
        .valueOrNull
        ?.any((t) => t.id == teamId && t.leadUid == uid) ??
        false;
    if (isCaptain) return teamScoped.map((u) => u['id'] as String).toSet();

    return teamScoped
        .where((u) => u['unitLeadUid'] == uid)
        .map((u) => u['id'] as String)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(clubTeamsProvider);

    return AlertDialog(
      title: const Text('Yeni Görev Ata'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              teamsAsync.when(
                data: (teams) {
                  final availableTeams = _visibleTeams(teams);
                  if (availableTeams.isEmpty) {
                    return  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Görev atayabileceğiniz bir takım yok.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    );
                  }
                  return DropdownButtonFormField<ClubTeam>(
                    dropdownColor: AppColors.surface2,
                    style:  TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Takım *', hintText: 'Takım seçin'),
                    initialValue: _selectedTeam,
                    items: availableTeams
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedTeam = v;
                      _selectedUnit = null;
                      _selectedUid = null;
                      _selectedName = null;
                    }),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Hata: $e'),
              ),
              if (_selectedTeam != null) ...[
                const SizedBox(height: 12),
                SegmentedButton<_AssignmentMode>(
                  segments: const [
                    ButtonSegment(
                      value: _AssignmentMode.single,
                      label: Text('Tekil Üye'),
                      icon: Icon(Icons.person, size: 16),
                    ),
                    ButtonSegment(
                      value: _AssignmentMode.team,
                      label: Text('Tüm Takım'),
                      icon: Icon(Icons.groups, size: 16),
                    ),
                    ButtonSegment(
                      value: _AssignmentMode.unit,
                      label: Text('Birim'),
                      icon: Icon(Icons.apartment, size: 16),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() {
                    _mode = s.first;
                    _selectedUid = null;
                    _selectedName = null;
                    _selectedUnit = null;
                  }),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_selectedTeam != null && _mode == _AssignmentMode.single)
                _TeamMemberSelector(
                  teamId: _selectedTeam!.id,
                  selectedUid: _selectedUid,
                  onChanged: (uid, name) => setState(() {
                    _selectedUid = uid;
                    _selectedName = name;
                  }),
                ),
              if (_selectedTeam != null && _mode == _AssignmentMode.unit)
                _TeamUnitSelector(
                  teamId: _selectedTeam!.id,
                  value: _selectedUnit,
                  allowedUnitIds: _allowedUnitIdsFor(_selectedTeam!.id),
                  onChanged: (u) => setState(() {
                    _selectedUnit = u;
                    _selectedUid = null;
                    _selectedName = null;
                  }),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                style:  TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Görev Başlığı *', hintText: 'Örn: Atölye temizliği'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                style:  TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Açıklama', hintText: 'Görev detayı (isteğe bağlı)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pointsCtrl,
                keyboardType: TextInputType.number,
                style:  TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Puan', hintText: '10'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: Text(_pickedImage != null ? 'Görsel Seçildi' : 'Görsel Ekle'),
              ),
              if (_pickedImage != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
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
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text('İptal')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ata'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final requiresPerson = _mode == _AssignmentMode.single && _selectedUid == null;
    // Birim modunda bir birim seçilmesi zorunludur.
    final requiresUnit = _mode == _AssignmentMode.unit && _selectedUnit == null;

    // Client-side authorization guard (defense in depth — the Firestore rules
    // are the real enforcement). A unit lead can only target their own unit.
    if (_selectedUnit != null &&
        _selectedTeam != null &&
        !_allowedUnitIdsFor(_selectedTeam!.id).contains(_selectedUnit!['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bu birime görev atama yetkiniz yok.'),
          backgroundColor: AppColors.error));
      return;
    }

    if (title.isEmpty || (_selectedTeam == null) || requiresPerson) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Takım ve başlık zorunludur'),
          backgroundColor: AppColors.error));
      return;
    }
    if (requiresUnit) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Birim seçmelisiniz'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).value;
      final firestore = ref.read(firestoreProvider);
      final notifService = ref.read(notificationServiceProvider);
      final points = int.tryParse(_pointsCtrl.text.trim()) ?? 10;

      // Resolve the list of (uid, name) recipients.
      final recipients = <({String uid, String name})>[];
      if (_mode == _AssignmentMode.unit) {
        final unitDoc =
            await firestore.collection('units').doc(_selectedUnit!['id'] as String).get();
        final memberUids = (unitDoc.data()?['memberUids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        if (memberUids.isNotEmpty) {
          for (var i = 0; i < memberUids.length; i += 10) {
            final chunk = memberUids.sublist(
                i,
                i + 10 > memberUids.length ? memberUids.length : i + 10);
            final snap = await firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (final doc in snap.docs) {
              final data = doc.data();
              recipients.add((
                uid: doc.id,
                name: (data['displayName'] as String?) ?? 'Üye',
              ));
            }
          }
          recipients.sort((a, b) => a.name.compareTo(b.name));
        }
        if (recipients.isEmpty) {
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bu birimde görev atanacak üye yok.'),
                backgroundColor: AppColors.warning));
          }
          return;
        }
      } else if (_mode == _AssignmentMode.team) {
        final members = ref.read(teamMembersProvider(_selectedTeam!.id)).valueOrNull;
        if (members == null || members.isEmpty) {
          // Fallback to reading the team doc's memberIds directly.
          final teamDoc =
              await firestore.collection('teams').doc(_selectedTeam!.id).get();
          final memberIds = (teamDoc.data()?['memberIds'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [];
          for (final uid in memberIds) {
            final doc = await firestore.collection('users').doc(uid).get();
            recipients.add((
              uid: uid,
              name: (doc.data()?['displayName'] as String?) ?? 'Üye',
            ));
          }
        } else {
          for (final m in members) {
            recipients.add((uid: m.uid, name: m.displayName));
          }
        }
        if (recipients.isEmpty) {
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bu takımda görev atanacak üye yok.'),
                backgroundColor: AppColors.warning));
          }
          return;
        }
      } else {
        recipients.add((uid: _selectedUid!, name: _selectedName ?? 'Üye'));
      }

      // Upload task image once (client-side compressed) and reuse for every task.
      String? imageUrl;
      if (_pickedImage != null) {
        final tempId = 'task_${DateTime.now().microsecondsSinceEpoch}';
        final storageRef =
            FirebaseStorage.instance.ref().child('tasks/$tempId.jpg');
        final compressed = await _pickedImage!.compressedUploadBytes();
        if (compressed.isNotEmpty) {
          await storageRef.putData(compressed);
        } else if (_pickedImage!.dartFile != null) {
          await storageRef.putFile(_pickedImage!.dartFile!);
        } else if (_pickedImage!.bytes != null) {
          await storageRef.putData(_pickedImage!.bytes!);
        }
        imageUrl = await storageRef.getDownloadURL();
      }

      // Generate one bulk-group id so all tasks created in this batch share the
      // same group (used to notify every assignee when a comment is posted on
      // any one of the copies). Single assignments have no bulk group.
      final bulkGroupId = _mode != _AssignmentMode.single
          ? 'bulk_${DateTime.now().microsecondsSinceEpoch}'
          : null;

      // Create a task for each recipient.
      for (final recipient in recipients) {
        final docRef = await firestore.collection('tasks').add({
          'title': title,
          'description': _descCtrl.text.trim(),
          'assignedTo': recipient.uid,
          'assignedToName': recipient.name,
          'assignedByName': user?.displayName ?? 'Admin',
          'assignedBy': user?.uid,
          'points': points,
          'status': 'assigned',
          'createdAt': FieldValue.serverTimestamp(),
          'teamId': _selectedTeam?.id,
          'teamName': _selectedTeam?.name,
          'unitId': _selectedUnit?['id'],
          'unitName': _selectedUnit?['name'],
          'pointsAwarded': false,
          'imageUrl': imageUrl,
          'bulkGroupId': bulkGroupId,
          'assignmentMode': _mode.name,
        });
        await notifService.send(
          recipientId: recipient.uid,
          title: 'Yeni görev atandı',
          body: 'Sana "$title" görevi atandı. +$points puan',
          type: 'task_assigned',
          relatedId: docRef.id,
        );
      }

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(recipients.length > 1
                ? '${recipients.length} kişiye görev atandı.'
                : 'Görev atandı.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}

/// Dropdown for selecting a unit within a team.
class _TeamUnitSelector extends ConsumerWidget {
  final String teamId;
  final Map<String, dynamic>? value;
  final Set<String>? allowedUnitIds;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const _TeamUnitSelector({
    required this.teamId,
    required this.value,
    this.allowedUnitIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(teamUnitsProvider(teamId));
    return unitsAsync.when(
      data: (units) {
        // When a filter is present, only the user's authorized units appear.
        final visible = allowedUnitIds == null
            ? units
            : units.where((u) => allowedUnitIds!.contains(u['id'])).toList();
        return DropdownButtonFormField<Map<String, dynamic>>(
          dropdownColor: AppColors.surface2,
          style:  TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
              labelText: 'Birim', hintText: 'Birim seçin (isteğe bağlı)'),
          initialValue: value,
          items: [
             DropdownMenuItem<Map<String, dynamic>>(
              value: null,
              child: Text('Birim seçilmedi',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ...visible.map((u) => DropdownMenuItem(
                value: u, child: Text(u['name'] as String? ?? ''))),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Dropdown for selecting a team member.
class _TeamMemberSelector extends ConsumerWidget {
  final String teamId;
  final String? selectedUid;
  final void Function(String uid, String name) onChanged;

  const _TeamMemberSelector({
    required this.teamId,
    required this.selectedUid,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider(teamId));
    return membersAsync.when(
      data: (members) => DropdownButtonFormField<String>(
        dropdownColor: AppColors.surface2,
        style:  TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
            labelText: 'Kişi *', hintText: 'Görev atanacak kişi'),
        initialValue: selectedUid,
        items: members
            .map((u) => DropdownMenuItem(value: u.uid, child: Text(u.displayName)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            final m = members.firstWhere((m) => m.uid == v);
            onChanged(v, m.displayName);
          }
        },
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Üyeler yüklenemedi',
          style: TextStyle(color: AppColors.error)),
    );
  }
}