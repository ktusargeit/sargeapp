import 'package:sarge_depo_app/core/services/imgbb_service.dart';
import 'package:sarge_depo_app/core/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../providers/team_providers.dart';
import '../models/team_models.dart';
import '../widgets/team_members_tab.dart';
import '../widgets/team_scoreboard_tab.dart';
import '../widgets/team_units_tab.dart';

class TeamDetailScreen extends ConsumerStatefulWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});
  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
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
              icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (action) {
                // `.valueOrNull` — `.value` rethrows on a provider error and
                // would cancel this Scaffold's build.
                final teams = ref.read(clubTeamsProvider).valueOrNull ?? [];
                ClubTeam? team;
                try {
                  team = teams.firstWhere((t) => t.id == widget.teamId);
                } catch (_) {}
                if (team == null) return;
                if (action == 'edit') _showEditDialog(team);
                if (action == 'delete') _confirmDelete(team);
                if (action == 'photo') _pickTeamPhoto(team);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'photo', child: Text('Fotoğraf Değiştir')),
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Sil', style: TextStyle(color: AppColors.error))),
              ],
            ),
        ],
      ),
      body: teamsAsync.when(
        data: (teams) {
          ClubTeam? team;
          try {
            team = teams.firstWhere((t) => t.id == widget.teamId);
          } catch (_) {}
          if (team == null) {
            return Center(
                child: Text('Takım bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }

          final isCaptain = currentUid != null && team.leadUid == currentUid;
          final canManage = isAdmin || isCaptain;

          return Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (team.photoUrl != null && team.photoUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
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
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: team.isActive
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: team.isActive
                                  ? AppColors.success.withValues(alpha: 0.4)
                                  : AppColors.error.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            team.isActive ? 'AKTİF' : 'PASİF',
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
                    if (team.hasLead) TeamCaptainRow(team: team),
                    if (team.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        team.description,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.teamAccent,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Puan Tablosu'),
                    Tab(text: 'Birimler'),
                    Tab(text: 'Üyeler'),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    TeamScoreboardTab(team: team),
                    TeamUnitsTab(team: team, canManage: canManage),
                    TeamMembersTab(
                        team: team, canManage: canManage, isAdmin: isAdmin),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.teamAccent)),
        error: (e, _) => Center(
            child: Text('Yüklenemedi: $e',
                style: const TextStyle(color: AppColors.error))),
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
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.teamAccent),
              title: const Text('Kameradan Çek'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      final image = await PickedImage.pick(picked);
      if (image == null) return;
      
      var uploadBytes = image.bytes;
      if (uploadBytes == null && image.dartFile != null) {
        uploadBytes = await image.dartFile!.readAsBytes();
      }
      if (uploadBytes == null) throw Exception('No image data');
      
      final url = await ImgbbService.uploadImage(uploadBytes);
      if (url == null) throw Exception('Image upload failed');
      
      await ref
          .read(firestoreProvider)
          .collection('teams')
          .doc(team.id)
          .update({'photoUrl': url});
      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            const SnackBar(
                content: Text('Takım fotoğrafı güncellendi.'),
                backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            SnackBar(
                content: Text('Fotoğraf yüklenemedi: $e'),
                backgroundColor: AppColors.error));
      }
    }
  }

  void _showEditDialog(ClubTeam team) {
    final nameCtrl = TextEditingController(text: team.name);
    final descCtrl = TextEditingController(text: team.description);
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
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Takım Adı *'),
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
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(firestoreProvider)
                            .collection('teams')
                            .doc(team.id)
                            .update({
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          TopSnackBar.showSnackBar(
                              context,
                              const SnackBar(
                                  content: Text('Takım güncellendi.'),
                                  backgroundColor: AppColors.success));
                        }
                      } catch (e) {
                        if (mounted) {
                          TopSnackBar.showSnackBar(
                              context,
                              SnackBar(
                                  content: Text('Güncellenemedi: $e'),
                                  backgroundColor: AppColors.error));
                        }
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
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takımı Sil'),
        content: Text('"${team.name}" silinecek. Onaylıyor musunuz?'),
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
      final ok = await runDeleteWithFeedback(
        context: context,
        successMessage: 'Takım başarıyla silindi.',
        operation: () => ref
            .read(firestoreProvider)
            .collection('teams')
            .doc(team.id)
            .delete(),
      );
      if (ok && mounted) context.pop();
    });
  }
}

/// Shows captain name with badge in team header.
class TeamCaptainRow extends ConsumerWidget {
  final ClubTeam team;
  const TeamCaptainRow({super.key, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captainAsync = ref.watch(userProfileProvider(team.leadUid!));
    return captainAsync.when(
      data: (captain) => Row(
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            captain?.displayName ?? 'Bilinmiyor',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
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
                  child: CircularProgressIndicator(strokeWidth: 1)))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
