import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../models/store_models.dart';
import '../providers/store_providers.dart';

/// Sipariş formu — IBAN bilgisi gösterilir, dekont PDF'i yüklenir.
class StoreOrderFormScreen extends ConsumerStatefulWidget {
  final String productId;
  const StoreOrderFormScreen({super.key, required this.productId});

  @override
  ConsumerState<StoreOrderFormScreen> createState() =>
      _StoreOrderFormScreenState();
}

class _StoreOrderFormScreenState extends ConsumerState<StoreOrderFormScreen> {
  final _noteCtrl = TextEditingController();
  PickedPdf? _receiptPdf;
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final pdf = await pickReceiptPdf();
      if (pdf != null) {
        setState(() {
          _receiptPdf = pdf;
          _errorText = null;
        });
      }
    } catch (e) {
      setState(() => _errorText = e.toString());
    }
  }

  Future<void> _submit(StoreProduct product) async {
    if (_receiptPdf == null) {
      setState(() => _errorText = 'Lütfen dekont PDF\'inizi yükleyin.');
      return;
    }

    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;

      final orderId = await ref.read(storeRepositoryProvider).createOrder(
            productId: product.id,
            productName: product.name,
            price: product.price,
            note: _noteCtrl.text.trim(),
            receiptPdf: _receiptPdf!,
            userId: user.uid,
            userName: user.displayName ?? 'Kullanıcı',
          );

      // Notify store managers about the new order. The order id lets the
      // notification deep-link straight to the order detail screen.
      await ref.read(storeNotifierProvider).notifyNewOrder(
            productName: product.name,
            userName: user.displayName ?? 'Kullanıcı',
            orderId: orderId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Siparişiniz alındı. Dekontunuz admin tarafından kontrol edilecek.'),
            backgroundColor: AppColors.success));
        context.go('/store/orders');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(storeProductsProvider);
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sipariş Ver'),
        backgroundColor: AppColors.surface,
      ),
      body: productsAsync.when(
        data: (products) {
          final product = products.where((p) => p.id == widget.productId).firstOrNull;
          if (product == null) {
            return Center(
              child: Text('Ürün bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return settingsAsync.when(
            data: (settings) => _buildForm(context, product, settings),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildForm(
      BuildContext context, StoreProduct product, StoreSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Product summary
        Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: SafeNetworkImage(
                      url: product.coverImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('₺${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppColors.sargeGold,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // IBAN info
        Text('Havale / EFT Bilgileri',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (settings.ibans.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Henüz IBAN bilgisi eklenmemiş. Lütfen daha sonra tekrar deneyin.',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          )
        else
          ...settings.ibans.map((entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance,
                        size: 18, color: AppColors.sargeGold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(entry.displayText,
                          style:
                              TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    ),
                  ],
                ),
              )),

        const SizedBox(height: 16),
        // Info text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
          ),
          child: Text(
            'Lütfen ürün tutarını yukarıdaki IBAN\'lardan birine gönderin ve dekontu aşağıya yükleyin.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),

        // Receipt upload
        Text('Dekont (PDF) *',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickReceipt,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: _receiptPdf != null
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _receiptPdf != null
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _receiptPdf != null
                      ? Icons.description_outlined
                      : Icons.upload_file_outlined,
                  size: 28,
                  color: _receiptPdf != null
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _receiptPdf != null
                        ? 'Yüklendi: ${_receiptPdf!.name}'
                        : 'PDF dosyası seçmek için dokunun\n(maks. 10MB)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _receiptPdf != null
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Note
        TextFormField(
          controller: _noteCtrl,
          maxLines: 3,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Not (opsiyonel)',
            hintText: 'Örn: Beden: L, Renk: Siyah',
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ],
        const SizedBox(height: 20),

        // Submit
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading || settings.ibans.isEmpty
                ? null
                : () => _submit(product),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sargeGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('Siparişi Gönder',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}