import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/permission_system.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../models/store_models.dart';
import '../providers/store_providers.dart';

/// "Tüm Siparişler" ekranı — filtre: Tümü / Benim Siparişlerim.
class StoreOrdersScreen extends ConsumerStatefulWidget {
  /// When provided (e.g. from a notification deep-link), the matching order's
  /// detail screen is automatically opened once the list is ready.
  final String? initialOrderId;

  const StoreOrdersScreen({super.key, this.initialOrderId});

  @override
  ConsumerState<StoreOrdersScreen> createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends ConsumerState<StoreOrdersScreen> {
  bool _showAll = false;
  bool _didOpenInitial = false;

  @override
  void initState() {
    super.initState();
    // When arriving from a notification deep-link, managers should default to
    // the "Tümü" view so the referenced order is visible and can be auto-opened.
    if (widget.initialOrderId != null && widget.initialOrderId!.isNotEmpty) {
      _showAll = true;
    }
  }

  void _maybeOpenInitialOrder(List<StoreOrder> orders) {
    if (_didOpenInitial) return;
    final target = widget.initialOrderId;
    if (target == null || target.isEmpty) {
      _didOpenInitial = true;
      return;
    }
    if (orders.any((o) => o.id == target)) {
      _didOpenInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/store/order-detail/$target');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        ref.watch(currentUserCanProvider(Permissions.manageStore));
    final allOrdersAsync = ref.watch(allOrdersProvider);
    final myOrdersAsync = ref.watch(myOrdersProvider);

    // Default: "Tümü" is only available to managers. Regular users always
    // see their own orders.
    final effectiveShowAll = canManage && _showAll;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tüm Siparişler'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          // Filter
          if (canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Tümü'),
                    icon: Icon(Icons.view_list, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Benim Siparişlerim'),
                    icon: Icon(Icons.person_outline, size: 16),
                  ),
                ],
                selected: {effectiveShowAll},
                onSelectionChanged: (s) => setState(() => _showAll = s.first),
                style: ButtonStyle(
                  foregroundColor:
                      WidgetStatePropertyAll(AppColors.textPrimary),
                  backgroundColor: WidgetStatePropertyAll(AppColors.surface),
                  side: WidgetStatePropertyAll(
                      BorderSide(color: AppColors.border)),
                ),
              ),
            ),
          Expanded(
            child: effectiveShowAll
                ? allOrdersAsync.when(
                    data: (orders) {
                      _maybeOpenInitialOrder(orders);
                      return _OrderList(orders: orders);
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                        child: Text('Hata: $e',
                            style: const TextStyle(color: AppColors.error))),
                  )
                : myOrdersAsync.when(
                    data: (orders) {
                      _maybeOpenInitialOrder(orders);
                      return _OrderList(orders: orders);
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                        child: Text('Hata: $e',
                            style: const TextStyle(color: AppColors.error))),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  final List<StoreOrder> orders;
  const _OrderList({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Henüz sipariş yok.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final order = orders[i];
        final visual = StoreOrderStatus.statusVisual(order.status);
        final canManage =
            ref.watch(currentUserCanProvider(Permissions.manageStore));

        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/store/order-detail/${order.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Product thumbnail (from product if available; fallback icon)
                  _OrderProductThumb(order: order),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              '₺${order.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.sargeGold,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formatDate(order.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (canManage) ...[
                          const SizedBox(height: 3),
                          Text(
                            order.userName,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Status chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: visual.$2.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: visual.$2.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            visual.$1,
                            style: TextStyle(
                              color: visual.$2,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

/// Shows the product's cover image next to the order. Resolves the product
/// from the storeProductsProvider if available; falls back to an icon.
class _OrderProductThumb extends ConsumerWidget {
  final StoreOrder order;
  const _OrderProductThumb({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(storeProductsProvider);
    final products = productsAsync.valueOrNull ?? const <StoreProduct>[];
    final product = products.where((p) => p.id == order.productId).firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: product != null && product.coverImageUrl.isNotEmpty
            ? SafeNetworkImage(url: product.coverImageUrl, fit: BoxFit.cover)
            : Container(
                color: AppColors.surface2,
                child: Icon(Icons.shopping_bag_outlined,
                    size: 20, color: AppColors.textSecondary),
              ),
      ),
    );
  }
}
