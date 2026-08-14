import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../models/cleaning_models.dart';

/// A draft cleaning assignment: a type + targets + optional label.
class AssignmentDraft {
  final String assignmentType;
  final List<String> targetIds;
  final String? label;

  const AssignmentDraft({
    required this.assignmentType,
    required this.targetIds,
    this.label,
  });
}

/// Opens a bottom sheet to edit a cleaning assignment slot.
///
/// Returns an [AssignmentDraft] or `null` if cancelled.
Future<AssignmentDraft?> showAssignmentEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  AssignmentDraft? initial,
}) {
  return showModalBottomSheet<AssignmentDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _AssignmentEditorSheet(initial: initial),
  );
}

class _AssignmentEditorSheet extends ConsumerStatefulWidget {
  final AssignmentDraft? initial;
  const _AssignmentEditorSheet({this.initial});

  @override
  ConsumerState<_AssignmentEditorSheet> createState() =>
      _AssignmentEditorSheetState();
}

class _AssignmentEditorSheetState
    extends ConsumerState<_AssignmentEditorSheet> {
  late String _type;
  late List<String> _targetIds;
  late final TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.initial?.assignmentType ?? CleaningAssignmentType.individual;
    _targetIds = List.of(widget.initial?.targetIds ?? const []);
    _labelCtrl = TextEditingController(text: widget.initial?.label ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  String _defaultLabel() {
    switch (_type) {
      case CleaningAssignmentType.team:
        return _targetIds.isEmpty ? '' : 'Takım';
      case CleaningAssignmentType.unit:
        return _targetIds.isEmpty ? '' : 'Birim';
      case CleaningAssignmentType.individual:
        return _targetIds.isEmpty ? '' : 'Tek Kişi';
      case CleaningAssignmentType.customGroup:
        return _targetIds.isEmpty ? '' : 'Özel Grup';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sıra Ataması',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Type selector
              DropdownButtonFormField<String>(
                initialValue: _type,
                dropdownColor: AppColors.surface2,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Atama Türü'),
                items: CleaningAssignmentType.all
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(CleaningAssignmentType.label(t))))
                    .toList(),
                onChanged: (v) => setState(() {
                  _type = v ?? CleaningAssignmentType.individual;
                  _targetIds = [];
                }),
              ),
              const SizedBox(height: 12),
              // Target selector depending on type
              Flexible(child: _buildTargetSelector()),
              const SizedBox(height: 12),
              TextField(
                controller: _labelCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Etiket (opsiyonel)',
                  hintText: _defaultLabel().isEmpty
                      ? 'Örn: Hafta Sonu Ekibi'
                      : _defaultLabel(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.depoAccent),
                    onPressed: _targetIds.isEmpty
                        ? null
                        : () {
                            Navigator.pop(
                              context,
                              AssignmentDraft(
                                assignmentType: _type,
                                targetIds: _targetIds,
                                label: _labelCtrl.text.trim().isEmpty
                                    ? null
                                    : _labelCtrl.text.trim(),
                              ),
                            );
                          },
                    child: const Text('Seç'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetSelector() {
    switch (_type) {
      case CleaningAssignmentType.team:
        return _TeamSelector(
          selectedId: _targetIds.isEmpty ? null : _targetIds.first,
          onSelect: (id) => setState(() => _targetIds = [id]),
        );
      case CleaningAssignmentType.unit:
        return _UnitSelector(
          selectedUnitId: _targetIds.isEmpty ? null : _targetIds.first,
          onSelect: (id) => setState(() => _targetIds = [id]),
        );
      case CleaningAssignmentType.customGroup:
        return _UserMultiSelector(
          selectedIds: _targetIds,
          onChanged: (ids) => setState(() => _targetIds = ids),
        );
      case CleaningAssignmentType.individual:
      default:
        return _UserSingleSelector(
          selectedId: _targetIds.isEmpty ? null : _targetIds.first,
          onSelect: (id) => setState(() => _targetIds = [id]),
        );
    }
  }
}

class _TeamSelector extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _TeamSelector({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(clubTeamsProvider).valueOrNull ?? [];
    return ListView.separated(
      shrinkWrap: true,
      itemCount: teams.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final t = teams[i];
        final selected = t.id == selectedId;
        return RadioListTile<String>(
          value: t.id,
          groupValue: selectedId,
          onChanged: (_) => onSelect(t.id),
          title: Text(t.name, style: TextStyle(color: AppColors.textPrimary)),
          secondary: Icon(selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.depoAccent : AppColors.textSecondary),
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }
}

class _UnitSelector extends ConsumerStatefulWidget {
  final String? selectedUnitId;
  final ValueChanged<String> onSelect;

  const _UnitSelector({required this.selectedUnitId, required this.onSelect});

  @override
  ConsumerState<_UnitSelector> createState() => _UnitSelectorState();
}

class _UnitSelectorState extends ConsumerState<_UnitSelector> {
  String? _teamId;

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(clubTeamsProvider).valueOrNull ?? [];
    final units = _teamId == null
        ? <TeamUnit>[]
        : ref.watch(teamUnitsListProvider(_teamId!)).valueOrNull ?? [];
    final grouped = <String, List<TeamUnit>>{};
    for (final u in units) {
      grouped.putIfAbsent(u.teamId, () => []).add(u);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _teamId,
          dropdownColor: AppColors.surface2,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Takım'),
          items: teams
              .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
              .toList(),
          onChanged: (v) => setState(() => _teamId = v),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: units.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Önce bir takım seçin.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: units.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final u = units[i];
                    final selected = u.id == widget.selectedUnitId;
                    return RadioListTile<String>(
                      value: u.id,
                      groupValue: widget.selectedUnitId,
                      onChanged: (_) => widget.onSelect(u.id),
                      title: Text(u.name,
                          style: TextStyle(color: AppColors.textPrimary)),
                      secondary: Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          color: selected
                              ? AppColors.depoAccent
                              : AppColors.textSecondary),
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _UserSingleSelector extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _UserSingleSelector({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    return _UserList(
      users: users,
      selectedIds: selectedId == null ? const [] : [selectedId!],
      single: true,
      onToggle: (u) => onSelect(u.uid),
    );
  }
}

class _UserMultiSelector extends ConsumerWidget {
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const _UserMultiSelector(
      {required this.selectedIds, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    return _UserList(
      users: users,
      selectedIds: selectedIds,
      single: false,
      onToggle: (u) {
        final next = List.of(selectedIds);
        if (next.contains(u.uid)) {
          next.remove(u.uid);
        } else {
          next.add(u.uid);
        }
        onChanged(next);
      },
    );
  }
}

class _UserList extends StatelessWidget {
  final List<AppUser> users;
  final List<String> selectedIds;
  final bool single;
  final ValueChanged<AppUser> onToggle;

  const _UserList({
    required this.users,
    required this.selectedIds,
    required this.single,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
          child: Text('Kullanıcı bulunamadı.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    final sorted = List.of(users)
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return ListView.separated(
      shrinkWrap: true,
      itemCount: sorted.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final u = sorted[i];
        final selected = selectedIds.contains(u.uid);
        return CheckboxListTile(
          value: selected,
          onChanged: single
              ? (v) {
                  if (v == true) onToggle(u);
                }
              : (v) => onToggle(u),
          title: Text(u.displayName,
              style: TextStyle(color: AppColors.textPrimary)),
          secondary: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface2,
            backgroundImage:
                u.photoUrl != null && u.photoUrl!.isNotEmpty
                    ? NetworkImage(u.photoUrl!)
                    : null,
            child: u.photoUrl == null || u.photoUrl!.isEmpty
                ? Icon(Icons.person_outline,
                    size: 16, color: AppColors.textSecondary)
                : null,
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }
}