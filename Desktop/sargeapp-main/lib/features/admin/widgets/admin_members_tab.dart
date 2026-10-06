import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';

class AdminTag extends StatelessWidget {
  final String text;
  final Color color;
  const AdminTag({super.key, required this.text, required this.color});

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

class AdminMembersTab extends ConsumerStatefulWidget {
  const AdminMembersTab({super.key});

  @override
  ConsumerState<AdminMembersTab> createState() => _AdminMembersTabState();
}

class _AdminMembersTabState extends ConsumerState<AdminMembersTab> {
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
                  return AdminMemberCard(user: user);
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

class AdminMemberCard extends ConsumerWidget {
  final AppUser user;
  const AdminMemberCard({super.key, required this.user});

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
                          const AdminTag(
                              text: 'ASKIDA', color: AppColors.error),
                        AdminTag(
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
