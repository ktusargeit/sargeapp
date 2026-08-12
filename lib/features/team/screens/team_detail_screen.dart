import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../providers/team_providers.dart';
import '../models/team_models.dart';

class TeamDetailScreen extends ConsumerStatefulWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});
  @override
  ConsumerState<TeamDetailScreen> createState() =>
      _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final appUser = ref.watch(currentAppUserProvider).value;
    final isAdmin = appUser?.isAdmin ?? false;
    final currentUid = appUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.teamBg,
      appBar: AppBar(
        title: const Text('Takım Detayı'),
        backgroundColor: AppColors.surface,
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textSecondary),
              onSelected: (action) {
                final teams =
                    ref.read(clubTeamsProvider).value ?? [];
                ClubTeam? team;
                try {
                  team = teams
                      .firstWhere((t) => t.id == widget.teamId);
                } catch (_) {}
                if (team == null) return;
                if (action == 'edit') _showEditDialog(team);
                if (action == 'delete') _confirmDelete(team);
                if (action == 'photo') _pickTeamPhoto(team);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                    value: 'photo',
                    child: Text('Fotoğraf Değiştir')),
                PopupMenuItem(
                    value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Sil',
                        style:
                            TextStyle(color: AppColors.error))),
              ],
            ),
        ],
      ),
      body: teamsAsync.when(
        data: (teams) {
          ClubTeam? team;
          try {
            team = teams
                .firstWhere((t) => t.id == widget.teamId);
          } catch (_) {}
          if (team == null)
            return const Center(
                child: Text('Takım bulunamadı.',
                    style: TextStyle(
                        color: AppColors.textSecondary)));

          // Determine captain status
          final isCaptain =
              currentUid != null && team.leadUid == currentUid;
          final canManage =
              isAdmin || isCaptain;

          return Column(
            children: [
              Container(
                color: AppColors.surface,
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (team.photoUrl != null &&
                        team.photoUrl!.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(14),
                          child: SafeNetworkImage(
                            url: team.photoUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            team.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: team.isActive
                                ? AppColors.success
                                    .withValues(alpha: 0.12)
                                : AppColors.error
                                    .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(6),
                            border: Border.all(
                              color: team.isActive
                                  ? AppColors.success
                                      .withValues(alpha: 0.4)
                                  : AppColors.error
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            team.isActive
                                ? 'AKTİF'
                                : 'PASİF',
                            style: TextStyle(
                              color: team.isActive
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Captain row
                    if (team.hasLead)
                      _CaptainRow(team: team),
                    if (team.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        team.description,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(
                  height: 1, color: AppColors.border),
              Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.teamAccent,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor:
                      AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Puan Tablosu'),
                    Tab(text: 'Üyeler'),
                  ],
                ),
              ),
              const Divider(
                  height: 1, color: AppColors.border),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ScoreboardTab(team: team),
                    _MembersTab(
                        team: team,
                        canManage: canManage,
                        isAdmin: isAdmin),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.teamAccent)),
        error: (e, _) => Center(
            child: Text('Yüklenemedi: $e',
                style: const TextStyle(
                    color: AppColors.error))),
      ),
    );
  }

  Future<void> _pickTeamPhoto(ClubTeam team) async {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.teamAccent),
              title: const Text('Galeriden Seç'),
              onTap: () =>
                  Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.teamAccent),
              title: const Text('Kameradan Çek'),
              onTap: () =>
                  Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final image = await PickedImage.pick(picked);
      if (image == null) return;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('team_photos/${team.id}.jpg');
      if (kIsWeb && image.bytes != null) {
        await storageRef.putData(image.bytes!);
      } else if (image.dartFile != null) {
        await storageRef.putFile(image.dartFile!);
      }
      final url = await storageRef.getDownloadURL();
      await ref
          .read(firestoreProvider)
          .collection('teams')
          .doc(team.id)
          .update({'photoUrl': url});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Takım fotoğrafı güncellendi.'),
                backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Fotoğraf yüklenemedi: $e'),
            backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showEditDialog(ClubTeam team) {
    final nameCtrl =
        TextEditingController(text: team.name);
    final descCtrl =
        TextEditingController(text: team.description);
    bool saving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Takımı Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(
                    color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Takım Adı *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: const TextStyle(
                    color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Açıklama'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty)
                        return;
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(firestoreProvider)
                            .collection('teams')
                            .doc(team.id)
                            .update({
                          'name': nameCtrl.text.trim(),
                          'description':
                              descCtrl.text.trim(),
                        });
                        if (ctx.mounted)
                          Navigator.pop(ctx);
                        if (mounted)
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text(
                                      'Takım güncellendi.'),
                                  backgroundColor:
                                      AppColors.success));
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                                  content: Text(
                                      'Güncellenemedi: $e'),
                                  backgroundColor:
                                      AppColors.error));
                      }
                    },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ClubTeam team) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takımı Sil'),
        content: Text(
            '"${team.name}" silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(firestoreProvider)
                    .collection('teams')
                    .doc(team.id)
                    .delete();
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(
                          content:
                              Text('Takım silindi.'),
                          backgroundColor:
                              AppColors.success));
                  context.pop();
                }
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(
                          content:
                              Text('Silinemedi: $e'),
                          backgroundColor:
                              AppColors.error));
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

/// Shows captain name with badge in team header.
class _CaptainRow extends ConsumerWidget {
  final ClubTeam team;
  const _CaptainRow({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captainAsync =
        ref.watch(userProfileProvider(team.leadUid!));
    return captainAsync.when(
      data: (captain) => Row(
        children: [
          const Icon(Icons.star,
              size: 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            captain?.displayName ?? 'Bilinmiyor',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
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
      ),
      loading: () => const SizedBox(
          height: 18,
          child: Center(
              child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1)))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ScoreboardTab extends ConsumerWidget {
  final ClubTeam team;
  const _ScoreboardTab({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    return usersAsync.when(
      data: (users) {
        final members = users
            .where((u) => team.memberIds.contains(u.uid))
            .toList();
        if (members.isEmpty)
          return const Center(
              child: Text('Bu takımda henüz üye yok.',
                  style: TextStyle(
                      color: AppColors.textSecondary)));
        members.sort(
            (a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));
        return ListView.separated(
          padding:
              const EdgeInsets.all(AppConstants.spacingMd),
          itemCount: members.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final user = members[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i < 3
                            ? [
                                const Color(0xFFFFD700),
                                const Color(0xFFC0C0C0),
                                const Color(0xFFCD7F32)
                              ][i]
                            : AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context
                        .push('/profile/${user.uid}'),
                    child: SafeAvatar(
                        url: user.photoUrl, radius: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                  user.displayName,
                                  style: const TextStyle(
                                      color: AppColors
                                          .textPrimary,
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w600)),
                            ),
                            if (team.leadUid ==
                                user.uid) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                        horizontal: 6,
                                        vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withValues(
                                          alpha: 0.15),
                                  borderRadius:
                                      BorderRadius
                                          .circular(3),
                                  border: Border.all(
                                      color: AppColors
                                          .warning
                                          .withValues(
                                              alpha: 0.4)),
                                ),
                                child: const Text(
                                  'KAPTAN',
                                  style: TextStyle(
                                      color: AppColors
                                          .warning,
                                      fontSize: 9,
                                      fontWeight:
                                          FontWeight
                                              .w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(user.roleLabel,
                            style: const TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.teamAccent
                          .withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.teamAccent
                              .withValues(alpha: 0.4)),
                    ),
                    child: Text('${user.weeklyPoints} puan',
                        style: const TextStyle(
                            color: AppColors.teamAccent,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

class _MembersTab extends ConsumerStatefulWidget {
  final ClubTeam team;
  final bool canManage;
  final bool isAdmin;
  const _MembersTab(
      {required this.team,
      required this.canManage,
      required this.isAdmin});

  @override
  ConsumerState<_MembersTab> createState() =>
      _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  String? _filterUnitId;

  void _showAddMemberDialog(BuildContext context) {
    final allUsers = ref.read(allUsersProvider).valueOrNull ?? [];
    final currentMemberIds = widget.team.memberIds;
    // Filter users not already in team
    final availableUsers =
        allUsers.where((u) => !currentMemberIds.contains(u.uid)).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üye Ekle'),
        content: SizedBox(
          width: double.maxFinite,
          child: availableUsers.isEmpty
              ? const Text('Eklenebilecek uygun kullanıcı yok.',
                  style: TextStyle(color: AppColors.textSecondary))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableUsers.length,
                  itemBuilder: (_, i) {
                    final user = availableUsers[i];
                    return ListTile(
                      leading: SafeAvatar(
                          url: user.photoUrl, radius: 16),
                      title: Text(user.displayName),
                      subtitle: Text(user.roleLabel,
                          style: const TextStyle(fontSize: 11)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await ref
                            .read(firestoreProvider)
                            .collection('teams')
                            .doc(widget.team.id)
                            .update({
                          'memberIds':
                              FieldValue.arrayUnion([user.uid]),
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                '${user.displayName} takıma eklendi.'),
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
    final unitsAsync =
        ref.watch(teamUnitsProvider(widget.team.id));

    return Column(
      children: [
        // Unit filter
        unitsAsync.when(
          data: (units) {
            if (units.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.fromLTRB(
                  16, 8, 16, 4),
              child: DropdownButtonFormField<String?>(
                value: _filterUnitId,
                isDense: true,
                dropdownColor: AppColors.surface2,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  labelText: 'Birim Filtresi',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.border),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tümü'),
                  ),
                  ...units.map((u) => DropdownMenuItem(
                      value: u['id'] as String,
                      child: Text(
                          u['name'] as String? ?? ''))),
                ],
                onChanged: (v) =>
                    setState(() => _filterUnitId = v),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // Add member button (for managers)
        if (widget.canManage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _showAddMemberDialog(context),
                icon: const Icon(Icons.person_add_outlined,
                    size: 18),
                label: const Text('Üye Ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teamAccent,
                  side: BorderSide(
                      color: AppColors.teamAccent
                          .withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
        // Members list
        Expanded(
          child: usersAsync.when(
            data: (users) {
              final members = users
                  .where((u) =>
                      widget.team.memberIds.contains(u.uid))
                  .toList();
              if (members.isEmpty)
                return const Center(
                    child: Text(
                        'Bu takımda henüz üye yok.',
                        style: TextStyle(
                            color:
                                AppColors.textSecondary)));
              if (members.length <= 1) {
                // Nothing to manage
              }
              return ListView(
                padding: const EdgeInsets.all(
                    AppConstants.spacingMd),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.border),
                    ),
                    child: Column(
                      children: members
                          .asMap()
                          .entries
                          .map((e) {
                        final user = e.value;
                        // If unit filter is active, skip non-matching
                        if (_filterUnitId != null &&
                            !(user.unitResponsibilities
                                .any((r) {
                              final matchingUnit =
                                  unitsAsync.valueOrNull
                                          ?.firstWhere(
                                        (u) =>
                                            u['name'] == r,
                                        orElse: () => {
                                          'id': ''
                                        },
                                      ) ??
                                      {};
                              return matchingUnit['id'] ==
                                  _filterUnitId;
                            }))) {
                          return const SizedBox.shrink();
                        }
                        return _MemberRow(
                          user: user,
                          team: widget.team,
                          canManage: widget.canManage,
                          isAdmin: widget.isAdmin,
                          isLast: e.key ==
                              members.length - 1,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends ConsumerWidget {
  final AppUser user;
  final ClubTeam team;
  final bool canManage;
  final bool isAdmin;
  final bool isLast;

  const _MemberRow({
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
          onTap: () =>
              context.push('/profile/${user.uid}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SafeAvatar(url: user.photoUrl, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(user.displayName,
                                style: const TextStyle(
                                    color: AppColors
                                        .textPrimary,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w500)),
                          ),
                          if (team.leadUid == user.uid) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.warning
                                    .withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(3),
                                border: Border.all(
                                    color: AppColors.warning
                                        .withValues(
                                            alpha: 0.4)),
                              ),
                              child: const Text('KAPTAN',
                                  style: TextStyle(
                                      color:
                                          AppColors.warning,
                                      fontSize: 9,
                                      fontWeight:
                                          FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      if (user.unitResponsibilities.isNotEmpty)
                        Text(
                          user.unitResponsibilities.join(', '),
                          style: const TextStyle(
                              color:
                                  AppColors.textSecondary,
                              fontSize: 11),
                        ),
                      if (user.roleLabel.isNotEmpty)
                        Text(user.roleLabel,
                            style: const TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 11)),
                    ],
                  ),
                ),
                if (canManage && user.uid != team.leadUid)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 18,
                        color: AppColors.textSecondary),
                    onSelected: (action) =>
                        _handleAction(context, ref, action),
                    itemBuilder: (ctx) => [
                      if (isAdmin ||
                          team.leadUid == user.uid ||
                          true)
                        const PopupMenuItem(
                          value: 'make_captain',
                          child: Text('Kaptan Yap'),
                        ),
                      const PopupMenuItem(
                        value: 'make_unit_lead',
                        child: Text('Birim Sorumlusu Yap'),
                      ),
                      const PopupMenuItem(
                        value: 'remove_member',
                        child: Text('Takımdan Çıkar',
                            style: TextStyle(
                                color: AppColors.error)),
                      ),
                    ],
                  )
                else
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.border),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref,
      String action) async {
    final firestore = ref.read(firestoreProvider);
    switch (action) {
      case 'make_captain':
        await firestore
            .collection('teams')
            .doc(team.id)
            .update({'leadUid': user.uid});
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${user.displayName} takım kaptanı yapıldı.'),
              backgroundColor: AppColors.success));
      case 'make_unit_lead':
        _showUnitPicker(context, ref);
      case 'remove_member':
        await firestore
            .collection('teams')
            .doc(team.id)
            .update({
          'memberIds': FieldValue.arrayRemove([user.uid]),
        });
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${user.displayName} takımdan çıkarıldı.'),
              backgroundColor: AppColors.success));
    }
  }

  void _showUnitPicker(
      BuildContext context, WidgetRef ref) {
    final units =
        ref.read(teamUnitsProvider(team.id)).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    16, 12, 8, 0),
                child: Row(
                  children: [
                    const Text('Birim Sorumlusu Ata',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                AppColors.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          size: 22,
                          color: AppColors.teamAccent),
                      tooltip: 'Yeni Birim Ekle',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _addUnitDialog(context, ref);
                        // Re-show the picker after creating
                        if (context.mounted) {
                          _showUnitPicker(context, ref);
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (units.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henüz birim eklenmemiş.',
                      style: TextStyle(
                          color:
                              AppColors.textSecondary)),
                )
              else
                ...units.map((u) {
                  final name =
                      u['name'] as String? ?? '';
                  return ListTile(
                    leading: const Icon(
                        Icons.folder_outlined,
                        color: AppColors.teamOrange,
                        size: 18),
                    title: Text(name,
                        style: const TextStyle(
                            color:
                                AppColors.textPrimary)),
                    trailing: isAdmin
                        ? PopupMenuButton<String>(
                            icon: const Icon(
                                Icons.more_vert,
                                size: 16,
                                color: AppColors
                                    .textSecondary),
                            onSelected: (action) {
                              Navigator.pop(ctx);
                              if (action == 'edit') {
                                _editUnitDialog(
                                    context,
                                    ref,
                                    u['id'] as String,
                                    name);
                              } else if (action ==
                                  'delete') {
                                _deleteUnit(
                                    context,
                                    ref,
                                    u['id'] as String,
                                    name);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'edit',
                                  child: Text(
                                      'Düzenle')),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Sil',
                                      style: TextStyle(
                                          color: AppColors
                                              .error))),
                            ],
                          )
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final userRef = ref
                          .read(firestoreProvider)
                          .collection('users')
                          .doc(user.uid);
                      final userDoc =
                          await userRef.get();
                      final current =
                          (userDoc.data()?[
                                  'unitResponsibilities']
                              as List?) ??
                              <String>[];
                      final updated = <String>{
                        ...current
                            .map((e) => e.toString()),
                        name
                      }.toList();
                      await userRef.update({
                        'unitResponsibilities': updated
                      });
                      if (context.mounted)
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                                content: Text(
                                    '${user.displayName} → $name sorumlusu'),
                                backgroundColor:
                                    AppColors.success));
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addUnitDialog(
      BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Birim'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(hintText: 'Birim adı'),
        ),
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
                  .add({
                'name': ctrl.text.trim(),
                'teamId': team.id,
                'createdAt':
                    FieldValue.serverTimestamp(),
              });
              // Invalidate provider so the stream refreshes
              ref.invalidate(teamUnitsProvider(team.id));
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _editUnitDialog(BuildContext context,
      WidgetRef ref, String id, String name) async {
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

  void _deleteUnit(BuildContext ctx,
      WidgetRef ref, String id, String name) {
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
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