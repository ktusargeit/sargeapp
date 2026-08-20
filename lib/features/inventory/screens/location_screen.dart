import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../cleaning/providers/cleaning_permissions.dart';
import '../models/depo_models.dart';
import '../providers/depo_providers.dart';
import '../services/location_migration_service.dart';

/// Location management: fixed categories (Toplantı Salonu / Atölye / Depo),
/// sub-locations under them, and the one-time migration of legacy locations.
class LocationScreen extends ConsumerWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsProvider);
    final categoriesAsync = ref.watch(locationCategoriesProvider);
    final canManage = ref.watch(cleaningManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Lokasyonlar'),
        actions: [
          if (canManage)
            TextButton.icon(
              onPressed: () => _runMigration(context, ref),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Migrasyon'),
            ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppColors.error))),
        data: (categories) {
          final locations = locationsAsync.valueOrNull ?? const <DepoLocation>[];
          if (categories.isEmpty && locations.isEmpty) {
            return Center(
                child: Text('Henüz kategori/lokasyon yok.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (canManage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Kategoriler sabittir; alt-lokasyon/raf tanımlayabilirsiniz.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ..._categorySections(
                  context, ref, categories, locations, canManage),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _categorySections(
    BuildContext context,
    WidgetRef ref,
    List<LocationCategory> categories,
    List<DepoLocation> locations,
    bool canManage,
  ) {
    final sections = <Widget>[];
    final assigned = <String>{};

    for (final cat in categories) {
      final owned = locations
          .where((l) => l.categoryId == cat.id)
          .toList();
      // group by parent
      final top = owned.where((l) => l.parentId == null).toList();
      final children = owned.where((l) => l.parentId != null).toList();
      for (final l in owned) {
        assigned.add(l.id);
      }
      sections.add(_CategorySection(
        category: cat,
        topLevel: top,
        children: children,
        canManage: canManage,
      ));
    }

    // Unassigned locations (legacy) shown under a special bucket.
    final unassigned = locations.where((l) => !assigned.contains(l.id)).toList();
    if (unassigned.isNotEmpty) {
      sections.add(Card(
        color: AppColors.surface2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kategorisiz (eski)',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Migrasyon ile bu lokasyonlar bir kategoriye atanır.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              ...unassigned.map((l) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.location_on_outlined,
                        color: AppColors.textSecondary, size: 18),
                    title: Text(l.name,
                        style: TextStyle(color: AppColors.textPrimary)),
                  )),
            ],
          ),
        ),
      ));
    }

    return sections;
  }

  Future<void> _runMigration(BuildContext context, WidgetRef ref) async {
    final service = ref.read(locationMigrationServiceProvider);
    final plan = await service.plan();

    if (!context.mounted) return;

    String categorySummary(LocationMigrationPlan p) {
      final parts = <String>[];
      for (final c in p.categories) {
        final n = p.categorized[c.id]?.length ?? 0;
        parts.add('${c.name}: $n');
      }
      if (p.unmatched.isNotEmpty) {
        parts.add('Depo altına: ${p.unmatched.length}');
      }
      return parts.join('\n');
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lokasyon Migrasyonu'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Özet (eşleşmeyenler Depo altına taşınır):'),
              const SizedBox(height: 8),
              Text(categorySummary(plan),
                  style: const TextStyle(fontFamily: 'monospace')),
              const SizedBox(height: 12),
              const Text(
                  'Not: Migrasyon öncesi tüm lokasyonlar '
                  'locations_backup_pre_migration koleksiyonuna yedeklenir.',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çalıştır'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Migrate ediliyor...',
      successMessage: 'Migrasyon tamamlandı.',
      operation: () => service.run(),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final LocationCategory category;
  final List<DepoLocation> topLevel;
  final List<DepoLocation> children;
  final bool canManage;

  const _CategorySection({
    required this.category,
    required this.topLevel,
    required this.children,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined,
                  color: AppColors.depoAccent, size: 20),
              title: Text(category.name,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              trailing: canManage
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_location_alt_outlined,
                              size: 18, color: AppColors.depoAccent),
                          tooltip: 'Alt-lokasyon ekle',
                          onPressed: () => _addSubLocation(context, ref),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.textSecondary),
                          tooltip: 'Kategoriyi düzenle',
                          onPressed: () => _editCategory(context, ref),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          tooltip: 'Kategoriyi sil',
                          onPressed: () => _deleteCategory(context, ref),
                        ),
                      ],
                    )
                  : null,
            ),
            if (topLevel.isNotEmpty)
              ...topLevel.map((l) => _locationTile(context, l)),
            if (children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children
                      .map((l) => _locationTile(context, l, indented: true))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _locationTile(BuildContext context, DepoLocation l,
      {bool indented = false}) {
    return ListTile(
      dense: true,
      contentPadding:
          EdgeInsets.only(left: indented ? 32 : 16, right: 8),
      leading: Icon(indented ? Icons.subdirectory_arrow_right : Icons.place,
          color: AppColors.textSecondary, size: 18),
      title: Text(l.name, style: TextStyle(color: AppColors.textPrimary)),
    );
  }

  Future<void> _addSubLocation(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${category.name} > Alt-lokasyon Ekle'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Örn: Raf A-1'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Ekle')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;

    // Determine parent: first top-level location in this category, or none.
    final parentId = topLevel.isNotEmpty ? topLevel.first.id : null;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Ekleniyor...',
      successMessage: 'Alt-lokasyon eklendi.',
      operation: () async {
        await addLocationWithCategory(
          ref,
          name: name,
          category: category,
          parentId: parentId,
        );
      },
    );
  }

  Future<void> _editCategory(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: category.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategoriyi Düzenle'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Güncelleniyor...',
      successMessage: 'Kategori güncellendi.',
      operation: () =>
          ref.read(depoRepositoryProvider).updateCategoryName(category.id, name),
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref) async {
    int count = 0;
    try {
      count = await ref
          .read(depoRepositoryProvider)
          .countLocationsInCategory(category.id);
    } catch (_) {}

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategoriyi Sil'),
        content: Text(count > 0
            ? 'Bu kategoride $count lokasyon var. Kategori silinirse lokasyonlar kategorisiz kalır.'
            : '"${category.name}" silinecek. Onaylıyor musunuz?'),
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
    if (!context.mounted) return;
    await runDeleteWithFeedback(
      context: context,
      successMessage: 'Kategori silindi.',
      operation: () =>
          ref.read(depoRepositoryProvider).deleteLocationCategory(category.id),
    );
  }
}

/// Helper that inserts a new location with category + parent set.
Future<void> addLocationWithCategory(
  WidgetRef ref, {
  required String name,
  required LocationCategory category,
  String? parentId,
}) async {
  final repo = ref.read(depoRepositoryProvider);
  final loc = DepoLocation(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    name: name,
    categoryId: category.id,
    categoryName: category.name,
    parentId: parentId,
  );
  await repo.addLocation(loc);
}