import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/app_colors.dart';
import '../models/cleaning_models.dart';
import '../providers/cleaning_providers.dart';
import '../providers/cleaning_resolver.dart';

/// Takvim / Döngü Görünümü: önümüzdeki haftalarda kimin sırada olduğu.
class CleaningCalendarScreen extends ConsumerWidget {
  const CleaningCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingCleaningProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Temizlik Takvimi'),
      ),
      body: upcomingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppColors.error))),
        data: (weeks) {
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: weeks.length,
            itemBuilder: (_, i) => _WeekRow(schedule: weeks[i]),
          );
        },
      ),
    );
  }
}

class _WeekRow extends ConsumerWidget {
  final CleaningSchedule schedule;
  const _WeekRow({required this.schedule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = CleaningDates.keyOf(DateTime.now());
    final isCurrent = schedule.weekKey == now;
    final resolvedAsync = ref.watch(resolvedAssignmentProvider((
      schedule.effectiveAssignmentType,
      schedule.effectiveTargetIds,
      schedule.effectiveLabel,
    )));

    return Card(
      color: isCurrent ? AppColors.surface2 : AppColors.surface,
      shape: isCurrent
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.depoAccent, width: 1.2),
            )
          : null,
      child: ListTile(
        isThreeLine: true,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCurrent)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.depoAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Bu hafta',
                    style: TextStyle(color: AppColors.depoAccent, fontSize: 9)),
              ),
            Icon(Icons.calendar_today_outlined,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
        title: Text(
          CleaningDates.humanRange(schedule.weekStart),
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: resolvedAsync.when(
            loading: () => Text('Yükleniyor...',
                style: TextStyle(color: AppColors.textSecondary)),
            error: (e, _) => Text('Hata: $e',
                style: const TextStyle(color: AppColors.error)),
            data: (resolved) {
              if (resolved.users.isEmpty) {
                return Text('Atama yok',
                    style: TextStyle(color: AppColors.textSecondary));
              }
              return Text(resolved.label.isNotEmpty
                  ? '${resolved.label} · ${_names(resolved.users)}'
                  : _names(resolved.users));
            },
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
          size: 18,
        ),
        onTap: () => context.push('/cleaning/week/${schedule.weekKey}'),
      ),
    );
  }

  String _names(List<AppUser> users) =>
      users.map((u) => u.displayName).join(', ');
}