import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_user.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../tasks/models/task_models.dart';
import '../../tasks/providers/task_providers.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../admin_permissions.dart';

/// Comprehensive "Admin Kontrol Paneli".
///
/// Tabbed structure:
///  * Üye Yönetimi    — searchable member list + detailed per-member management
///  * Takım & Birim   — team CRUD + unit management
///  * Başvurular      — centralized team-application review
///  * Bekleyen İşler  — pending action summary cards
///  * İstatistikler   — high-level system statistics
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(adminCapabilitiesProvider);
    if (!caps.canViewAdminPanel) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Yönetim')),
        body: Center(
          child: Text('Bu bölüme erişim yetkiniz yok.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Kontrol Paneli'),
        backgroundColor: AppColors.surface,
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.sargeGold,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.sargeGold,
              tabs: const [
                Tab(text: 'Üyeler'),
                Tab(text: 'Takım & Birim'),
                Tab(text: 'Başvurular'),
                Tab(text: 'Bekleyen İşler'),
                Tab(text: 'İstatistikler'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _MemberManagementTab(),
                  _TeamManagementTab(),
                  _ApplicationsTab(),
                  _PendingContentTab(),
                  _SystemStatsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// a) ÜYE YÖNETİMİ
// ─────────────────────────────────────────────────────────────────────────────

class _MemberManagementTab extends ConsumerStatefulWidget {
  const _MemberManagementTab();

  @override
  ConsumerState<_MemberManagementTab> createState() =>
      _MemberManagementTabState();
}

class _MemberManagementTabState extends ConsumerState<_MemberManagementTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'İsme göre ara...',
              hintStyle:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search, size: 18, color: AppColors.textSecondary),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: usersAsync.when(
            data: (users) {
              final filtered = _query.isEmpty
                  ? users
                  : users
                      .where((u) =>
                          u.displayName.toLowerCase().contains(_query) ||
                          u.email.toLowerCase().contains(_query))
                      .toList();
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final user = filtered[i];
                  return _MemberCard(user: user);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Hata: $e',
                  style: const TextStyle(color: AppColors.error)),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends ConsumerWidget {
  final AppUser user;
  const _MemberCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTitles = user.activeTitles;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/admin/members/${user.uid}', extra: user),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeAvatar(url: user.photoUrl, radius: 20),
              const SizedBox(width: 12),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (user.isSuspended)
                          const _Tag(text: 'ASKIDA', color: AppColors.error),
                        _Tag(
                          text: roleLabel(user.role),
                          color: AppColors.panelBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (user.department != null &&
                            user.department!.isNotEmpty)
                          Text(
                            user.department!,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          '${user.points} puan',
                          style: const TextStyle(
                            color: AppColors.sargeGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (activeTitles.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: activeTitles
                            .map((t) => _Tag(
                                  text: t.displayLabel,
                                  color: AppColors.sargeGold,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// b) TAKIM & BİRİM YÖNETİMİ
// ─────────────────────────────────────────────────────────────────────────────

class _TeamManagementTab extends ConsumerWidget {
  const _TeamManagementTab();

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
                  onPressed: () => _showTeamDialog(context, ref),
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
                      itemBuilder: (_, i) => _TeamCard(team: teams[i]),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
    );
  }
}

class _TeamCard extends ConsumerWidget {
  final ClubTeam team;
  const _TeamCard({required this.team});

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
            _Tag(
              text: team.isActive ? 'AKTİF' : 'PASİF',
              color: team.isActive ? AppColors.success : AppColors.error,
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: AppColors.textSecondary),
              onSelected: (action) {
                if (action == 'edit') _showTeamDialog(context, ref, team);
                if (action == 'units') _showUnitsDialog(context, ref, team);
                if (action == 'delete') _confirmDelete(context, ref, team);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'units', child: Text('Birimleri Yönet')),
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(
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

Future<void> _showTeamDialog(BuildContext context, WidgetRef ref,
    [ClubTeam? team]) async {
  final nameCtrl = TextEditingController(text: team?.name ?? '');
  final descCtrl = TextEditingController(text: team?.description ?? '');
  bool isActive = team?.isActive ?? true;
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
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
                            ref.read(authStateProvider).value?.uid;
                        await ref
                            .read(firestoreProvider)
                            .collection('teams')
                            .add({
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'isActive': isActive,
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

Future<void> _confirmDelete(
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

  try {
    await ref.read(firestoreProvider).collection('teams').doc(team.id).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Takım silindi.'), backgroundColor: AppColors.success));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Silinemedi: $e'), backgroundColor: AppColors.error));
    }
  }
}

// ── Birim (unit) yönetimi ────────────────────────────────────────────────────

Future<void> _showUnitsDialog(
    BuildContext context, WidgetRef ref, ClubTeam team) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => UnitManagementDialog(team: team),
  );
}

class UnitManagementDialog extends ConsumerStatefulWidget {
  final ClubTeam team;
  const UnitManagementDialog({super.key, required this.team});

  @override
  ConsumerState<UnitManagementDialog> createState() =>
      _UnitManagementDialogState();
}

class _UnitManagementDialogState extends ConsumerState<UnitManagementDialog> {
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
    await ref.read(firestoreProvider).collection('units').doc(id).delete();
    ref.invalidate(teamUnitsProvider(widget.team.id));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// c) BAŞVURU YÖNETİMİ
// ─────────────────────────────────────────────────────────────────────────────

class _ApplicationsTab extends ConsumerWidget {
  const _ApplicationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(teamApplicationsProvider);

    return appsAsync.when(
      data: (apps) {
        final pending = apps.where((a) => a['status'] == 'pending').toList();
        if (pending.isEmpty) {
          return Center(
            child: Text('Bekleyen başvuru yok.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pending.length,
          itemBuilder: (_, i) {
            final app = pending[i];
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app['applicantName'] as String? ?? 'Bilinmiyor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Takım: ${app['teamName'] ?? ''}',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final teamId = app['teamId'] as String?;
                            final uid = app['applicantUid'] as String?;
                            if (teamId != null && uid != null) {
                              await ref
                                  .read(firestoreProvider)
                                  .collection('teams')
                                  .doc(teamId)
                                  .update({
                                'memberIds': FieldValue.arrayUnion([uid]),
                              });
                            }
                            await ref
                                .read(firestoreProvider)
                                .collection('teamApplications')
                                .doc(app['id'] as String)
                                .update({'status': 'approved'});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Onaylandı.'),
                                    backgroundColor: AppColors.success),
                              );
                            }
                          },
                          icon: const Icon(Icons.check,
                              size: 16, color: AppColors.success),
                          label: const Text('Onayla',
                              style: TextStyle(color: AppColors.success)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await ref
                                .read(firestoreProvider)
                                .collection('teamApplications')
                                .doc(app['id'] as String)
                                .update({'status': 'rejected'});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Reddedildi.'),
                                    backgroundColor: AppColors.warning),
                              );
                            }
                          },
                          icon: const Icon(Icons.close,
                              size: 16, color: AppColors.error),
                          label: const Text('Reddet',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// d) BEKLEYEN İÇERİK ONAYLARI (dashboard kartları)
// ─────────────────────────────────────────────────────────────────────────────

class _PendingContentTab extends ConsumerWidget {
  const _PendingContentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(teamApplicationsProvider);
    final reportsAsync = ref.watch(bugReportsProvider);
    final tasksAsync =
        ref.watch(tasksScreenProvider((uid: null, isAdmin: true)));

    final pendingApps =
        (appsAsync.valueOrNull ?? const []).where((a) => a['status'] == 'pending').length;
    final openReports = (reportsAsync.valueOrNull ?? const [])
        .where((r) => r.status != 'done')
        .length;
    final pendingApprovalTasks = (tasksAsync.valueOrNull ?? const [])
        .where((t) => t.status == TaskStatus.pendingApproval)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Aksiyon gerektiren öğeler',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        _PendingCard(
          icon: Icons.how_to_reg_outlined,
          title: 'Bekleyen Başvuru',
          value: '$pendingApps',
          color: AppColors.teamAccent,
          onTap: () => DefaultTabController.of(context).animateTo(2),
        ),
        const SizedBox(height: 10),
        _PendingCard(
          icon: Icons.bug_report_outlined,
          title: 'Çözülmemiş Hata Bildirimi',
          value: '$openReports',
          color: AppColors.error,
        ),
        const SizedBox(height: 10),
        _PendingCard(
          icon: Icons.task_alt,
          title: 'Onay Bekleyen Görev',
          value: '$pendingApprovalTasks',
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _PendingCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style:
                      TextStyle(color: AppColors.textPrimary, fontSize: 15),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// e) SİSTEM İSTATİSTİKLERİ
// ─────────────────────────────────────────────────────────────────────────────

class _SystemStatsTab extends ConsumerWidget {
  const _SystemStatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final teamsAsync = ref.watch(clubTeamsProvider);
    final tasksAsync =
        ref.watch(tasksScreenProvider((uid: null, isAdmin: true)));
    final appsAsync = ref.watch(teamApplicationsProvider);

    final totalUsers = usersAsync.valueOrNull?.length ?? 0;
    final totalTeams = teamsAsync.valueOrNull?.length ?? 0;
    final tasks = tasksAsync.valueOrNull ?? const <TaskModel>[];

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final completedThisWeek = tasks
        .where((t) =>
            t.status == TaskStatus.completed &&
            t.completedAt != null &&
            t.completedAt!.isAfter(weekAgo))
        .length;
    final totalTasks = tasks.length;
    final activeTeams =
        (teamsAsync.valueOrNull ?? const []).where((t) => t.isActive).length;
    final pendingApps = (appsAsync.valueOrNull ?? const [])
        .where((a) => a['status'] == 'pending')
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(
          icon: Icons.people_outline,
          title: 'Toplam Üye',
          value: '$totalUsers',
          color: AppColors.panelBlue,
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: Icons.groups_outlined,
          title: 'Toplam Takım',
          value: '$totalTeams',
          color: AppColors.teamAccent,
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: Icons.check_circle_outline,
          title: 'Aktif Takım',
          value: '$activeTeams',
          color: AppColors.success,
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: Icons.task_alt,
          title: 'Toplam Görev',
          value: '$totalTasks',
          color: AppColors.tasksGreen,
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: Icons.event_available_outlined,
          title: 'Bu Hafta Tamamlanan Görev',
          value: '$completedThisWeek',
          color: AppColors.warning,
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: Icons.how_to_reg_outlined,
          title: 'Bekleyen Başvuru',
          value: '$pendingApps',
          color: AppColors.sargeGold,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

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
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}