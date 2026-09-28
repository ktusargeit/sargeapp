import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/profile_basic_info.dart';
import '../widgets/profile_connections.dart';
import '../widgets/profile_edit_screen.dart';
import '../widgets/profile_experience.dart';
import '../widgets/profile_teams_roles.dart';

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
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
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
            return Center(
                child: Text('Kullanıcı bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }

          final Widget tabContent;
          switch (_tabIndex) {
            case 0:
              tabContent = ProfileAboutTab(user: user);
              break;
            case 1:
              tabContent = ProfileExperienceSection(user: user);
              break;
            default:
              tabContent = ProfileConnectionsSection(user: user);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ProfileHero(user: user, isOwnProfile: isOwnProfile),
              ),
              SliverToBoxAdapter(child: ProfileIdentityShowcase(user: user)),
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

/// "Hakkında" tab: basic info + current teams & roles.
class ProfileAboutTab extends StatelessWidget {
  final AppUser user;
  const ProfileAboutTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileBasicInfoSection(user: user),
          const SizedBox(height: 16),
          ProfileTeamsRolesSection(user: user),
        ],
      ),
    );
  }
}