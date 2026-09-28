import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/permissions/permission_system.dart';
import '../../core/providers/auth_providers.dart';

/// Fine-grained capabilities for the Admin Kontrol Paneli.
///
/// These are now derived from the permission system (`hasPermission`) instead
/// of hard-coded role checks, so the "Rol ve Yetki Yönetimi" screen can toggle
/// them per role.
class AdminCapabilities {
  final bool canViewAdminPanel;
  final bool canChangeRoles;
  final bool canDeleteMembers;
  final bool canSuspendMembers;
  final bool canEditPoints;
  final bool canManageTitles;
  final bool canManageTeams;
  final bool canReviewApplications;
  final bool canManageRolesAndPermissions;

  const AdminCapabilities({
    required this.canViewAdminPanel,
    required this.canChangeRoles,
    required this.canDeleteMembers,
    required this.canSuspendMembers,
    required this.canEditPoints,
    required this.canManageTitles,
    required this.canManageTeams,
    required this.canReviewApplications,
    required this.canManageRolesAndPermissions,
  });

  factory AdminCapabilities.forUser(AppUser? user) {
    bool can(String permission) =>
        userHasPermission(user, Permissions.defaultRolePermissions, permission);

    return AdminCapabilities(
      canViewAdminPanel: can(Permissions.viewAdminPanel),
      canChangeRoles: can(Permissions.changeRoles),
      canDeleteMembers: can(Permissions.manageUsers),
      canSuspendMembers: can(Permissions.manageUsers),
      canEditPoints: can(Permissions.awardPoints),
      canManageTitles: can(Permissions.manageTitles),
      canManageTeams: can(Permissions.manageTeams),
      canReviewApplications: can(Permissions.reviewApplications),
      canManageRolesAndPermissions: can(Permissions.manageRolesAndPermissions),
    );
  }

  static const none = AdminCapabilities(
    canViewAdminPanel: false,
    canChangeRoles: false,
    canDeleteMembers: false,
    canSuspendMembers: false,
    canEditPoints: false,
    canManageTitles: false,
    canManageTeams: false,
    canReviewApplications: false,
    canManageRolesAndPermissions: false,
  );
}

/// Convenience provider resolving the current user's base admin capabilities.
///
/// NOTE: This uses the default role → permission map (not Firestore overrides)
/// to keep member detail / admin panel wiring stable. For a live, override-aware
/// check prefer [currentUserCanProvider].
final adminCapabilitiesProvider = Provider<AdminCapabilities>((ref) {
  return AdminCapabilities.forUser(ref.watch(currentAppUserProvider).valueOrNull);
});