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
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/platform_image.dart';
import '../../notifications/providers/notification_providers.dart';
import '../models/team_models.dart';
import '../providers/team_providers.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});
  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final currentUser = ref.watch(currentAppUserProvider).value;
    final teamsAsync = ref.watch(clubTeamsProvider);

    return Scaffold(
      backgroundColor: AppColors.teamBg,
      appBar: AppBar(
        title: const Text('Takımım'),
        backgroundColor: AppColors.teamBg,
        actions: [
          if (isAdmin)
            IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.teamOrange), onPressed: () => _showCreateTeamDialog(context)),
        ],
        bottom: isAdmin ? TabBar(controller: _tabCtrl, indicatorColor: AppColors.teamAccent, labelColor: AppColors.textPrimary, unselectedLabelColor: AppColors.textSecondary, tabs: const [Tab(text: 'Takımlar'), Tab(text: 'Başvurular')]) : null,
      ),
      body: isAdmin ? TabBarView(controller: _tabCtrl, children: [_buildTeamList(teamsAsync, isAdmin, currentUser), _ApplicationsTab()]) : _buildTeamList(teamsAsync, isAdmin, currentUser),
    );
  }

  Widget _buildTeamList(AsyncValue<List<ClubTeam>> teamsAsync, bool isAdmin, AppUser? currentUser) {
    return teamsAsync.when(
      data: (teams) {
        List<ClubTeam> visible;
        if (isAdmin) { visible = teams; } else { visible = teams.where((t) => t.memberIds.contains(currentUser?.uid)).toList(); }
        if (visible.isEmpty && !isAdmin && currentUser != null) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
             Icon(Icons.groups_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
             Text('Henüz bir takıma dahil değilsiniz.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: () => _showApplyDialog(context, teams), icon: const Icon(Icons.send_outlined, size: 18), label: const Text('Takıma Başvur'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.teamOrange)),
          ]));
        }
        if (visible.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
             Icon(Icons.groups_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(isAdmin ? 'Henüz takım oluşturulmadı.' : 'Henüz bir takıma dahil değilsiniz.', style:  TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            if (isAdmin) ...[const SizedBox(height: 16), ElevatedButton.icon(onPressed: () => _showCreateTeamDialog(context), icon: const Icon(Icons.add, size: 18), label: const Text('Takım Oluştur'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.teamOrange))],
          ]));
        }
        return RefreshIndicator(color: AppColors.teamOrange, onRefresh: () async => ref.refresh(clubTeamsProvider.future), child: ListView.builder(padding: const EdgeInsets.all(AppConstants.spacingMd), itemCount: visible.length, itemBuilder: (context, i) {
          final team = visible[i];
          return Card(color: AppColors.surface.withValues(alpha: 0.9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd), side:  BorderSide(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(borderRadius: BorderRadius.circular(AppConstants.radiusMd), onTap: () => context.push('/team/${team.id}'),
                child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.teamOrange.withValues(alpha: 0.3)), image: team.photoUrl != null && team.photoUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(team.photoUrl!), fit: BoxFit.cover) : null), child: team.photoUrl == null || team.photoUrl!.isEmpty ? const Icon(Icons.groups_outlined, size: 28, color: AppColors.teamOrange) : null),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(team.name, style:  TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (team.description.isNotEmpty) Text(team.description, maxLines: 2, overflow: TextOverflow.ellipsis, style:  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(children: [
                       Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary), const SizedBox(width: 4),
                      Text('${team.memberIds.length} üye', style:  TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 16),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: team.isActive ? AppColors.success.withValues(alpha: 0.12) : AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: team.isActive ? AppColors.success.withValues(alpha: 0.4) : AppColors.error.withValues(alpha: 0.4))), child: Text(team.isActive ? 'AKTİF' : 'PASİF', style: TextStyle(color: team.isActive ? AppColors.success : AppColors.error, fontSize: 10, fontWeight: FontWeight.w700))),
                    ]),
                  ])),
                   Icon(Icons.chevron_right, color: AppColors.border),
                ])),
              ),
              _TeamUnitsSection(team: team),
            ]),
          );
        }));
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.teamOrange)),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
    );
  }

  void _showCreateTeamDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    PickedImage? pickedImage;
    bool uploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Takım Oluştur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo picker
                GestureDetector(
                  onTap: () async {
                    final img = await PickedImage.pick(ImageSource.gallery);
                    if (img != null) setDialogState(() => pickedImage = img);
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd - 1),
                            child: PlatformImageFile(
                              bytes: pickedImage!.bytes,
                              file: pickedImage!.dartFile,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        :  Icon(Icons.add_a_photo_outlined,
                            size: 32, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style:  TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'Takım Adı *',
                      hintText: 'Örn: Elektronik Harp'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style:  TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      hintText: 'Takım hakkında kısa bilgi'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: uploading ? null : () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: uploading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setDialogState(() => uploading = true);
                      try {
                        String? photoUrl;
                        if (pickedImage != null) {
                          final tempId =
                              DateTime.now().millisecondsSinceEpoch.toString();
                          final storageRef = FirebaseStorage.instance
                              .ref()
                              .child('team_photos/$tempId.jpg');
                          if (kIsWeb && pickedImage!.bytes != null) {
                            await storageRef.putData(pickedImage!.bytes!);
                          } else if (pickedImage!.dartFile != null) {
                            await storageRef.putFile(pickedImage!.dartFile!);
                          }
                          photoUrl = await storageRef.getDownloadURL();
                        }
                        final creatorUid = ref.read(authStateProvider).value?.uid;
                        await ref
                            .read(firestoreProvider)
                            .collection('teams')
                            .add({
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'photoUrl': photoUrl,
                          'isActive': true,
                          'memberIds': [creatorUid].whereType<String>().toList(),
                          'createdAt': FieldValue.serverTimestamp(),
                          'createdBy': creatorUid,
                          'leadUid': creatorUid, // creator is the initial captain
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDialogState(() => uploading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                                content: Text('Hata: $e'),
                                backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: AppColors.teamOrange))
                  : const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApplyDialog(BuildContext context, List<ClubTeam> teams) async {
    final currentUser = ref.read(currentAppUserProvider).value;
    if (currentUser == null) return;

    // Check for ANY pending application first (spam prevention)
    final pendingSnap = await ref.read(firestoreProvider)
        .collection('teamApplications')
        .where('applicantUid', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (pendingSnap.docs.isNotEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zaten bekleyen bir başvurunuz var. Lütfen sonuçlanmasını bekleyin.'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Filter teams: not already a member
    final availableTeams = teams.where((t) {
      if (t.memberIds.contains(currentUser.uid)) return false;
      return true;
    }).toList();

    if (!context.mounted) return;
    var applying = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Takıma Başvur'),
            content: SizedBox(
              width: double.maxFinite,
              child: applying
                  ?  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.teamOrange),
                            const SizedBox(height: 16),
                            Text('Başvurunuz gönderiliyor...',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : availableTeams.isEmpty
                      ?  Text('Başvurabileceğiniz takım yok.',
                          style: TextStyle(color: AppColors.textSecondary))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableTeams.length,
                          itemBuilder: (_, i) {
                            final team = availableTeams[i];
                            return ListTile(
                              leading: const Icon(Icons.groups_outlined,
                                  color: AppColors.teamOrange),
                              title: Text(team.name),
                              subtitle: Text('${team.memberIds.length} üye',
                                  style:  TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                              onTap: () async {
                                setDialogState(() => applying = true);
                                try {
                                  // Check if already a member (auto-approve)
                                  if (team.memberIds.contains(currentUser.uid)) {
                                    await ref.read(firestoreProvider)
                                        .collection('teamApplications')
                                        .add({
                                      'teamId': team.id,
                                      'teamName': team.name,
                                      'applicantUid': currentUser.uid,
                                      'applicantName': currentUser.displayName,
                                      'status': 'approved',
                                      'appliedAt': FieldValue.serverTimestamp(),
                                    });
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${team.name} takımına zaten üyesiniz, başvurunuz otomatik onaylandı.'),
                                          backgroundColor: AppColors.success,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // Submit application
                                  await ref.read(firestoreProvider)
                                      .collection('teamApplications')
                                      .add({
                                    'teamId': team.id,
                                    'teamName': team.name,
                                    'applicantUid': currentUser.uid,
                                    'applicantName': currentUser.displayName,
                                    'status': 'pending',
                                    'appliedAt': FieldValue.serverTimestamp(),
                                  });

                                  // Send notification to admins and unit_leads
                                  final usersSnap = await ref.read(firestoreProvider)
                                      .collection('users')
                                      .where('role', whereIn: ['admin', 'unit_lead'])
                                      .get();
                                  final notifService = ref.read(notificationServiceProvider);
                                  for (final userDoc in usersSnap.docs) {
                                    await notifService.send(
                                      recipientId: userDoc.id,
                                      title: 'Yeni Takım Başvurusu',
                                      body: '${currentUser.displayName}, ${team.name} takımına başvurdu.',
                                      type: 'team_application',
                                      relatedId: team.id,
                                    );
                                  }

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${team.name} takımına başvurunuz başarıyla gönderildi!'),
                                        backgroundColor: AppColors.success,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => applying = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
            ),
            actions: applying
                ? []
                : [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Kapat')),
                  ],
          );
        },
      ),
    );
  }

}

/// Inline display of a team's "birimler" (units) inside the Takımım list.
///
/// Uses the same stream/data source as the admin/team-detail unit lists, but
/// shows only the units that belong to this specific team (each team's unit
/// system is independent).
class _TeamUnitsSection extends ConsumerWidget {
  final ClubTeam team;
  const _TeamUnitsSection({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(teamUnitsListProvider(team.id));
    return unitsAsync.when(
      data: (units) {
        if (units.isEmpty) {
          return  Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text('Bu takımda henüz birim tanımlanmamış.',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: units.map((u) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.teamAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.teamAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined,
                        size: 13, color: AppColors.teamAccent),
                    const SizedBox(width: 5),
                    Text(
                      u.name,
                      style: const TextStyle(
                          color: AppColors.teamAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    if (u.memberUids.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Text('${u.memberUids.length}',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11)),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPLICATIONS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ApplicationsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(teamApplicationsProvider);
    return appsAsync.when(
      data: (apps) {
        final pending = apps.where((a) => a['status'] == 'pending').toList();
        if (pending.isEmpty) return  Center(child: Text('Bekleyen başvuru yok.', style: TextStyle(color: AppColors.textSecondary)));
        return ListView.builder(padding: const EdgeInsets.all(AppConstants.spacingMd), itemCount: pending.length, itemBuilder: (_, i) {
          final app = pending[i];
          return Card(color: AppColors.surface, margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app['applicantName'] as String? ?? '', style:  TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            Text('Takım: ${app['teamName'] ?? ''}', style:  TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(onPressed: () async {
                final teamId = app['teamId'] as String?; final uid = app['applicantUid'] as String?;
                if (teamId != null && uid != null) await ref.read(firestoreProvider).collection('teams').doc(teamId).update({'memberIds': FieldValue.arrayUnion([uid])});
                await ref.read(firestoreProvider).collection('teamApplications').doc(app['id'] as String).update({'status': 'approved'});
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onaylandı.'), backgroundColor: AppColors.success));
              }, icon: const Icon(Icons.check, size: 16, color: AppColors.success), label: const Text('Onayla', style: TextStyle(color: AppColors.success))),
              TextButton.icon(onPressed: () async {
                await ref.read(firestoreProvider).collection('teamApplications').doc(app['id'] as String).update({'status': 'rejected'});
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reddedildi.'), backgroundColor: AppColors.warning));
              }, icon: const Icon(Icons.close, size: 16, color: AppColors.error), label: const Text('Reddet', style: TextStyle(color: AppColors.error))),
            ]),
          ])));
        });
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIT MANAGEMENT DIALOG (team-scoped)
// ─────────────────────────────────────────────────────────────────────────────

class _UnitManagementDialog extends ConsumerStatefulWidget {
  const _UnitManagementDialog();

  @override
  ConsumerState<_UnitManagementDialog> createState() => _UnitManagementDialogState();
}

class _UnitManagementDialogState extends ConsumerState<_UnitManagementDialog> {
  String? _selectedTeamId;

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final unitsAsync = _selectedTeamId != null
        ? ref.watch(teamUnitsProvider(_selectedTeamId!))
        : null;

    return AlertDialog(
      title: const Text('Birim Yönetimi'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Team selector
            teamsAsync.when(
              data: (teams) => DropdownButtonFormField<String>(
                dropdownColor: AppColors.surface2,
                style:  TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Takım Seçin *',
                  hintText: 'Önce takım seçin',
                ),
                initialValue: _selectedTeamId,
                items: teams
                    .map((t) => DropdownMenuItem(
                        value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTeamId = v),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Hata: $e'),
            ),
            const SizedBox(height: 8),
            if (_selectedTeamId != null) ...[
              Row(
                children: [
                   Text('Mevcut Birimler',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addUnit,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ekle'),
                  ),
                ],
              ),
               Divider(color: AppColors.border),
              Expanded(
                child: unitsAsync != null
                    ? unitsAsync.when(
                        data: (units) => units.isEmpty
                            ?  Center(
                                child: Text('Bu takımda henüz birim yok.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: units.length,
                                itemBuilder: (_, i) {
                                  final u = units[i];
                                  final name = u['name'] as String? ?? '';
                                  final id = u['id'] as String;
                                  return ListTile(
                                    dense: true,
                                    title: Text(name),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 16),
                                            onPressed: () =>
                                                _editUnit(id, name)),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: AppColors.error),
                                          onPressed: () =>
                                              _deleteUnit(id, name),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Hata: $e')),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat')),
      ],
    );
  }

  void _addUnit() {
    if (_selectedTeamId == null) return;
    final ctrl = TextEditingController();
    showDialog(
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
                'teamId': _selectedTeamId,
                'createdAt': FieldValue.serverTimestamp(),
              });
              // Invalidate provider so the unit list refreshes
              ref.invalidate(teamUnitsProvider(_selectedTeamId!));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _editUnit(String id, String name) {
    final ctrl = TextEditingController(text: name);
    showDialog(
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

  void _deleteUnit(String id, String name) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Birimi Sil'),
        content: Text('"$name" silinecek.'),
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
    ).then((confirmed) async {
      if (confirmed != true) return;
      if (!mounted) return;
      await runDeleteWithFeedback(
        context: context,
        successMessage: 'Birim başarıyla silindi.',
        operation: () async {
          await ref
              .read(firestoreProvider)
              .collection('units')
              .doc(id)
              .delete();
          ref.invalidate(teamUnitsProvider(_selectedTeamId!));
        },
      );
    });
  }
}