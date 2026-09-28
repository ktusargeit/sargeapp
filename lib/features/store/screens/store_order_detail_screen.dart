import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/screens/profile_screen.dart';
import '../models/store_models.dart';
import '../providers/store_providers.dart';

/// Sipariş detay ekranı — dekont görüntüleme, not, admin durum yönetimi.
class StoreOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const StoreOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<StoreOrderDetailScreen> createState() =>
      _StoreOrderDetailScreenState();
}

class _StoreOrderDetailScreenState
    extends ConsumerState<StoreOrderDetailScreen> {
  bool _updating = false;
  String? _errorText;

  Future<void> _changeStatus(StoreOrder order, String newStatus) async {
    setState(() {
      _updating = true;
      _errorText = null;
    });
    try {
      await ref
          .read(storeRepositoryProvider)
          .updateOrderStatus(widget.orderId, newStatus);

      // Notify the order owner about the status change.
      await ref.read(storeNotifierProvider).notifyOrderStatusChanged(
            recipientId: order.userId,
            productName: order.productName,
            newStatus: newStatus,
            orderId: widget.orderId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Durum güncellendi: $newStatus'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      setState(() => _errorText = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  StoreOrder? _resolveOrder(
    List<StoreOrder> allOrders,
    List<StoreOrder>? myOrders,
    bool canManage,
  ) {
    var order = allOrders.where((o) => o.id == widget.orderId).firstOrNull;
    if (order == null && !canManage) {
      final mine = myOrders ?? const <StoreOrder>[];
      order = mine.where((o) => o.id == widget.orderId).firstOrNull;
    }
    return order;
  }

  Future<void> _openReceipt(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('PDF açılamadı: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allOrdersAsync = ref.watch(allOrdersProvider);
    final myOrdersAsync = ref.watch(myOrdersProvider);
    final canManage = ref.watch(currentUserCanProvider(Permissions.manageStore));
    final authUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sipariş Detayı'),
        backgroundColor: AppColors.surface,
      ),
      body: allOrdersAsync.when(
        data: (allOrders) {
          final order =
              _resolveOrder(allOrders, myOrdersAsync.valueOrNull, canManage);
          if (order == null) {
            return Center(
              child: Text('Sipariş bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return _OrderDetailBody(
            order: order,
            canManage: canManage,
            isOwnOrder: order.userId == authUid,
            updating: _updating,
            errorText: _errorText,
            onChangeStatus: (s) => _changeStatus(order, s),
            onOpenReceipt: () => _openReceipt(order.receiptUrl),
          );
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

class _OrderDetailBody extends StatelessWidget {
  final StoreOrder order;
  final bool canManage;
  final bool isOwnOrder;
  final bool updating;
  final String? errorText;
  final ValueChanged<String> onChangeStatus;
  final VoidCallback onOpenReceipt;

  const _OrderDetailBody({
    required this.order,
    required this.canManage,
    required this.isOwnOrder,
    required this.updating,
    required this.errorText,
    required this.onChangeStatus,
    required this.onOpenReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final visual = StoreOrderStatus.statusVisual(order.status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status big chip
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: visual.$2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: visual.$2.withValues(alpha: 0.35)),
            ),
            child: Text(
              visual.$1,
              style: TextStyle(
                color: visual.$2,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Product info
        Text('Ürün',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          color: AppColors.surface,
          child: ListTile(
            leading: const Icon(Icons.shopping_bag_outlined,
                color: AppColors.sargeGold),
            title: Text(order.productName,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            subtitle: Text('₺${order.price.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: AppColors.sargeGold,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),

        // Customer info (admin view)
        if (canManage) ...[
          Text('Sipariş Veren',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            child: ListTile(
              leading: Icon(Icons.person_outline,
                  color: AppColors.textSecondary),
              title: Text(order.userName,
                  style: TextStyle(color: AppColors.textPrimary)),
              trailing: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: order.userId))),
                child: const Text('Profil'),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Receipt
        Text('Dekont',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          color: AppColors.surface,
          child: ListTile(
            leading: const Icon(Icons.description_outlined,
                color: AppColors.success),
            title: const Text('Dekont PDF'),
            subtitle: Text(
              order.receiptUrl.isEmpty ? 'Dekont bulunamadı' : 'PDF dosyası',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: order.receiptUrl.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.open_in_new,
                        size: 18, color: AppColors.textSecondary),
                    tooltip: 'Aç/İndir',
                    onPressed: onOpenReceipt,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),

        // Note
        if (order.note.isNotEmpty) ...[
          Text('Not',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(order.note,
                style: TextStyle(color: AppColors.textPrimary, height: 1.4)),
          ),
          const SizedBox(height: 12),
        ],

        // Date
        Text(
          'Sipariş Tarihi: ${_formatDate(order.createdAt)}',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 24),

        // Admin status management
        if (canManage) ...[
          if (errorText != null) ...[
            Text(errorText!,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          Text('Durum Yönetimi',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // Status transition buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Forward flow buttons (skip current status)
              ...StoreOrderStatus.forwardFlow
                  .where((s) => s != order.status)
                  .map((s) {
                final v = StoreOrderStatus.statusVisual(s);
                return ActionChip(
                  label: Text(s, style: TextStyle(color: v.$2, fontSize: 12)),
                  backgroundColor: v.$2.withValues(alpha: 0.08),
                  side: BorderSide(color: v.$2.withValues(alpha: 0.3)),
                  onPressed: updating ? null : () => onChangeStatus(s),
                );
              }),
              // Cancel button
              if (order.status != StoreOrderStatus.cancelled)
                ActionChip(
                  label: const Text('İptal Edildi',
                      style: TextStyle(
                          color: AppColors.error, fontSize: 12)),
                  backgroundColor: AppColors.error.withValues(alpha: 0.08),
                  side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.3)),
                  onPressed: updating
                      ? null
                      : () => onChangeStatus(StoreOrderStatus.cancelled),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} $h:$m';
  }
}