import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../providers/auth_providers.dart';

/// Centralized permission model.
///
/// Instead of scattering `if (isAdmin)` checks across every screen, features
/// should ask "can the current user do X?" through [PermissionService]. The
/// same permission names are mirrored in Firestore security rules so the UI
/// is never the only line of defense.
class Permissions {
  static const viewAdminPanel = 'viewAdminPanel';
  static const manageUsers = 'manageUsers';
  static const changeRoles = 'changeRoles';
  static const manageTitles = 'manageTitles';
  static const manageTeams = 'manageTeams';
  static const manageUnits = 'manageUnits';
  static const manageInventory = 'manageInventory';
  static const manageAnnouncements = 'manageAnnouncements';
  static const createTasks = 'createTasks';
  static const approveTasks = 'approveTasks';
  static const manageReports = 'manageReports';
  static const awardPoints = 'awardPoints';
  static const reviewApplications = 'reviewApplications';

  /// Role → permissions map. Central source of truth for the app's RBAC.
  static const Map<String, Set<String>> rolePermissions = {
    'admin': {
      viewAdminPanel,
      manageUsers,
      changeRoles,
      manageTitles,
      manageTeams,
      manageUnits,
      manageInventory,
      manageAnnouncements,
      createTasks,
      approveTasks,
      manageReports,
      awardPoints,
      reviewApplications,
    },
    'unit_lead': {
      manageAnnouncements,
      createTasks,
      approveTasks,
      manageReports,
      awardPoints,
      reviewApplications,
    },
    'board_president': {
      viewAdminPanel,
      manageTitles,
      manageUsers,
      changeRoles,
    },
    'board_member': {
      manageTitles,
    },
    'member': {},
  };
}

/// Returns whether the user's `role` field grants a permission.
bool roleHasPermission(String role, String permission) {
  return Permissions.rolePermissions[role]?.contains(permission) ?? false;
}

/// Human-readable Turkish label for a role value.
String roleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'unit_lead':
      return 'Birim Sorumlusu';
    case 'board_president':
      return 'Yönetim Kurulu Başkanı';
    case 'board_member':
      return 'Yönetim Kurulu Üyesi';
    default:
      return 'Üye';
  }
}

/// All roles selectable by an admin (central list).
const List<String> allRoles = [
  'member',
  'unit_lead',
  'admin',
  'board_member',
  'board_president',
];

/// Centralized permission service + Riverpod provider.
class PermissionService {
  final FirebaseFirestore _firestore;

  PermissionService(this._firestore);

  bool can(String permission, AppUser? user) {
    if (user == null) return false;
    return roleHasPermission(user.role, permission);
  }

  /// Admin-only: update another user's `role` field.
  ///
  /// Guarded by Firestore rules (only `isAdmin()` may write the `role` key),
  /// so calling this with a non-admin account is rejected server-side too.
  Future<void> updateRole({
    required String targetUid,
    required String newRole,
  }) async {
    if (!allRoles.contains(newRole)) {
      throw ArgumentError('Invalid role: $newRole');
    }
    await _firestore.collection('users').doc(targetUid).update({
      'role': newRole,
    });
  }

  /// One-off migration: convert any legacy `role == 'user'` documents to the
  /// canonical `'member'` value. Returns the number of updated documents.
  Future<int> migrateLegacyUserRoles() async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'user')
        .get();
    var updated = 0;
    for (final doc in snap.docs) {
      await doc.reference.update({'role': 'member'});
      updated++;
    }
    return updated;
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(ref.watch(firestoreProvider));
});

/// Convenience provider: current user's role.
final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(currentAppUserProvider).value?.role ?? 'member';
});

/// Convenience provider: resolves a permission for the current user.
final currentUserCanProvider =
    Provider.family<bool, String>((ref, permission) {
  final user = ref.watch(currentAppUserProvider).value;
  return user != null && roleHasPermission(user.role, permission);
});