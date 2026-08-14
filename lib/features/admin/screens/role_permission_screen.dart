import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';

/// "Rol ve Yetki Yönetimi" — lets admins toggle permissions per role.
///
/// Reads the resolved role → permission map from [rolePermissionsProvider] and
/// writes overrides back to the `role_permissions` collection via
/// [PermissionService.setRolePermissions] / [resetRolePermissions].
class RolePermissionScreen extends ConsumerStatefulWidget {
  const RolePermissionScreen({super.key});

  @override
  ConsumerState<RolePermissionScreen> createState() =>
      _RolePermissionScreenState();
}

class _RolePermissionScreenState extends ConsumerState<RolePermissionScreen> {
  String? _selectedRole = 'admin';

  @override
  Widget build(BuildContext context) {
    final rolePermsAsync = ref.watch(rolePermissionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rol ve Yetki Yönetimi'),
        backgroundColor: AppColors.surface,
      ),
      body: rolePermsAsync.when(
        data: (rolePerms) {
          final role = _selectedRole ?? 'admin';
          final current = rolePerms[role] ??
              Permissions.defaultRolePermissions[role] ??
              const <String>{};

          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: allRoles.map((r) {
                      final selected = r == role;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(roleLabel(r)),
                          selected: selected,
                          selectedColor: AppColors.sargeGold,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.black
                                : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedRole = r),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${roleLabel(role)} rolünün yetkileri',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _resetRole(context, role),
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Varsayılana Dön'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: Permissions.all.length,
                  itemBuilder: (_, i) {
                    final permission = Permissions.all[i];
                    final checked = current.contains(permission);
                    final label = Permissions.labels[permission] ?? permission;
                    return CheckboxListTile(
                      value: checked,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.sargeGold,
                      title: Text(label,
                          style:
                              TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      onChanged: (v) => _togglePermission(
                          role, permission, v ?? false),
                    );
                  },
                ),
              ),
            ],
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

  Future<void> _togglePermission(
      String role, String permission, bool value) async {
    final service = ref.read(permissionServiceProvider);
    final rolePerms = ref.read(rolePermissionsProvider).valueOrNull ??
        Permissions.defaultRolePermissions;
    final current = Set<String>.from(
        rolePerms[role] ?? Permissions.defaultRolePermissions[role] ?? const {});

    if (value) {
      current.add(permission);
    } else {
      current.remove(permission);
    }

    // Show feedback but don't block the UI.
    final ok = await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Yetki güncelleniyor...',
      successMessage: '${roleLabel(role)} rolünün yetkileri güncellendi.',
      operation: () => service.setRolePermissions(role, current),
    );
    if (!ok && mounted) {
      // Re-sync local UI on failure.
      setState(() {});
    }
  }

  Future<void> _resetRole(BuildContext context, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varsayılana Dön'),
        content: Text('${roleLabel(role)} rolünün yetkileri varsayılana döndürülecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Döndür')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Varsayılana döndürülüyor...',
      successMessage: '${roleLabel(role)} rolü varsayılana döndürüldü.',
      operation: () => ref.read(permissionServiceProvider).resetRolePermissions(role),
    );
  }
}