import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/shell/screens/app_shell.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/inventory_add_screen.dart';
import '../../features/inventory/screens/inventory_detail_screen.dart';
import '../../features/inventory/screens/location_screen.dart';
import '../../features/shell/screens/club_screen.dart';
import '../../features/cleaning/screens/cleaning_main_screen.dart';
import '../../features/cleaning/screens/cleaning_calendar_screen.dart';
import '../../features/cleaning/screens/cleaning_manage_screen.dart';
import '../../features/cleaning/screens/cleaning_week_screen.dart';
import '../../features/team/screens/team_screen.dart';
import '../../features/about/screens/about_screen.dart';
import '../../features/contact/screens/contact_screen.dart';
import '../../features/reports/screens/report_bug_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/team/screens/team_detail_screen.dart';
import '../../features/admin/screens/admin_panel_screen.dart';
import '../../features/admin/screens/admin_member_detail_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../models/app_user.dart';
import '../providers/auth_providers.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Public routes that guests (not logged in) are allowed to see without redirect.
const _publicRoutes = {'/login', '/register', '/about', '/contact', '/splash'};

/// Routes guests are allowed to browse (showcase only).
const _guestAllowedRoutes = {
  '/dashboard',
  '/about',
  '/contact',
  '/login',
  '/register',
  '/splash',
  '/profile',
  '/team',
  '/notifications',
  '/club',
};

class AppRouter {
  static GoRouter build(Ref ref) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: GoRouterRefreshStream(ref),
      redirect: (context, state) {
        final authState = ref.read(authStateProvider);
        final isLoggedIn = authState.value != null;
        final isGuest = ref.read(isGuestProvider);
        final path = state.matchedLocation;
        final isPublic = _publicRoutes.contains(path);

        // Still loading auth state -> don't redirect yet.
        if (authState.isLoading) return null;

        // Logged in: only redirect away from login/register.
        //
        // NOTE: '/splash' is intentionally NOT redirected here. If we
        // redirected /splash → /dashboard for an already-signed-in user, the
        // dashboard would become the *initial* route (no page transition), so
        // the login/splash fade-slide animation would never run on app open.
        // Letting splash always render and then `context.go('/dashboard')`
        // keeps the ShellRoute's CustomTransitionPage animation on every
        // startup (manual login AND persisted auto-login).
        if (isLoggedIn) {
          if (path == '/login' || path == '/register') {
            return '/dashboard';
          }
          return null;
        }

        // Guest session active: allow showcase routes but NOT admin or write operations.
        if (isGuest) {
          if (path.startsWith('/admin') || path.startsWith('/inventory/add')) {
            return '/dashboard';
          }
          if (!_guestAllowedRoutes.contains(path) &&
              !path.startsWith('/profile') &&
              !path.startsWith('/team') &&
              !path.startsWith('/inventory') &&
              !path.startsWith('/locations') &&
              !path.startsWith('/cleaning') &&
              !path.startsWith('/settings') &&
              !path.startsWith('/tasks') &&
              !path.startsWith('/report-bug') &&
              !path.startsWith('/notifications')) {
            return '/dashboard';
          }
          return null;
        }

        // Not logged in and not guest.
        if (!isPublic) {
          return '/login';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/profile/:id',
          name: 'profile',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return ProfileScreen(userId: id);
          },
        ),
        GoRoute(
          path: '/admin',
          name: 'admin',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const AdminPanelScreen(),
          routes: [
            GoRoute(
              path: 'members/:id',
              name: 'admin-member-detail',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final extra = state.extra;
                return AdminMemberDetailScreen(
                  userId: id,
                  initialUser: extra is AppUser ? extra : null,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const NotificationsScreen(),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          pageBuilder: (context, state, child) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: AppShell(key: ValueKey(state.matchedLocation), child: child),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Fade + slight upward slide on entry (the "entry animation").
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
          routes: [
            GoRoute(
              path: '/dashboard',
              name: 'dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/club',
              name: 'club',
              builder: (context, state) {
                final extra = state.extra;
                return ClubScreen(
                    initialIndex: extra is int ? extra : 0);
              },
            ),
            GoRoute(
              path: '/inventory',
              name: 'inventory',
              builder: (context, state) => const InventoryScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'inventory-add',
                  builder: (context, state) {
                    final extra = state.extra;
                    if (extra is String) {
                      return InventoryAddScreen(editItemId: extra);
                    }
                    return const InventoryAddScreen();
                  },
                ),
                GoRoute(
                  path: 'detail/:id',
                  name: 'inventory-detail',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return InventoryDetailScreen(itemId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/locations',
              name: 'locations',
              builder: (context, state) => const LocationScreen(),
            ),
            GoRoute(
              path: '/cleaning',
              name: 'cleaning',
              builder: (context, state) => const CleaningMainScreen(),
              routes: [
                GoRoute(
                  path: 'calendar',
                  name: 'cleaning-calendar',
                  builder: (context, state) => const CleaningCalendarScreen(),
                ),
                GoRoute(
                  path: 'manage',
                  name: 'cleaning-manage',
                  builder: (context, state) => const CleaningManageScreen(),
                ),
                GoRoute(
                  path: 'week/:weekKey',
                  name: 'cleaning-week',
                  builder: (context, state) {
                    final weekKey = state.pathParameters['weekKey'] ?? '';
                    return CleaningWeekScreen(weekKey: weekKey);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/team',
              name: 'team',
              builder: (context, state) => const TeamScreen(),
            ),
            GoRoute(
              path: '/team/:id',
              name: 'team-detail',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return TeamDetailScreen(teamId: id);
              },
            ),
            GoRoute(
              path: '/tasks',
              name: 'tasks',
              builder: (context, state) {
                final extra = state.extra;
                return TasksScreen(
                  initialTaskId: extra is String ? extra : null,
                );
              },
            ),
            GoRoute(
              path: '/about',
              name: 'about',
              builder: (context, state) => const AboutScreen(),
            ),
            GoRoute(
              path: '/contact',
              name: 'contact',
              builder: (context, state) => const ContactScreen(),
            ),
            GoRoute(
              path: '/report-bug',
              name: 'report-bug',
              builder: (context, state) => const ReportBugScreen(),
            ),
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Caches the [GoRouter] so it is built exactly once and reused on rebuilds.
///
/// Recreating the router (and re-using the same global navigator keys) on every
/// [SargeDepoApp.build] caused go_router to rebuild its shell navigator with a
/// duplicate `GlobalObjectKey(navigatorKey.hashCode)`. Caching fixes that.
final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.build(ref);
});

/// Bridges Riverpod's authStateProvider stream to a [Listenable] so
/// go_router's [refreshListenable] can trigger re-evaluation of [redirect].
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(authStateProvider, (previous, next) {
      notifyListeners();
    });
    ref.listen(currentAppUserProvider, (previous, next) {
      notifyListeners();
    });
    ref.listen(guestSessionProvider, (previous, next) {
      notifyListeners();
    });
  }
}