import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../models/team_models.dart';

class TeamScoreboardTab extends ConsumerWidget {
  final ClubTeam team;
  const TeamScoreboardTab({super.key, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    return usersAsync.when(
      data: (users) {
        final members =
            users.where((u) => team.memberIds.contains(u.uid)).toList();
        if (members.isEmpty) {
          return Center(
              child: Text('Bu takımda henüz üye yok.',
                  style: TextStyle(color: AppColors.textSecondary)));
        }
        members.sort((a, b) =>
            b.teamPointsFor(team.id).compareTo(a.teamPointsFor(team.id)));
        return ListView.separated(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final user = members[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
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
                    onTap: () => context.push('/profile/${user.uid}'),
                    child: SafeAvatar(url: user.photoUrl, radius: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(user.displayName,
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
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
                                child: const Text(
                                  'KAPTAN',
                                  style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(user.roleLabel,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.teamAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.teamAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text('Toplam: ${user.teamPointsFor(team.id)} puan',
                        style: const TextStyle(
                            color: AppColors.teamAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
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
