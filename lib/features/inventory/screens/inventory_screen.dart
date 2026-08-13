import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../models/depo_models.dart';
import '../providers/depo_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _filterTeamId;
  String? _filterUnitId;
  String? _filterCategoryId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200 ? 6 : (width >= AppConstants.breakpointTablet ? 5 : 3);

    return Scaffold(
      backgroundColor: AppColors.depoBg,
      appBar: AppBar(
        title: const Text('Depo'),
        backgroundColor: AppColors.depoBg,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 48),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  style:  TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ürün ara...',
                    hintStyle:  TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon:  Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    _FilterChipGroup(
                      label: 'Takım',
                      selected: _filterTeamId,
                      stream: ref.watch(clubTeamsProvider).valueOrNull,
                      labelFn: (t) => t is ClubTeam ? t.name : '',
                      idFn: (t) => t is ClubTeam ? t.id : '',
                      onChanged: (v) {
                        setState(() {
                          _filterTeamId = v;
                          _filterUnitId = null;
                          _filterCategoryId = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    if (_filterTeamId != null)
                      _FilterChipGroup(
                        label: 'Birim',
                        selected: _filterUnitId,
                        stream: ref.watch(teamUnitsProvider(_filterTeamId!)).valueOrNull,
                        labelFn: (u) => u is Map ? (u['name'] as String? ?? '') : '',
                        idFn: (u) => u is Map ? (u['id'] as String) : '',
                        onChanged: (v) {
                          setState(() {
                            _filterUnitId = v;
                            _filterCategoryId = null;
                          });
                        },
                      ),
                    const SizedBox(width: 8),
                    if (_filterTeamId != null) _buildCategoryFilter(ref),
                    const SizedBox(width: 8),
                    if (_filterTeamId != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => setState(() {
                          _filterTeamId = null;
                          _filterUnitId = null;
                          _filterCategoryId = null;
                        }),
                        child: const Text('Temizle',
                            style: TextStyle(fontSize: 12, color: AppColors.error)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: itemsAsync.when(
        data: (items) {
          // Apply filters
          List<DepoItem> filtered = items;
          if (_filterTeamId != null) {
            filtered = filtered.where((i) => i.teamId == _filterTeamId).toList();
          }
          if (_filterUnitId != null) {
            filtered = filtered.where((i) => i.unitId == _filterUnitId).toList();
          }
          if (_filterCategoryId != null) {
            filtered = filtered.where((i) => i.categoryId == _filterCategoryId).toList();
          }
          // Apply search query
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((i) => i.name.toLowerCase().contains(_searchQuery)).toList();
          }

          if (filtered.isEmpty) {
            return  Center(
                child: Text('Henüz ürün yok.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
               childAspectRatio: 0.9,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                return _ItemCard(item: item);
              },
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.depoAccent)),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppColors.error))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/inventory/add'),
        backgroundColor: AppColors.depoAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryFilter(WidgetRef ref) {
    final catsAsync = ref.watch(inventoryCategoriesProvider);
    final cats = catsAsync.valueOrNull ?? [];
    final filtered = cats
        .where((c) =>
            c.teamId == _filterTeamId && c.unitId == _filterUnitId)
        .toList();

    return _FilterChipGroup(
      label: 'Kategori',
      selected: _filterCategoryId,
      stream: filtered,
      labelFn: (c) => c is InventoryCategory ? c.name : '',
      idFn: (c) => c is InventoryCategory ? c.id : '',
      onChanged: (v) => setState(() => _filterCategoryId = v),
    );
  }
}

/// Horizontal scrollable filter chip group.
class _FilterChipGroup extends StatelessWidget {
  final String label;
  final String? selected;
  final List<dynamic>? stream;
  final String Function(dynamic) labelFn;
  final String Function(dynamic) idFn;
  final ValueChanged<String?> onChanged;

  const _FilterChipGroup({
    required this.label,
    required this.selected,
    required this.stream,
    required this.labelFn,
    required this.idFn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = stream ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          isDense: true,
          dropdownColor: AppColors.surface2,
          style:  TextStyle(color: AppColors.textPrimary, fontSize: 12),
          hint: Text(label,
              style:  TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('Tüm $label',
                  style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 12)),
            ),
            ...items.map((item) => DropdownMenuItem(
                  value: idFn(item),
                  child: Text(labelFn(item), style: const TextStyle(fontSize: 12)),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Product image with tap-to-zoom. Supports a single image or a gallery of
/// images (comma-separated or a `List`), with a proper placeholder on error.
class _ProductImage extends StatelessWidget {
  final DepoItem item;
  const _ProductImage({required this.item});

  List<String> _imageUrls() {
    final raw = item.imageUrl;
    if (raw == null || raw.isEmpty) return const [];
    // Support both a single URL and multiple URLs separated by a delimiter
    // (comma) or stored as a Firestore list.
    final parts = raw
        .split(RegExp(r',\s*|\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final urls = _imageUrls();

    if (urls.isEmpty) {
      return Container(
        color: AppColors.surface2,
        child:  Center(
          child: Icon(Icons.inventory_2_outlined,
              size: 28, color: AppColors.textSecondary),
        ),
      );
    }

    return GestureDetector(
      onTap: () => showFullScreenImageViewer(
        context,
        urls: urls,
        initialIndex: 0,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            urls.first,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.surface2,
              child:  Center(
                child: Icon(Icons.image_not_supported_outlined,
                    size: 28, color: AppColors.textSecondary),
              ),
            ),
          ),
          // Visual hint that this area opens the full-screen zoom viewer.
          Positioned(
            right: 4,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.zoom_in,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final DepoItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image fills most of the card. Tapping it opens the full-screen
          // zoomable viewer; it is intentionally NOT the detail route.
          Expanded(
            child: _ProductImage(item: item),
          ),
          // Minimal text footer. Tapping it opens the detail screen.
          InkWell(
            onTap: () => context.push('/inventory/detail/${item.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.depoAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(item.status,
                        style: const TextStyle(
                            color: AppColors.depoAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
