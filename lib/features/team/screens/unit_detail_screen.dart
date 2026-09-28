import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../models/team_models.dart';
import '../providers/team_providers.dart';

/// Detail + management screen for a team-scoped unit ("birim").
///
/// Normal members can only view. The team captain or an admin can create
/// (elsewhere), edit, delete, add/remove members, and assign/change the unit
/// lead. Assigning a lead auto-grants a `unit_lead` title via [UnitService].
class UnitDetailScreen extends ConsumerStatefulWidget {
  final String unitId;
  final ClubTeam team;

  const UnitDetailScreen({
    super.key,
    required this.unitId,
    required this.team,
  });

  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isAdmin = ref.watch(isAdminProvider);
    final canManage =
        isAdmin || (widget.team.leadUid == currentUid);

    final unitAsync = ref.watch(unitDocProvider(widget.unitId));

    return Scaffold(
      backgroundColor: AppColors.teamBg,
      appBar: AppBar(
        title: Text(unitAsync.valueOrNull?.name ?? 'Birim'),
        backgroundColor: AppColors.surface,
        actions: [
          if (canManage && unitAsync.valueOrNull != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: AppColors.textSecondary),
              onSelected: (action) {
                final unit = unitAsync.valueOrNull!;
                if (action == 'edit') _editUnit(unit);
                if (action == 'delete') _deleteUnit(unit);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Sil',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
      body: unitAsync.when(
        data: (unit) {
          if (unit == null) {
            return Center(
              child: Text('Birim bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return _buildBody(context, unit, canManage);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Yüklenemedi: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TeamUnit unit, bool canManage) {
    final membersAsync = ref.watch(unitMembersProvider(unit.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card
        Container(
          width: double.infinity,
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      unit.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.teamAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.teamAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${unit.memberUids.length} üye',
                      style: const TextStyle(
                        color: AppColors.teamAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (unit.description != null &&
                  unit.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  unit.description!,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'Birim Sorumlusu',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _UnitLeadName(uid: unit.unitLeadUid),
                  ),
                  if (canManage)
                    TextButton.icon(
                      onPressed: () => _assignLead(unit),
                      icon: const Icon(Icons.manage_accounts_outlined,
                          size: 16),
                      label: const Text('Ata/Değiştir'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                'Birim Üyeleri',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (canManage)
                TextButton.icon(
                  onPressed: () => _addMember(unit),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Üye Ekle'),
                ),
            ],
          ),
        ),

        Expanded(
          child: membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return Center(
                  child: Text('Bu birimde henüz üye yok.',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: members
                          .asMap()
                          .entries
                          .map((e) {
                            final user = e.value;
                            final isLead = unit.unitLeadUid == user.uid;
                            return _UnitMemberRow(
                              user: user,
                              isLead: isLead,
                              canManage: canManage,
                              unit: unit,
                              isLast: e.key == members.length - 1,
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _editUnit(TeamUnit unit) async {
    final nameCtrl = TextEditingController(text: unit.name);
    final descCtrl = TextEditingController(text: unit.description ?? '');
    final service = ref.read(unitServiceProvider);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Birimi Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Birim Adı *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Açıklama'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await service.updateUnit(
                  unitId: unit.id,
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Güncellenemedi: $e'),
                      backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUnit(TeamUnit unit) async {
    final hasMembers = unit.memberUids.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Birimi Sil'),
        content: Text(
          hasMembers
              ? '"${unit.name}" silinecek. Bu birimde ${unit.memberUids.length} üye var — üyeler takımdan silinmez, yalnızca bu birimden ayrılır. Onaylıyor musunuz?'
              : '"${unit.name}" silinecek. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final service = ref.read(unitServiceProvider);
    final ok = await runDeleteWithFeedback(
      context: context,
      successMessage: 'Birim başarıyla silindi.',
      operation: () async {
        // Retire the lead's title first (if any), then delete the unit.
        if (unit.hasLead) {
          await service.setUnitLead(unit: unit, newLeadUid: null);
        }
        await service.deleteUnit(unit.id);
      },
    );
    if (ok && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _addMember(TeamUnit unit) async {
    final teamMembers = ref.read(teamMembersProvider(widget.team.id)).valueOrNull ?? [];
    final available =
        teamMembers.where((u) => !unit.memberUids.contains(u.uid)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Eklenebilecek takım üyesi yok.'),
          backgroundColor: AppColors.warning));
      return;
    }

    final selectedUid = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Birime Üye Ekle',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: available
                    .map((u) => ListTile(
                          leading: SafeAvatar(url: u.photoUrl, radius: 16),
                          title: Text(u.displayName),
                          subtitle:
                              Text(u.roleLabel, style: const TextStyle(fontSize: 11)),
                          onTap: () => Navigator.pop(ctx, u.uid),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedUid == null) return;
    try {
      await ref.read(unitServiceProvider).addMember(unit.id, selectedUid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Eklenemedi: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _assignLead(TeamUnit unit) async {
    final members =
        ref.read(unitMembersProvider(unit.id)).valueOrNull ?? [];

    final selectedUid = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Birim Sorumlusu Ata',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, ''), // empty = clear
                    child: const Text('Boş Bırak'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: members
                    .map((u) => ListTile(
                          leading: SafeAvatar(url: u.photoUrl, radius: 16),
                          title: Text(u.displayName),
                          trailing: unit.unitLeadUid == u.uid
                              ? const Icon(Icons.check_circle,
                                  color: AppColors.success, size: 18)
                              : null,
                          onTap: () => Navigator.pop(ctx, u.uid),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );

    // null = dismissed without action; '' = clear lead.
    if (selectedUid == null) return;

    final newLead = (selectedUid.isEmpty) ? null : selectedUid;
    try {
      await ref
          .read(unitServiceProvider)
          .setUnitLead(unit: unit, newLeadUid: newLead);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(newLead == null
                ? 'Birim sorumlusu kaldırıldı.'
                : 'Birim sorumlusu güncellendi.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _removeMember(TeamUnit unit, AppUser user) async {
    final isLead = unit.unitLeadUid == user.uid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: Text(
          isLead
              ? '"${user.displayName}" bu birimin sorumlusu. Birimden çıkarılırsa sorumluluk da kaldırılacak.'
              : '"${user.displayName}" birimden çıkarılacak. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final service = ref.read(unitServiceProvider);
      if (isLead) {
        await service.setUnitLead(unit: unit, newLeadUid: null);
      }
      await service.removeMember(unit.id, user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${user.displayName} birimden çıkarıldı.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Çıkarılamadı: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }
}

class _UnitLeadName extends ConsumerWidget {
  final String? uid;
  const _UnitLeadName({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uid == null || uid!.isEmpty) {
      return Text(
        'Atanmamış',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final profileAsync = ref.watch(userProfileProvider(uid!));
    return profileAsync.when(
      data: (user) => Text(
        user?.displayName ?? 'Bilinmiyor',
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      loading: () => const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => Text(
        'Bilinmiyor',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _UnitMemberRow extends ConsumerWidget {
  final AppUser user;
  final bool isLead;
  final bool canManage;
  final TeamUnit unit;
  final bool isLast;

  const _UnitMemberRow({
    required this.user,
    required this.isLead,
    required this.canManage,
    required this.unit,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SafeAvatar(url: user.photoUrl, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isLead) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'SORUMLU',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      user.roleLabel,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      size: 18, color: AppColors.textSecondary),
                  onSelected: (action) => _handleAction(context, ref, action),
                  itemBuilder: (ctx) => [
                    if (!isLead)
                      const PopupMenuItem(
                        value: 'make_lead',
                        child: Text('Sorumlu Yap'),
                      ),
                    if (isLead)
                      const PopupMenuItem(
                        value: 'clear_lead',
                        child: Text('Sorumluluktan Al'),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Birimden Çıkar',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                )
              else
                Icon(Icons.chevron_right,
                    size: 18, color: AppColors.border),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final service = ref.read(unitServiceProvider);
    try {
      switch (action) {
        case 'make_lead':
          await service.setUnitLead(unit: unit, newLeadUid: user.uid);
          break;
        case 'clear_lead':
          await service.setUnitLead(unit: unit, newLeadUid: null);
          break;
        case 'remove':
          // Delegate to the screen-level remove flow (handles lead clearing).
          final screen = context.findAncestorStateOfType<_UnitDetailScreenState>();
          if (screen != null) {
            await screen._removeMember(unit, user);
          } else {
            await service.removeMember(unit.id, user.uid);
          }
          return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Güncellendi.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }
}