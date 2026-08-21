import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../admin_permissions.dart';
import '../widgets/admin_member_multi_role_sheet.dart';
import '../widgets/admin_member_widgets.dart';
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
          child:
              Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
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
        AdminMemberHeaderCard(user: user),
        const SizedBox(height: 16),

        // ── Ünvanlar ────────────────────────────────────────────────────────
        AdminMemberSectionTitle(
          icon: Icons.workspace_premium_outlined,
          title: 'Ünvanlar',
          trailing: caps.canManageTitles
              ? TextButton.icon(
                  onPressed: () =>
                      showUserTitleManagementSheet(context, ref, user),
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
        const AdminMemberSectionTitle(
            icon: Icons.badge_outlined, title: 'Rol'),
        const SizedBox(height: 8),
        if (caps.canChangeRoles)
          AdminMemberRoleEditor(
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
            label: const Text(
                'Çoklu Rol Yönetimi (Admin + Kaptan + Birim Sorumlusu)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.sargeGold,
              side: BorderSide(
                  color: AppColors.sargeGold.withValues(alpha: 0.5)),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // ── Puan ────────────────────────────────────────────────────────────
        const AdminMemberSectionTitle(
            icon: Icons.stars_outlined, title: 'Puan'),
        const SizedBox(height: 8),
        AdminMemberPointsEditor(user: user, canEdit: caps.canEditPoints),
        const SizedBox(height: 20),

        // ── Hesap (tehlike bölgesi) ─────────────────────────────────────────
        const AdminMemberSectionTitle(
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
          content: Text(targetActive
              ? 'Hesap askıya alındı.'
              : 'Hesap aktifleştirildi.'),
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
      builder: (_) => AdminMemberMultiRoleSheet(user: user),
    );
  }
}