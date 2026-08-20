import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/platform_image.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../models/store_models.dart';
import '../providers/store_providers.dart';

/// Ürün ekleme/düzenleme formu.
class StoreProductFormScreen extends ConsumerStatefulWidget {
  final String? editProductId;
  const StoreProductFormScreen({super.key, this.editProductId});

  @override
  ConsumerState<StoreProductFormScreen> createState() =>
      _StoreProductFormScreenState();
}

class _StoreProductFormScreenState
    extends ConsumerState<StoreProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _inStock = true;
  bool _loading = false;
  bool _editLoaded = false;
  List<PickedImage> _newImages = [];
  List<String> _existingImageUrls = [];

  bool get _isEditing => widget.editProductId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final doc = await ref
          .read(firestoreProvider)
          .collection('store_products')
          .doc(widget.editProductId!)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final rawImages = data['imageUrls'];
        final urls = rawImages is List
            ? rawImages.whereType<String>().toList()
            : <String>[];
        setState(() {
          _nameCtrl.text = data['name'] as String? ?? '';
          // Prefer the original free-text price so "50 TL" round-trips exactly;
          // fall back to the numeric field for older products.
          _priceCtrl.text = (data['priceDisplay'] as String? ?? '');
          if (_priceCtrl.text.isEmpty) {
            _priceCtrl.text = (data['price'] as num?)?.toString() ?? '';
          }
          _descCtrl.text = data['description'] as String? ?? '';
          _inStock = data['inStock'] as bool? ?? true;
          _existingImageUrls = urls;
          _editLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await PickedImage.pickMultiple();
    if (picked.isNotEmpty) {
      setState(() => _newImages = [..._newImages, ...picked]);
    }
  }

  void _pickSingleImage(ImageSource source) async {
    final picked = await PickedImage.pick(source);
    if (picked != null) {
      setState(() => _newImages = [..._newImages, picked]);
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ürün adı zorunludur.'),
          backgroundColor: AppColors.error));
      return;
    }

    // Allow the user to type the price however they like ("50", "50 TL",
    // "50₺", ...). Their exact text is kept for display, while a numeric value
    // is extracted and stored separately for consistent display/sorting.
    final rawPrice = _priceCtrl.text.trim();
    final normalized = rawPrice
        .replaceAll('₺', ' ')
        .replaceAll(RegExp(r'[^0-9,.\s]'), ' ')
        .trim();
    final priceMatch = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(normalized);
    final price = priceMatch != null
        ? double.tryParse(priceMatch.group(1)!.replaceAll(',', '.'))
        : null;

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Fiyatta sayısal bir değer bulunamadı. Lütfen bir fiyat girin.'),
          backgroundColor: AppColors.error));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    // Show the user's original wording on the product card ("50 TL", "50₺"),
    // while the numeric `price` is stored separately for sorting.
    final priceDisplay =
        rawPrice.isEmpty ? '₺${price.toStringAsFixed(0)}' : rawPrice;

    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).value;
      final repo = ref.read(storeRepositoryProvider);

      if (_isEditing) {
        await repo.updateProduct(
          productId: widget.editProductId!,
          name: name,
          price: price,
          priceDisplay: priceDisplay,
          description: _descCtrl.text.trim(),
          inStock: _inStock,
          existingImageUrls: _existingImageUrls,
          newImages: _newImages,
        );
      } else {
        await repo.addProduct(
          name: name,
          price: price,
          priceDisplay: priceDisplay,
          description: _descCtrl.text.trim(),
          inStock: _inStock,
          images: _newImages,
          createdBy: user?.uid,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? 'Ürün güncellendi.' : 'Ürün eklendi.'),
            backgroundColor: AppColors.success));
        context.pop();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Ürün Düzenle' : 'Ürün Ekle'),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.sargeGold))
                : const Text('Kaydet',
                    style: TextStyle(
                        color: AppColors.sargeGold,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _isEditing && !_editLoaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Image picker
                  Text('Görsel(ler)',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  // Existing images
                  if (_existingImageUrls.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingImageUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            Container(
                              width: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: SafeNetworkImage(
                                  url: _existingImageUrls[i],
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removeExistingImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // New images
                  if (_newImages.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _newImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            Container(
                              width: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: PlatformImageFile(
                                  bytes: _newImages[i].bytes,
                                  file: _newImages[i].dartFile,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removeNewImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Add image buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickSingleImage(ImageSource.camera),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text('Kamera',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library,
                                    size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text('Galeri',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Name
                  TextFormField(
                    controller: _nameCtrl,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Ürün Adı *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 12),
                  // Price — free text so "50", "50 TL" and "50₺" all work.
                  TextFormField(
                    controller: _priceCtrl,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Fiyat *',
                      hintText: '50, 50 TL veya 50₺',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 5,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      hintText:
                          'Ürün detayları, beden/renk seçenekleri vb.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stock toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Stokta Var',
                        style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text('Kapatılırsa "Stokta Yok" olarak işaretlenir.',
                        style: TextStyle(color: AppColors.textSecondary)),
                    value: _inStock,
                    activeThumbColor: AppColors.success,
                    onChanged: (v) => setState(() => _inStock = v),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}