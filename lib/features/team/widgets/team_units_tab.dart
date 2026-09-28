import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../models/team_models.dart';
import '../providers/team_providers.dart';
import '../screens/unit_detail_screen.dart';

class TeamUnitsTab extends ConsumerWidget {
  final ClubTeam team;
  final bool canManage;
  const TeamUnitsTab({super.key, required this.team, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(teamUnitsListProvider(team.id));

    return Column(
      children: [
        if (canManage)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _createUnit(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yeni Birim'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teamAccent,
                  side: BorderSide(
                      color: AppColors.teamAccent.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
        Expanded(
          child: unitsAsync.when(
            data: (units) {
              if (units.isEmpty) {
                return Center(
                  child: Text('Bu takımda henüz birim yok.',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: units.length,
                itemBuilder: (_, i) => TeamUnitCard(
                    team: team, unit: units[i], canManage: canManage),
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.teamAccent)),
            error: (e, _) => Center(
                child: Text('Hata: $e',
                    style: const TextStyle(color: AppColors.error))),
          ),
        ),
      ],
    );
  }

  Future<void> _createUnit(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Birim'),
        content: SingleChildScrollView(
          child: Column(
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
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await ref.read(unitServiceProvider).createUnit(
                      teamId: team.id,
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Oluşturulamadı: $e'),
                      backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }
}

class TeamUnitCard extends ConsumerWidget {
  final ClubTeam team;
  final TeamUnit unit;
  final bool canManage;
  const TeamUnitCard({
    super.key,
    required this.team,
    required this.unit,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => UnitDetailScreen(unitId: unit.id, team: team),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.teamAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.teamAccent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.folder_outlined,
                    color: AppColors.teamAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${unit.memberUids.length} üye',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star,
                            size: 13, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Expanded(
                          child: TeamUnitCardLeadName(uid: unit.unitLeadUid),
                        ),
                      ],
                    ),
                    if (unit.description != null &&
                        unit.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        unit.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (canManage)
                Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class TeamUnitCardLeadName extends ConsumerWidget {
  final String? uid;
  const TeamUnitCardLeadName({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uid == null || uid!.isEmpty) {
      return Text(
        'Sorumlu atanmamış',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final profileAsync = ref.watch(userProfileProvider(uid!));
    return profileAsync.when(
      data: (user) => Text(
        user?.displayName ?? 'Bilinmiyor',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Text(
        'Bilinmiyor',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}