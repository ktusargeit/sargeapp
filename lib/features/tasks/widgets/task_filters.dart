import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../team/providers/team_providers.dart';

/// Reusable dropdown filter for any type.
class TaskFilterDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelFn;
  final String Function(T) idFn;
  final ValueChanged<T?> onChanged;
  final VoidCallback? onClear;

  const TaskFilterDropdown({
    super.key,
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
          style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
          hint: Text(hint,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                  child: Text(labelFn(item), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
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
class TaskTeamUnitDropdown extends ConsumerWidget {
  final String teamId;
  final String? value;
  final ValueChanged<String?> onChanged;

  const TaskTeamUnitDropdown({
    super.key,
    required this.teamId,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(teamUnitsProvider(teamId));
    return unitsAsync.when(
      data: (units) => TaskFilterDropdown<Map<String, dynamic>>(
        hint: 'Birim',
        value: value != null && units.any((u) => u['id'] == value)
            ? units.firstWhere((u) => u['id'] == value)
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
class TaskPersonFilterDropdown extends ConsumerWidget {
  final String teamId;
  final String? value;
  final ValueChanged<String?> onChanged;

  const TaskPersonFilterDropdown({
    super.key,
    required this.teamId,
    required this.value,
    required this.onChanged,
  });

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
            style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
            hint: Text('Kişi',
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
                    child: Text(u.displayName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
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