import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/platform_image.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../models/depo_models.dart';
import '../providers/depo_providers.dart';

class InventoryAddScreen extends ConsumerStatefulWidget {
  final String? editItemId;
  const InventoryAddScreen({super.key, this.editItemId});

  @override
  ConsumerState<InventoryAddScreen> createState() => _InventoryAddScreenState();
}

class _InventoryAddScreenState extends ConsumerState<InventoryAddScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Stage 1: Product info
  late final TextEditingController _nameCtrl = TextEditingController();
  late final TextEditingController _descCtrl = TextEditingController();
  late final TextEditingController _serialCtrl = TextEditingController();
  late final TextEditingController _modelCtrl = TextEditingController();
  late final TextEditingController _brandCtrl = TextEditingController();
  late final TextEditingController _quantityCtrl = TextEditingController();

  String? _selectedTeamId;
  String? _selectedUnitId;
  String? _selectedCategoryId;
  String _selectedStatus = 'available';
  PickedImage? _pickedImage;
  bool _loading = false;
  bool _editLoaded = false;

  // Stage 2: Location info
  String? _selectedLocationId;
  String? _selectedLocationName;
  String? _selectedLocationCategoryId;
  String? _selectedLocationCategoryName;
  late final TextEditingController _shelfCtrl = TextEditingController();
  late final TextEditingController _drawerCtrl = TextEditingController();
  PickedImage? _pickedLocationImage;

  @override
  void initState() {
    super.initState();
    if (widget.editItemId != null) {
      _loadExistingItem();
    }
  }

  Future<void> _loadExistingItem() async {
    try {
      final doc = await ref
          .read(firestoreProvider)
          .collection('depo_urunler')
          .doc(widget.editItemId!)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameCtrl.text = data['name'] as String? ?? '';
          _descCtrl.text = data['description'] as String? ?? '';
          _serialCtrl.text = data['serialNumber'] as String? ?? '';
          _modelCtrl.text = data['model'] as String? ?? '';
          _brandCtrl.text = data['brand'] as String? ?? '';
          _quantityCtrl.text = (data['quantity'] as num?)?.toString() ?? '';
          _selectedTeamId = data['teamId'] as String?;
          _selectedUnitId = data['unitId'] as String?;
          _selectedCategoryId = data['categoryId'] as String?;
          _selectedStatus = data['status'] as String? ?? 'available';
          _selectedLocationId = data['locationId'] as String?;
          _selectedLocationName = data['locationName'] as String?;
          _selectedLocationCategoryId = data['locationCategoryId'] as String?;
          _selectedLocationCategoryName =
              data['locationCategoryName'] as String?;
          _shelfCtrl.text = data['shelfName'] as String? ?? '';
          _drawerCtrl.text = data['drawerName'] as String? ?? '';
          _editLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _serialCtrl.dispose();
    _modelCtrl.dispose();
    _brandCtrl.dispose();
    _quantityCtrl.dispose();
    _shelfCtrl.dispose();
    _drawerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await PickedImage.pick(source);
    if (picked != null) setState(() => _pickedImage = picked);
  }

  Future<void> _pickLocationImage(ImageSource source) async {
    final picked = await PickedImage.pick(source);
    if (picked != null) setState(() => _pickedLocationImage = picked);
  }

  Future<void> _pickLocation() async {
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) =>
          _LocationPickerSheet(categoryId: _selectedLocationCategoryId),
    );
    if (selected != null) {
      setState(() {
        _selectedLocationId = selected['id'];
        _selectedLocationName = selected['name'];
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ürün adı zorunludur.'),
          backgroundColor: AppColors.error));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final quantityRaw = _quantityCtrl.text.trim();
    if (quantityRaw.isNotEmpty && int.tryParse(quantityRaw) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Adet alanı geçerli bir sayı olmalıdır.'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).value;
      final repo = ref.read(depoRepositoryProvider);
      String? categoryName;
      if (_selectedCategoryId != null) {
        final catDoc = await ref
            .read(firestoreProvider)
            .collection('inventory_categories')
            .doc(_selectedCategoryId)
            .get();
        categoryName = catDoc.data()?['name'] as String?;
      }

      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'teamId': _selectedTeamId,
        'unitId': _selectedUnitId,
        'categoryId': _selectedCategoryId,
        'categoryName': categoryName,
        'serialNumber':
            _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        'model': _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        'quantity': int.tryParse(_quantityCtrl.text.trim()),
        'status': _selectedStatus,
        'locationId': _selectedLocationId,
        'locationName': _selectedLocationName,
        'locationCategoryId': _selectedLocationCategoryId,
        'locationCategoryName': _selectedLocationCategoryName,
        'shelfName':
            _shelfCtrl.text.trim().isEmpty ? null : _shelfCtrl.text.trim(),
        'drawerName':
            _drawerCtrl.text.trim().isEmpty ? null : _drawerCtrl.text.trim(),
      };

      if (widget.editItemId == null) {
        data['createdBy'] = user?.uid;
      }

      if (widget.editItemId != null) {
        await repo.updateItem(
          widget.editItemId!,
          data,
          imageBytes: _pickedImage?.bytes,
          imageFile: _pickedImage?.dartFile,
          locationBytes: _pickedLocationImage?.bytes,
          locationFile: _pickedLocationImage?.dartFile,
        );
      } else {
        await repo.addItem(
          data,
          imageBytes: _pickedImage?.bytes,
          imageFile: _pickedImage?.dartFile,
          locationBytes: _pickedLocationImage?.bytes,
          locationFile: _pickedLocationImage?.dartFile,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editItemId != null
                ? 'Ürün güncellendi.'
                : 'Ürün eklendi.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editItemId != null;
    final statusesAsync = ref.watch(inventoryStatusesProvider);
    final teamsAsync = ref.watch(teamListProvider);
    final unitsAsync = ref.watch(unitsByTeamProvider(_selectedTeamId));
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Ürün Düzenle' : 'Yeni Ürün Ekle'),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.depoAccent))
                : const Text('Kaydet',
                    style: TextStyle(
                        color: AppColors.depoAccent,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: isEditing && !_editLoaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.depoAccent))
          : Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 1) {
                    setState(() => _currentStep++);
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep--);
                  }
                },
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        if (_currentStep < 1)
                          ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.depoAccent,
                            ),
                            child: const Text('Devam'),
                          ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: details.onStepCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: BorderSide(color: AppColors.border),
                            ),
                            child: const Text('Geri'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: [
                  // STEP 1: Product Info
                  Step(
                    title: Text('Ürün Bilgileri',
                        style: TextStyle(color: AppColors.textPrimary)),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0
                        ? StepState.complete
                        : StepState.indexed,
                    content: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Image picker
                          Center(
                            child: _pickedImage != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            AppConstants.radiusMd),
                                        child: PlatformImageFile(
                                          bytes: _pickedImage!.bytes,
                                          file: _pickedImage!.dartFile,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: AppIconButton(
                                          icon: Icons.close,
                                          iconSize: 16,
                                          color: AppColors.error,
                                          tooltip: 'Kaldır',
                                          onTap: () => setState(
                                              () => _pickedImage = null),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            _pickImage(ImageSource.camera),
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: AppColors.surface2,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppConstants.radiusMd),
                                            border: Border.all(
                                                color: AppColors.border),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.camera_alt,
                                                  size: 28,
                                                  color:
                                                      AppColors.textSecondary),
                                              const SizedBox(height: 4),
                                              Text('Kamera',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () =>
                                            _pickImage(ImageSource.gallery),
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: AppColors.surface2,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppConstants.radiusMd),
                                            border: Border.all(
                                                color: AppColors.border),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.photo_library,
                                                  size: 28,
                                                  color:
                                                      AppColors.textSecondary),
                                              const SizedBox(height: 4),
                                              Text('Galeri',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          // Name
                          TextFormField(
                            controller: _nameCtrl,
                            style: TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Ürün Adı *',
                              hintText: 'Örn: Arduino Uno R3',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Zorunlu'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          // Description
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 2,
                            style: TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Açıklama',
                              hintText: 'Ürün hakkında detay',
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Team dropdown
                          teamsAsync.when(
                            data: (teams) => DropdownButtonFormField<String>(
                              initialValue: _selectedTeamId,
                              dropdownColor: AppColors.surface2,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration:
                                  const InputDecoration(labelText: 'Takım'),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('—')),
                                ...teams.map((t) => DropdownMenuItem(
                                    value: t['id'] as String,
                                    child: Text(t['name'] as String))),
                              ],
                              onChanged: (v) => setState(() {
                                _selectedTeamId = v;
                                _selectedUnitId = null;
                                _selectedCategoryId = null;
                              }),
                            ),
                            loading: () =>
                                const CircularProgressIndicator(),
                            error: (e, _) => Text('Hata: $e'),
                          ),
                          const SizedBox(height: 12),
                          // Unit dropdown (filtered by team)
                          if (_selectedTeamId != null)
                            unitsAsync.when(
                              data: (units) => DropdownButtonFormField<String>(
                                initialValue: _selectedUnitId,
                                dropdownColor: AppColors.surface2,
                                style:
                                    TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                    labelText: 'Birim'),
                                items: [
                                  const DropdownMenuItem(
                                      value: null, child: Text('—')),
                                  ...units.map((u) => DropdownMenuItem(
                                      value: u['id'] as String,
                                      child: Text(u['name'] as String))),
                                ],
                                onChanged: (v) => setState(() {
                                  _selectedUnitId = v;
                                  _selectedCategoryId = null;
                                }),
                              ),
                              loading: () =>
                                  const CircularProgressIndicator(),
                              error: (e, _) => Text('Hata: $e'),
                            ),
                          const SizedBox(height: 12),
                          // Category dropdown (filtered by team + unit)
                          categoriesAsync.when(
                            data: (cats) {
                              final filtered = cats
                                  .where((c) =>
                                      c.teamId == _selectedTeamId &&
                                      c.unitId == _selectedUnitId)
                                  .toList();
                              return DropdownButtonFormField<String>(
                                initialValue: _selectedCategoryId,
                                dropdownColor: AppColors.surface2,
                                style:
                                    TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                    labelText: 'Kategori'),
                                items: [
                                  const DropdownMenuItem(
                                      value: null, child: Text('—')),
                                  ...filtered.map((c) => DropdownMenuItem(
                                      value: c.id, child: Text(c.name))),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedCategoryId = v),
                              );
                            },
                            loading: () =>
                                const CircularProgressIndicator(),
                            error: (e, _) => Text('Hata: $e'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _serialCtrl,
                                  style: TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: const InputDecoration(
                                      labelText: 'Seri No',
                                      hintText: 'SN-12345'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _modelCtrl,
                                  style: TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: const InputDecoration(
                                      labelText: 'Model', hintText: 'R3'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _brandCtrl,
                                  style: TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: const InputDecoration(
                                      labelText: 'Marka', hintText: 'Arduino'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _quantityCtrl,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: const InputDecoration(
                                      labelText: 'Adet', hintText: '1'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Status dropdown (dynamic from Firestore)
                          statusesAsync.when(
                            data: (statuses) {
                              final options = statuses.isNotEmpty
                                  ? statuses
                                  : [
                                      const InventoryStatus(
                                          id: 'available', label: 'Mevcut'),
                                      const InventoryStatus(
                                          id: 'inUse', label: 'Kullanımda'),
                                      const InventoryStatus(
                                          id: 'maintenance', label: 'Bakımda'),
                                    ];
                              return DropdownButtonFormField<String>(
                                initialValue: _selectedStatus,
                                dropdownColor: AppColors.surface2,
                                style:
                                    TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                    labelText: 'Durum'),
                                items: options
                                    .map((s) => DropdownMenuItem(
                                        value: s.id, child: Text(s.label)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedStatus = v!),
                              );
                            },
                            loading: () =>
                                const CircularProgressIndicator(),
                            error: (e, _) => Text('Hata: $e'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // STEP 2: Location
                  Step(
                    title: Text('Lokasyon',
                        style: TextStyle(color: AppColors.textPrimary)),
                    isActive: _currentStep >= 1,
                    state: StepState.indexed,
                    content: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Location picker
                          InkWell(
                            onTap: _pickLocation,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Lokasyon',
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(
                                _selectedLocationName ?? 'Lokasyon seçin',
                                style: TextStyle(
                                  color: _selectedLocationName != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Shelf
                          TextFormField(
                            controller: _shelfCtrl,
                            style: TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Raf Adı',
                              hintText: 'Örn: A-3',
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Drawer
                          TextFormField(
                            controller: _drawerCtrl,
                            style: TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Çekmece Adı',
                              hintText: 'Örn: Çekmece 2',
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Location photo
                          Text('Lokasyon Fotoğrafı',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _pickLocationImage(ImageSource.camera),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface2,
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.radiusMd),
                                    border: Border.all(
                                        color: AppColors.border),
                                  ),
                                  child: _pickedLocationImage != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  AppConstants.radiusMd - 1),
                                          child: PlatformImageFile(
                                            bytes: _pickedLocationImage!.bytes,
                                            file: _pickedLocationImage!.dartFile,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.camera_alt,
                                                size: 28,
                                                color:
                                                    AppColors.textSecondary),
                                            const SizedBox(height: 4),
                                            Text('Kamera',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors
                                                        .textSecondary)),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () =>
                                    _pickLocationImage(ImageSource.gallery),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface2,
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.radiusMd),
                                    border: Border.all(
                                        color: AppColors.border),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.photo_library,
                                          size: 28,
                                          color: AppColors.textSecondary),
                                      const SizedBox(height: 4),
                                      Text('Galeri',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Standalone ConsumerStatefulWidget for the "Lokasyon Seç" bottom sheet.
class _LocationPickerSheet extends ConsumerStatefulWidget {
  final String? categoryId;
  const _LocationPickerSheet({this.categoryId});

  @override
  ConsumerState<_LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<_LocationPickerSheet> {
  Future<void> _addLocation() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Lokasyon Ekle'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Raf/Bölüm Adı',
            hintText: 'Örn: Raf A-1',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Ekleniyor...',
      successMessage: 'Lokasyon eklendi.',
      operation: () =>
          ref.read(depoRepositoryProvider).addLocationByName(name),
    );
  }

  Future<void> _editLocation(DepoLocation loc) async {
    final nameCtrl = TextEditingController(text: loc.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lokasyonu Düzenle'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Lokasyon Adı'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Güncelleniyor...',
      successMessage: 'Lokasyon güncellendi.',
      operation: () =>
          ref.read(depoRepositoryProvider).updateLocationName(loc.id, name),
    );
  }

  Future<void> _deleteLocation(DepoLocation loc) async {
    int count = 0;
    try {
      count = await ref
          .read(depoRepositoryProvider)
          .countItemsInLocation(loc.id);
    } catch (_) {}

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lokasyonu Sil'),
        content: Text(
          count > 0
              ? 'Bu lokasyonda $count ürün var, yine de silinsin mi?'
              : '"${loc.name}" silinecek. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await runDeleteWithFeedback(
      context: context,
      successMessage: 'Lokasyon silindi.',
      operation: () =>
          ref.read(depoRepositoryProvider).deleteLocation(loc.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(locationsProvider);
    final canManage = ref.watch(isAdminProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Lokasyon Seç',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  if (canManage)
                    TextButton.icon(
                      onPressed: _addLocation,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Lokasyon Ekle'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.depoAccent,
                      ),
                    ),
                ],
              ),
            ),
            Divider(color: AppColors.border, height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: locationsAsync.when(
                data: (locations) {
                  final filtered = widget.categoryId == null
                      ? locations
                      : locations
                          .where((l) => l.categoryId == widget.categoryId)
                          .toList();
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Bu kategoride lokasyon bulunamadı.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final loc = filtered[i];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            color: AppColors.depoAccent),
                        title: Text(loc.name,
                            style: TextStyle(color: AppColors.textPrimary)),
                        trailing: canManage
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary),
                                    tooltip: 'Düzenle',
                                    onPressed: () => _editLocation(loc),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppColors.error),
                                    tooltip: 'Sil',
                                    onPressed: () => _deleteLocation(loc),
                                  ),
                                ],
                              )
                            : null,
                        onTap: () => Navigator.pop(context, {
                          'id': loc.id,
                          'name': loc.name,
                        }),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text('Hata: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}