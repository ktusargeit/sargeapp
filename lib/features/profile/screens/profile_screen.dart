import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/utils/image_utils.dart';
import '../../team/providers/team_providers.dart';
import '../../tasks/providers/task_providers.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final currentUser = ref.watch(currentAppUserProvider).value;
    final isOwnProfile = currentUser?.uid == widget.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppColors.surface,
        actions: [
          if (isOwnProfile && currentUser != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.settingsPurple),
              tooltip: 'Profili Düzenle',
              onPressed: () => _openEditor(currentUser),
            ),
        ],
      ),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
                child: Text('Kullanıcı bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return DefaultTabController(
            length: 3,
            child: Column(children: [
              _ProfileHero(
                user: user,
                isOwnProfile: isOwnProfile,
              ),
              _StatsBar(user: user),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.border),
                ),
                child: const TabBar(
                  indicator: BoxDecoration(
                    color: AppColors.sargeGold,
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.background,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  indicatorPadding: EdgeInsets.zero,
                  tabs: [
                    Tab(height: 32, text: 'Hakkında'),
                    Tab(height: 32, text: 'Deneyim'),
                    Tab(height: 32, text: 'Bağlantılar'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AboutTab(user: user),
                    _ExperienceTab(user: user),
                    _ConnectionsTab(user: user),
                  ],
                ),
              ),
            ]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  void _openEditor(AppUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditScreen(user: user)),
    );
  }
}

// ---------------------------------------------------------------------------
// HERO / COVER
// ---------------------------------------------------------------------------

class _ProfileHero extends ConsumerStatefulWidget {
  final AppUser user;
  final bool isOwnProfile;
  const _ProfileHero({
    required this.user,
    required this.isOwnProfile,
  });

  @override
  ConsumerState<_ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends ConsumerState<_ProfileHero> {
  bool _uploadingPhoto = false;
  bool _uploadingCover = false;

  Future<void> _pickPhoto() async {
    if (!widget.isOwnProfile) return;
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos/${widget.user.uid}.jpg');
      if (kIsWeb && picked.bytes != null) {
        await storageRef.putData(picked.bytes!);
      } else if (picked.dartFile != null) {
        await storageRef.putFile(picked.dartFile!);
      }
      final url = await storageRef.getDownloadURL();
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.user.uid)
          .update({'photoUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profil fotoğrafı güncellendi.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Fotoğraf yüklenemedi: $e'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickCover() async {
    if (!widget.isOwnProfile) return;
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploadingCover = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('cover_photos/${widget.user.uid}.jpg');
      if (kIsWeb && picked.bytes != null) {
        await storageRef.putData(picked.bytes!);
      } else if (picked.dartFile != null) {
        await storageRef.putFile(picked.dartFile!);
      }
      final url = await storageRef.getDownloadURL();
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.user.uid)
          .update({'coverPhotoUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kapak fotoğrafı güncellendi.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Kapak fotoğrafı yüklenemedi: $e'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final headline = [
      if (user.department != null && user.department!.isNotEmpty)
        user.department!,
      if (user.className != null && user.className!.isNotEmpty)
        user.className!,
    ].join(' · ');

    final activeTitles = user.activeTitles;
    final hasCover =
        user.coverPhotoUrl != null && user.coverPhotoUrl!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF0D0D0D),
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 90,
            child: GestureDetector(
              onTap: widget.isOwnProfile ? _pickCover : null,
              child: Container(
                decoration: hasCover
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(user.coverPhotoUrl!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.sargeGold.withValues(alpha: 0.35),
                            AppColors.teamAccent.withValues(alpha: 0.25),
                            AppColors.tasksAccent.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                child: widget.isOwnProfile
                    ? Center(
                        child: _uploadingCover
                            ? const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.sargeGold,
                              )
                            : Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar (tap to upload if own profile)
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.sargeGold, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.surface2,
                          backgroundImage: user.photoUrl != null &&
                                  user.photoUrl!.isNotEmpty
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: _uploadingPhoto
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.sargeGold)
                              : (user.photoUrl == null ||
                                      user.photoUrl!.isEmpty
                                  ? const Icon(Icons.person_outline,
                                      size: 44,
                                      color: AppColors.textSecondary)
                                  : null),
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  user.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (activeTitles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: activeTitles
                        .map((t) => _TitleChip(title: t))
                        .toList(),
                  ),
                ],
                if (headline.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _titleColor(String titleType) {
  switch (titleType) {
    case TitleType.boardPresident:
      return AppColors.sargeGold;
    case TitleType.boardMember:
      return AppColors.teamAccent;
    case TitleType.captain:
      return AppColors.info;
    case TitleType.admin:
      return AppColors.error;
    case TitleType.unitLead:
      return AppColors.warning;
    case TitleType.honoraryMember:
      return AppColors.primaryGreen;
    case TitleType.member:
    default:
      return AppColors.depoAccent;
  }
}

class _TitleChip extends StatelessWidget {
  final UserTitle title;
  const _TitleChip({required this.title});

  @override
  Widget build(BuildContext context) {
    final color = _titleColor(title.titleType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            title.displayLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STATS BAR (header)
// ---------------------------------------------------------------------------

class _StatsBar extends ConsumerWidget {
  final AppUser user;
  const _StatsBar({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedCount =
        ref.watch(completedTaskCountProvider(user.uid)).valueOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
                icon: Icons.stars_outlined,
                label: 'Toplam Puan',
                value: '${user.points}',
                color: AppColors.sargeGold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
                icon: Icons.trending_up,
                label: 'Haftalık Puan',
                value: '${user.weeklyPoints}',
                color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
                icon: Icons.task_alt,
                label: 'Tamamlanan',
                value: '${completedCount ?? 0}',
                color: AppColors.info),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface2, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION HEADER WITH OPTIONAL EDIT
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ABOUT TAB
// ---------------------------------------------------------------------------

class _AboutTab extends ConsumerWidget {
  final AppUser user;
  const _AboutTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final teams = teamsAsync.valueOrNull ?? [];
    final myTeams =
        teams.where((t) => user.teamIds.contains(t.id)).toList();

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        // Bio
        _SectionTitleWithCard(
          header: const _SectionHeader(title: 'HAKKINDA'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              user.bio != null && user.bio!.isNotEmpty
                  ? user.bio!
                  : 'Henüz bir biyografi eklenmemiş.',
              style: TextStyle(
                color: (user.bio == null || user.bio!.isEmpty)
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingLg),

        // Personal info
        _SectionTitleWithCard(
          header: const _SectionHeader(title: 'BİLGİLER'),
          child: Column(
            children: [
              _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Ad Soyad',
                  value: user.displayName,
                  color: AppColors.info),
              _InfoRow(
                  icon: Icons.school_outlined,
                  label: 'Bölüm',
                  value: user.department ?? '—',
                  color: AppColors.teamAccent),
              _InfoRow(
                  icon: Icons.class_outlined,
                  label: 'Sınıf',
                  value: user.className ?? '—',
                  color: AppColors.depoAccent),
              _InfoRow(
                  icon: Icons.mail_outline,
                  label: 'E-posta',
                  value: user.email,
                  color: AppColors.primaryGreen,
                  isLast: true),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingLg),

        // Active teams & roles
        _SectionTitleWithCard(
          header: const _SectionHeader(title: 'GÜNCEL TAKIMLAR & ROLLER'),
          child: myTeams.isEmpty
              ? const _EmptyCard(
                  'Aktif takım bulunmuyor.', icon: Icons.groups_outlined)
              : Column(
                  children: [
                    for (var i = 0; i < myTeams.length; i++)
                      _TeamCard(
                        team: myTeams[i],
                        isCaptain: myTeams[i].leadUid == user.uid,
                        isLast: i == myTeams.length - 1,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppConstants.spacingLg),

        // Unit responsibilities
        _SectionTitleWithCard(
          header: const _SectionHeader(title: 'BİRİM SORUMLULUKLARI'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: user.unitResponsibilities.isEmpty
                ? const _EmptyCard('Sorumluluk eklenmemiş.',
                    icon: Icons.assignment_outlined)
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.unitResponsibilities
                        .map((r) => _TagChip(label: r))
                        .toList(),
                  ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingLg),

        // Active titles summary
        _SectionTitleWithCard(
          header: const _SectionHeader(title: 'ÜNVANLAR'),
          child: user.activeTitles.isEmpty
              ? const _EmptyCard('Aktif ünvan bulunmuyor.',
                  icon: Icons.workspace_premium_outlined)
              : Column(
                  children: [
                    for (var i = 0; i < user.activeTitles.length; i++)
                      _TitleRow(
                        title: user.activeTitles[i],
                        isLast: i == user.activeTitles.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final dynamic team;
  final bool isCaptain;
  final bool isLast;
  const _TeamCard({
    required this.team,
    required this.isCaptain,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = team.photoUrl as String?;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surface3,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? const Icon(Icons.groups_outlined,
                    color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  isCaptain ? 'Kaptan' : 'Üye',
                  style: TextStyle(
                    color: isCaptain
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        isCaptain ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (isCaptain)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              child: const Text('KAPTAN',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final UserTitle title;
  final bool isLast;
  const _TitleRow({required this.title, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = _titleColor(title.titleType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.workspace_premium, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.displayLabel,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('Başlangıç: ${_dateFormat.format(title.startDate)}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.teamAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teamAccent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_outlined,
              size: 14, color: AppColors.teamAccent),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EXPERIENCE TAB (merged timeline + awards)
// ---------------------------------------------------------------------------

class _ExperienceTab extends StatelessWidget {
  final AppUser user;
  const _ExperienceTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final entries = _buildTimeline(user);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        const _SectionHeader(title: 'DENEYİM'),
        if (entries.isEmpty)
          const _EmptyCard(
            'Henüz geçmiş kaydı yok — kulüpteki yolculuğun burada birikecek.',
            icon: Icons.auto_awesome,
          )
        else
          _Timeline(entries: entries),
        const SizedBox(height: AppConstants.spacingLg),

        const _SectionHeader(title: 'ÖDÜLLER & BAŞARILAR'),
        if (user.awards.isEmpty)
          const _EmptyCard('Henüz ödül eklenmemiş.',
              icon: Icons.emoji_events_outlined)
        else
          _AwardsGrid(awards: user.awards),
      ],
    );
  }
}

class _ExperienceEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int sortMillis;
  const _ExperienceEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.sortMillis,
  });
}

List<_ExperienceEntry> _buildTimeline(AppUser user) {
  final entries = <_ExperienceEntry>[];

  // Former titles
  for (final t in user.formerTitles) {
    entries.add(_ExperienceEntry(
      icon: Icons.workspace_premium_outlined,
      color: _titleColor(t.titleType),
      title: t.displayLabel,
      subtitle: _formatRange(t.startDate, t.endDate),
      sortMillis: t.startDate.millisecondsSinceEpoch,
    ));
  }

  // Past teams
  for (final t in user.pastTeams) {
    final role = (t['role'] as String?)?.trim();
    final teamName = (t['teamName'] as String?)?.trim() ?? '';
    final startYear = (t['startYear'] as num?)?.toInt() ?? 0;
    final endYear = (t['endYear'] as num?)?.toInt();
    final title = role != null && role.isNotEmpty
        ? '$role — $teamName'
        : teamName;
    final range =
        endYear != null ? '$startYear - $endYear' : '$startYear - Devam ediyor';
    entries.add(_ExperienceEntry(
      icon: Icons.groups_outlined,
      color: AppColors.teamAccent,
      title: title,
      subtitle: range,
      sortMillis: DateTime(startYear).millisecondsSinceEpoch,
    ));
  }

  // Club roles (deneyim / geçmiş roller)
  for (final r in user.clubRoles) {
    final roleName = (r['roleName'] as String?)?.trim();
    if (roleName == null || roleName.isEmpty) continue;
    final teamName = (r['teamName'] as String?)?.trim();
    final startYear = (r['startYear'] as num?)?.toInt() ?? 0;
    final endYear = (r['endYear'] as num?)?.toInt();
    final title = teamName != null && teamName.isNotEmpty
        ? '$roleName — $teamName'
        : roleName;
    final range =
        endYear != null ? '$startYear - $endYear' : '$startYear - Devam ediyor';
    entries.add(_ExperienceEntry(
      icon: Icons.badge_outlined,
      color: AppColors.primaryGreen,
      title: title,
      subtitle: range,
      sortMillis: DateTime(startYear).millisecondsSinceEpoch,
    ));
  }

  entries.sort((a, b) => b.sortMillis.compareTo(a.sortMillis));
  return entries;
}

String _formatRange(DateTime start, DateTime? end) {
  final startStr = _dateFormat.format(start);
  final endStr = end != null ? _dateFormat.format(end) : 'Devam ediyor';
  return '$startStr - $endStr';
}

class _Timeline extends StatelessWidget {
  final List<_ExperienceEntry> entries;
  const _Timeline({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: entries.asMap().entries.map((e) {
        final idx = e.key;
        final entry = e.value;
        final isLast = idx == entries.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            entry.color.withValues(alpha: 0.3),
                            entry.color.withValues(alpha: 0.12),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: entry.color),
                      ),
                      child: Icon(entry.icon, size: 15, color: entry.color),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(width: 2, color: AppColors.border),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.surface2, AppColors.surface],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: entry.color.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(entry.subtitle,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AwardsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> awards;
  const _AwardsGrid({required this.awards});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: awards.map((a) {
        final title = a['title'] as String? ?? '';
        final desc = a['description'] as String? ?? '';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface2, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.sargeGold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.sargeGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_outlined,
                    color: AppColors.sargeGold, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              if (desc.isNotEmpty)
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// CONNECTIONS TAB (big, tappable social links)
// ---------------------------------------------------------------------------

class _ConnectionsTab extends StatelessWidget {
  final AppUser user;
  const _ConnectionsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        // Optional contact card
        if (user.email.isNotEmpty) ...[
          const _SectionHeader(title: 'İLETİŞİM'),
          _ContactCard(email: user.email),
          const SizedBox(height: AppConstants.spacingLg),
        ],

        const _SectionHeader(title: 'BAĞLANTILAR'),
        if (user.links.isEmpty)
          const _EmptyCard(
            'Henüz bağlantı eklenmedi.',
            icon: Icons.hub_outlined,
          )
        else
          ...user.links.map((l) {
            final label = l['label'] as String? ?? '';
            final url = l['url'] as String? ?? '';
            final type = l['type'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LinkCard(
                  label: label, url: url, type: type),
            );
          }),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String email;
  const _ContactCard({required this.email});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _launch('mailto:$email'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryBlueAccent, AppColors.primaryBlue],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mail_outline,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('E-posta',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(email,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_outward,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String label;
  final String url;
  final String type;
  const _LinkCard({
    required this.label,
    required this.url,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _linkVisual(type, label);
    final color = visual.$1;
    final icon = visual.$2;
    final displayLabel = label.trim().isNotEmpty ? label.trim() : url.trim();
    final host = _hostFromUrl(url);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _launch(url),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: 0.12),
                AppColors.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.9), color],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    if (host.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward,
                  color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

String _hostFromUrl(String url) {
  final normalized = _normalizeUri(url);
  if (normalized == null) return '';
  return normalized.host.isEmpty ? url.trim() : normalized.host;
}

(Color, IconData) _linkVisual(String type, String label) {
  final t = type.toLowerCase();
  final l = label.toLowerCase();

  Color colorForPlatform(Color c) =>
      c == AppColors.teamAccent ? AppColors.teamAccent : c;

  if (t.contains('github') || l.contains('github')) {
    return (colorForPlatform(const Color(0xFF6E40C9)), Icons.code);
  }
  if (t.contains('linkedin') || l.contains('linkedin')) {
    return (const Color(0xFF0A66C2), Icons.business_center);
  }
  if (t.contains('instagram') || l.contains('instagram')) {
    return (const Color(0xFFE4405F), Icons.camera_alt);
  }
  if (t.contains('twitter') || t.contains('x') || l.contains('twitter')) {
    return (const Color(0xFF1DA1F2), Icons.alternate_email);
  }
  if (t.contains('youtube') || l.contains('youtube')) {
    return (const Color(0xFFFF0000), Icons.play_circle_outline);
  }
  if (t.contains('web') || t.contains('site') || t == 'url' ||
      l.contains('web') || l.contains('site')) {
    return (AppColors.teamAccent, Icons.language);
  }
  if (t.contains('mail') || t.contains('email') ||
      l.contains('mail') || l.contains('email')) {
    return (AppColors.info, Icons.mail_outline);
  }
  if (t.contains('discord') || l.contains('discord')) {
    return (const Color(0xFF5865F2), Icons.forum);
  }
  if (t.contains('phone') || t.contains('tel') ||
      l.contains('phone') || l.contains('tel')) {
    return (AppColors.primaryGreen, Icons.phone_outlined);
  }
  return (AppColors.depoAccent, Icons.link);
}

Uri? _normalizeUri(String url) {
  var u = url.trim();
  if (u.isEmpty) return null;
  if (!u.contains('://')) u = 'https://$u';
  return Uri.tryParse(u);
}

Future<void> _launch(String url) async {
  final uri = _normalizeUri(url);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ---------------------------------------------------------------------------
// SHARED WIDGETS
// ---------------------------------------------------------------------------

class _SectionTitleWithCard extends StatelessWidget {
  final Widget header;
  final Widget child;
  const _SectionTitleWithCard({
    required this.header,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  final IconData icon;
  const _EmptyCard(
    this.text, {
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isLast;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.settingsAccent,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))),
          const SizedBox(width: 12),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EDIT SCREEN (existing photo upload + profile fields — kept intact)
// ---------------------------------------------------------------------------

class ProfileEditScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const ProfileEditScreen({super.key, required this.user});
  @override
  ConsumerState<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _displayNameCtrl =
      TextEditingController(text: widget.user.displayName);
  late final TextEditingController _bioCtrl =
      TextEditingController(text: widget.user.bio ?? '');
  late final TextEditingController _departmentCtrl =
      TextEditingController(text: widget.user.department ?? '');
  late final TextEditingController _classNameCtrl =
      TextEditingController(text: widget.user.className ?? '');
  PickedImage? _pickedImage;
  bool _saving = false;
  bool _inWorkshop = false;

  // Editable lists
  late List<Map<String, dynamic>> _links;
  late List<Map<String, dynamic>> _clubRoles;
  late List<String> _unitResponsibilities;
  late List<Map<String, dynamic>> _awards;

  @override
  void initState() {
    super.initState();
    _inWorkshop = widget.user.inWorkshop;
    _links = widget.user.links.map((e) => Map<String, dynamic>.from(e)).toList();
    _clubRoles =
        widget.user.clubRoles.map((e) => Map<String, dynamic>.from(e)).toList();
    _unitResponsibilities = List<String>.from(widget.user.unitResponsibilities);
    _awards =
        widget.user.awards.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _departmentCtrl.dispose();
    _classNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet',
                    style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        children: [
          // Photo
          Center(
            child: GestureDetector(
              onTap: () async {
                final picked = await PickedImage.pick(ImageSource.gallery);
                if (picked != null) setState(() => _pickedImage = picked);
              },
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.surface2,
                backgroundImage: _pickedImage?.bytes != null
                    ? MemoryImage(_pickedImage!.bytes!)
                    : (widget.user.photoUrl != null &&
                            widget.user.photoUrl!.isNotEmpty
                        ? NetworkImage(widget.user.photoUrl!)
                        : null) as ImageProvider?,
                child: (_pickedImage == null &&
                        (widget.user.photoUrl == null ||
                            widget.user.photoUrl!.isEmpty))
                    ? const Icon(Icons.add_a_photo_outlined,
                        size: 32, color: AppColors.textSecondary)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('TEMEL BİLGİLER'),
          const SizedBox(height: 8),
          TextField(
              controller: _displayNameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Ad Soyad *')),
          const SizedBox(height: 12),
          TextField(
              controller: _bioCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration:
                  const InputDecoration(hintText: 'Hakkımda / Biyografi')),
          const SizedBox(height: 12),
          TextField(
              controller: _departmentCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Bölüm')),
          const SizedBox(height: 12),
          TextField(
              controller: _classNameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Sınıf')),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Atölyede',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: const Text('Şu anda atölyede misin?',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            value: _inWorkshop,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: (v) => setState(() => _inWorkshop = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          const _SectionTitle('SOSYAL BAĞLANTILAR'),
          const SizedBox(height: 8),
          ..._links.asMap().entries.map((entry) {
            final i = entry.key;
            final link = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                        hintText: 'Etiket (örn: GitHub)', isDense: true),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    controller: TextEditingController(
                        text: link['label'] as String? ?? ''),
                    onChanged: (v) => _links[i]['label'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration:
                        const InputDecoration(hintText: 'URL', isDense: true),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    controller: TextEditingController(
                        text: link['url'] as String? ?? ''),
                    onChanged: (v) => _links[i]['url'] = v,
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.error, size: 20),
                    onPressed: () => setState(() => _links.removeAt(i))),
              ]),
            );
          }),
          TextButton.icon(
              onPressed: () => setState(
                  () => _links.add({'label': '', 'url': '', 'type': 'other'})),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Bağlantı Ekle'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen)),
          const SizedBox(height: 20),
          const _SectionTitle('KULÜP ROLLERİ'),
          const SizedBox(height: 8),
          ..._clubRoles.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: TextField(
                          decoration: const InputDecoration(
                              hintText: 'Rol Adı (örn: Başkan)',
                              isDense: true),
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          controller: TextEditingController(
                              text: r['roleName'] as String? ?? ''),
                          onChanged: (v) => _clubRoles[i]['roleName'] = v)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          decoration: const InputDecoration(
                              hintText: 'Takım', isDense: true),
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          controller: TextEditingController(
                              text: r['teamName'] as String? ?? ''),
                          onChanged: (v) => _clubRoles[i]['teamName'] = v)),
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppColors.error, size: 20),
                      onPressed: () => setState(() => _clubRoles.removeAt(i))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child: TextField(
                          decoration: const InputDecoration(
                              hintText: 'Başlangıç Yılı', isDense: true),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          controller: TextEditingController(
                              text: r['startYear']?.toString() ?? ''),
                          onChanged: (v) => _clubRoles[i]['startYear'] =
                              int.tryParse(v) ?? 0)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          decoration: const InputDecoration(
                              hintText: 'Bitiş Yılı', isDense: true),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          controller: TextEditingController(
                              text: r['endYear']?.toString() ?? ''),
                          onChanged: (v) =>
                              _clubRoles[i]['endYear'] = int.tryParse(v))),
                ]),
              ]),
            );
          }),
          TextButton.icon(
              onPressed: () => setState(() => _clubRoles.add({
                  'roleName': '',
                  'teamName': null,
                  'startYear': DateTime.now().year,
                  'endYear': null
                })),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Rol Ekle'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen)),
          const SizedBox(height: 20),
          const _SectionTitle('BİRİM SORUMLULUKLARI'),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _unitResponsibilities.asMap().entries.map((entry) {
                return Chip(
                  label:
                      Text(entry.value, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () =>
                      setState(() => _unitResponsibilities.removeAt(entry.key)),
                  backgroundColor: AppColors.surface2,
                );
              }).toList()),
          TextField(
            decoration: const InputDecoration(
                hintText: 'Yeni sorumluluk ekle (örn: Envanter)',
                isDense: true),
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                setState(() => _unitResponsibilities.add(v.trim()));
              }
            },
          ),
          const SizedBox(height: 20),
          const _SectionTitle('ÖDÜLLER & BAŞARILAR'),
          const SizedBox(height: 8),
          ..._awards.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                        hintText: 'Ödül Adı', isDense: true),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    controller: TextEditingController(
                        text: a['title'] as String? ?? ''),
                    onChanged: (v) => _awards[i]['title'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: const InputDecoration(
                        hintText: 'Açıklama', isDense: true),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    controller: TextEditingController(
                        text: a['description'] as String? ?? ''),
                    onChanged: (v) => _awards[i]['description'] = v,
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.error, size: 20),
                    onPressed: () => setState(() => _awards.removeAt(i))),
              ]),
            );
          }),
          TextButton.icon(
              onPressed: () =>
                  setState(() => _awards.add({'title': '', 'description': null})),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ödül Ekle'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_displayNameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      String? photoUrl = widget.user.photoUrl;
      if (_pickedImage != null) {
        final ref_ = FirebaseStorage.instance
            .ref()
            .child('profile_photos/${widget.user.uid}.jpg');
        if (kIsWeb && _pickedImage!.bytes != null) {
          await ref_.putData(_pickedImage!.bytes!);
        } else if (_pickedImage!.dartFile != null) {
          await ref_.putFile(_pickedImage!.dartFile!);
        }
        photoUrl = await ref_.getDownloadURL();
      }
      final cleanLinks = _links
          .where((l) =>
              (l['label'] as String? ?? '').isNotEmpty ||
              (l['url'] as String? ?? '').isNotEmpty)
          .toList();
      final cleanRoles = _clubRoles
          .where((r) => (r['roleName'] as String? ?? '').isNotEmpty)
          .toList();
      final cleanAwards = _awards
          .where((a) => (a['title'] as String? ?? '').isNotEmpty)
          .toList();
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'displayName': _displayNameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'department': _departmentCtrl.text.trim().isEmpty
            ? null
            : _departmentCtrl.text.trim(),
        'className': _classNameCtrl.text.trim().isEmpty
            ? null
            : _classNameCtrl.text.trim(),
        'photoUrl': photoUrl,
        'inWorkshop': _inWorkshop,
        'links': cleanLinks,
        'clubRoles': cleanRoles,
        'unitResponsibilities': _unitResponsibilities
            .where((s) => s.trim().isNotEmpty)
            .toList(),
        'awards': cleanAwards,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profil güncellendi.'),
            backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Kaydedilemedi: $e'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2));
  }
}