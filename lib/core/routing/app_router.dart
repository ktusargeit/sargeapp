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
import '../../features/auth/screens/pending_approval_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/team/screens/team_detail_screen.dart';
import '../../features/admin/screens/admin_panel_screen.dart';
import '../../features/admin/screens/admin_member_detail_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/store/screens/store_screen.dart';
import '../../features/store/screens/store_product_detail_screen.dart';
import '../../features/store/screens/store_product_form_screen.dart';
import '../../features/store/screens/store_order_form_screen.dart';
import '../../features/store/screens/store_orders_screen.dart';
import '../../features/store/screens/store_order_detail_screen.dart';
import '../../features/store/screens/store_settings_screen.dart';
import '../models/app_user.dart';
import '../providers/auth_providers.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Exposes the root navigator key so the FCM handlers in `main.dart` can
/// deep-link into the running router from a tapped push notification.
GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

/// Public routes that guests (not logged in) are allowed to see without redirect.
const _publicRoutes = {'/login', '/register', '/about', '/contact', '/splash'};

/// The waiting room for signed-in users whose registration has not been
/// approved by an admin yet. Reachable ONLY in that state, and it is the only
/// non-public route an unapproved user is allowed to stay on.
const String kPendingApprovalRoute = '/pending-approval';

/// Routes that live inside the [ShellRoute] (i.e. the screens that render the
/// bottom navigation bar). Used by [AppRouter.build]'s redirect to decide
/// whether a requested location is safe to honour while the auth state is still
/// inconclusive. Keeping this list in sync with the `ShellRoute.routes` below is
/// what guarantees a signed-in user can never be silently parked on a
/// non-shell screen (login/splash) that has no bottom navigation bar.
const _shellAllowedRoutes = {
  '/dashboard',
  '/club',
  '/inventory',
  '/locations',
  '/cleaning',
  '/team',
  '/tasks',
  '/about',
  '/contact',
  '/report-bug',
  '/settings',
  '/store',
};

class AppRouter {
  static GoRouter build(Ref ref) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: GoRouterRefreshStream(ref),
      redirect: (context, state) {
        final authState = ref.read(authStateProvider);
        // CRITICAL: `.valueOrNull`, never `.value`.
        //
        // `AsyncError.value` RETHROWS the provider error (riverpod's
        // `throwErrorWithCombinedStackTrace`). This `redirect` callback runs on
        // every navigation AND on every auth-state change (see
        // [GoRouterRefreshStream]). If auth hits an error state (token refresh,
        // offline, permission-denied), a `.value` read here would throw INSIDE
        // go_router's redirect, so go_router renders its error page INSTEAD of
        // the matched route — which means the whole ShellRoute (and therefore
        // the bottom navigation bar) silently disappears. With `.valueOrNull`
        // an errored auth state simply behaves like "not logged in yet" and the
        // shell keeps rendering.
        final isLoggedIn = authState.valueOrNull != null;
        final path = state.matchedLocation;
        final isPublic = _publicRoutes.contains(path);

        // ─── REGISTRATION APPROVAL GUARD (v4.4.0) ────────────────────────────
        //
        // Guest login was REMOVED. A signed-in user whose `approvalStatus` is
        // 'pending' (or 'rejected') must NOT reach the shell/dashboard; they may
        // only sit on [kPendingApprovalRoute].
        //
        // `hasProfile` distinguishes "profile document not loaded YET" (the
        // common transient state right after sign-in, and also the state an
        // admin would be in if their own document were missing) from a real
        // 'pending' verdict. We only enforce the gate when the profile is
        // actually in hand, so a slow/offline profile fetch can never bounce an
        // approved member onto the waiting screen.
        final appUserAsync = ref.read(currentAppUserProvider);
        final appUser = appUserAsync.valueOrNull;
        final hasProfile = appUser != null;
        final isUnapproved = hasProfile && appUser.needsApproval;

        if (isUnapproved) {
          if (path == kPendingApprovalRoute) return null;
          // Anything else — including /login and /register, which would
          // otherwise let them sign in as a different account while the
          // unapproved session is still active — goes to the waiting room.
          return kPendingApprovalRoute;
        }

        // An approved user has no business on the waiting screen.
        if (hasProfile && !appUser.needsApproval && path == kPendingApprovalRoute) {
          return '/dashboard';
        }

        // Auth state not conclusive yet (first stream emission still pending, or
        // the stream is in an error state — offline / token refresh /
        // permission-denied / Firebase still booting).
        //
        // CRITICAL: in this window we must NOT treat the user as "signed out".
        // `LoginScreen._submit` calls `context.go('/dashboard')` immediately
        // after `signInWithEmailAndPassword` succeeds, i.e. one microtask BEFORE
        // `authStateChanges()` emits the new user. With the old
        // `if (isLoading || hasError) return null;` the redirect was skipped
        // entirely, so go_router kept rendering the *previous* match (the login
        // screen) under the new `/dashboard` URL — the user stayed stuck on a
        // screen that has no bottom navigation bar, with a perfectly clean log.
        //
        // Fix: (1) an authenticated route requested while auth is inconclusive is
        // always ALLOWED (optimistic — the ShellRoute renders and any screen that
        // needs a uid already degrades gracefully via `.valueOrNull`), and
        // (2) only the signed-out decision is deferred.
        if (authState.isLoading || authState.hasError) {
          if (isPublic) return null;
          // REQUESTS TARGETING A SHELL ROUTE ARE ALWAYS HONOURED. These are
          // exactly the screens that render the bottom navigation bar, so
          // letting them through means an authenticated user can never be
          // parked on login/splash just because `authStateChanges()` had not
          // emitted yet (the sign-in race described above). Every screen inside
          // the shell resolves its own data with `.valueOrNull`, so an
          // inconclusive auth state degrades to a guest-like view instead of a
          // crash.
          if (_shellAllowedRoutes.any(path.startsWith)) return null;
          // Unknown session on a protected route (admin, store checkout, ...):
          // stay put rather than bouncing a possibly-authenticated user back to
          // /login, which would wipe the screen they were on.
          return null;
        }

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
            // Prevent flashing the dashboard if we don't know the approval status yet.
            if (!hasProfile && appUserAsync.isLoading) {
              return null; // stay on auth screen while loading profile
            }
            return '/dashboard';
          }
          return null;
        }

        // Not logged in: every non-public route bounces to /login.
        // (Guest sessions were removed in v4.4.0, so there is no showcase
        // carve-out any more.)
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
          path: kPendingApprovalRoute,
          name: 'pending-approval',
          builder: (context, state) => const PendingApprovalScreen(),
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
            child: AppShell(child: child),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // NOTE: this transition is purely decorative. It must never gate
              // the shell from being *painted*: if the animation is interrupted
              // or the incoming page is rebuilt mid-flight, the outgoing
              // (login/splash) screen stays on top and the user sees a shell-less
              // screen with no bottom navigation bar even though the URL and the
              // matched route are correct.
              //
              // `FadeTransition` alone already keeps the new page in the tree
              // from the first frame, so we drop the `SlideTransition` wrapper
              // (which forced an extra `Tween<Offset>` animation to complete
              // before the shell looked settled) and keep the shorter fade.
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
          routes: [
            GoRoute(
              path: '/dashboard',
              name: 'dashboard',
              builder: (context, state) {
                final extra = state.extra;
                return DashboardScreen(
                  initialAnnouncementId:
                      extra is String ? extra : null,
                );
              },
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
              builder: (context, state) {
                final extra = state.extra;
                return ReportBugScreen(
                  initialReportId: extra is String ? extra : null,
                );
              },
            ),
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/store',
              name: 'store',
              builder: (context, state) => const StoreScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'store-add',
                  builder: (context, state) => const StoreProductFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  name: 'store-edit',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return StoreProductFormScreen(editProductId: id);
                  },
                ),
                GoRoute(
                  path: 'product/:id',
                  name: 'store-product',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return StoreProductDetailScreen(productId: id);
                  },
                ),
                GoRoute(
                  path: 'order/:id',
                  name: 'store-order',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return StoreOrderFormScreen(productId: id);
                  },
                ),
                GoRoute(
                  path: 'orders',
                  name: 'store-orders',
                  builder: (context, state) {
                    final extra = state.extra;
                    return StoreOrdersScreen(
                      initialOrderId: extra is String ? extra : null,
                    );
                  },
                ),
                GoRoute(
                  path: 'order-detail/:id',
                  name: 'store-order-detail',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return StoreOrderDetailScreen(orderId: id);
                  },
                ),
                GoRoute(
                  path: 'settings',
                  name: 'store-settings',
                  builder: (context, state) => const StoreSettingsScreen(),
                ),
              ],
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
  }
}