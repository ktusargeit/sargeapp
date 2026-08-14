import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../admin_permissions.dart';
import '../services/user_title_service.dart';
import 'user_title_management_sheet.dart';

/// Detail / management screen for a single member.
///
/// Consolidates the per-member admin actions in one place:
///  * title add / retire / remove (via [UserTitleService])
///  * role change (admin yap / çıkar + full role dropdown)
///  * manual points add / remove (with an explanation)
///  * suspend / delete account (with confirmation dialogs)
class AdminMemberDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  final AppUser? initialUser;

  const AdminMemberDetailScreen({
    super.key,
    required this.userId,
    this.initialUser,
  });

  @override
  ConsumerState<AdminMemberDetailScreen> createState() =>
      _AdminMemberDetailScreenState();
}

class _AdminMemberDetailScreenState
    extends ConsumerState<AdminMemberDetailScreen> {
  String? _savingRole;

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(adminCapabilitiesProvider);
    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final user = profileAsync.valueOrNull ?? widget.initialUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(user?.displayName ?? 'Üye Yönetimi'),
        backgroundColor: AppColors.surface,
      ),
      body: profileAsync.when(
        data: (u) {
          if (u == null) {
            return Center(
              child: Text(
                'Kullanıcı bulunamadı.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return _buildBody(context, u, caps);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppUser user,
    AdminCapabilities caps,
  ) {
    final activeTitles = user.activeTitles;
    final formerTitles = user.formerTitles;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(user: user),
        const SizedBox(height: 16),

        // ── Ünvanlar ────────────────────────────────────────────────────────
        _SectionTitle(
          icon: Icons.workspace_premium_outlined,
          title: 'Ünvanlar',
          trailing: caps.canManageTitles
              ? TextButton.icon(
                  onPressed: () => showUserTitleManagementSheet(
                      context, ref, user),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Yönet'),
                )
              : null,
        ),
        if (activeTitles.isEmpty)
          _muted('Güncel ünvan yok.')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: activeTitles
                .map((t) => _titleBadge(t, isActive: true))
                .toList(),
          ),
        if (formerTitles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Geçmiş ünvanlar',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: formerTitles
                .map((t) => _titleBadge(t, isActive: false))
                .toList(),
          ),
        ],
        const SizedBox(height: 20),

        // ── Rol ─────────────────────────────────────────────────────────────
        const _SectionTitle(icon: Icons.badge_outlined, title: 'Rol'),
        const SizedBox(height: 8),
        if (caps.canChangeRoles)
          _RoleEditor(
            user: user,
            saving: _savingRole == user.uid,
            onChanged: (newRole) => _changeRole(user, newRole),
          )
        else
          _muted('Rol değiştirme yetkisi yalnızca admin rolündedir.'),
        if (caps.canChangeRoles) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openMultiRoleSheet(user),
            icon: const Icon(Icons.checklist, size: 18),
            label: const Text('Çoklu Rol Yönetimi (Admin + Kaptan + Birim Sorumlusu)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.sargeGold,
              side: BorderSide(
                  color: AppColors.sargeGold.withValues(alpha: 0.5)),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // ── Puan ────────────────────────────────────────────────────────────
        const _SectionTitle(icon: Icons.stars_outlined, title: 'Puan'),
        const SizedBox(height: 8),
        _PointsEditor(user: user, canEdit: caps.canEditPoints),
        const SizedBox(height: 20),

        // ── Hesap (tehlike bölgesi) ─────────────────────────────────────────
        const _SectionTitle(
          icon: Icons.shield_outlined,
          title: 'Hesap Yönetimi',
          color: AppColors.error,
        ),
        if (caps.canSuspendMembers || caps.canDeleteMembers) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tehlike bölgesi',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                if (caps.canSuspendMembers)
                  OutlinedButton.icon(
                    onPressed: () => _toggleSuspend(user),
                    icon: Icon(
                      user.isSuspended
                          ? Icons.lock_open_outlined
                          : Icons.block_outlined,
                      size: 18,
                    ),
                    label: Text(user.isSuspended
                        ? 'Hesabı Tekrar Aktifleştir'
                        : 'Hesabı Askıya Al'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(
                          color: AppColors.warning.withValues(alpha: 0.5)),
                    ),
                  ),
                if (caps.canSuspendMembers) const SizedBox(height: 8),
                if (caps.canDeleteMembers)
                  OutlinedButton.icon(
                    onPressed: () => _deleteAccount(user),
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text('Hesabı Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5)),
                    ),
                  ),
              ],
            ),
          ),
        ] else
          _muted('Hesap silme/askıya alma yetkisi yalnızca admin rolündedir.'),
      ],
    );
  }

  Widget _titleBadge(UserTitle t, {required bool isActive}) {
    final color = isActive ? AppColors.sargeGold : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        t.displayLabel,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _muted(String text) {
    return Text(
      text,
      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _changeRole(AppUser user, String newRole) async {
    if (user.role == newRole) return;
    setState(() => _savingRole = user.uid);
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
      if (mounted) setState(() => _savingRole = null);
    }
  }

  Future<void> _toggleSuspend(AppUser user) async {
    final targetActive = !user.isSuspended;
    final confirmed = await _confirm(
      title: targetActive ? 'Hesabı Askıya Al' : 'Hesabı Aktifleştir',
      message: targetActive
          ? '"${user.displayName}" hesabını askıya almak istediğinize emin misiniz?'
          : '"${user.displayName}" hesabını tekrar aktifleştirmek istediğinize emin misiniz?',
      confirmLabel: targetActive ? 'Askıya Al' : 'Aktifleştir',
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .update({'isSuspended': targetActive});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(targetActive ? 'Hesap askıya alındı.' : 'Hesap aktifleştirildi.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('İşlem başarısız: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _deleteAccount(AppUser user) async {
    final confirmed = await _confirm(
      title: 'Hesabı Sil',
      message:
          '"${user.displayName}" hesabı kalıcı olarak silinecek. Bu işlem geri alınamaz!',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final ok = await runDeleteWithFeedback(
      context: context,
      successMessage: '${user.displayName} hesabı başarıyla silindi.',
      operation: () => ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .delete(),
    );
    if (ok && mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? AppColors.error : null,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _openMultiRoleSheet(AppUser user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _MultiRoleSheet(user: user),
    );
  }
}

/// Multi-select editor for a user's roles.
///
/// A user can simultaneously hold:
///  * a global role (`users/{uid}.role`, e.g. admin),
///  * a team captain role (`teams/{id}.leadUid`),
///  * one or more unit-lead roles (`units/{id}.unitLeadUid`).
///
/// Each checkbox writes to its own authoritative Firestore field, so all
/// combinations are supported.
class _MultiRoleSheet extends ConsumerStatefulWidget {
  final AppUser user;
  const _MultiRoleSheet({required this.user});

  @override
  ConsumerState<_MultiRoleSheet> createState() => _MultiRoleSheetState();
}

class _MultiRoleSheetState extends ConsumerState<_MultiRoleSheet> {
  final Set<String> _pendingTeamIds = {};
  final Set<String> _pendingUnitIds = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final unitsAsync = ref.watch(teamUnitListProvider);
    final teams = teamsAsync.valueOrNull ?? const <ClubTeam>[];
    final units = unitsAsync.valueOrNull ?? const <Map<String, dynamic>>[];

    final isAdmin = widget.user.role == 'admin';
    final captainTeamIds =
        teams.where((t) => t.leadUid == widget.user.uid).map((t) => t.id).toSet();
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
                'Bir kullanıcı aynı anda Admin, Takım Kaptanı ve Birim Sorumlusu olabilir.',
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
                    // ── Global role ──────────────────────────────────────────
                    const _SectionLabel('GLOBAL ROL'),
                    CheckboxListTile(
                      value: isAdmin,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.error,
                      title: const Text('Admin'),
                      subtitle: const Text('Sistem genelinde tam yetki'),
                      onChanged: _busy
                          ? null
                          : (v) => _setAdmin(v ?? false),
                    ),
                    const Divider(height: 16),
                    // ── Team captain ──────────────────────────────────────────
                    const _SectionLabel('TAKIM KAPTANI'),
                    if (teams.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Takım bulunmuyor.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      )
                    else
                      ...teams.map((t) {
                        final checked =
                            captainTeamIds.contains(t.id) ||
                                _pendingTeamIds.contains(t.id);
                        return CheckboxListTile(
                          value: checked,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.info,
                          title: Text(t.name),
                          subtitle: Text(
                            t.leadUid != null &&
                                    t.leadUid != widget.user.uid
                                ? 'Mevcut kaptan değiştirilecek'
                                : 'Takım kaptanı',
                          ),
                          onChanged: _busy
                              ? null
                              : (v) => _setCaptain(t, v ?? false),
                        );
                      }),
                    const Divider(height: 16),
                    // ── Unit lead ────────────────────────────────────────────
                    const _SectionLabel('BİRİM SORUMLUSU'),
                    if (units.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Birim bulunmuyor.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      )
                    else
                      ...units.map((u) {
                        final name = u['name'] as String? ?? '';
                        final id = u['id'] as String;
                        final teamName = teams
                            .where((t) => t.id == u['teamId'])
                            .map((t) => t.name)
                            .firstOrNull;
                        final checked = leadUnitIds.contains(id) ||
                            _pendingUnitIds.contains(id);
                        return CheckboxListTile(
                          value: checked,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.warning,
                          title: Text(name),
                          subtitle: Text(teamName ?? 'Birim sorumlusu'),
                          onChanged: _busy
                              ? null
                              : (v) => _setUnitLead(id, name, v ?? false),
                        );
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

  Future<void> _setAdmin(bool value) async {
    setState(() => _busy = true);
    try {
      await ref.read(permissionServiceProvider).updateRole(
            targetUid: widget.user.uid,
            newRole: value ? 'admin' : 'member',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value ? 'Admin yapıldı.' : 'Adminlik kaldırıldı.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Güncellenemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCaptain(ClubTeam team, bool value) async {
    setState(() {
      _busy = true;
      _pendingTeamIds.add(team.id);
    });
    try {
      await ref.read(firestoreProvider).collection('teams').doc(team.id).update({
        'leadUid': value ? widget.user.uid : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value
              ? '${widget.user.displayName}, ${team.name} kaptanı yapıldı.'
              : 'Kaptanlık kaldırıldı.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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

      // Keep the unit_lead title in sync (best effort).
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value
              ? '$unitName birim sorumlusu yapıldı.'
              : 'Birim sorumluluğu kaldırıldı.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final AppUser user;
  const _HeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeAvatar(url: user.photoUrl, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (user.isSuspended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'ASKIDA',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoChip(
                      Icons.badge_outlined,
                      roleLabel(user.role),
                      AppColors.panelBlue,
                    ),
                    const SizedBox(width: 8),
                    if (user.department != null && user.department!.isNotEmpty)
                      _infoChip(
                        Icons.apartment_outlined,
                        user.department!,
                        AppColors.teamAccent,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.stars, size: 16, color: AppColors.sargeGold),
                    const SizedBox(width: 4),
                    Text(
                      '${user.points} puan',
                      style: const TextStyle(
                        color: AppColors.sargeGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${user.weeklyPoints} haftalık',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: c,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _RoleEditor extends ConsumerWidget {
  final AppUser user;
  final bool saving;
  final ValueChanged<String> onChanged;

  const _RoleEditor({
    required this.user,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (saving) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButton<String>(
            value: user.role,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: AppColors.surface2,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            items: allRoles
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(roleLabel(r)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (user.role != 'admin')
              OutlinedButton.icon(
                onPressed: () => onChanged('admin'),
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: const Text('Admin Yap'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sargeGold,
                  side: BorderSide(
                      color: AppColors.sargeGold.withValues(alpha: 0.5)),
                ),
              ),
            if (user.role == 'admin')
              OutlinedButton.icon(
                onPressed: () => onChanged('member'),
                icon: const Icon(Icons.arrow_downward, size: 16),
                label: const Text('Adminlıktan Çıkar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(
                      color: AppColors.warning.withValues(alpha: 0.5)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PointsEditor extends ConsumerStatefulWidget {
  final AppUser user;
  final bool canEdit;
  const _PointsEditor({required this.user, required this.canEdit});

  @override
  ConsumerState<_PointsEditor> createState() => _PointsEditorState();
}

class _PointsEditorState extends ConsumerState<_PointsEditor> {
  bool _busy = false;

  Future<void> _editPoints({required bool isAdd}) async {
    final amountCtrl = TextEditingController(text: '1');
    final amount = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? 'Puan Ekle' : 'Puan Düş'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.user.displayName} — mevcut puan: ${widget.user.points}.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isAdd ? 'Eklenecek puan' : 'Düşülecek puan',
                hintText: 'Miktar girin (pozitif tam sayı)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, amountCtrl.text.trim()),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );

    if (amount == null) return;
    final parsed = int.tryParse(amount) ?? 0;
    if (parsed <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Geçerli bir puan miktarı girin.'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    final delta = isAdd ? parsed : -parsed;

    setState(() => _busy = true);
    try {
      final currentUid = ref.read(authStateProvider).value?.uid;
      // Record the adjustment without a description. History logging is
      // best-effort; a unit_lead can still adjust the raw point total.
      try {
        await ref.read(firestoreProvider).collection('points_history').add({
          'targetUid': widget.user.uid,
          'targetName': widget.user.displayName,
          'delta': delta,
          'changedBy': currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Ignore: history logging is secondary to the actual point update.
      }

      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.user.uid)
          .update({'points': FieldValue.increment(delta)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAdd
              ? '$delta puan eklendi.'
              : '${delta.abs()} puan düşüldü.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Puan güncellenemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canEdit) {
      return Text(
        'Puan düzenleme yetkisi admin ve birim sorumlusu rollerindedir.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _editPoints(isAdd: true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Puan Ekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              side: BorderSide(
                  color: AppColors.success.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _editPoints(isAdd: false),
            icon: const Icon(Icons.remove, size: 18),
            label: const Text('Puan Düş'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: BorderSide(
                  color: AppColors.warning.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}