import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/permission_system.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../models/store_models.dart';
import '../providers/store_providers.dart';

/// Mağaza ana ekranı — ürünler kart/grid görünümünde listelenir.
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(storeProductsProvider);
    final canManage = ref.watch(currentUserCanProvider(Permissions.manageStore));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mağaza'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long_outlined,
                color: AppColors.textPrimary),
            tooltip: 'Tüm Siparişler',
            onPressed: () => context.push('/store/orders'),
          ),
          if (canManage) ...[
            IconButton(
              icon: Icon(Icons.settings_outlined,
                  color: AppColors.textPrimary),
              tooltip: 'Mağaza Ayarları',
              onPressed: () => context.push('/store/settings'),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/store/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ürün Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sargeGold,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final available =
                    products.where((p) => p.inStock).toList();
                final outOfStock =
                    products.where((p) => !p.inStock).toList();
                final display = [...available, ...outOfStock];

                if (display.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 56, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz ürün yok.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                        if (canManage) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => context.push('/store/add'),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('İlk ürünü ekle'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.sargeGold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: display.length,
                  itemBuilder: (_, i) => _ProductCard(product: display[i]),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Hata: $e',
                    style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final StoreProduct product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage =
        ref.watch(currentUserCanProvider(Permissions.manageStore));

    return Card(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/store/product/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(
                    url: product.coverImageUrl,
                    fit: BoxFit.cover,
                  ),
                  if (!product.inStock)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'STOKTA YOK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (canManage)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        child: IconButton(
                          iconSize: 16,
                          padding: const EdgeInsets.all(4),
                          color: Colors.white,
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Düzenle',
                          onPressed: () => context
                              .push('/store/edit/${product.id}'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      color: AppColors.sargeGold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Main store screen entry (used from router).
class StoreMainScreen extends StatelessWidget {
  const StoreMainScreen({super.key});

  @override
  Widget build(BuildContext context) => const StoreScreen();
}