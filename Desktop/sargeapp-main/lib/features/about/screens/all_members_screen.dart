import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../team/providers/team_providers.dart';
import '../../admin/widgets/admin_members_tab.dart';

class AllMembersScreen extends ConsumerStatefulWidget {
  const AllMembersScreen({super.key});

  @override
  ConsumerState<AllMembersScreen> createState() => _AllMembersScreenState();
}

class _AllMembersScreenState extends ConsumerState<AllMembersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedTeamId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final teamsAsync = ref.watch(clubTeamsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tüm Üyeler'),
        backgroundColor: AppColors.surface,
      ),
      body: usersAsync.when(
        data: (users) {
          final teams = teamsAsync.valueOrNull ?? [];
          final activeTeams = teams.where((t) => !t.isArchived).toList();

          var filtered = users;
          if (_selectedTeamId != null) {
            final st = teams.where((t) => t.id == _selectedTeamId).firstOrNull;
            if (st != null) {
              filtered =
                  filtered.where((u) => st.memberIds.contains(u.uid)).toList();
            }
          }

          if (_query.isNotEmpty) {
            filtered = filtered
                .where((u) =>
                    u.displayName.toLowerCase().contains(_query) ||
                    u.email.toLowerCase().contains(_query))
                .toList();
          }

          return Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toplam Üye: ${users.length}',
                      style: const TextStyle(
                          color: AppColors.sargeGold,
                          fontSize: 24, // Much larger and more prominent
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (activeTeams.isNotEmpty) ...[
                      Text(
                        'Takımlara Göre Üye Sayıları:',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: activeTeams.map((team) {
                          final count = team.memberIds.length;
                          final isSelected = _selectedTeamId == team.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTeamId = null;
                                } else {
                                  _selectedTeamId = team.id;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.sargeGold.withValues(alpha: 0.2)
                                    : AppColors.surface2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: isSelected
                                        ? AppColors.sargeGold
                                        : AppColors.border),
                              ),
                              child: Text(
                                '${team.name}: $count',
                                style: TextStyle(
                                    color: isSelected
                                        ? AppColors.sargeGold
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 12),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'İsme veya e-postaya göre ara...',
                    hintStyle:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: AppColors.textSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final user = filtered[i];
                    return _MemberCard(user: user);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child:
              Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
        ),
      ),
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
        onTap: () => context.push('/profile/${user.uid}'),
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
                        AdminTag(
                          text: user.roleLabel,
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
                      ],
                    ),
                    if (activeTitles.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: activeTitles
                            .map((t) => AdminTag(
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
