import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../models/cleaning_models.dart';
import '../providers/cleaning_permissions.dart';
import '../providers/cleaning_providers.dart';
import '../providers/cleaning_resolver.dart';
import '../widgets/assignment_editor_sheet.dart';

/// A single week's detail: responsible person(s) + shopping list, with a
/// manual override option for admins/kaptan.
class CleaningWeekScreen extends ConsumerWidget {
  final String weekKey;
  const CleaningWeekScreen({super.key, required this.weekKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(cleaningScheduleProvider(weekKey));
    final isManager = ref.watch(cleaningManagerProvider);
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(CleaningDates.humanRange(CleaningDates.parseKey(weekKey))),
        actions: [
          if (isManager)
            TextButton(
              onPressed: () => _override(context, ref),
              child: const Text('Atamayı Değiştir'),
            ),
        ],
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppColors.error))),
        data: (schedule) {
          final hasDoc = schedule.assignmentType != 'individual' ||
              schedule.targetIds.isNotEmpty ||
              schedule.items.isNotEmpty ||
              schedule.isOverridden;
          if (!hasDoc) {
            return Center(
                child: Text('Bu hafta için kayıt yok.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ResponsibleBlock(
                  schedule: schedule, isManager: isManager, weekKey: weekKey),
              const SizedBox(height: 16),
              _ShoppingBlock(
                  schedule: schedule,
                  weekKey: weekKey,
                  isManager: isManager,
                  currentUser: currentUser),
            ],
          );
        },
      ),
    );
  }

  Future<void> _override(BuildContext context, WidgetRef ref) async {
    final schedule = ref.read(cleaningScheduleProvider(weekKey)).valueOrNull;
    final draft = await showAssignmentEditorSheet(
      context,
      ref,
      initial: AssignmentDraft(
        assignmentType: schedule?.effectiveAssignmentType ??
            CleaningAssignmentType.individual,
        targetIds: schedule?.effectiveTargetIds ?? const [],
        label: schedule?.effectiveLabel,
      ),
    );
    if (draft == null) return;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Kaydediliyor...',
      successMessage: 'Atama güncellendi.',
      operation: () => ref.read(cleaningRepositoryProvider).overrideWeek(
            weekKey: weekKey,
            assignmentType: draft.assignmentType,
            targetIds: draft.targetIds,
            label: draft.label,
          ),
    );
  }
}

class _ResponsibleBlock extends ConsumerWidget {
  final CleaningSchedule schedule;
  final bool isManager;
  final String weekKey;

  const _ResponsibleBlock({
    required this.schedule,
    required this.isManager,
    required this.weekKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedAsync = ref.watch(resolvedAssignmentProvider((
      schedule.effectiveAssignmentType,
      schedule.effectiveTargetIds,
      schedule.effectiveLabel,
    )));

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_search_outlined,
                    color: AppColors.depoAccent, size: 20),
                const SizedBox(width: 8),
                Text('Sorumlu',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                if (schedule.isOverridden) ...[
                  const SizedBox(width: 8),
                  const Text('Manuel',
                      style: TextStyle(color: AppColors.warning, fontSize: 11)),
                ],
                const Spacer(),
                if (isManager && schedule.isOverridden)
                  IconButton(
                    icon: const Icon(Icons.undo, size: 18),
                    tooltip: 'Manuel atamayı kaldır',
                    onPressed: () => _clearOverride(context, ref),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            resolvedAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.depoAccent))),
              ),
              error: (e, _) => Text('Hata: $e',
                  style: const TextStyle(color: AppColors.error)),
              data: (resolved) {
                if (resolved.users.isEmpty) {
                  return Text('Sorumlu bulunamadı.',
                      style: TextStyle(color: AppColors.textSecondary));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (resolved.label.isNotEmpty)
                      Text(resolved.label,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(resolved.users.map((u) => u.displayName).join(', '),
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearOverride(BuildContext context, WidgetRef ref) async {
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Kaldırılıyor...',
      successMessage: 'Manuel atama kaldırıldı.',
      operation: () =>
          ref.read(cleaningRepositoryProvider).clearOverride(weekKey),
    );
  }
}

class _ShoppingBlock extends ConsumerWidget {
  final CleaningSchedule schedule;
  final String weekKey;
  final bool isManager;
  final AppUser? currentUser;

  const _ShoppingBlock({
    required this.schedule,
    required this.weekKey,
    required this.isManager,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = schedule.items;

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    color: AppColors.tasksGreen, size: 20),
                const SizedBox(width: 8),
                Text('Alışveriş Listesi',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('Liste yok.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...items.map((item) => CheckboxListTile(
                    value: item.done,
                    onChanged: (v) => _toggle(context, ref, item, v ?? false),
                    activeColor: AppColors.tasksGreen,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name,
                        style: TextStyle(
                            color: item.done
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration:
                                item.done ? TextDecoration.lineThrough : null)),
                    subtitle: item.done && item.doneByName != null
                        ? Text(item.doneByName!,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11))
                        : null,
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, CleaningItem item, bool done) async {
    final user = currentUser;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Güncelleniyor...',
      successMessage: done ? 'İşaretlendi.' : 'İşaret kaldırıldı.',
      operation: () => ref.read(cleaningRepositoryProvider).setItemDone(
            weekKey: weekKey,
            item: item,
            done: done,
            uid: user?.uid ?? '',
            displayName: user?.displayName ?? '',
          ),
    );
  }
}
