import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../models/user_profile_models.dart';
import '../providers/auth_providers.dart';

/// Centralized, permission-based access control (RBAC).
///
/// Every protected action in the app is represented by a permission string
/// (see [Permissions]). Roles are mapped to permission sets. The mapping can be
/// overridden at runtime from the `role_permissions` Firestore collection,
/// which lets admins toggle permissions per role from the "Rol ve Yetki
/// Yönetimi" screen without redeploying the app.
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
  static const deleteTasks = 'deleteTasks';
  static const manageReports = 'manageReports';
  static const awardPoints = 'awardPoints';
  static const reviewApplications = 'reviewApplications';
  static const editClubStory = 'editClubStory';
  static const editTeamStory = 'editTeamStory';
  static const addHonoraryMember = 'addHonoraryMember';
  static const manageRolesAndPermissions = 'manageRolesAndPermissions';
  static const manageStore = 'manageStore';

  /// Ordered list of every known permission.
  static const List<String> all = [
    manageRolesAndPermissions,
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
    deleteTasks,
    manageReports,
    awardPoints,
    reviewApplications,
    editClubStory,
    editTeamStory,
    addHonoraryMember,
    manageStore,
  ];

  /// Turkish labels for the role/permission management screen.
  static const Map<String, String> labels = {
    manageRolesAndPermissions: 'Rol ve Yetki Yönetimi',
    viewAdminPanel: 'Kontrol Panelini Görüntüle',
    manageUsers: 'Üye Yönetimi',
    changeRoles: 'Kullanıcı Rolü Atayabilir',
    manageTitles: 'Ünvan Yönetimi',
    manageTeams: 'Takım Yönetimi',
    manageUnits: 'Birim Yönetimi',
    manageInventory: 'Envanter Yönetimi',
    manageAnnouncements: 'Duyuru Yönetimi',
    createTasks: 'Görev Oluşturabilir',
    approveTasks: 'Görev Onaylayabilir',
    deleteTasks: 'Görev Silebilir',
    manageReports: 'Hata Bildirimi Yönetimi',
    awardPoints: 'Puan Ekleyebilir/Düşürebilir',
    reviewApplications: 'Başvuru Onaylayabilir',
    editClubStory: 'Kulüp Hikayesi Düzenleyebilir',
    editTeamStory: 'Takım Hikayesi Düzenleyebilir',
    addHonoraryMember: 'Onursal Üye Ekleyebilir',
    manageStore: 'Mağaza Ürünü Ekleyebilir/Düzenleyebilir',
  };

  /// Default role → permission map. This is the baseline used when no
  /// `role_permissions/{role}` override document exists.
  ///
  /// Defaults: `admin` and `board_president` (Başkan) have every permission.
  /// Every other role starts with reasonable defaults and can be fine-tuned
  /// from the admin panel.
  static const Map<String, Set<String>> defaultRolePermissions = {
    'admin': {
      ...all,
    },
    'board_president': {
      ...all,
    },
    'board_member': {
      viewAdminPanel,
      manageTitles,
      manageAnnouncements,
      reviewApplications,
      editClubStory,
      editTeamStory,
      addHonoraryMember,
      manageStore,
    },
    'captain': {
      createTasks,
      approveTasks,
      deleteTasks,
      manageUnits,
      manageAnnouncements,
      reviewApplications,
      editTeamStory,
      manageStore,
    },
    'unit_lead': {
      manageAnnouncements,
      createTasks,
      approveTasks,
      manageReports,
      awardPoints,
      reviewApplications,
      manageStore,
    },
    'member': {},
  };
}

/// Maps a [TitleType] value to the permission-system role it implies.
///
/// The club stores rich roles in the `titles` array (with `titleType`), while
/// the legacy `role` field is used for lightweight permission checks. This
/// helper lets the system resolve permissions from BOTH sources.
String titleTypeToRoleCode(String titleType) {
  switch (titleType) {
    case TitleType.admin:
      return 'admin';
    case TitleType.boardPresident:
      return 'board_president';
    case TitleType.boardMember:
      return 'board_member';
    case TitleType.captain:
      return 'captain';
    case TitleType.unitLead:
      return 'unit_lead';
    default:
      return 'member';
  }
}

/// Effective roles for a user = their primary `role` field plus every active
/// title's mapped role code. This means a user holding an active
/// `board_member` title is treated as a board member even if their legacy
/// `role` field is still `member`.
Set<String> effectiveRoleCodes(AppUser? user) {
  if (user == null) return const {};
  final roles = <String>{user.role};
  for (final title in user.activeTitles) {
    roles.add(titleTypeToRoleCode(title.titleType));
  }
  return roles;
}

/// Whether [user] is a Yönetim Kurulu member (`board_member` or
/// `board_president`), honoring both the legacy `role` field and active titles.
bool userIsBoard(AppUser? user) {
  final roles = effectiveRoleCodes(user);
  return roles.contains('board_member') || roles.contains('board_president');
}

/// Whether [user] is the Yönetim Kurulu Başkanı (`board_president`).
bool userIsBoardPresident(AppUser? user) {
  return effectiveRoleCodes(user).contains('board_president');
}

/// Human-readable Turkish label for a role value.
String roleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'board_president':
      return 'Başkan';
    case 'board_member':
      return 'Yönetim Kurulu Üyesi';
    case 'captain':
      return 'Kaptan';
    case 'unit_lead':
      return 'Birim Sorumlusu';
    default:
      return 'Üye';
  }
}

/// All roles configurable by an admin (central, ordered list).
const List<String> allRoles = [
  'admin',
  'board_president',
  'board_member',
  'captain',
  'unit_lead',
  'member',
];

/// Resolves the union of permissions a user holds, given a resolved
/// role → permission map.
Set<String> userEffectivePermissions(
  AppUser? user,
  Map<String, Set<String>> rolePerms,
) {
  final out = <String>{};
  if (user == null) return out;
  for (final role in effectiveRoleCodes(user)) {
    out.addAll(rolePerms[role] ?? Permissions.defaultRolePermissions[role] ?? const {});
  }
  return out;
}

/// Returns whether [user] holds [permission], given a resolved role map.
bool userHasPermission(
  AppUser? user,
  Map<String, Set<String>> rolePerms,
  String permission,
) {
  return userEffectivePermissions(user, rolePerms).contains(permission);
}

/// Centralized permission service + Riverpod provider.
class PermissionService {
  final FirebaseFirestore _firestore;

  PermissionService(this._firestore);

  /// Streams the resolved role → permission map: default permissions merged
  /// with any `role_permissions/{role}` overrides from Firestore.
  Stream<Map<String, Set<String>>> watchRolePermissions() {
    return _firestore.collection('role_permissions').snapshots().map((snap) {
      final map = Permissions.defaultRolePermissions.map(
        (k, v) => MapEntry(k, <String>{...v}),
      );
      for (final doc in snap.docs) {
        final role = doc.id;
        if (!map.containsKey(role)) continue;
        final perms = (doc.data()['permissions'] as List?)
                ?.map((e) => e.toString())
                .where(Permissions.all.contains)
                .toSet() ??
            <String>{};
        map[role] = perms;
      }
      return map;
    });
  }

  /// Persists the permission set for [role] (creates an override document).
  ///
  /// Guarded by Firestore rules (`isAdmin()` may write `role_permissions`).
  Future<void> setRolePermissions(String role, Set<String> permissions) async {
    if (!allRoles.contains(role)) {
      throw ArgumentError('Invalid role: $role');
    }
    await _firestore.collection('role_permissions').doc(role).set({
      'permissions': permissions.where(Permissions.all.contains).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes the override for [role], falling back to defaults.
  Future<void> resetRolePermissions(String role) async {
    await _firestore.collection('role_permissions').doc(role).delete();
  }

  /// Admin-only: update another user's `role` field.
  ///
  /// Guarded by Firestore rules (only `isRoleManager()` may write the `role`
  /// key), so calling this with a non-admin account is rejected server-side.
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

/// Resolved role → permission map, reactive to Firestore overrides.
final rolePermissionsProvider = StreamProvider<Map<String, Set<String>>>((ref) {
  return ref.watch(permissionServiceProvider).watchRolePermissions();
});

/// Convenience provider: current user's role.
final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(currentAppUserProvider).value?.role ?? 'member';
});

/// Convenience provider: resolves a permission for the current user, honoring
/// any `role_permissions` overrides.
final currentUserCanProvider = Provider.family<bool, String>((ref, permission) {
  final user = ref.watch(currentAppUserProvider).value;
  final rolePerms =
      ref.watch(rolePermissionsProvider).valueOrNull ?? Permissions.defaultRolePermissions;
  return userHasPermission(user, rolePerms, permission);
});