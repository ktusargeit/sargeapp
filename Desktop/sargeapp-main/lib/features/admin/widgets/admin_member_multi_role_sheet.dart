import 'package:flutter/material.dart';
import 'package:sarge_depo_app/core/utils/snackbar_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../services/user_title_service.dart';
import 'admin_member_widgets.dart';

/// Multi-select editor for a user's roles.
///
/// A user can simultaneously hold:
///  * a global role (`users/{uid}.role`, e.g. admin),
///  * a team captain role (`teams/{id}.leadUid`),
///  * one or more unit-lead roles (`units/{id}.unitLeadUid`).
///
/// Each checkbox writes to its own authoritative Firestore field, so all
/// combinations are supported.
class AdminMemberMultiRoleSheet extends ConsumerStatefulWidget {
  final AppUser user;
  const AdminMemberMultiRoleSheet({super.key, required this.user});

  @override
  ConsumerState<AdminMemberMultiRoleSheet> createState() =>
      _AdminMemberMultiRoleSheetState();
}

class _AdminMemberMultiRoleSheetState
    extends ConsumerState<AdminMemberMultiRoleSheet> {
  final Set<String> _pendingTeamIds = {};
  final Set<String> _pendingUnitIds = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final unitsAsync = ref.watch(teamUnitListProvider);
    final teams = teamsAsync.valueOrNull ?? const <ClubTeam>[];
    final units = unitsAsync.valueOrNull ?? const <Map<String, dynamic>>[];

    final isAdmin = widget.user.role == 'admin' ||
        widget.user.activeTitles.any((t) => t.titleType == TitleType.admin);
    final isBoardPresident = widget.user.role == 'board_president' ||
        widget.user.activeTitles
            .any((t) => t.titleType == TitleType.boardPresident);
    final isBoardVicePresident = widget.user.role == 'board_vice_president' ||
        widget.user.activeTitles
            .any((t) => t.titleType == TitleType.boardVicePresident);
    final isBoardMember = widget.user.role == 'board_member' ||
        widget.user.activeTitles
            .any((t) => t.titleType == TitleType.boardMember);
    final captainTeamIds = teams
        .where((t) => t.leadUid == widget.user.uid)
        .map((t) => t.id)
        .toSet();
    final leadUnitIds = units
        .where((u) => u['unitLeadUid'] == widget.user.uid)
        .map((u) => u['id'] as String)
        .toSet();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rolleri Yönet — ${widget.user.displayName}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Global roller (Admin) ve Yönetim Kurulu rolleri bağımsız atanır. Ayrıca bir kullanıcı Takım Kaptanı ve Birim Sorumlusu olabilir.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (_busy)
                const LinearProgressIndicator(minHeight: 2)
              else
                const SizedBox(height: 2),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const AdminMemberSectionLabel('GLOBAL ROL'),
                    CheckboxListTile(
                      value: isAdmin,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.error,
                      title: const Text('Admin'),
                      subtitle: const Text('Sistem genelinde tam yetki'),
                      onChanged: _busy
                          ? null
                          : (v) => _setGlobalRole(
                                TitleType.admin,
                                v ?? false,
                                'Admin yapıldı.',
                                'Adminlik kaldırıldı.',
                              ),
                    ),
                    const Divider(height: 16),
                    const AdminMemberSectionLabel('YÖNETİM KURULU ROLLERİ'),
                    CheckboxListTile(
                      value: isBoardPresident,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.gold,
                      title: const Text('Başkan'),
                      subtitle: const Text(
                          'Tek aktif başkan olabilir — yeni başkan atanınca önceki emekliye ayrılır'),
                      onChanged: _busy
                          ? null
                          : (v) => _setGlobalRole(
                                TitleType.boardPresident,
                                v ?? false,
                                'Yönetim Kurulu Başkanı yapıldı.',
                                'Yönetim Kurulu Başkanlığı kaldırıldı.',
                              ),
                    ),
                    CheckboxListTile(
                      value: isBoardVicePresident,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.goldLight,
                      title: const Text('Başkan Yardımcısı'),
                      subtitle: const Text(
                          'Başkan ile aynı yetkilere sahip; birden fazla atanabilir'),
                      onChanged: _busy
                          ? null
                          : (v) => _setGlobalRole(
                                TitleType.boardVicePresident,
                                v ?? false,
                                'Yönetim Kurulu Başkan Yardımcısı yapıldı.',
                                'Yönetim Kurulu Başkan Yardımcılığı kaldırıldı.',
                              ),
                    ),
                    CheckboxListTile(
                      value: isBoardMember,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.info,
                      title: const Text('Üye'),
                      subtitle: const Text(
                          'Yönetim Kurulu Üyesi; birden fazla atanabilir'),
                      onChanged: _busy
                          ? null
                          : (v) => _setGlobalRole(
                                TitleType.boardMember,
                                v ?? false,
                                'Yönetim Kurulu Üyesi yapıldı.',
                                'Yönetim Kurulu Üyeliği kaldırıldı.',
                              ),
                    ),
                    const Divider(height: 16),
                    const AdminMemberSectionLabel('TAKIM KAPTANI'),
                    if (teams.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Takım bulunmuyor.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      )
                    else
                      ...teams.map((t) {
                        final checked = captainTeamIds.contains(t.id) ||
                            _pendingTeamIds.contains(t.id);
                        return CheckboxListTile(
                          value: checked,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.info,
                          title: Text(t.name),
                          subtitle: Text(
                            t.leadUid != null && t.leadUid != widget.user.uid
                                ? 'Mevcut kaptan değiştirilecek'
                                : 'Takım kaptanı',
                          ),
                          onChanged:
                              _busy ? null : (v) => _setCaptain(t, v ?? false),
                        );
                      }),
                    const Divider(height: 16),
                    const AdminMemberSectionLabel('BİRİM SORUMLUSU'),
                    if (units.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Birim bulunmuyor.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      )
                    else
                      ...units
                          .fold<Map<String, List<Map<String, dynamic>>>>(
                            {},
                            (acc, u) {
                              final teamId = u['teamId'] as String?;
                              if (teamId != null) {
                                acc.putIfAbsent(teamId, () => []).add(u);
                              }
                              return acc;
                            },
                          )
                          .entries
                          .expand((entry) {
                            final teamId = entry.key;
                            final teamName = teams
                                    .where((t) => t.id == teamId)
                                    .map((t) => t.name)
                                    .firstOrNull ??
                                'Bilinmeyen Takım';
                            final unitsInTeam = entry.value;
                            return [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 4),
                                child: Text(
                                  teamName,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              ...unitsInTeam.map((u) {
                                final name = u['name'] as String? ?? '';
                                final id = u['id'] as String;
                                final checked = leadUnitIds.contains(id) ||
                                    _pendingUnitIds.contains(id);
                                return CheckboxListTile(
                                  value: checked,
                                  contentPadding:
                                      const EdgeInsets.only(left: 16),
                                  activeColor: AppColors.warning,
                                  title: Text(name),
                                  subtitle: const Text('Birim sorumlusu'),
                                  onChanged: _busy
                                      ? null
                                      : (v) =>
                                          _setUnitLead(id, name, v ?? false),
                                );
                              }),
                            ];
                          }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sets a GLOBAL/board role (admin / Başkan / Başkan Yardımcısı / Üye) for the
  /// user.
  ///
  /// Every role is stored BOTH in the legacy single `role` field (so
  /// Firestore/Storage rules keep working) AND in the `titles` array (so the
  /// profile can display all roles simultaneously). Removing a role retires its
  /// title and lets `reconcileRole` promote the `role` field back to whatever
  /// privileged title the user still holds — meaning Admin + Yönetim Kurulu
  /// Üyesi can coexist without overwriting each other.
  ///
  /// AŞAMA 2.4 — `board_president` is EXCLUSIVE: granting the presidency goes
  /// through [UserTitleService.grantPresidentTitle], which retires the active
  /// president's title first (same pattern as team captaincy).
  Future<void> _setGlobalRole(
    String titleType,
    bool value,
    String successMessage,
    String removedMessage,
  ) async {
    setState(() => _busy = true);
    try {
      final titleService = ref.read(userTitleServiceProvider);
      if (value) {
        if (titleType == TitleType.boardPresident) {
          await titleService.grantPresidentTitle(uid: widget.user.uid);
        } else {
          await titleService.addTitle(
            uid: widget.user.uid,
            titleType: titleType,
          );
        }
      } else {
        await titleService.retireActiveTitleByType(
          uid: widget.user.uid,
          titleType: titleType,
        );
      }
      // Board titles (Başkan / Başkan Yardımcısı / Üye) map 1:1 to a role code,
      // so the legacy `role` field can be written directly. `reconcileRole`
      // below then re-promotes any remaining privileged active title.
      await ref.read(permissionServiceProvider).updateRole(
            targetUid: widget.user.uid,
            newRole: value ? titleType : 'member',
          );
      await titleService.reconcileRole(widget.user.uid);
      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            SnackBar(
              content: Text(value ? successMessage : removedMessage),
              backgroundColor: AppColors.success,
            ));
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            SnackBar(
              content: Text('Güncellenemedi: $e'),
              backgroundColor: AppColors.error,
            ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kaptanlık atama/kaldırma.
  ///
  /// `teams/{id}.leadUid` tek başına yetkiyi taşır, ancak profildeki Deneyim
  /// geçmişinin (`titles` array'i) sağlam kalması ve legacy `role` string'inin
  /// senkronlanması için eşzamanlı olarak `captain` ünvanı da eklenir/emekliye
  /// ayrılır (Çakışma #2).
  ///  * Kaptan yapılıyorsa → `titles` dizisine `isActive: true` bir `captain`
  ///    ünvanı eklenir.
  ///  * Kaptanlıktan alınıyorsa → mevcut aktif `captain` ünvanı silinmez,
  ///    `isActive: false` + `endDate` ile emekliye ayrılır (geçmiş korunur).
  Future<void> _setCaptain(ClubTeam team, bool value) async {
    setState(() {
      _busy = true;
      _pendingTeamIds.add(team.id);
    });
    try {
      await ref
          .read(firestoreProvider)
          .collection('teams')
          .doc(team.id)
          .update({
        'leadUid': value ? widget.user.uid : null,
      });

      final titleService = ref.read(userTitleServiceProvider);
      try {
        if (value) {
          await titleService.addTitle(
            uid: widget.user.uid,
            titleType: TitleType.captain,
            unitName: team.name,
          );
        } else {
          await titleService.retireCaptainTitle(
            uid: widget.user.uid,
            teamName: team.name,
          );
        }
      } catch (_) {
        // Best-effort: kaptanlık yazımı ünvan senkronundan bağımsız başarılıdır.
      }

      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            SnackBar(
              content: Text(value
                  ? '${widget.user.displayName}, ${team.name} kaptanı yapıldı.'
                  : 'Kaptanlık kaldırıldı.'),
              backgroundColor: AppColors.success,
            ));
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            SnackBar(
              content: Text('Güncellenemedi: $e'),
              backgroundColor: AppColors.error,
            ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingTeamIds.remove(team.id);
        });
      }
    }
  }

  Future<void> _setUnitLead(String unitId, String unitName, bool value) async {
    setState(() {
      _busy = true;
      _pendingUnitIds.add(unitId);
    });
    try {
      await ref
          .read(firestoreProvider)
          .collection('units')
          .doc(unitId)
          .update({'unitLeadUid': value ? widget.user.uid : null});

      final titleService = ref.read(userTitleServiceProvider);
      try {
        if (value) {
          await titleService.addTitle(
            uid: widget.user.uid,
            titleType: TitleType.unitLead,
            unitName: unitName,
          );
        } else {
          await titleService.retireUnitLeadTitle(
            uid: widget.user.uid,
            unitName: unitName,
          );
        }
      } catch (_) {}

      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            SnackBar(
              content: Text(value
                  ? '$unitName birim sorumlusu yapıldı.'
                  : 'Birim sorumluluğu kaldırıldı.'),
              backgroundColor: AppColors.success,
            ));
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            SnackBar(
              content: Text('Güncellenemedi: $e'),
              backgroundColor: AppColors.error,
            ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingUnitIds.remove(unitId);
        });
      }
    }
  }
}
