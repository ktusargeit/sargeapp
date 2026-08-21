import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';

// ---------------------------------------------------------------------------
// PAST TEAMS — "Geçmiş Takımlarım" section inside the profile editor.
// Pure presentation; the parent handles selected-state and persistence.
// ---------------------------------------------------------------------------

class ProfilePastTeamsSection extends ConsumerWidget {
  final String userId;
  final List<String> selectedIds;
  final void Function(ClubTeam team, bool value) onToggle;
  const ProfilePastTeamsSection({
    super.key,
    required this.userId,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(clubTeamsProvider);
    final archived = (archiveAsync.valueOrNull ?? const <ClubTeam>[])
        .where((t) => t.isArchived)
        .toList();

    if (archived.isEmpty) {
      return Text(
        'Henüz arşivlenmiş (geçmiş) takım yok.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Geçmişte yer aldığın takımları seç. Bu seçim profilde ve takımın "eski üyeler" listesinde otomatik görünür.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...archived.map((t) {
          final selected = selectedIds.contains(t.id);
          return CheckboxListTile(
            value: selected,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.sargeGold,
            title: Text(t.name,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: (t.period != null && t.period!.isNotEmpty)
                ? Text(
                    t.period!,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  )
                : null,
            onChanged: (v) => onToggle(t, v ?? false),
          );
        }),
      ],
    );
  }
}