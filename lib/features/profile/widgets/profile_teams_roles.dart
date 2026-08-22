import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import 'profile_common.dart';

// ---------------------------------------------------------------------------
// CURRENT TEAMS & ROLES — "Güncel Takımlar & Roller".
//
// Single source of truth: `teams/{id}.memberIds`. We query the `teams`
// collection with `array-contains` on the user's uid instead of relying on the
// (frequently out-of-sync) `users/{uid}.teamIds` denormalized copy, so a user
// added/removed via `teams/{id}.memberIds` always shows up correctly here.
// ---------------------------------------------------------------------------

/// Stream of teams the given [uid] is an ACTIVE member of, queried directly
/// from `teams` using `array-contains` (source of truth).
final userActiveTeamsProvider = StreamProvider.family<List<ClubTeam>, String>(
    (ref, uid) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('teams')
      .where('memberIds', arrayContains: uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => ClubTeam.fromDoc(d)).toList());
});

class ProfileTeamsRolesSection extends ConsumerWidget {
  final AppUser user;
  const ProfileTeamsRolesSection({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(userActiveTeamsProvider(user.uid));
    final unitsAsync = ref.watch(teamUnitListProvider);
    final teams = teamsAsync.valueOrNull ?? [];
    final units = unitsAsync.valueOrNull ?? const [];

    // Global roller: role alanı + aktif titles birleşimi. Aynı anda birden
    // fazla global rol taşınabilir (örn. Admin + Yönetim Kurulu Üyesi).
    final globalRoles = <({String type, String label, IconData icon, Color color})>[
      if (user.role == 'admin' ||
          user.activeTitles.any((t) => t.titleType == TitleType.admin))
        (
          type: 'admin',
          label: 'Admin',
          icon: Icons.admin_panel_settings,
          color: AppColors.error,
        ),
      if (user.role == 'board_president' ||
          user.activeTitles.any((t) => t.titleType == TitleType.boardPresident))
        (
          type: 'board_president',
          label: 'Yönetim Kurulu Başkanı',
          icon: Icons.gavel_outlined,
          color: AppColors.info,
        ),
      if (user.role == 'board_member' ||
          user.activeTitles.any((t) => t.titleType == TitleType.boardMember))
        (
          type: 'board_member',
          label: 'Yönetim Kurulu Üyesi',
          icon: Icons.groups_2_outlined,
          color: AppColors.info,
        ),
    ];

    // Birim sorumlulukları: units koleksiyonunda unitLeadUid == user.uid.
    final ledUnits =
        units.where((u) => u['unitLeadUid'] == user.uid).toList();

    return ProfileSectionTitleWithCard(
      header: const ProfileSectionHeader(title: 'GÜNCEL TAKIMLAR & ROLLER'),
      child: (teams.isEmpty && globalRoles.isEmpty)
          ? const ProfileEmptyCard(
              'Aktif takım bulunmuyor.',
              icon: Icons.groups_outlined,
            )
          : Column(
              children: [
                for (final role in globalRoles)
                  ProfileGlobalRoleRow(
                    label: role.label,
                    icon: role.icon,
                    color: role.color,
                  ),
                for (var i = 0; i < teams.length; i++)
                  ProfileTeamCard(
                    team: teams[i],
                    isCaptain: teams[i].leadUid == user.uid,
                    ledUnitNames: ledUnits
                        .where((u) => u['teamId'] == teams[i].id)
                        .map((u) => u['name'] as String? ?? '')
                        .where((n) => n.isNotEmpty)
                        .toList(),
                    isLast: i == teams.length - 1,
                  ),
              ],
            ),
    );
  }
}

class ProfileTeamCard extends StatelessWidget {
  final ClubTeam team;
  final bool isCaptain;
  final List<String> ledUnitNames;
  final bool isLast;
  const ProfileTeamCard({
    super.key,
    required this.team,
    required this.isCaptain,
    this.ledUnitNames = const [],
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = team.photoUrl;
    final roles = <String>[
      if (isCaptain) 'Kaptan',
      if (ledUnitNames.isNotEmpty)
        'Birim Sorumlusu: ${ledUnitNames.join(', ')}',
      if (!isCaptain && ledUnitNames.isEmpty) 'Üye',
    ];
    final roleLabel = roles.join(' • ');
    final roleColor = isCaptain
        ? AppColors.warning
        : (ledUnitNames.isNotEmpty
            ? AppColors.teamAccent
            : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surface3,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Icon(Icons.groups_outlined,
                    color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 12,
                    fontWeight: (isCaptain || ledUnitNames.isNotEmpty)
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (isCaptain)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              child: const Text('KAPTAN',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
          if (ledUnitNames.isNotEmpty)
            const SizedBox(width: 6),
          if (ledUnitNames.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.teamAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.teamAccent.withValues(alpha: 0.5)),
              ),
              child: const Text('SORUMLU',
                  style: TextStyle(
                      color: AppColors.teamAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

/// Row showing a single GLOBAL role (Admin / Yönetim Kurulu Başkanı /
/// Yönetim Kurulu Üyesi). Multiple rows render one after another so a user who
/// holds several global roles at once sees all of them listed.
class ProfileGlobalRoleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const ProfileGlobalRoleRow({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              label == 'Admin' ? 'SİSTEM YÖNETİCİSİ' : 'KURUL',
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
