import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../models/task_models.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery(WidgetRef ref) {
    final firestore = ref.read(firestoreProvider);
    final uid = ref.read(authStateProvider).value?.uid;
    final isAdmin = ref.watch(isAdminProvider);

    Query<Map<String, dynamic>> q = firestore.collection('tasks');

    // Only keep the essential user-scope filter at Firestore level.
    // Team, unit, and status filters are applied client-side to avoid
    // requiring composite indexes for every combination.
    if (!isAdmin && uid != null) {
      q = q.where('assignedTo', isEqualTo: uid);
    }

    q = q.orderBy('createdAt', descending: true);
    return q;
  }

  /// Applies team / unit / status filters client-side after Firestore
  /// delivers the base set.  This avoids composite-index failures and
  /// makes the "Tümü" (clear) path trivial – just pass null/empty.
  List<TaskModel> _applyClientFilters(List<TaskModel> tasks) {
    if (_filterTeamId != null && _filterTeamId!.isNotEmpty) {
      tasks = tasks.where((t) => t.teamId == _filterTeamId).toList();
    }
    if (_filterUnitId != null && _filterUnitId!.isNotEmpty) {
      tasks = tasks.where((t) => t.unitId == _filterUnitId).toList();
    }
    if (_filterStatus != null) {
      tasks = tasks.where((t) => t.status == _filterStatus!).toList();
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

  /// Points color follows the same logic as status color.
  Color _pointsColor(TaskStatus status) => _statusColor(status);

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final appUser = ref.watch(currentAppUserProvider).value;
    final teamsAsync = ref.watch(clubTeamsProvider);
    final visibleTeams = teamsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.tasksBg,
      appBar: AppBar(
        title: const Text('Görevler'),
        backgroundColor: AppColors.tasksBg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 80),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Görev ara...',
                    hintStyle: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: AppColors.textSecondary),
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
                  onChanged: (v) => setState(
                      () => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Aktif',
                          style: TextStyle(fontSize: 12)),
                      selected: !_showHistory,
                      selectedColor:
                          AppColors.tasksAccent.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.tasksAccent,
                      onSelected: (_) =>
                          setState(() => _showHistory = false),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Geçmiş',
                          style: TextStyle(fontSize: 12)),
                      selected: _showHistory,
                      selectedColor:
                          AppColors.textSecondary.withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setState(() => _showHistory = true),
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
                      }),
                      onClear: () => setState(() {
                        _filterTeamId = null;
                        _filterUnitId = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    if (_filterTeamId != null)
                      _TeamUnitDropdown(
                        teamId: _filterTeamId!,
                        value: _filterUnitId,
                        onChanged: (u) =>
                            setState(() => _filterUnitId = u),
                      ),
                    const SizedBox(width: 8),
                    _FilterDropdown<TaskStatus>(
                      hint: 'Durum',
                      value: _filterStatus,
                      items: TaskStatus.values,
                      labelFn: (s) => s.name == 'inProgress'
                          ? 'Devam Ediyor'
                          : s.name == 'pendingApproval'
                              ? 'Onay Bekliyor'
                              : s.name == 'assigned'
                                  ? 'Atandı'
                                  : s.name == 'completed'
                                      ? 'Tamamlandı'
                                      : s.name == 'rejected'
                                          ? 'Reddedildi'
                                          : s.name == 'cancelled'
                                              ? 'İptal'
                                              : s.name,
                      idFn: (s) => s.name,
                      onChanged: (s) =>
                          setState(() => _filterStatus = s),
                      onClear: () =>
                          setState(() => _filterStatus = null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildQuery(ref).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.tasksAccent));
          }
          final docs = snapshot.data?.docs ?? [];
          var tasks = docs.map((d) => TaskModel.fromDoc(d)).toList();

          // 1) Apply team / unit / status filters client-side
          tasks = _applyClientFilters(tasks);

          // 2) Apply search query client-side
          final filtered = _searchQuery.isEmpty
              ? tasks
              : tasks.where((t) {
                  return t.title
                          .toLowerCase()
                          .contains(_searchQuery) ||
                      t.assignedByName
                          .toLowerCase()
                          .contains(_searchQuery) ||
                      (t.unitName?.toLowerCase().contains(_searchQuery) ??
                          false) ||
                      (t.teamName?.toLowerCase().contains(_searchQuery) ??
                          false);
                }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text('Gösterilecek görev yok.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          // Client-side active/history filter
          final taskList = _showHistory
              ? filtered
              : filtered
                  .where((t) =>
                      t.status == TaskStatus.assigned ||
                      t.status == TaskStatus.inProgress ||
                      t.status == TaskStatus.pendingApproval)
                  .toList();

          if (taskList.isEmpty) {
            return const Center(
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
                task: task,
                isAdmin: isAdmin,
                isUnitLead: appUser?.isUnitLead ?? false,
                currentUid: appUser?.uid,
                statusColor: _statusColor(task.status),
                pointsColor: _pointsColor(task.status),
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTaskDialog(context),
              backgroundColor: AppColors.tasksAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Görev Ekle',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            )
          : null,
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddTaskDialog(),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canApprove = _canApprove(context, ref);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        onTap: () => _showDetail(context, ref, canApprove),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3, height: 20,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(task.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(task.statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pointsColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: pointsColor.withValues(alpha: 0.4)),
                    ),
                    child: Text('${task.points} puan',
                        style: TextStyle(
                            color: pointsColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(task.assignedByName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  if (task.teamName != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.groups_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(task.teamName!,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                  ],
                  const Spacer(),
                  // ── Action buttons on card ──
                  if (task.assignedTo == currentUid &&
                      (task.status == TaskStatus.assigned ||
                          task.status == TaskStatus.inProgress))
                    _ActionButton(
                      label: '✔',
                      color: AppColors.success,
                      onTap: () =>
                          _confirmComplete(context, ref),
                    ),
                  if (task.status == TaskStatus.pendingApproval &&
                      canApprove)
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

  void _confirmComplete(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Görevi Tamamla'),
        content: const Text(
            'Görevi tamamladığınızdan emin misiniz?\n\n'
            'Görev onay için yetkiliye iletilecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _updateStatus(ctx, ref, TaskStatus.pendingApproval);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
            child: const Text('Evet, tamamladım'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
      BuildContext ctx, WidgetRef ref, TaskStatus newStatus) async {
    try {
      await ref
          .read(firestoreProvider)
          .collection('tasks')
          .doc(task.id)
          .update({'status': newStatus.name});
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _approveTask(
      BuildContext ctx, WidgetRef ref, bool approve) async {
    final uid = ref.read(authStateProvider).value?.uid;
    try {
      if (approve) {
        // Re-read latest task data to prevent double point award
        final taskDoc = await ref
            .read(firestoreProvider)
            .collection('tasks')
            .doc(task.id)
            .get();
        final alreadyAwarded =
            (taskDoc.data()?['pointsAwarded'] as bool?) ?? false;

        final batch = ref.read(firestoreProvider).batch();
        batch.update(
            ref
                .read(firestoreProvider)
                .collection('tasks')
                .doc(task.id), {
          'status': 'completed',
          'approvedBy': uid,
        });
        if (!alreadyAwarded && !task.pointsAwarded) {
          batch.update(
              ref
                  .read(firestoreProvider)
                  .collection('users')
                  .doc(task.assignedTo), {
            'points': FieldValue.increment(task.points),
            'weeklyPoints': FieldValue.increment(task.points),
          });
          batch.update(
              ref
                  .read(firestoreProvider)
                  .collection('tasks')
                  .doc(task.id), {
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
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, bool canApprove) {
    final isAssignee = task.assignedTo == currentUid;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(task.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.description.isNotEmpty)
                Text(task.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 12),
              _infoLine('Atanan', task.assignedByName),
              _infoLine('Durum', task.statusLabel),
              if (task.teamName != null)
                _infoLine('Takım', task.teamName!),
              if (task.unitName != null)
                _infoLine('Birim', task.unitName!),
              _infoLine('Puan', '${task.points}'),
              if (task.pointsAwarded)
                _infoLine('Puan Durumu', 'Verildi ✓'),
            ],
          ),
        ),
        actions: [
          // ── User self-service actions ──
          if (isAssignee &&
              task.status == TaskStatus.assigned)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(
                    context, ref, TaskStatus.inProgress);
              },
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Başla'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tasksAccent,
                  foregroundColor: Colors.white),
            ),
          if (isAssignee &&
              task.status == TaskStatus.inProgress)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(context, ref,
                    TaskStatus.pendingApproval);
              },
              icon: const Icon(Icons.check_circle_outline,
                  size: 16),
              label: const Text('Tamamlandı Olarak İşaretle'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
            ),
          // ── Approve / Reject for authorized users ──
          if (task.status == TaskStatus.pendingApproval &&
              canApprove) ...[
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _approveTask(context, ref, false);
              },
              icon: const Icon(Icons.close,
                  size: 16, color: AppColors.error),
              label: const Text('Reddet',
                  style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _approveTask(context, ref, true);
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Onayla'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
            ),
          ] else
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            Flexible(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13)),
            ),
          ],
        ),
      );
}

/// Small text button for task actions.
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label, required this.color, required this.onTap});

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
          style:
              const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          hint: Text(hint,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          items: [
            if (value != null)
              DropdownMenuItem<T?>(
                value: null,
                child: Text('Tümü',
                    style: TextStyle(
                        color: AppColors.textSecondary
                            .withValues(alpha: 0.6),
                        fontSize: 12)),
              ),
            ...items.map((item) => DropdownMenuItem<T?>(
                  value: item,
                  child: Text(labelFn(item),
                      style: const TextStyle(fontSize: 12)),
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

  const _TeamUnitDropdown({
    required this.teamId,
    required this.value,
    required this.onChanged,
  });

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
      loading: () => const SizedBox(
          width: 16, child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ADD TASK DIALOG — Takım → Birim → Kişi
// ═══════════════════════════════════════════════════════════════════════

class _AddTaskDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '10');

  ClubTeam? _selectedTeam;
  Map<String, dynamic>? _selectedUnit;
  String? _selectedUid;
  String? _selectedName;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
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
              // ── Team selection ──
              teamsAsync.when(
                data: (teams) =>
                    DropdownButtonFormField<ClubTeam>(
                  dropdownColor: AppColors.surface2,
                  style:
                      const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'Takım *',
                      hintText: 'Takım seçin'),
                  value: _selectedTeam,
                  items: teams
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedTeam = v;
                    _selectedUnit = null;
                    _selectedUid = null;
                    _selectedName = null;
                  }),
                ),
                loading: () =>
                    const CircularProgressIndicator(),
                error: (e, _) => Text('Hata: $e'),
              ),
              const SizedBox(height: 12),

              // ── Unit selection (team-scoped) ──
              if (_selectedTeam != null)
                _TeamUnitSelector(
                  teamId: _selectedTeam!.id,
                  value: _selectedUnit,
                  onChanged: (u) => setState(() {
                    _selectedUnit = u;
                    _selectedUid = null;
                    _selectedName = null;
                  }),
                ),
              const SizedBox(height: 12),

              // ── Person selection (team members) ──
              if (_selectedTeam != null)
                _TeamMemberSelector(
                  teamId: _selectedTeam!.id,
                  selectedUid: _selectedUid,
                  onChanged: (uid, name) => setState(() {
                    _selectedUid = uid;
                    _selectedName = name;
                  }),
                ),
              const SizedBox(height: 12),

              // ── Task fields ──
              TextField(
                controller: _titleCtrl,
                style:
                    const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Görev Başlığı *',
                    hintText: 'Örn: Atölye temizliği'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                style:
                    const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Görev detayı (isteğe bağlı)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pointsCtrl,
                keyboardType: TextInputType.number,
                style:
                    const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Puan', hintText: '10'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _loading
                ? null
                : () => Navigator.pop(context),
            child: const Text('İptal')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ata'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _selectedUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Takım, kişi ve başlık zorunludur'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).value;
      final docRef = await ref.read(firestoreProvider).collection('tasks').add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'assignedTo': _selectedUid!,
        'assignedByName': user?.displayName ?? 'Admin',
        'assignedBy': user?.uid,
        'points': int.tryParse(_pointsCtrl.text.trim()) ?? 10,
        'status': 'assigned',
        'createdAt': FieldValue.serverTimestamp(),
        'teamId': _selectedTeam?.id,
        'teamName': _selectedTeam?.name,
        'unitId': _selectedUnit?['id'],
        'unitName': _selectedUnit?['name'],
        'pointsAwarded': false,
      });
      // Send notification to assigned user
      final notifService = ref.read(notificationServiceProvider);
      await notifService.send(
        recipientId: _selectedUid!,
        title: 'Yeni görev atandı',
        body: 'Sana "${_titleCtrl.text.trim()}" görevi atandı. +${int.tryParse(_pointsCtrl.text.trim()) ?? 10} puan',
        type: 'task_assigned',
        relatedId: docRef.id,
      );
      if (mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Görev atandı.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }
}

/// Dropdown for selecting a unit within a team.
class _TeamUnitSelector extends ConsumerWidget {
  final String teamId;
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const _TeamUnitSelector({
    required this.teamId,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(teamUnitsProvider(teamId));
    return unitsAsync.when(
      data: (units) =>
          DropdownButtonFormField<Map<String, dynamic>>(
        dropdownColor: AppColors.surface2,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
            labelText: 'Birim',
            hintText: 'Birim seçin (isteğe bağlı)'),
        value: value,
        items: [
          const DropdownMenuItem<Map<String, dynamic>>(
            value: null,
            child: Text('Birim seçilmedi',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ...units.map((u) => DropdownMenuItem(
              value: u,
              child: Text(u['name'] as String? ?? ''))),
        ],
        onChanged: onChanged,
      ),
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
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
            labelText: 'Kişi *',
            hintText: 'Görev atanacak kişi'),
        value: selectedUid,
        items: members
            .map((u) => DropdownMenuItem(
                value: u.uid, child: Text(u.displayName)))
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