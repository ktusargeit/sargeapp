import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../team/providers/team_providers.dart';

/// Whether the current user is the captain (leadUid) of at least one team.
final isCaptainOfAnyTeamProvider = Provider<bool>((ref) {
  final appUser = ref.watch(currentAppUserProvider).valueOrNull;
  final teams = ref.watch(clubTeamsProvider).valueOrNull;
  if (appUser == null || teams == null) return false;
  return teams.any((t) => t.leadUid == appUser.uid);
});

/// Whether the current user can administer cleaning (döngü, takvim, şablon)
/// and location categories. Includes admin, board members, unit leads, and any
/// team captain. Mirrors the spirit of the "kaptan/admin" requirement while
/// staying consistent with the app's existing RBAC sources.
final cleaningManagerProvider = Provider<bool>((ref) {
  final appUser = ref.watch(currentAppUserProvider).valueOrNull;
  if (appUser == null) return false;
  if (appUser.isAdmin) return true;
  final roles = effectiveRoleCodes(appUser);
  if (roles.contains('unit_lead') ||
      roles.contains('board_president') ||
      roles.contains('board_vice_president') ||
      roles.contains('board_member')) {
    return true;
  }
  return ref.watch(isCaptainOfAnyTeamProvider);
});
