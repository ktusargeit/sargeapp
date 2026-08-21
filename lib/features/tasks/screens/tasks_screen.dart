import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../models/task_models.dart';
import '../widgets/task_add_dialog.dart';
import '../widgets/task_detail_panel.dart';
import '../widgets/task_filters.dart';
import '../widgets/task_list.dart';

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
          builder: (ctx) => TaskDetailSheet(taskId: taskId),
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
    final currentUid = authUser?.uid ?? appUser?.uid;
    final profileStillLoading = authUser != null && appUser == null;
    final teamsAsync = ref.watch(clubTeamsProvider);
    final visibleTeams = teamsAsync.valueOrNull ?? [];
    final isUnitLead = appUser?.isUnitLead ?? false;
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
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Görev ara...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textSecondary),
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
                    TaskFilterDropdown<ClubTeam>(
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
                      TaskTeamUnitDropdown(
                        teamId: _filterTeamId!,
                        value: _filterUnitId,
                        onChanged: (u) => setState(() => _filterUnitId = u),
                      ),
                    const SizedBox(width: 8),
                    if (_filterTeamId != null)
                      TaskPersonFilterDropdown(
                        teamId: _filterTeamId!,
                        value: _filterPersonId,
                        onChanged: (uid) => setState(() => _filterPersonId = uid),
                      ),
                    const SizedBox(width: 8),
                    TaskFilterDropdown<TaskStatus>(
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
          : TasksBody(
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
      builder: (ctx) => const AddTaskDialog(),
    );
  }
}