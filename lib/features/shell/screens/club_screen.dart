import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../inventory/screens/inventory_screen.dart';
import '../../cleaning/screens/cleaning_main_screen.dart';

/// "KULÜP" tab container: two top tabs — Temizlik and Malzemeler.
///
/// Replaces the old top-level "Depo" screen. All existing inventory
/// functionality lives under "Malzemeler".
class ClubScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const ClubScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends ConsumerState<ClubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('KULÜP'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.depoAccent,
          tabs: const [
            Tab(icon: Icon(Icons.cleaning_services_outlined), text: 'Temizlik'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Malzemeler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CleaningMainScreen(),
          InventoryScreen(),
        ],
      ),
    );
  }
}
