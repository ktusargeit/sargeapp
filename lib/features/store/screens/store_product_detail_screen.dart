import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../models/store_models.dart';
import '../providers/store_providers.dart';

/// Ürün detay ekranı — büyük galeri, tam açıklama, fiyat ve "Al" butonu.
class StoreProductDetailScreen extends ConsumerWidget {
  final String productId;
  const StoreProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(storeProductsProvider);
    final canManage = ref.watch(currentUserCanProvider(Permissions.manageStore));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ürün Detayı'),
        backgroundColor: AppColors.surface,
        actions: [
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzenle',
              onPressed: () => context.push('/store/edit/$productId'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Sil',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Ürünü Sil'),
                    content:
                        const Text('Bu ürün silinecek. Onaylıyor musunuz?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('İptal')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;
                try {
                  await ref
                      .read(storeRepositoryProvider)
                      .deleteProduct(productId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Ürün silindi.'),
                            backgroundColor: AppColors.success));
                    context.pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: AppColors.error));
                  }
                }
              },
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          final product = products.where((p) => p.id == productId).firstOrNull;
          if (product == null) {
            return Center(
              child: Text('Ürün bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return _ProductDetailBody(product: product);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Hata: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}

class _ProductDetailBody extends StatefulWidget {
  final StoreProduct product;
  const _ProductDetailBody({required this.product});

  @override
  State<_ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends State<_ProductDetailBody> {
  int _currentImage = 0;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.imageUrls;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gallery
          if (images.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: SafeNetworkImage(
                  url: images[_currentImage.clamp(0, images.length - 1)],
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (images.length > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => _currentImage = i),
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentImage == i
                              ? AppColors.sargeGold
                              : AppColors.border,
                          width: _currentImage == i ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: SafeNetworkImage(
                          url: images[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ] else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
              child: Icon(Icons.storefront_outlined,
                  size: 48, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 16),
          // Stock badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (product.inStock ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (product.inStock
                            ? AppColors.success
                            : AppColors.error)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  product.inStock ? 'STOKTA VAR' : 'STOKTA YOK',
                  style: TextStyle(
                    color:
                        product.inStock ? AppColors.success : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            product.name,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // Price
          Text(
            product.formattedPrice,
            style: TextStyle(
              color: AppColors.sargeGold,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.border),
          const SizedBox(height: 12),
          // Description
          if (product.description.isNotEmpty) ...[
            Text(
              'Açıklama',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.description,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Buy button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: product.inStock
                  ? () => context.push('/store/order/${product.id}')
                  : null,
              icon: Icon(Icons.shopping_bag_outlined, size: 18),
              label: Text(product.inStock ? 'Al' : 'Stokta Yok'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    product.inStock ? AppColors.sargeGold : AppColors.surface2,
                foregroundColor:
                    product.inStock ? Colors.black : AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}