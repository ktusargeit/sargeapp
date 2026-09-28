import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/operation_feedback.dart';
import '../models/depo_models.dart';
import '../providers/depo_providers.dart';
import 'inventory_add_screen.dart';

class InventoryDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const InventoryDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<InventoryDetailScreen> createState() =>
      _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends ConsumerState<InventoryDetailScreen> {
  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:  Text('Ürünü Sil',
            style: TextStyle(color: AppColors.textPrimary)),
        content:  Text(
            'Bu ürünü silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final ok = await runDeleteWithFeedback(
      context: context,
      successMessage: 'Ürün başarıyla silindi.',
      operation: () =>
          ref.read(depoRepositoryProvider).deleteItem(widget.itemId),
    );
    if (ok && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ürün Detayı'),
        backgroundColor: AppColors.surface,
        actions: [
          if (currentUser != null && (currentUser.isAdmin || currentUser.isUnitLead))
            PopupMenuButton<String>(
              icon:  Icon(Icons.more_vert, color: AppColors.textPrimary),
              color: AppColors.surface2,
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            InventoryAddScreen(editItemId: widget.itemId)),
                  );
                } else if (value == 'delete') {
                  _deleteItem();
                }
              },
              itemBuilder: (_) =>  [
                PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      const Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text('Düzenle',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Sil',
                          style: TextStyle(color: AppColors.error)),
                    ])),
              ],
            ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          final item = items.where((i) => i.id == widget.itemId).firstOrNull;
          if (item == null) {
            return  Center(
                child: Text('Ürün bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return _ItemDetailView(item: item);
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.depoAccent)),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}

void _showFullScreenImage(BuildContext context, String url) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5.0,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

class _ItemDetailView extends StatelessWidget {
  final DepoItem item;
  const _ItemDetailView({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        // Main product image – tap to view full screen
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
          GestureDetector(
            onTap: () => _showFullScreenImage(context, item.imageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              child: Image.network(
                item.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child:  Center(
                    child: Icon(Icons.inventory_2_outlined,
                        size: 48, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child:  Center(
              child: Icon(Icons.inventory_2_outlined,
                  size: 48, color: AppColors.textSecondary),
            ),
          ),
        const SizedBox(height: 16),
        // Name & status
        Row(
          children: [
            Expanded(
              child: Text(item.name,
                  style:  TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.depoAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppColors.depoAccent.withValues(alpha: 0.4)),
              ),
              child: Text(
                item.status,
                style: const TextStyle(
                    color: AppColors.depoAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (item.description != null && item.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(item.description!,
              style:  TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
        ],
        const SizedBox(height: 20),
        // Details
        _SectionCard(title: 'ÜRÜN BİLGİLERİ', children: [
          _InfoRow(label: 'Seri No', value: item.serialNumber ?? '—'),
          _InfoRow(label: 'Marka', value: item.brand ?? '—'),
          _InfoRow(label: 'Model', value: item.model ?? '—'),
          _InfoRow(label: 'Adet', value: '${item.quantity ?? 0}'),
          if (item.categoryName != null)
            _InfoRow(label: 'Kategori', value: item.categoryName!),
        ]),
        const SizedBox(height: AppConstants.spacingLg),
        _SectionCard(title: 'LOKASYON', children: [
          _InfoRow(
              label: 'Lokasyon', value: item.locationName ?? '—'),
          _InfoRow(label: 'Raf', value: item.shelfName ?? '—'),
          _InfoRow(label: 'Çekmece', value: item.drawerName ?? '—'),
        ]),
        // Location photo
        if (item.locationImageUrl != null &&
            item.locationImageUrl!.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Location photo – tap to view full screen
          GestureDetector(
            onTap: () => _showFullScreenImage(context, item.locationImageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              child: Image.network(
                item.locationImageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppConstants.spacingLg),
        if (item.createdAt != null)
          Center(
            child: Text(
              'Eklenme: ${_formatDate(item.createdAt!)}',
              style:  TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        const SizedBox(height: 8),
        _CreatorLabel(createdBy: item.createdBy),
        const SizedBox(height: 40),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Resolves and renders the "Ekleyen: [isim]" line for an inventory item.
class _CreatorLabel extends ConsumerWidget {
  final String? createdBy;
  const _CreatorLabel({required this.createdBy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (createdBy == null || createdBy!.isEmpty) {
      return const SizedBox.shrink();
    }
    final creatorAsync = ref.watch(userProfileProvider(createdBy!));
    final name = creatorAsync.valueOrNull?.displayName;
    return Center(
      child: Text(
        'Ekleyen: ${name ?? 'Bilinmiyor'}',
        style:  TextStyle(
            color: AppColors.textSecondary, fontSize: 11),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style:  TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
      ),
      Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.border)),
        child: Column(
          children: children.asMap().entries.map((entry) {
            return Column(children: [
              entry.value,
              if (entry.key != children.length - 1)
                 Divider(height: 1, color: AppColors.border)
            ]);
          }).toList(),
        ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style:  TextStyle(
                    color: AppColors.textSecondary, fontSize: 13))),
        const SizedBox(width: 12),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style:  TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }
}