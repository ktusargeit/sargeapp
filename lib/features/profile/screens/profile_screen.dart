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
import '../../../core/widgets/full_screen_image_view.dart';
import '../../team/providers/team_providers.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Rank priority used for the "highest active title" showcase.
/// Lower number = higher priority.
const Map<String, int> _titlePriority = {
  TitleType.boardPresident: 0,
  TitleType.boardMember: 1,
  TitleType.captain: 2,
  TitleType.admin: 3,
  TitleType.unitLead: 4,
  TitleType.honoraryMember: 5,
  TitleType.member: 6,
};

int _titleRank(String titleType) => _titlePriority[titleType] ?? 99;

UserTitle? _highestActiveTitle(AppUser user) {
  final active = user.activeTitles;
  if (active.isEmpty) return null;
  final list = [...active];
  list.sort((a, b) => _titleRank(a.titleType).compareTo(_titleRank(b.titleType)));
  return list.first;
}

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _tabIndex) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
            return  Center(
                child: Text('Kullanıcı bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }

          final Widget tabContent;
          switch (_tabIndex) {
            case 0:
              tabContent = _AboutTab(user: user);
              break;
            case 1:
              tabContent = _ExperienceTab(user: user);
              break;
            default:
              tabContent = _ConnectionsTab(user: user);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ProfileHero(user: user, isOwnProfile: isOwnProfile),
              ),
              SliverToBoxAdapter(child: _IdentityShowcase(user: user)),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: const BoxDecoration(
                      color: AppColors.sargeGold,
                      borderRadius:
                          BorderRadius.all(Radius.circular(30)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.background,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    indicatorPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(height: 32, text: 'Hakkında'),
                      Tab(height: 32, text: 'Deneyim'),
                      Tab(height: 32, text: 'Bağlantılar'),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: tabContent),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
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
// HERO / COVER — Instagram/Twitter style cover that extends behind the name,
// with the avatar overlapping the bottom edge and a dark gradient overlay.
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
  bool _uploadingCover = false;

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover image / fallback gradient
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                    child: hasCover
                        ? Image.network(
                            user.coverPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _CoverFallback(),
                          )
                        : const _CoverFallback(),
                  ),
                ),
                // Dark gradient overlay so the name/titles stay readable
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0x26000000),
                            Color(0xB3000000),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Cover change button (own profile only)
                if (widget.isOwnProfile)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _pickCover,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: _uploadingCover
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.sargeGold),
                              )
                            : const Icon(Icons.camera_alt_outlined,
                                size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                // Avatar overlapping the cover's bottom edge
                Positioned(
                  left: 20,
                  bottom: -40,
                  child: _buildAvatar(),
                ),
                // Name + titles + headline, beside the avatar over gradient
                Positioned(
                  left: 138,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),
                      if (activeTitles.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: activeTitles
                              .map((t) => _TitleChip(title: t))
                              .toList(),
                        ),
                      ],
                      if (headline.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD6DDE7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Space for the avatar overflow below the cover
          const SizedBox(height: 52),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final photoUrl = widget.user.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return GestureDetector(
      // Tapping the avatar always opens the full-screen viewer; editing is
      // only reached via the top-right "Düzenle" button.
      onTap: hasPhoto ? () => openNetworkImageViewer(context, photoUrl) : null,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.sargeGold, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 46,
          backgroundColor: AppColors.surface2,
          backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
          child: !hasPhoto
              ?  Icon(Icons.person_outline,
                  size: 46, color: AppColors.textSecondary)
              : null,
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF2A2450),
            Color(0xFF0D0D0D),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.landscape_outlined,
            size: 44, color: Color(0x66FFFFFF)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 14, color: color),
          const SizedBox(width: 4),
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
// IDENTITY SHOWCASE (rank + stats) — redesigned as an achievement "vitrin".
// ---------------------------------------------------------------------------

class _IdentityShowcase extends StatelessWidget {
  final AppUser user;
  const _IdentityShowcase({required this.user});

  @override
  Widget build(BuildContext context) {
    final top = _highestActiveTitle(user);
    final rankLabel = top?.displayLabel ?? 'Normal Üye';
    final rankType = top?.titleType ?? TitleType.member;
    final rankColor = _titleColor(rankType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          _RankBadge(
            label: rankLabel,
            color: rankColor,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatBadge(
                  icon: Icons.emoji_events_outlined,
                  label: 'Toplam Puan',
                  value: '${user.points}',
                  color: AppColors.sargeGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBadge(
                  icon: Icons.auto_awesome,
                  label: 'Haftalık Puan',
                  value: '${user.weeklyPoints}',
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RankBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.06),
            AppColors.surface2,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF2D57E), AppColors.sargeGold],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sargeGold.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.military_tech,
                color: Color(0xFF1E1E1E), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AKTİF RÜTBE',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.workspace_premium, color: color, size: 28),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            AppColors.surface2,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style:  TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style:  TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION HEADER
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
        style:  TextStyle(
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
    final unitsAsync = ref.watch(teamUnitListProvider);
    final teams = teamsAsync.valueOrNull ?? [];
    final units = unitsAsync.valueOrNull ?? const [];
    final myTeams =
        teams.where((t) => user.teamIds.contains(t.id)).toList();
    final isAdmin = user.role == 'admin' ||
        user.activeTitles.any((t) => t.titleType == TitleType.admin);

    // Birim sorumlulukları: units koleksiyonunda unitLeadUid == user.uid.
    final ledUnits =
        units.where((u) => u['unitLeadUid'] == user.uid).toList();

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          _SectionTitleWithCard(
            header: const _SectionHeader(title: 'GÜNCEL TAKIMLAR & ROLLER'),
            child: (myTeams.isEmpty && !isAdmin)
                ? const _EmptyCard(
                    'Aktif takım bulunmuyor.', icon: Icons.groups_outlined)
                : Column(
                    children: [
                      if (isAdmin) const _AdminBadgeRow(),
                      for (var i = 0; i < myTeams.length; i++)
                        _TeamCard(
                          team: myTeams[i],
                          isCaptain: myTeams[i].leadUid == user.uid,
                          ledUnitNames: ledUnits
                              .where((u) => u['teamId'] == myTeams[i].id)
                              .map((u) => u['name'] as String? ?? '')
                              .where((n) => n.isNotEmpty)
                              .toList(),
                          isLast: i == myTeams.length - 1,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
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
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final dynamic team;
  final bool isCaptain;
  final List<String> ledUnitNames;
  final bool isLast;
  const _TeamCard({
    required this.team,
    required this.isCaptain,
    this.ledUnitNames = const [],
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = team.photoUrl as String?;
    final roleLabel = isCaptain
        ? 'Kaptan'
        : (ledUnitNames.isNotEmpty
            ? 'Birim Sorumlusu: ${ledUnitNames.join(', ')}'
            : 'Üye');
    final roleColor = isCaptain
        ? AppColors.warning
        : (ledUnitNames.isNotEmpty
            ? AppColors.teamAccent
            : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            :  Border(bottom: BorderSide(color: AppColors.border)),
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
                ?  Icon(Icons.groups_outlined,
                    color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name as String? ?? '',
                    style:  TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 12,
                    fontWeight: (isCaptain || ledUnitNames.isNotEmpty)
                        ? FontWeight.w700
                        : FontWeight.w400,
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
            )
          else if (ledUnitNames.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.teamAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.teamAccent.withValues(alpha: 0.5)),
              ),
              child: const Text('SORUMLU',
                  style: TextStyle(
                      color: AppColors.teamAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _AdminBadgeRow extends StatelessWidget {
  const _AdminBadgeRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.admin_panel_settings,
                color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Admin',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
            ),
            child: const Text('SİSTEM YÖNETİCİSİ',
                style: TextStyle(
                    color: AppColors.error,
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
            :  Border(bottom: BorderSide(color: AppColors.border)),
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
                    style:  TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('Başlangıç: ${_dateFormat.format(title.startDate)}',
                    style:  TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
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

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
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

  for (final t in user.formerTitles) {
    entries.add(_ExperienceEntry(
      icon: Icons.workspace_premium_outlined,
      color: _titleColor(t.titleType),
      title: t.displayLabel,
      subtitle: _formatRange(t.startDate, t.endDate),
      sortMillis: t.startDate.millisecondsSinceEpoch,
    ));
  }

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
                      gradient:  LinearGradient(
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
                            style:  TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(entry.subtitle,
                            style:  TextStyle(
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
            gradient:  LinearGradient(
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
                style:  TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              if (desc.isNotEmpty)
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
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
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: _LinkCard(label: label, url: url, type: type),
              );
            }),
        ],
      ),
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
                     Text('E-posta',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(email,
                        style:  TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
               Icon(Icons.arrow_outward,
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
                        style:  TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    if (host.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:  TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: color, size: 20),
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

  if (t.contains('github') || l.contains('github')) {
    return (const Color(0xFF6E40C9), Icons.code);
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
              style:  TextStyle(
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
            :  Border(bottom: BorderSide(color: AppColors.border)),
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
                  style:  TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))),
          const SizedBox(width: 12),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style:  TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EDIT SCREEN — fully redesigned full-page editor, consistent card styling.
// ---------------------------------------------------------------------------

const List<(String, String)> _linkPlatforms = [
  ('GitHub', 'github'),
  ('LinkedIn', 'linkedin'),
  ('Instagram', 'instagram'),
  ('Twitter / X', 'twitter'),
  ('YouTube', 'youtube'),
  ('Web Sitesi', 'web'),
  ('E-posta', 'email'),
  ('Discord', 'discord'),
  ('Telefon', 'phone'),
  ('Diğer', 'other'),
];

String _normalizeLinkType(String? t) {
  final v = (t ?? '').trim().toLowerCase();
  for (final p in _linkPlatforms) {
    if (p.$2 == v) return v;
  }
  if (v == 'url' || v == 'site') return 'web';
  if (v == 'mail') return 'email';
  if (v == 'tel') return 'phone';
  return 'other';
}

InputDecoration _editInputDecoration({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon != null
        ? Icon(icon, size: 20, color: AppColors.textSecondary)
        : null,
    filled: true,
    fillColor: AppColors.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      borderSide:  BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      borderSide:  BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      borderSide: const BorderSide(color: AppColors.sargeGold, width: 1.4),
    ),
    labelStyle:  TextStyle(color: AppColors.textSecondary, fontSize: 14),
    floatingLabelStyle: const TextStyle(color: AppColors.sargeGold),
  );
}

class _EditSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  const _EditSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style:  TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
  final TextEditingController _unitCtrl = TextEditingController();

  PickedImage? _avatar;
  PickedImage? _cover;
  bool _saving = false;

  late List<Map<String, dynamic>> _links;
  late List<Map<String, dynamic>> _clubRoles;
  late List<String> _unitResponsibilities;
  late List<Map<String, dynamic>> _awards;

  @override
  void initState() {
    super.initState();
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
    _unitCtrl.dispose();
    super.dispose();
  }

  ImageProvider? _avatarProvider() {
    if (_avatar?.bytes != null) return MemoryImage(_avatar!.bytes!);
    if (widget.user.photoUrl != null && widget.user.photoUrl!.isNotEmpty) {
      return NetworkImage(widget.user.photoUrl!);
    }
    return null;
  }

  ImageProvider? _coverProvider() {
    if (_cover?.bytes != null) return MemoryImage(_cover!.bytes!);
    if (widget.user.coverPhotoUrl != null &&
        widget.user.coverPhotoUrl!.isNotEmpty) {
      return NetworkImage(widget.user.coverPhotoUrl!);
    }
    return null;
  }

  Future<void> _pickAvatar() async {
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked != null) setState(() => _avatar = picked);
  }

  Future<void> _pickCover() async {
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked != null) setState(() => _cover = picked);
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _avatarProvider();
    final coverProvider = _coverProvider();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title:  Text(
          'Profili Düzenle',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sargeGold,
                  disabledBackgroundColor:
                      AppColors.sargeGold.withValues(alpha: 0.5),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black87),
                        ),
                      )
                    : const Text(
                        'Kaydet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditSection(
              icon: Icons.photo_library_outlined,
              color: AppColors.info,
              title: 'Fotoğraflar',
              child: _buildPhotosSection(avatarProvider, coverProvider),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.person_outline,
              color: AppColors.teamAccent,
              title: 'Kişisel Bilgiler',
              child: _buildPersonalSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.notes_outlined,
              color: AppColors.primaryGreen,
              title: 'Hakkında',
              child: _buildAboutSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.link_outlined,
              color: AppColors.depoAccent,
              title: 'Bağlantılar',
              child: _buildLinksSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.badge_outlined,
              color: AppColors.sargeGold,
              title: 'Kulüp Rolleri',
              child: _buildClubRolesSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.assignment_outlined,
              color: AppColors.warning,
              title: 'Birim Sorumlulukları',
              child: _buildUnitsSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.emoji_events_outlined,
              color: AppColors.primaryGreen,
              title: 'Ödüller & Başarılar',
              child: _buildAwardsSection(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection(ImageProvider? avatar, ImageProvider? cover) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sargeGold, width: 2),
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.surface2,
                  backgroundImage: avatar,
                  child: avatar == null
                      ?  Icon(Icons.add_a_photo_outlined,
                          size: 30, color: AppColors.textSecondary)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Profil Fotoğrafı',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickAvatar,
                    style: _outlineButtonStyle(AppColors.info),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Fotoğrafı Değiştir'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
         Text('Kapak Fotoğrafı',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickCover,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover != null
                      ? Image(
                          image: cover, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _CoverFallback())
                      : const _CoverFallback(),
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickCover,
          style: _outlineButtonStyle(AppColors.teamAccent),
          icon: const Icon(Icons.image_outlined, size: 16),
          label: const Text('Kapağı Değiştir'),
        ),
      ],
    );
  }

  Widget _buildPersonalSection() {
    return Column(
      children: [
        TextFormField(
          controller: _displayNameCtrl,
          style:  TextStyle(color: AppColors.textPrimary),
          decoration: _editInputDecoration(label: 'Ad Soyad *', icon: Icons.person_outline),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _departmentCtrl,
          style:  TextStyle(color: AppColors.textPrimary),
          decoration: _editInputDecoration(label: 'Bölüm', icon: Icons.school_outlined),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _classNameCtrl,
          style:  TextStyle(color: AppColors.textPrimary),
          decoration: _editInputDecoration(label: 'Sınıf', icon: Icons.class_outlined),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return TextFormField(
      controller: _bioCtrl,
      maxLines: 5,
      style:  TextStyle(color: AppColors.textPrimary),
      decoration: _editInputDecoration(
          label: 'Hakkımda / Biyografi', icon: Icons.notes_outlined),
    );
  }

  Widget _buildLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._links.asMap().entries.map((entry) {
          final i = entry.key;
          final link = entry.value;
          final type = _normalizeLinkType(link['type'] as String?);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: type,
                        isExpanded: true,
                        dropdownColor: AppColors.surface2,
                        iconEnabledColor: AppColors.textSecondary,
                        style:  TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        decoration: _editInputDecoration(
                            label: 'Platform', icon: Icons.public),
                        items: _linkPlatforms
                            .map((p) => DropdownMenuItem<String>(
                                value: p.$2, child: Text(p.$1)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _links[i]['type'] = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 22),
                        onPressed: () => setState(() => _links.removeAt(i))),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: link['label'] as String? ?? '',
                  style:  TextStyle(color: AppColors.textPrimary),
                  decoration: _editInputDecoration(
                      label: 'Etiket (örn: Kişisel GitHub)'),
                  onChanged: (v) => _links[i]['label'] = v,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: link['url'] as String? ?? '',
                  keyboardType: TextInputType.url,
                  style:  TextStyle(color: AppColors.textPrimary),
                  decoration: _editInputDecoration(
                      label: 'URL', icon: Icons.link),
                  onChanged: (v) => _links[i]['url'] = v,
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(
                () => _links.add({'label': '', 'url': '', 'type': 'other'})),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni Bağlantı Ekle'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildClubRolesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._clubRoles.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: r['roleName'] as String? ?? '',
                        style:  TextStyle(color: AppColors.textPrimary),
                        decoration: _editInputDecoration(
                            label: 'Rol Adı (örn: Başkan)'),
                        onChanged: (v) => _clubRoles[i]['roleName'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 22),
                        onPressed: () => setState(() => _clubRoles.removeAt(i))),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: r['teamName'] as String? ?? '',
                  style:  TextStyle(color: AppColors.textPrimary),
                  decoration: _editInputDecoration(
                      label: 'Takım (opsiyonel)', icon: Icons.groups_outlined),
                  onChanged: (v) => _clubRoles[i]['teamName'] =
                      v.trim().isEmpty ? null : v,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: r['startYear']?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        style:  TextStyle(color: AppColors.textPrimary),
                        decoration: _editInputDecoration(
                            label: 'Başlangıç Yılı'),
                        onChanged: (v) => _clubRoles[i]['startYear'] =
                            int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: r['endYear']?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        style:  TextStyle(color: AppColors.textPrimary),
                        decoration: _editInputDecoration(label: 'Bitiş Yılı'),
                        onChanged: (v) => _clubRoles[i]['endYear'] =
                            v.trim().isEmpty ? null : int.tryParse(v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _clubRoles.add({
                  'roleName': '',
                  'teamName': null,
                  'startYear': DateTime.now().year,
                  'endYear': null
                })),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Rol Ekle'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_unitResponsibilities.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _unitResponsibilities.asMap().entries.map((entry) {
              return Chip(
                label: Text(entry.value,
                    style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(
                    () => _unitResponsibilities.removeAt(entry.key)),
                backgroundColor: AppColors.surface2,
                side:  BorderSide(color: AppColors.border),
              );
            }).toList(),
          ),
        if (_unitResponsibilities.isNotEmpty) const SizedBox(height: 12),
        TextFormField(
          controller: _unitCtrl,
          style:  TextStyle(color: AppColors.textPrimary),
          decoration: _editInputDecoration(
              label: 'Yeni sorumluluk ekle (örn: Envanter)',
              icon: Icons.add_task_outlined),
          onFieldSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              setState(() => _unitResponsibilities.add(v.trim()));
              _unitCtrl.clear();
            }
          },
        ),
      ],
    );
  }

  Widget _buildAwardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._awards.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: a['title'] as String? ?? '',
                        style:  TextStyle(color: AppColors.textPrimary),
                        decoration:
                            _editInputDecoration(label: 'Ödül Adı'),
                        onChanged: (v) => _awards[i]['title'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 22),
                        onPressed: () => setState(() => _awards.removeAt(i))),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: a['description'] as String? ?? '',
                  style:  TextStyle(color: AppColors.textPrimary),
                  decoration:
                      _editInputDecoration(label: 'Açıklama (opsiyonel)'),
                  onChanged: (v) => _awards[i]['description'] =
                      v.trim().isEmpty ? null : v,
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _awards.add({'title': '', 'description': null})),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ödül Ekle'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  ButtonStyle _outlineButtonStyle(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.6)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Future<void> _save() async {
    if (_displayNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ad Soyad boş bırakılamaz.'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoUrl = widget.user.photoUrl;
      if (_avatar != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_photos/${widget.user.uid}.jpg');
        if (kIsWeb && _avatar!.bytes != null) {
          await storageRef.putData(_avatar!.bytes!);
        } else if (_avatar!.dartFile != null) {
          await storageRef.putFile(_avatar!.dartFile!);
        }
        photoUrl = await storageRef.getDownloadURL();
      }

      String? coverUrl = widget.user.coverPhotoUrl;
      if (_cover != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('cover_photos/${widget.user.uid}.jpg');
        if (kIsWeb && _cover!.bytes != null) {
          await storageRef.putData(_cover!.bytes!);
        } else if (_cover!.dartFile != null) {
          await storageRef.putFile(_cover!.dartFile!);
        }
        coverUrl = await storageRef.getDownloadURL();
      }

      final cleanLinks = _links
          .where((l) =>
              (l['label'] as String? ?? '').isNotEmpty ||
              (l['url'] as String? ?? '').isNotEmpty)
          .map((l) => {
                'label': l['label'] as String? ?? '',
                'url': l['url'] as String? ?? '',
                'type': _normalizeLinkType(l['type'] as String?),
              })
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
        'coverPhotoUrl': coverUrl,
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