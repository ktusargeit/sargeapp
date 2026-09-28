import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../admin/screens/user_title_management_sheet.dart';
import '../../admin/services/user_title_service.dart';
import '../models/team_models.dart';
import '../providers/team_providers.dart';

class TeamMembersTab extends ConsumerStatefulWidget {
  final ClubTeam team;
  final bool canManage;
  final bool isAdmin;
  const TeamMembersTab(
      {super.key,
      required this.team,
      required this.canManage,
      required this.isAdmin});

  @override
  ConsumerState<TeamMembersTab> createState() => _TeamMembersTabState();
}

class _TeamMembersTabState extends ConsumerState<TeamMembersTab> {
  String? _filterUnitId;

  /// A member matches the selected unit filter when they are that unit's lead
  /// (`units/{id}.unitLeadUid`) OR a member of it (`units/{id}.memberUids`).
  ///
  /// The legacy free-text `users/{uid}.unitResponsibilities` array was removed
  /// (AŞAMA 3): unit membership now lives in ONE source of truth — the `units`
  /// collection — so the filter reads the document directly.
  bool _matchesUnitFilter(AppUser user, List<Map<String, dynamic>>? units) {
    if (_filterUnitId == null) return true;
    if (units == null || units.isEmpty) return false;
    return units.any((u) {
      if (u['id'] != _filterUnitId) return false;
      final leadUid = u['unitLeadUid'];
      if (leadUid is String && leadUid == user.uid) return true;
      final memberUids = u['memberUids'];
      return memberUids is List && memberUids.contains(user.uid);
    });
  }

  void _showAddMemberDialog(BuildContext context) {
    final allUsers = ref.read(allUsersProvider).valueOrNull ?? [];
    final currentMemberIds = widget.team.memberIds;
    final availableUsers =
        allUsers.where((u) => !currentMemberIds.contains(u.uid)).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üye Ekle'),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: availableUsers.isEmpty
              ? Text('Eklenebilecek uygun kullanıcı yok.',
                  style: TextStyle(color: AppColors.textSecondary))
              : ListView.builder(
                  itemCount: availableUsers.length,
                  itemBuilder: (_, i) {
                    final user = availableUsers[i];
                    return ListTile(
                      leading: SafeAvatar(url: user.photoUrl, radius: 16),
                      title: Text(user.displayName, overflow: TextOverflow.ellipsis, maxLines: 1),
                      subtitle: Text(user.roleLabel,
                          style: const TextStyle(fontSize: 11)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await ref
                            .read(firestoreProvider)
                            .collection('teams')
                            .doc(widget.team.id)
                            .update({
                          'memberIds': FieldValue.arrayUnion([user.uid]),
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('${user.displayName} takıma eklendi.'),
                            backgroundColor: AppColors.success,
                          ));
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final unitsAsync = ref.watch(teamUnitsProvider(widget.team.id));

    return Column(
      children: [
        unitsAsync.when(
          data: (units) {
            if (units.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: DropdownButtonFormField<String?>(
                initialValue: _filterUnitId,
                isExpanded: true,
                isDense: true,
                dropdownColor: AppColors.surface2,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  labelText: 'Birim Filtresi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tümü'),
                  ),
                  ...units.map((u) => DropdownMenuItem(
                      value: u['id'] as String,
                      child: Text(u['name'] as String? ?? '', overflow: TextOverflow.ellipsis, maxLines: 1))),
                ],
                onChanged: (v) => setState(() => _filterUnitId = v),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        if (widget.canManage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddMemberDialog(context),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Üye Ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teamAccent,
                  side: BorderSide(
                      color: AppColors.teamAccent.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
        Expanded(
          child: usersAsync.when(
            data: (users) {
              final members = users
                  .where((u) => widget.team.memberIds.contains(u.uid))
                  .toList();
              if (members.isEmpty) {
                return Center(
                    child: Text('Bu takımda henüz üye yok.',
                        style: TextStyle(color: AppColors.textSecondary)));
              }
              return ListView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: members.asMap().entries.map((e) {
                        final user = e.value;
                        if (!_matchesUnitFilter(
                            user, unitsAsync.valueOrNull)) {
                          return const SizedBox.shrink();
                        }
                        return TeamMemberRow(
                          user: user,
                          team: widget.team,
                          canManage: widget.canManage,
                          isAdmin: widget.isAdmin,
                          isLast: e.key == members.length - 1,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }
}

class TeamMemberRow extends ConsumerWidget {
  final AppUser user;
  final ClubTeam team;
  final bool canManage;
  final bool isAdmin;
  final bool isLast;

  const TeamMemberRow({
    super.key,
    required this.user,
    required this.team,
    required this.canManage,
    required this.isAdmin,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        InkWell(
          onTap: () => context.push('/profile/${user.uid}'),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            child: Text(user.displayName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                          ),
                          if (team.leadUid == user.uid) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Text('KAPTAN',
                                  style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      if (user.roleLabel.isNotEmpty)
                        Text(user.roleLabel,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                if (canManage && user.uid != team.leadUid)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 18, color: AppColors.textSecondary),
                    onSelected: (action) =>
                        _handleAction(context, ref, action),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'make_captain',
                        child: Text('Kaptan Yap'),
                      ),
                      const PopupMenuItem(
                        value: 'make_unit_lead',
                        child: Text('Birim Sorumlusu Yap'),
                      ),
                      if (isAdmin)
                        const PopupMenuItem(
                          value: 'manage_titles',
                          child: Text('Ünvanları Yönet'),
                        ),
                      const PopupMenuItem(
                        value: 'remove_member',
                        child: Text('Takımdan Çıkar',
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
        ),
        if (!isLast) Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final firestore = ref.read(firestoreProvider);
    switch (action) {
      case 'make_captain':
        await firestore
            .collection('teams')
            .doc(team.id)
            .update({'leadUid': user.uid});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${user.displayName} takım kaptanı yapıldı.'),
              backgroundColor: AppColors.success));
        }
        break;
      case 'make_unit_lead':
        _showUnitPicker(context, ref);
        break;
      case 'manage_titles':
        showUserTitleManagementSheet(context, ref, user);
        break;
      case 'remove_member':
        await firestore.collection('teams').doc(team.id).update({
          'memberIds': FieldValue.arrayRemove([user.uid]),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${user.displayName} takımdan çıkarıldı.'),
              backgroundColor: AppColors.success));
        }
        break;
    }
  }

  void _showUnitPicker(BuildContext context, WidgetRef ref) {
    final units = ref.read(teamUnitsProvider(team.id)).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Text('Birim Sorumlusu Ata',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          size: 22, color: AppColors.teamAccent),
                      tooltip: 'Yeni Birim Ekle',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _addUnitDialog(context, ref);
                        if (context.mounted) {
                          _showUnitPicker(context, ref);
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (units.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Henüz birim eklenmemiş.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: units.map((u) {
                      final name = u['name'] as String? ?? '';
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined,
                            color: AppColors.teamOrange, size: 18),
                        title: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textPrimary)),
                        trailing: isAdmin
                            ? PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert,
                                    size: 16, color: AppColors.textSecondary),
                                onSelected: (action) {
                                  Navigator.pop(ctx);
                                  if (action == 'edit') {
                                    _editUnitDialog(context, ref,
                                        u['id'] as String, name);
                                  } else if (action == 'delete') {
                                    _deleteUnit(context, ref, u['id'] as String,
                                        name);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Düzenle')),
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Sil',
                                          style: TextStyle(
                                              color: AppColors.error))),
                                ],
                              )
                            : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          // AŞAMA 3: yazma kaynağı artık `units/{id}.unitLeadUid`.
                          // `users.unitResponsibilities` (serbest metin) kaldırıldı;
                          // birim sorumluluğu tek doğru kaynaktan (units koleksiyonu)
                          // okunur — team_screen filtresi ve profil görünümü de
                          // aynı alanı kullanır.
                          await ref
                              .read(firestoreProvider)
                              .collection('units')
                              .doc(u['id'] as String)
                              .update({'unitLeadUid': user.uid});
                          try {
                            await ref.read(userTitleServiceProvider).addTitle(
                                  uid: user.uid,
                                  titleType: TitleType.unitLead,
                                  unitName: name,
                                );
                          } catch (_) {
                            // Best-effort unvan senkronu; birim ataması yine geçerli.
                          }
                          ref.invalidate(teamUnitsProvider(team.id));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    '${user.displayName} → $name sorumlusu'),
                                backgroundColor: AppColors.success));
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addUnitDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Birim'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Birim adı'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref.read(firestoreProvider).collection('units').add({
                'name': ctrl.text.trim(),
                'teamId': team.id,
                'createdAt': FieldValue.serverTimestamp(),
              });
              ref.invalidate(teamUnitsProvider(team.id));
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _editUnitDialog(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final ctrl = TextEditingController(text: name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Birimi Düzenle'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref
                  .read(firestoreProvider)
                  .collection('units')
                  .doc(id)
                  .update({'name': ctrl.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _deleteUnit(
      BuildContext ctx, WidgetRef ref, String id, String name) {
    showDialog(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: const Text('Birimi Sil'),
        content: Text('"$name" silinecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref
                  .read(firestoreProvider)
                  .collection('units')
                  .doc(id)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}