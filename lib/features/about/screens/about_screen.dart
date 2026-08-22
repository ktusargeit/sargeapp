import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/image_utils.dart';
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
    final canEditTeamStory =
        ref.watch(currentUserCanProvider(Permissions.editTeamStory));

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

          _SectionHeader(
            title: 'GEÇMİŞ TAKIMLAR',
            icon: Icons.history_outlined,
            trailing: canEditTeamStory
                ? TextButton.icon(
                    onPressed: () => _showAddArchivedTeamSheet(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Geçmiş Takım Ekle'),
                  )
                : null,
          ),
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

    return GestureDetector(
      onTap: () => _showTeamDetailSheet(context, team, canEditTeamStory),
      child: Container(
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
        return GestureDetector(
          onTap: () => _showHonoraryDetailSheet(context, m, user),
          child: _HonoraryCard(member: m, user: user),
        );
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
  final existingPhotos = List<String>.from(team.photos);
  final newPhotos = <PickedImage>[];
  bool saving = false;
  bool picking = false;

  Future<List<String>> uploadNewPhotos() async {
    final uploaded = <String>[];
    for (var i = 0; i < newPhotos.length; i++) {
      final img = newPhotos[i];
      final ext = DateTime.now().microsecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('team_photos/story_${team.id}_${ext}_$i.jpg');
      final compressed = await img.compressedUploadBytes();
      if (compressed.isNotEmpty) {
        await ref.putData(compressed);
      } else if (img.bytes != null) {
        await ref.putData(img.bytes!);
      } else if (img.dartFile != null) {
        await ref.putFile(img.dartFile!);
      }
      uploaded.add(await ref.getDownloadURL());
    }
    return uploaded;
  }

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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('GÖRSELLER',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...existingPhotos.map((url) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 72,
                                height: 72,
                                color: AppColors.surface2,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  setDialogState(() => existingPhotos.remove(url)),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )),
                  ...newPhotos.map((p) {
                    ImageProvider? provider;
                    if (kIsWeb && p.bytes != null) {
                      provider = MemoryImage(p.bytes!);
                    } else if (p.dartFile != null) {
                      provider = FileImage(p.dartFile!);
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: provider != null
                          ? Image(image: provider,
                              width: 72, height: 72, fit: BoxFit.cover)
                          : Container(
                              width: 72,
                              height: 72,
                              color: AppColors.surface2),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: picking
                    ? null
                    : () async {
                        setDialogState(() => picking = true);
                        final imgs = await PickedImage.pickMultiple();
                        if (imgs.isNotEmpty) {
                          setDialogState(() => newPhotos.addAll(imgs));
                        }
                        setDialogState(() => picking = false);
                      },
                icon: picking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Görsel Ekle'),
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
                      final uploaded = await uploadNewPhotos();
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
                        'photos': [...existingPhotos, ...uploaded],
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

// ---------------------------------------------------------------------------
// Team detail sheet (story + gallery + members) — opens on card tap
// ---------------------------------------------------------------------------

Future<void> _showTeamDetailSheet(
    BuildContext context, ClubTeam team, bool canEdit) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _TeamDetailSheet(team: team, canEdit: canEdit),
  );
}

class _TeamDetailSheet extends ConsumerWidget {
  final ClubTeam team;
  final bool canEdit;
  const _TeamDetailSheet({required this.team, required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final allUsers = usersAsync.valueOrNull ?? const <AppUser>[];
    final memberIds = {...team.memberIds, ...team.pastMemberIds}.toList();
    final members = allUsers.where((u) => memberIds.contains(u.uid)).toList();
    final freeNames = team.pastMemberNames;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    team.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (team.period != null && team.period!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PeriodBadge(period: team.period!, isPast: team.isArchived),
              ),
            if (team.description.isNotEmpty)
              Text(team.description,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5)),
            if (team.story != null && team.story!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(team.story!,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.6)),
            ],
            if (team.photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              _TeamGallery(photos: team.photos),
            ],
            if (members.isNotEmpty || freeNames.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('ÜYELER',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...members.map((m) => _MemberChip(team: team, user: m)),
                  ...freeNames.map((n) => Chip(
                        label: Text(n,
                            style: TextStyle(
                                color: AppColors.textPrimary, fontSize: 12)),
                        backgroundColor: AppColors.surface2,
                      )),
                ],
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _editTeamStory(context, team);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Hikaye/Galeriyi Düzenle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Honorary member detail sheet (gallery + story + profile link)
// ---------------------------------------------------------------------------

Future<void> _showHonoraryDetailSheet(
    BuildContext context, HonoraryMember member, AppUser? user) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _HonoraryDetailSheet(member: member, user: user),
  );
}

class _HonoraryDetailSheet extends ConsumerWidget {
  final HonoraryMember member;
  final AppUser? user;
  const _HonoraryDetailSheet({required this.member, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit =
        ref.watch(currentUserCanProvider(Permissions.addHonoraryMember));
    final name = user?.displayName ?? 'Bilinmiyor';
    final photoUrl = user?.photoUrl;
    final hasProfile = member.userId.isNotEmpty && user != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SafeAvatar(url: photoUrl, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (member.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(member.note,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4)),
            ],
            if (member.story.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(member.story,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.6)),
            ],
            if (member.photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              _HonoraryGallery(photos: member.photos),
            ],
            const SizedBox(height: 16),
            if (hasProfile)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/profile/${member.userId}');
                  },
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Profili Gör'),
                ),
              ),
            if (canEdit) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _editHonoraryStory(context, member);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Hikaye/Galeriyi Düzenle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HonoraryGallery extends StatelessWidget {
  final List<String> photos;
  const _HonoraryGallery({required this.photos});

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

Future<void> _editHonoraryStory(
    BuildContext context, HonoraryMember member) async {
  final storyCtrl = TextEditingController(text: member.story);
  final existingPhotos = List<String>.from(member.photos);
  final newPhotos = <PickedImage>[];
  bool saving = false;
  bool picking = false;

  Future<List<String>> uploadNewPhotos() async {
    final uploaded = <String>[];
    for (var i = 0; i < newPhotos.length; i++) {
      final img = newPhotos[i];
      final ts = DateTime.now().microsecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('honorary_members/${member.id}_${ts}_$i.jpg');
      final compressed = await img.compressedUploadBytes();
      if (compressed.isNotEmpty) {
        await ref.putData(compressed);
      } else if (img.bytes != null) {
        await ref.putData(img.bytes!);
      } else if (img.dartFile != null) {
        await ref.putFile(img.dartFile!);
      }
      uploaded.add(await ref.getDownloadURL());
    }
    return uploaded;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Onursal Üye Hikayesi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: storyCtrl,
                maxLines: 6,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Hikaye / Not'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('GÖRSELLER',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...existingPhotos.map((url) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 72,
                                height: 72,
                                color: AppColors.surface2,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setDialogState(
                                  () => existingPhotos.remove(url)),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )),
                  ...newPhotos.map((p) {
                    ImageProvider? provider;
                    if (kIsWeb && p.bytes != null) {
                      provider = MemoryImage(p.bytes!);
                    } else if (p.dartFile != null) {
                      provider = FileImage(p.dartFile!);
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: provider != null
                          ? Image(image: provider,
                              width: 72, height: 72, fit: BoxFit.cover)
                          : Container(
                              width: 72,
                              height: 72,
                              color: AppColors.surface2),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: picking
                    ? null
                    : () async {
                        setDialogState(() => picking = true);
                        final imgs = await PickedImage.pickMultiple();
                        if (imgs.isNotEmpty) {
                          setDialogState(() => newPhotos.addAll(imgs));
                        }
                        setDialogState(() => picking = false);
                      },
                icon: picking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Görsel Ekle'),
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
                    setDialogState(() => saving = true);
                    final container = ProviderScope.containerOf(ctx, listen: false);
                    try {
                      final uploaded = await uploadNewPhotos();
                      final repo = container.read(clubInfoRepositoryProvider);
                      await repo.updateHonoraryMemberStory(
                        id: member.id,
                        story: storyCtrl.text.trim(),
                        photos: [...existingPhotos, ...uploaded],
                      );
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

// ---------------------------------------------------------------------------
// "+ Geçmiş Takım Ekle" sheet
// ---------------------------------------------------------------------------

Future<void> _showAddArchivedTeamSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => const _AddArchivedTeamSheet(),
  );
}

class _AddArchivedTeamSheet extends ConsumerStatefulWidget {
  const _AddArchivedTeamSheet();
  @override
  ConsumerState<_AddArchivedTeamSheet> createState() =>
      _AddArchivedTeamSheetState();
}

class _AddArchivedTeamSheetState extends ConsumerState<_AddArchivedTeamSheet> {
  final _nameCtrl = TextEditingController();
  final _periodCtrl = TextEditingController();
  final _freeTextCtrl = TextEditingController();
  final Set<String> _selectedUids = {};
  final List<String> _freeTextNames = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _periodCtrl.dispose();
    _freeTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(clubInfoRepositoryProvider);
      final addedBy = ref.read(currentAppUserProvider).value?.uid ?? '';
      await repo.createArchivedTeam(
        name: _nameCtrl.text.trim(),
        period: _periodCtrl.text.trim(),
        memberIds: _selectedUids.toList(),
        freeTextMembers: _freeTextNames,
        createdBy: addedBy,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Geçmiş takım eklendi.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Eklenemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _addFreeText() {
    final v = _freeTextCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      if (!_freeTextNames.contains(v)) _freeTextNames.add(v);
      _freeTextCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final allUsers = usersAsync.valueOrNull ?? const <AppUser>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Geçmiş Takım Ekle',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Takım Adı'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _periodCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Dönem / Yıl (örn: 2019-2020)'),
              ),
              const SizedBox(height: 12),
              Text('ÜYELER (sistemden seç)',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1)),
              const SizedBox(height: 6),
              Flexible(
                child: usersAsync.when(
                  data: (_) {
                    if (allUsers.isEmpty) {
                      return Text('Kayıtlı kullanıcı yok.',
                          style: TextStyle(color: AppColors.textSecondary));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: allUsers.length,
                      itemBuilder: (_, i) {
                        final u = allUsers[i];
                        final selected = _selectedUids.contains(u.uid);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(u.displayName,
                              style: TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text(u.email,
                              style: TextStyle(color: AppColors.textSecondary)),
                          value: selected,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selectedUids.add(u.uid);
                            } else {
                              _selectedUids.remove(u.uid);
                            }
                          }),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Hata: $e'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _freeTextCtrl,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                          hintText: 'Sistemde olmayan üye adı'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addFreeText,
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.primaryGreen),
                  ),
                ],
              ),
              if (_freeTextNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _freeTextNames
                      .map((n) => Chip(
                            label: Text(n,
                                style: TextStyle(
                                    color: AppColors.textPrimary, fontSize: 12)),
                            onDeleted: () =>
                                setState(() => _freeTextNames.remove(n)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Oluştur'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
