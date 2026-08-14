import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../models/cleaning_models.dart';
import '../providers/cleaning_permissions.dart';
import '../providers/cleaning_providers.dart';
import '../providers/cleaning_resolver.dart';

/// Temizlik Ana Ekranı: bu haftanın sorumlusu/sorumluları büyük gösterilir,
/// altında bu haftanın alışveriş listesi (checkbox'larla).
class CleaningMainScreen extends ConsumerWidget {
  const CleaningMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekKey = CleaningDates.keyOf(DateTime.now());
    final weekStart = CleaningDates.parseKey(weekKey);
    final scheduleAsync = ref.watch(cleaningScheduleProvider(weekKey));
    final isManager = ref.watch(cleaningManagerProvider);
    final currentUser = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Temizlik'),
        actions: [
          if (isManager)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Yönetim',
              onPressed: () => context.push('/cleaning/manage'),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Takvim',
            onPressed: () => context.push('/cleaning/calendar'),
          ),
        ],
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppColors.error))),
        data: (schedule) {
          final hasDoc = schedule.weekKey.isNotEmpty &&
              schedule.weekKey == weekKey &&
              (schedule.assignmentType != 'individual' ||
                  schedule.targetIds.isNotEmpty ||
                  schedule.items.isNotEmpty ||
                  schedule.isOverridden);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(cleaningScheduleProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Week header
                Text(
                  'Bu Hafta (${CleaningDates.humanRange(weekStart)})',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (!hasDoc && schedule.items.isEmpty)
                  _EmptyThisWeek(isManager: isManager)
                else ...[
                  // Responsible person(s) card
                  _ResponsibleCard(
                    schedule: schedule,
                    weekKey: weekKey,
                    isManager: isManager,
                  ),
                  const SizedBox(height: 16),
                  // Shopping list
                  _ShoppingList(
                    weekKey: weekKey,
                    schedule: schedule,
                    isManager: isManager,
                    currentUser: currentUser,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyThisWeek extends StatelessWidget {
  final bool isManager;
  const _EmptyThisWeek({required this.isManager});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.cleaning_services_outlined,
                color: AppColors.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(
              'Bu hafta için henüz bir temizlik kaydı oluşturulmadı.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isManager
                  ? 'Yönetim ekranından döngüyü kurup önümüzdeki haftaları oluşturabilirsiniz.'
                  : 'Kaptan/admin döngüyü kurduğunda burada göreceksiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsibleCard extends ConsumerWidget {
  final CleaningSchedule schedule;
  final String weekKey;
  final bool isManager;

  const _ResponsibleCard({
    required this.schedule,
    required this.weekKey,
    required this.isManager,
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
                Icon(Icons.person_search_outlined,
                    color: AppColors.depoAccent, size: 20),
                const SizedBox(width: 8),
                Text('Bu Haftanın Sorumlusu',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                if (schedule.isOverridden) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Manuel',
                        style: TextStyle(
                            color: AppColors.warning, fontSize: 10)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            resolvedAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.depoAccent))),
              ),
              error: (e, _) => Text('Hata: $e',
                  style: const TextStyle(color: AppColors.error)),
              data: (resolved) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (resolved.label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        resolved.label,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (resolved.users.isEmpty)
                    Text('Sorumlu bulunamadı.',
                        style: TextStyle(color: AppColors.textSecondary))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: resolved.users
                          .map((u) => _PersonChip(user: u))
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  final AppUser user;
  const _PersonChip({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.surface3,
            backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null || user.photoUrl!.isEmpty
                ? Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 6),
          Text(user.displayName,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ShoppingList extends ConsumerWidget {
  final String weekKey;
  final CleaningSchedule schedule;
  final bool isManager;
  final AppUser? currentUser;

  const _ShoppingList({
    required this.weekKey,
    required this.schedule,
    required this.isManager,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = schedule.items;
    final allDone = items.isNotEmpty && items.every((i) => i.done);

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart_outlined,
                    color: AppColors.tasksGreen, size: 20),
                const SizedBox(width: 8),
                Text('Alışveriş Listesi',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                if (schedule.completed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Tamamlandı',
                        style: TextStyle(
                            color: AppColors.success, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('Bu hafta için liste yok.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...items.map((item) => _ItemTile(
                    weekKey: weekKey,
                    item: item,
                    currentUser: currentUser,
                  )),
            if (isManager) ...[
              const Divider(height: 24),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _addItem(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ürün Ekle'),
                  ),
                  const Spacer(),
                  if (!schedule.completed)
                    TextButton.icon(
                      onPressed: allDone
                          ? () => _markCompleted(context, ref, true)
                          : null,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Tamamlandı İşaretle'),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _markCompleted(context, ref, false),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Geri Al'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürün Ekle'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Örn: Çöp poşeti'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Ekle')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Ekleniyor...',
      successMessage: 'Liste öğesi eklendi.',
      operation: () =>
          ref.read(cleaningRepositoryProvider).addWeekItem(weekKey, name),
    );
  }

  Future<void> _markCompleted(
      BuildContext context, WidgetRef ref, bool completed) async {
    final user = currentUser;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Güncelleniyor...',
      successMessage: completed ? 'Tamamlandı.' : 'Geri alındı.',
      operation: () => ref
          .read(cleaningRepositoryProvider)
          .setWeekCompleted(
            weekKey: weekKey,
            completed: completed,
            uid: user?.uid ?? '',
            displayName: user?.displayName ?? '',
          ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final String weekKey;
  final CleaningItem item;
  final AppUser? currentUser;

  const _ItemTile({
    required this.weekKey,
    required this.item,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _toggle(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: item.done,
              onChanged: (_) => _toggle(context, ref),
              activeColor: AppColors.tasksGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  color: item.done
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 14,
                  decoration:
                      item.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (item.done && item.doneByName != null)
              Text(item.doneByName!,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final user = currentUser;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Güncelleniyor...',
      successMessage: item.done ? 'İşaret kaldırıldı.' : 'Alındı olarak işaretlendi.',
      operation: () => ref
          .read(cleaningRepositoryProvider)
          .setItemDone(
            weekKey: weekKey,
            item: item,
            done: !item.done,
            uid: user?.uid ?? '',
            displayName: user?.displayName ?? '',
          ),
    );
  }
}