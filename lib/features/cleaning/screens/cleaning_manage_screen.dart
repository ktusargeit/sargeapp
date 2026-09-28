import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../models/cleaning_models.dart';
import '../providers/cleaning_providers.dart';
import '../widgets/assignment_editor_sheet.dart';

/// Temizlik Yönetim Ekranı (kaptan/admin): döngüyü düzenleme, haftaları
/// oluşturma ve alışveriş listesi şablonu.
class CleaningManageScreen extends ConsumerWidget {
  const CleaningManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rotationAsync = ref.watch(cleaningRotationProvider);
    final config = ref.watch(cleaningConfigProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Temizlik Yönetimi'),
      ),
      body: rotationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppColors.error))),
        data: (slots) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionTitle(
                icon: Icons.repeat,
                title: 'Temizlik Döngüsü',
                subtitle:
                    'Sıralar bu sırayla, önümüzdeki haftalara döngüsel olarak atanır.',
              ),
              const SizedBox(height: 8),
              if (slots.isEmpty)
                Text('Henüz sıra eklenmedi.',
                    style: TextStyle(color: AppColors.textSecondary))
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: slots.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final ordered = slots.map((s) => s.id).toList();
                    final moved = ordered.removeAt(oldIndex);
                    ordered.insert(newIndex, moved);
                    _reorder(context, ref, ordered);
                  },
                  itemBuilder: (_, i) {
                    final slot = slots[i];
                    return _SlotTile(
                      key: ValueKey(slot.id),
                      slot: slot,
                      index: i,
                    );
                  },
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _addSlot(context, ref, slots.length),
                icon: const Icon(Icons.add),
                label: const Text('Sıra Ekle'),
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                icon: Icons.event_available,
                title: 'Haftaları Oluştur',
                subtitle:
                    'Şablondaki listeyi kullanarak önümüzdeki haftaları döngüye göre otomatik oluşturur.',
              ),
              const SizedBox(height: 8),
              _RealizePanel(slots: slots, config: config),
              const SizedBox(height: 24),
              const _SectionTitle(
                icon: Icons.list_alt,
                title: 'Alışveriş Listesi Şablonu',
                subtitle: 'Her yeni haftaya bu listedeki ürünler eklenir.',
              ),
              const SizedBox(height: 8),
              _TemplateEditor(initial: config?.shoppingTemplate ?? const []),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addSlot(BuildContext context, WidgetRef ref, int order) async {
    final draft = await showAssignmentEditorSheet(context, ref);
    if (draft == null) return;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Ekleniyor...',
      successMessage: 'Sıra eklendi.',
      operation: () => ref.read(cleaningRepositoryProvider).addSlot(
            order: order,
            assignmentType: draft.assignmentType,
            targetIds: draft.targetIds,
            label: draft.label,
          ),
    );
  }

  Future<void> _reorder(
      BuildContext context, WidgetRef ref, List<String> orderedIds) async {
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Sıralanıyor...',
      successMessage: 'Sıra güncellendi.',
      operation: () =>
          ref.read(cleaningRepositoryProvider).reorderSlots(orderedIds),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.depoAccent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlotTile extends ConsumerWidget {
  final CleaningRotationSlot slot;
  final int index;

  const _SlotTile({super.key, required this.slot, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.surface,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(Icons.drag_handle, color: AppColors.textSecondary),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.depoAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#${index + 1} ${CleaningAssignmentType.label(slot.assignmentType)}',
                style: const TextStyle(
                    color: AppColors.depoAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Text(slot.label ?? _targetSummary(),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _edit(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.error),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  String _targetSummary() {
    if (slot.assignmentType == CleaningAssignmentType.team ||
        slot.assignmentType == CleaningAssignmentType.unit ||
        slot.assignmentType == CleaningAssignmentType.customGroup) {
      return '${slot.targetIds.length} hedef';
    }
    return 'Kişi';
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final draft = await showAssignmentEditorSheet(
      context,
      ref,
      initial: AssignmentDraft(
        assignmentType: slot.assignmentType,
        targetIds: slot.targetIds,
        label: slot.label,
      ),
    );
    if (draft == null) return;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Güncelleniyor...',
      successMessage: 'Sıra güncellendi.',
      operation: () => ref.read(cleaningRepositoryProvider).updateSlot(
            slotId: slot.id,
            assignmentType: draft.assignmentType,
            targetIds: draft.targetIds,
            label: draft.label,
          ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sırayı Sil'),
        content: const Text('Bu sıra silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true) return;
    await runDeleteWithFeedback(
      context: context,
      successMessage: 'Sıra silindi.',
      operation: () => ref.read(cleaningRepositoryProvider).deleteSlot(slot.id),
    );
  }
}

class _RealizePanel extends ConsumerStatefulWidget {
  final List<CleaningRotationSlot> slots;
  final CleaningConfig? config;

  const _RealizePanel({required this.slots, required this.config});

  @override
  ConsumerState<_RealizePanel> createState() => _RealizePanelState();
}

class _RealizePanelState extends ConsumerState<_RealizePanel> {
  int _count = 8;

  @override
  Widget build(BuildContext context) {
    final startMonday = CleaningDates.mondayOf(DateTime.now());

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Başlangıç: ${CleaningDates.humanRange(startMonday)}',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Hafta sayısı',
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _count.toDouble(),
                    min: 1,
                    max: 24,
                    divisions: 23,
                    label: '$_count',
                    activeColor: AppColors.depoAccent,
                    onChanged: (v) => setState(() => _count = v.round()),
                  ),
                ),
                Text('$_count',
                    style: const TextStyle(
                        color: AppColors.depoAccent,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.depoAccent),
                onPressed:
                    widget.slots.isEmpty ? null : () => _generate(context),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Haftaları Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(BuildContext context) async {
    final repo = ref.read(cleaningRepositoryProvider);
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Oluşturuluyor...',
      successMessage: '$_count hafta oluşturuldu (mevcutsa dokunulmadı).',
      operation: () => repo.realizeWeeks(
        rotation: widget.slots,
        startMonday: CleaningDates.mondayOf(DateTime.now()),
        count: _count,
        shoppingTemplate: widget.config?.shoppingTemplate ?? const [],
      ),
    );
  }
}

class _TemplateEditor extends ConsumerStatefulWidget {
  final List<String> initial;

  const _TemplateEditor({required this.initial});

  @override
  ConsumerState<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<_TemplateEditor> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_items.isEmpty)
              Text('Şablon boş.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ..._items.map((item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_box_outline_blank,
                        color: AppColors.textSecondary),
                    title: Text(item,
                        style: TextStyle(color: AppColors.textPrimary)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _items.remove(item)),
                    ),
                  )),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Öğe Ekle'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Şablonu Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Öğe Ekle'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Örn: Çöp poşeti')),
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
    setState(() => _items.add(name));
  }

  Future<void> _save() async {
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Kaydediliyor...',
      successMessage: 'Şablon kaydedildi.',
      operation: () =>
          ref.read(cleaningRepositoryProvider).saveShoppingTemplate(_items),
    );
  }
}
