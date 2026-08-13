import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/models/user_profile_models.dart';
import '../../core/providers/auth_providers.dart';

/// Maps a [TitleType] value to the permission-system role it implies.
///
/// The club stores rich roles in the `titles` array (with `titleType`), while
/// the legacy `role` field is used for lightweight permission checks. This
/// helper lets the admin panel resolve permissions from BOTH sources, as
/// required by the "titleType alanlarına göre kontrol et" requirement.
String titleTypeToRoleCode(String titleType) {
  switch (titleType) {
    case TitleType.admin:
      return 'admin';
    case TitleType.boardPresident:
      return 'board_president';
    case TitleType.boardMember:
      return 'board_member';
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

/// Fine-grained capabilities for the Admin Kontrol Paneli.
///
/// Mirrors the permission-level requirements:
///  * Only `admin` → member deletion, role changes, suspend, system settings.
///  * `admin` + board (başkan/üye) → title management, team/unit management.
///  * `admin` + `unit_lead` → point editing (existing `awardPoints`).
class AdminCapabilities {
  final bool canViewAdminPanel;
  final bool canChangeRoles;
  final bool canDeleteMembers;
  final bool canSuspendMembers;
  final bool canEditPoints;
  final bool canManageTitles;
  final bool canManageTeams;
  final bool canReviewApplications;

  const AdminCapabilities({
    required this.canViewAdminPanel,
    required this.canChangeRoles,
    required this.canDeleteMembers,
    required this.canSuspendMembers,
    required this.canEditPoints,
    required this.canManageTitles,
    required this.canManageTeams,
    required this.canReviewApplications,
  });

  factory AdminCapabilities.forUser(AppUser? user) {
    final roles = effectiveRoleCodes(user);
    bool hasAny(Set<String> rs) => roles.intersection(rs).isNotEmpty;

    const board = {'admin', 'board_president', 'board_member'};
    return AdminCapabilities(
      canViewAdminPanel: hasAny(board),
      canChangeRoles: roles.contains('admin'),
      canDeleteMembers: roles.contains('admin'),
      canSuspendMembers: roles.contains('admin'),
      canEditPoints: hasAny(const {'admin', 'unit_lead'}),
      canManageTitles: hasAny(board),
      canManageTeams: hasAny(board),
      canReviewApplications:
          hasAny(const {'admin', 'unit_lead', 'board_president', 'board_member'}),
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
  );
}

/// Convenience provider resolving the current user's admin capabilities.
final adminCapabilitiesProvider = Provider<AdminCapabilities>((ref) {
  return AdminCapabilities.forUser(ref.watch(currentAppUserProvider).value);
});