import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';

/// Extra security PIN required to open the Admin Panel.
///
/// This is intentionally a simple club-level gate (not a substitute for the
/// server-side `isAdmin()` Firestore rules). It prevents accidental/mistaken
/// entry from an admin's unlocked device.
const String adminPanelPin = '2719';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptForPin());
  }

  Future<void> _promptForPin() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Paneli'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
              'Yönetim paneline erişmek için güvenlik kodunu girin.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              style:  TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Güvenlik kodu',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, ctrl.text == adminPanelPin),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text == adminPanelPin),
            child: const Text('Giriş'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      setState(() => _unlocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Centralized gate: only roles granted the `viewAdminPanel` permission may
    // open this screen. Previously this also hard-required `isAdminProvider`,
    // which wrongly locked out board presidents even though the permission
    // system grants them `viewAdminPanel`.
    final canAccess =
        ref.watch(currentUserCanProvider(Permissions.viewAdminPanel));

    if (!canAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Yönetim')),
        body:  Center(
          child: Text('Bu bölüme erişim yetkiniz yok.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yönetim'),
        backgroundColor: AppColors.surface,
      ),
      body: !_unlocked
          ?  Center(
              child: Text('Panel kilitli.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : const DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Kullanıcılar & Roller'),
                      Tab(text: 'Rol Yetkileri'),
                      Tab(text: 'Özet'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _UsersAndRolesTab(),
                        _RolePermissionsTab(),
                        _SummaryTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _UsersAndRolesTab extends ConsumerStatefulWidget {
  const _UsersAndRolesTab();

  @override
  ConsumerState<_UsersAndRolesTab> createState() => _UsersAndRolesTabState();
}

class _UsersAndRolesTabState extends ConsumerState<_UsersAndRolesTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _savingUid;
  bool _canChangeRoles = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeRole(AppUser user, String newRole) async {
    if (user.role == newRole) return;
    setState(() => _savingUid = user.uid);
    try {
      await ref
          .read(permissionServiceProvider)
          .updateRole(targetUid: user.uid, newRole: newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${user.displayName} → ${roleLabel(newRole)}'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rol güncellenemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    _canChangeRoles =
        ref.watch(currentUserCanProvider(Permissions.changeRoles));
    final usersAsync = ref.watch(allUsersProvider);
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            style:  TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'İsim ara...',
              hintStyle:
                   TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon:  Icon(Icons.search,
                  size: 18, color: AppColors.textSecondary),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: usersAsync.when(
            data: (users) {
              final filtered = _query.isEmpty
                  ? users
                  : users
                      .where((u) =>
                          u.displayName.toLowerCase().contains(_query) ||
                          u.email.toLowerCase().contains(_query))
                      .toList();
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final user = filtered[i];
                  final isSelf = user.uid == currentUid;
                  final saving = _savingUid == user.uid;
                  return Card(
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.surface2,
                            backgroundImage: user.photoUrl != null &&
                                    user.photoUrl!.isNotEmpty
                                ? NetworkImage(user.photoUrl!)
                                : null,
                            child: user.photoUrl == null ||
                                    user.photoUrl!.isEmpty
                                ?  Icon(Icons.person_outline,
                                    size: 16, color: AppColors.textSecondary)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.displayName,
                                    style:  TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                Text(user.email,
                                    style:  TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          if (saving)
                            const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                          else if (!_canChangeRoles)
                            // No `changeRoles` permission → show a read-only role
                            // chip instead of an editable dropdown.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                roleLabel(user.role),
                                style:  TextStyle(
                                    color: AppColors.textPrimary, fontSize: 12),
                              ),
                            )
                          else
                            DropdownButton<String>(
                              value: user.role,
                              isDense: true,
                              underline: const SizedBox.shrink(),
                              dropdownColor: AppColors.surface2,
                              style:  TextStyle(
                                  color: AppColors.textPrimary, fontSize: 12),
                              // Prevent self-lockout: a manager can't demote
                              // themselves to a non-manager role.
                              onChanged: isSelf
                                  ? null
                                  : (v) {
                                      if (v != null) _changeRole(user, v);
                                    },
                              items: allRoles
                                  .map((r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(roleLabel(r),
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
          ),
        ),
      ],
    );
  }
}

class _RolePermissionsTab extends StatelessWidget {
  const _RolePermissionsTab();

  @override
  Widget build(BuildContext context) {
    final roleNames = Permissions.rolePermissions.keys.toList();
    final permissionNames = {
      Permissions.viewAdminPanel,
      Permissions.manageUsers,
      Permissions.changeRoles,
      Permissions.manageTitles,
      Permissions.manageTeams,
      Permissions.manageUnits,
      Permissions.manageInventory,
      Permissions.manageAnnouncements,
      Permissions.createTasks,
      Permissions.approveTasks,
      Permissions.manageReports,
      Permissions.awardPoints,
      Permissions.reviewApplications,
    }.toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
         Text('Rol bazlı yetki matrisi (salt okunur)',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                 WidgetStatePropertyAll(AppColors.surface2),
            columns: [
              const DataColumn(label: Text('Yetki')),
              ...roleNames.map((r) => DataColumn(
                  label: Text(roleLabel(r),
                      style: const TextStyle(color: AppColors.sargeGold)))),
            ],
            rows: permissionNames.map((p) {
              return DataRow(cells: [
                DataCell(Text(p)),
                ...roleNames.map((r) {
                  final granted =
                      Permissions.rolePermissions[r]?.contains(p) ?? false;
                  return DataCell(Icon(
                    granted ? Icons.check_circle : Icons.remove_circle_outline,
                    color: granted ? AppColors.success : AppColors.border,
                    size: 18,
                  ));
                }),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
         Text(
          'Not: Yetkiler yalnızca bu matriste değil, Firestore güvenlik '
          'kurallarında da doğrulanır. Kullanıcı arayüzü tek savunma hattı değildir.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.4),
        ),
      ],
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final totalUsers = usersAsync.valueOrNull?.length ?? 0;
    final counts = <String, int>{};
    for (final u in usersAsync.valueOrNull ?? []) {
      counts[u.role] = (counts[u.role] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(
          icon: Icons.people_outline,
          title: 'Toplam Kullanıcı',
          value: '$totalUsers',
          color: AppColors.panelBlue,
        ),
        const SizedBox(height: 12),
        ...allRoles.map((r) {
          return _SummaryCard(
            icon: Icons.badge_outlined,
            title: roleLabel(r),
            value: '${counts[r] ?? 0}',
            color: _roleColor(r),
          );
        }),
      ],
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.error;
      case 'unit_lead':
        return AppColors.warning;
      case 'board_president':
        return AppColors.sargeGold;
      case 'board_member':
        return AppColors.teamAccent;
      default:
        return AppColors.tasksGreen;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style:  TextStyle(
                    color: AppColors.textPrimary, fontSize: 14)),
          ),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}