import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../admin_permissions.dart';
import 'admin_members_tab.dart';

class AdminTeamUnitTab extends ConsumerWidget {
  const AdminTeamUnitTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(adminCapabilitiesProvider);
    final teamsAsync = ref.watch(clubTeamsProvider);

    if (!caps.canManageTeams) {
      return Center(
        child: Text(
          'Takım/birim yönetimi yetkiniz yok.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return teamsAsync.when(
      data: (teams) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => showAdminTeamDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Takım'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sargeGold,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ),
            Expanded(
              child: teams.isEmpty
                  ? Center(
                      child: Text('Henüz takım yok.',
                          style:
                              TextStyle(color: AppColors.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: teams.length,
                      itemBuilder: (_, i) => AdminTeamCard(team: teams[i]),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Hata: $e',
              style: const TextStyle(color: AppColors.error))),
    );
  }
}

class AdminTeamCard extends ConsumerWidget {
  final ClubTeam team;
  const AdminTeamCard({super.key, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.teamAccent.withValues(alpha: 0.3)),
                image: team.photoUrl != null && team.photoUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(team.photoUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: team.photoUrl == null || team.photoUrl!.isEmpty
                  ? const Icon(Icons.groups_outlined,
                      size: 22, color: AppColors.teamAccent)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${team.memberIds.length} üye',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            AdminTag(
              text: team.isActive ? 'AKTİF' : 'PASİF',
              color: team.isActive ? AppColors.success : AppColors.error,
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: AppColors.textSecondary),
              onSelected: (action) {
                if (action == 'edit') showAdminTeamDialog(context, ref, team);
                if (action == 'units') showAdminUnitsDialog(context, ref, team);
                if (action == 'archive') toggleTeamArchive(context, ref, team);
                if (action == 'delete') confirmTeamDelete(context, ref, team);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                    value: 'units', child: Text('Birimleri Yönet')),
                const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(team.isArchived
                      ? 'Aktifleştir'
                      : 'Arşivle (Geçmiş Yap)'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Sil', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAdminTeamDialog(BuildContext context, WidgetRef ref,
    [ClubTeam? team]) async {
  final nameCtrl = TextEditingController(text: team?.name ?? '');
  final descCtrl = TextEditingController(text: team?.description ?? '');
  bool isActive = team?.isActive ?? true;
  final periodCtrl = TextEditingController(text: team?.period ?? '');
  final storyCtrl = TextEditingController(text: team?.story ?? '');
  bool saving = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(team == null ? 'Yeni Takım' : 'Takımı Düzenle'),
        content: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 12),
              TextField(
                controller: periodCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration:
                    const InputDecoration(labelText: 'Dönem (örn: 2024-2025)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storyCtrl,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Takım Hikayesi'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                subtitle:
                    const Text('Kapatılırsa takım "Geçmiş" olarak arşivlenir.'),
                value: isActive,
                activeThumbColor: AppColors.success,
                onChanged: (v) => setDialogState(() => isActive = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setDialogState(() => saving = true);
                    try {
                      if (team == null) {
                        final creatorUid =
                            ref.read(authStateProvider).valueOrNull?.uid;
                        await ref
                            .read(firestoreProvider)
                            .collection('teams')
                            .add({
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'isActive': isActive,
                          'status': isActive ? 'active' : 'archived',
                          'period': periodCtrl.text.trim().isEmpty
                              ? null
                              : periodCtrl.text.trim(),
                          'story': storyCtrl.text.trim().isEmpty
                              ? null
                              : storyCtrl.text.trim(),
                          'memberIds': <String>[
                            if (creatorUid != null) creatorUid
                          ],
                          'createdAt': FieldValue.serverTimestamp(),
                          'createdBy': creatorUid,
                          'leadUid': creatorUid,
                        });
                      } else {
                        await ref
                            .read(firestoreProvider)
                            .collection('teams')
                            .doc(team.id)
                            .update({
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'isActive': isActive,
                          'status': isActive ? 'active' : 'archived',
                          'period': periodCtrl.text.trim().isEmpty
                              ? null
                              : periodCtrl.text.trim(),
                          'story': storyCtrl.text.trim().isEmpty
                              ? null
                              : storyCtrl.text.trim(),
                        });
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setDialogState(() => saving = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: AppColors.error));
                      }
                    }
                  },
            child: Text(team == null ? 'Oluştur' : 'Kaydet'),
          ),
        ],
      ),
    ),
  );
}

Future<void> toggleTeamArchive(
    BuildContext context, WidgetRef ref, ClubTeam team) async {
  final targetArchived = !team.isArchived;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(targetArchived ? 'Takımı Arşivle' : 'Takımı Aktifleştir'),
      content: Text(
        targetArchived
            ? '"${team.name}" geçmiş takım olarak arşivlenecek. Verisi silinmez, sadece durumu değişir.'
            : '"${team.name}" tekrar aktif takım yapılacak.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                targetArchived ? AppColors.warning : AppColors.success,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(targetArchived ? 'Arşivle' : 'Aktifleştir'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  final status = targetArchived ? 'archived' : 'active';
  await runOperationWithFeedback(
    context: context,
    loadingMessage: 'Güncelleniyor...',
    successMessage: targetArchived
        ? 'Takım arşivlendi (geçmiş).'
        : 'Takım aktifleştirildi.',
    operation: () => ref
        .read(firestoreProvider)
        .collection('teams')
        .doc(team.id)
        .update({'status': status, 'isActive': status == 'active'}),
  );
}

Future<void> confirmTeamDelete(
    BuildContext context, WidgetRef ref, ClubTeam team) async {
  final confirmed = await showDialog<bool>(
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
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  await runDeleteWithFeedback(
    context: context,
    successMessage: 'Takım başarıyla silindi.',
    operation: () => ref
        .read(firestoreProvider)
        .collection('teams')
        .doc(team.id)
        .delete(),
  );
}

Future<void> showAdminUnitsDialog(
    BuildContext context, WidgetRef ref, ClubTeam team) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AdminUnitManagementDialog(team: team),
  );
}

class AdminUnitManagementDialog extends ConsumerStatefulWidget {
  final ClubTeam team;
  const AdminUnitManagementDialog({super.key, required this.team});

  @override
  ConsumerState<AdminUnitManagementDialog> createState() =>
      _AdminUnitManagementDialogState();
}

class _AdminUnitManagementDialogState
    extends ConsumerState<AdminUnitManagementDialog> {
  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(teamUnitsProvider(widget.team.id));

    return AlertDialog(
      title: Text('Birimler — ${widget.team.name}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: unitsAsync.when(
          data: (units) => units.isEmpty
              ? Center(
                  child: Text('Bu takımda henüz birim yok.',
                      style: TextStyle(color: AppColors.textSecondary)))
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
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            onPressed: () => _editUnit(id, name),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: AppColors.error),
                            onPressed: () => _deleteUnit(id, name),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _addUnit,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Birim Ekle'),
        ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat')),
      ],
    );
  }

  void _addUnit() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<String>(
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
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (ok == null || ok.isEmpty) return;
    await ref.read(firestoreProvider).collection('units').add({
      'name': ok,
      'teamId': widget.team.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    ref.invalidate(teamUnitsProvider(widget.team.id));
  }

  void _editUnit(String id, String name) async {
    final ctrl = TextEditingController(text: name);
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Birimi Düzenle'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok == null || ok.isEmpty) return;
    await ref.read(firestoreProvider).collection('units').doc(id).update({
      'name': ok,
    });
    ref.invalidate(teamUnitsProvider(widget.team.id));
  }

  void _deleteUnit(String id, String name) async {
    final confirmed = await showDialog<bool>(
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
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await runDeleteWithFeedback(
      context: context,
      successMessage: 'Birim başarıyla silindi.',
      operation: () async {
        await ref.read(firestoreProvider).collection('units').doc(id).delete();
        ref.invalidate(teamUnitsProvider(widget.team.id));
      },
    );
  }
}