import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../models/club_info_models.dart';
import '../providers/club_info_providers.dart';
import 'club_story_edit_sheet.dart';
import 'honorary_add_sheet.dart';

/// "Hakkımızda" page — club history.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubInfoAsync = ref.watch(clubInfoProvider);
    final teamsAsync = ref.watch(clubTeamsProvider);
    final membersAsync = ref.watch(honoraryMembersProvider);

    final canEditStory =
        ref.watch(currentUserCanProvider(Permissions.editClubStory));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hakkımızda'),
        backgroundColor: AppColors.surface,
        actions: [
          if (canEditStory)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.primaryGreen),
              tooltip: 'Kulüp Hikayesini Düzenle',
              onPressed: () => showClubStoryEditSheet(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(
              title: 'KULÜP HİKAYESİ', icon: Icons.menu_book_outlined),
          const SizedBox(height: 10),
          clubInfoAsync.when(
            data: (info) {
              final hasStory = info.story.trim().isNotEmpty;
              final hasPhotos = info.galleryPhotos.isNotEmpty;
              if (!hasStory && !hasPhotos) {
                return const _EmptyCard(
                  'Kulüp hikayesi henüz eklenmemiş.',
                  icon: Icons.auto_stories_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (info.title != null && info.title!.isNotEmpty) ...[
                    Text(
                      info.title!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (hasStory) ...[
                    Text(
                      info.story,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (hasPhotos) _StoryGallery(photos: info.galleryPhotos),
                ],
              );
            },
            loading: () => const _LoadingBox(),
            error: (e, _) => Text('Hata: $e',
                style: const TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 28),

          const _SectionHeader(
              title: 'TAKIMLARIMIZ', icon: Icons.groups_outlined),
          const SizedBox(height: 10),
          teamsAsync.when(
            data: (teams) {
              final active = teams.where((t) => !t.isArchived).toList();
              if (active.isEmpty) {
                return const _EmptyCard(
                  'Henüz aktif takım bulunmuyor.',
                  icon: Icons.groups_outlined,
                );
              }
              return Column(
                children: active
                    .map((t) => _TeamCard(team: t, isPast: false))
                    .toList(),
              );
            },
            loading: () => const _LoadingBox(),
            error: (e, _) => Text('Hata: $e',
                style: const TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 28),

          const _SectionHeader(
              title: 'GEÇMİŞ TAKIMLAR', icon: Icons.history_outlined),
          const SizedBox(height: 10),
          teamsAsync.when(
            data: (teams) {
              final archived = teams.where((t) => t.isArchived).toList();
              if (archived.isEmpty) {
                return const _EmptyCard(
                  'Henüz arşivlenmiş takım yok.',
                  icon: Icons.history_outlined,
                );
              }
              return Column(
                children: archived
                    .map((t) => _TeamCard(team: t, isPast: true))
                    .toList(),
              );
            },
            loading: () => const _LoadingBox(),
            error: (e, _) => Text('Hata: $e',
                style: const TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 28),

          _SectionHeader(
            title: 'ONURSAL ÜYELERİMİZ',
            icon: Icons.workspace_premium_outlined,
            trailing: ref.watch(
                    currentUserCanProvider(Permissions.addHonoraryMember))
                ? TextButton.icon(
                    onPressed: () => showHonoraryAddSheet(context),
                    icon: const Icon(Icons.person_add_alt, size: 16),
                    label: const Text('Ekle'),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return const _EmptyCard(
                  'Henüz onursal üye eklenmemiş.',
                  icon: Icons.workspace_premium_outlined,
                );
              }
              return _HonoraryGrid(members: members);
            },
            loading: () => const _LoadingBox(),
            error: (e, _) => Text('Hata: $e',
                style: const TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 28),

          const _SectionHeader(title: 'İLETİŞİM', icon: Icons.mail_outline),
          const SizedBox(height: 10),
          clubInfoAsync.when(
            data: (info) => _ContactSection(info: info),
            loading: () => const _LoadingBox(),
            error: (e, _) => Text('Hata: $e',
                style: const TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const _SectionHeader({required this.title, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.sargeGold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  final IconData icon;
  const _EmptyCard(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// A) Story gallery
// ---------------------------------------------------------------------------

class _StoryGallery extends StatelessWidget {
  final List<String> photos;
  const _StoryGallery({required this.photos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => showFullScreenImageViewer(
          context,
          urls: photos,
          initialIndex: i,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SafeNetworkImage(
            url: photos[i],
            fit: BoxFit.cover,
            showLoadingIndicator: false,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// B) Team card (active + past)
// ---------------------------------------------------------------------------

class _TeamCard extends ConsumerWidget {
  final ClubTeam team;
  final bool isPast;
  const _TeamCard({required this.team, required this.isPast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final allUsers = usersAsync.valueOrNull ?? const <AppUser>[];

    final memberIds = isPast
        ? {...team.memberIds, ...team.pastMemberIds}.toList()
        : team.memberIds;
    final members = allUsers.where((u) => memberIds.contains(u.uid)).toList();

    final canEditTeamStory =
        ref.watch(currentUserCanProvider(Permissions.editTeamStory));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPast
              ? AppColors.textSecondary.withValues(alpha: 0.4)
              : AppColors.teamAccent.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TeamCardHeader(
              team: team, isPast: isPast, canEdit: canEditTeamStory),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (team.period != null && team.period!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _PeriodBadge(period: team.period!, isPast: isPast),
                  ),
                if (team.description.isNotEmpty)
                  Text(
                    team.description,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5),
                  ),
                if (team.story != null && team.story!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    team.story!,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.6),
                  ),
                ],
                if (team.photos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _TeamGallery(photos: team.photos),
                ],
                const SizedBox(height: 12),
                Text(
                  isPast ? 'O DÖNEMKİ ÜYELER' : 'ÜYELER',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                if (members.isEmpty)
                  Text('Üye listesi boş.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: members
                        .map((m) => _MemberChip(team: team, user: m))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamCardHeader extends StatelessWidget {
  final ClubTeam team;
  final bool isPast;
  final bool canEdit;
  const _TeamCardHeader({
    required this.team,
    required this.isPast,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface2.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (team.hasLead) _CaptainLabel(leadUid: team.leadUid!),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.teamAccent),
              onPressed: () => _editTeamStory(context, team),
            ),
        ],
      ),
    );
  }
}

class _CaptainLabel extends ConsumerWidget {
  final String leadUid;
  const _CaptainLabel({required this.leadUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captainAsync = ref.watch(userProfileProvider(leadUid));
    final name = captainAsync.valueOrNull?.displayName;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        name != null && name.isNotEmpty ? 'Kaptan: $name' : '',
        style: const TextStyle(color: AppColors.warning, fontSize: 11),
      ),
    );
  }
}

class _PeriodBadge extends StatelessWidget {
  final String period;
  final bool isPast;
  const _PeriodBadge({required this.period, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final color = isPast ? AppColors.textSecondary : AppColors.primaryGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        period,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TeamGallery extends StatelessWidget {
  final List<String> photos;
  const _TeamGallery({required this.photos});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => showFullScreenImageViewer(
            context,
            urls: photos,
            initialIndex: i,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 90,
              height: 90,
              child: SafeNetworkImage(
                url: photos[i],
                fit: BoxFit.cover,
                showLoadingIndicator: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final ClubTeam team;
  final AppUser user;
  const _MemberChip({required this.team, required this.user});

  @override
  Widget build(BuildContext context) {
    final isCaptain = team.leadUid == user.uid;
    final roleText = isCaptain ? 'Kaptan' : user.roleLabel;

    return GestureDetector(
      onTap: () => context.push('/profile/${user.uid}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeAvatar(url: user.photoUrl, radius: 10),
            const SizedBox(width: 6),
            Text(
              '${user.displayName} ($roleText)',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C) Honorary members grid
// ---------------------------------------------------------------------------

class _HonoraryGrid extends ConsumerWidget {
  final List<HonoraryMember> members;
  const _HonoraryGrid({required this.members});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final users = usersAsync.valueOrNull ?? const <AppUser>[];
    final byId = {for (final u in users) u.uid: u};

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        final user = byId[m.userId];
        return _HonoraryCard(member: m, user: user);
      },
    );
  }
}

class _HonoraryCard extends StatelessWidget {
  final HonoraryMember member;
  final AppUser? user;
  const _HonoraryCard({required this.member, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? 'Bilinmiyor';
    final photoUrl = user?.photoUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sargeGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          SafeAvatar(url: photoUrl, radius: 30),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (member.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              member.note,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact section (merged from old contact page)
// ---------------------------------------------------------------------------

class _ContactSection extends StatelessWidget {
  final ClubInfo info;
  const _ContactSection({required this.info});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    final email = info.email ?? '';
    final phone = info.phone ?? '';
    final address = info.address ?? '';
    final instagram = info.instagram ?? '';
    final website = info.website ?? '';
    final social = info.socialLinks ?? '';

    if (email.isNotEmpty) {
      rows.add(_contactRow(Icons.email_outlined, 'E-posta', email));
    }
    if (phone.isNotEmpty) {
      rows.add(_contactRow(Icons.phone_outlined, 'Telefon', phone));
    }
    if (address.isNotEmpty) {
      rows.add(_contactRow(Icons.location_on_outlined, 'Adres', address));
    }
    if (instagram.isNotEmpty) {
      rows.add(_contactRow(Icons.alternate_email, 'Instagram', instagram));
    }
    if (website.isNotEmpty) {
      rows.add(_contactRow(Icons.language_outlined, 'Web Sitesi', website));
    }
    if (social.isNotEmpty) {
      rows.add(_contactRow(Icons.link, 'Diğer', social));
    }

    if (rows.isEmpty) {
      return const _EmptyCard(
        'İletişim bilgisi henüz eklenmemiş.',
        icon: Icons.mail_outline,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: rows),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Team story editor (dialog)
// ---------------------------------------------------------------------------

Future<void> _editTeamStory(BuildContext context, ClubTeam team) async {
  final nameCtrl = TextEditingController(text: team.name);
  final periodCtrl = TextEditingController(text: team.period ?? '');
  final storyCtrl = TextEditingController(text: team.story ?? '');
  bool saving = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Takım Hikayesini Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Takım Adı'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: periodCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Dönem (örn: 2024-2025)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storyCtrl,
                maxLines: 6,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Takım Hikayesi'),
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
                      await FirebaseFirestore.instance
                          .collection('teams')
                          .doc(team.id)
                          .update({
                        'name': nameCtrl.text.trim(),
                        'period': periodCtrl.text.trim().isEmpty
                            ? null
                            : periodCtrl.text.trim(),
                        'story': storyCtrl.text.trim().isEmpty
                            ? null
                            : storyCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setDialogState(() => saving = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text('Kaydedilemedi: $e'),
                          backgroundColor: AppColors.error,
                        ));
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