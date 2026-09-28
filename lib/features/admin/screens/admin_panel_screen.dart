import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../admin_permissions.dart';
import '../widgets/admin_applications_tab.dart';
import '../widgets/admin_approvals_tab.dart';
import '../widgets/admin_members_tab.dart';
import '../widgets/admin_team_unit_tab.dart';
import 'role_permission_screen.dart';

/// Comprehensive "Admin Kontrol Paneli".
///
/// Tabbed structure:
///  * Üye Yönetimi    — searchable member list + detailed per-member management
///  * Takım & Birim   — team CRUD + unit management
///  * Başvurular      — centralized team-application review
///  * Kayıt Onayları  — approve/reject newly registered (pending) users
///  * Yetkiler        — role → permission editing
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(adminCapabilitiesProvider);
    if (!caps.canViewAdminPanel) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Yönetim')),
        body: Center(
          child: Text('Bu bölüme erişim yetkiniz yok.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Kontrol Paneli'),
        backgroundColor: AppColors.surface,
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.sargeGold,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.sargeGold,
              tabs: const [
                Tab(text: 'Üyeler'),
                Tab(text: 'Takım & Birim'),
                Tab(text: 'Başvurular'),
                Tab(text: 'Kayıt Onayları'),
                Tab(text: 'Yetkiler'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  AdminMembersTab(),
                  AdminTeamUnitTab(),
                  AdminApplicationsTab(),
                  AdminApprovalsTab(),
                  RolePermissionScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
