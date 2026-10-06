import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../notifications/providers/notification_providers.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NOTE: deliberately NOT responsive. The shell always uses the compact
    // layout (AppBar + AppDrawer + `_BottomNav`), no matter how wide the
    // viewport is. The old `width >= breakpointTablet` branch swapped the
    // 4-tab bar for a left `NavigationRail`-style sidebar on desktop/web,
    // which is unwanted: the 4 navigation entries must ALWAYS live in the
    // `bottomNavigationBar` slot, i.e. pinned to the bottom edge of the screen.
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('SARGE'),
        actions: const [
          _NotificationBell(),
          SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      body: child,
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.valueOrNull != null;
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    // The gold "Admin Kontrol Paneli" entry is intentionally Admin-only
    // (stricter than `viewAdminPanel`, which also admits board_president).
    final isAdmin = ref.watch(isAdminProvider);

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                if (isLoggedIn && appUser != null) {
                  context.push('/profile/${appUser.uid}');
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.surface2,
                      backgroundImage: appUser != null &&
                              appUser.photoUrl != null &&
                              appUser.photoUrl!.isNotEmpty
                          ? NetworkImage(appUser.photoUrl!)
                          : null,
                      onBackgroundImageError: appUser?.photoUrl?.isNotEmpty == true ? (_, __) {} : null,
                      child: appUser == null ||
                              appUser.photoUrl == null ||
                              appUser.photoUrl!.isEmpty
                          ? Icon(Icons.person_outline,
                              size: 18, color: AppColors.textSecondary)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (appUser != null)
                            Text(appUser.displayName,
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          if (appUser == null)
                            Text('Kullanıcı',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 8),
            if (isLoggedIn)
              _DrawerItem(
                icon: Icons.person_outline,
                label: 'Profilim',
                onTap: () {
                  Navigator.pop(context);
                  final uid = ref.read(authStateProvider).valueOrNull?.uid;
                  if (uid != null) context.push('/profile/$uid');
                },
              ),
            if (isLoggedIn)
              _DrawerItem(
                icon: Icons.storefront_outlined,
                label: 'Mağaza',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/store');
                },
              ),
            if (isLoggedIn)
              _DrawerItem(
                icon: Icons.bug_report_outlined,
                label: 'Hata Bildir',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/report-bug');
                },
              ),
            if (isLoggedIn)
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Ayarlar',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
            const Spacer(),
            _DrawerItem(
              icon: Icons.people_outline,
              label: 'Tüm Üyeler',
              onTap: () {
                Navigator.pop(context);
                context.push('/all-members');
              },
            ),
            _DrawerItem(
              icon: Icons.info_outline,
              label: 'Hakkımızda',
              onTap: () {
                Navigator.pop(context);
                context.push('/about');
              },
            ),
            if (isLoggedIn && isAdmin) ...[
              Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 4),
              _AdminPanelDrawerItem(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/admin');
                },
              ),
              const SizedBox(height: 4),
            ],
            Divider(color: AppColors.border, height: 1),
            if (isLoggedIn)
              _DrawerItem(
                icon: Icons.logout,
                label: 'Çıkış Yap',
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authControllerProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
              )
            else
              _DrawerItem(
                icon: Icons.login,
                label: 'Giriş Yap',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NOTE: must be `.valueOrNull`, NOT `.value`.
    // `AsyncValue.value` RE-THROWS the error when the provider is in an error
    // state (see riverpod's `AsyncError.value` → `throwErrorWithCombinedStackTrace`).
    // This widget sits in the AppShell's AppBar actions, so a thrown error
    // aborts the whole Scaffold build and the bottom navigation bar silently
    // disappears (no crash in the logs, just a blank/error shell).
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
          if (unread > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      onPressed: () => context.push('/notifications'),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon,
          size: 20,
          color: isDestructive ? AppColors.error : AppColors.textSecondary),
      title: Text(label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

/// A visually distinct, gold "Admin Kontrol Paneli" entry shown only to admins.
/// It intentionally uses a filled gold card + dark text so it clearly stands
/// out from the neutral drawer items as a privileged area.
class _AdminPanelDrawerItem extends StatelessWidget {
  final VoidCallback onTap;
  const _AdminPanelDrawerItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: AppColors.sargeGold,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings,
                    size: 20, color: Colors.black),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Admin Kontrol Paneli',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.black.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Panel',
                  route: '/dashboard',
                  isActive: location == '/dashboard',
                  accentColor: AppColors.panelBlue,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.groups_2_outlined,
                  label: 'KULÜP',
                  route: '/club',
                  isActive: location.startsWith('/club') ||
                      location.startsWith('/inventory') ||
                      location.startsWith('/locations') ||
                      location.startsWith('/cleaning'),
                  accentColor: AppColors.depoRed,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.groups_outlined,
                  label: 'Takımım',
                  route: '/team',
                  isActive: location.startsWith('/team'),
                  accentColor: AppColors.teamOrange,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.task_alt,
                  label: 'Tüm Görevler',
                  route: '/tasks',
                  isActive: location.startsWith('/tasks'),
                  accentColor: AppColors.tasksGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final Color accentColor;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: isActive ? accentColor : AppColors.textSecondary),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? accentColor : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
