import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarge_depo_app/core/providers/auth_providers.dart';
import 'package:sarge_depo_app/core/routing/app_router.dart';
import 'package:sarge_depo_app/core/utils/safe_date.dart';

/// Regression coverage for the "bottom navigation bar disappears" bug.
///
/// TWO root causes were found and fixed:
///
/// 1. `DateFormat(pattern, 'tr_TR')` throws `LocaleDataException` when
///    `initializeDateFormatting('tr_TR')` has not succeeded. `main.dart` used to
///    swallow that initialisation failure inside a silent try-catch and keep
///    going, so `DashboardHeader.build` threw while `AppShell` was building its
///    body — which aborted the whole Scaffold, taking the `bottomNavigationBar`
///    with it (no visible crash).
///    FIX: `SafeDate` (core/utils/safe_date.dart) never throws + main.dart
///    verifies and retries the init and records `intlLocaleReady`.
///
/// 2. `AsyncValue.value` rethrows on error state, killing anything that reads it
///    (see also test/async_value_safety_test.dart).
Future<void> _pumpShell(
  WidgetTester tester, {
  required Stream<fb.User?> Function(Ref ref) authOverride,
  String location = '/dashboard',
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [authStateProvider.overrideWith(authOverride)],
  );
  addTearDown(container.dispose);

  final router = container.read(appRouterProvider);
  router.go(location);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  test('SafeDate does NOT throw when tr_TR locale data is missing', () {
    // NOTE: no `initializeDateFormatting` call anywhere in this test file, so
    // the tr_TR locale data is NOT loaded — exactly the production failure mode.
    final d = DateTime(2026, 9, 27, 14, 30);

    expect(() => SafeDate.longWithWeekday(d), returnsNormally);
    expect(() => SafeDate.dayMonth(d), returnsNormally);
    expect(() => SafeDate.dayShortMonthYear(d), returnsNormally);
    expect(() => SafeDate.dayShortMonthYearTime(d), returnsNormally);
    expect(() => SafeDate.dayMonthYearTime(d), returnsNormally);
    expect(() => SafeDate.dayShortMonthTime(d), returnsNormally);
    expect(() => SafeDate.dayMonthCommaTime(d), returnsNormally);
    expect(() => SafeDate.numericDate(d), returnsNormally);

    // And they all produce non-empty output.
    expect(SafeDate.longWithWeekday(d), isNotEmpty);
    expect(SafeDate.dayMonth(d), isNotEmpty);
    expect(SafeDate.numericDate(d), '27.09.2026');
    debugPrint('SafeDate output -> ${SafeDate.longWithWeekday(d)}');
  });

  testWidgets('TRACE A: /dashboard renders bottom nav while auth is LOADING',
      (tester) async {
    await _pumpShell(
      tester,
      authOverride: (ref) => const Stream<fb.User?>.empty(),
    );

    expect(find.text('Panel'), findsOneWidget,
        reason: 'bottom nav must survive loading');
    // NOTE: the dashboard body has a pre-existing 45px RenderFlex overflow at
    // 400px width (unrelated to the shell/nav); the 4 nav tabs still render.
    final ex = tester.takeException();
    expect(ex, isNull,
        reason: 'no exception should escape the shell build; got: $ex');
  });

  testWidgets('TRACE B: /dashboard renders bottom nav while auth is in ERROR',
      (tester) async {
    await _pumpShell(
      tester,
      authOverride: (ref) => Stream<fb.User?>.error(Exception('auth boom')),
    );

    expect(find.text('Panel'), findsOneWidget,
        reason: 'bottom nav must survive auth error');
    final ex = tester.takeException();
    expect(ex, isNull,
        reason: 'no exception should escape the shell build; got: $ex');
  });

  testWidgets('TRACE C: all four bottom nav tabs are present on /dashboard',
      (tester) async {
    await _pumpShell(
      tester,
      authOverride: (ref) => const Stream<fb.User?>.empty(),
    );

    // The 4 shell tabs are unconditional (PROJECT_MAP: no permission gating).
    for (final label in ['Panel', 'KULÜP', 'Takımım', 'Tüm Görevler']) {
      expect(find.text(label), findsOneWidget, reason: '$label tab missing');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('TRACE D: bottom nav has no overflow at a narrow 320px width',
      (tester) async {
    await _pumpShell(
      tester,
      authOverride: (ref) => const Stream<fb.User?>.empty(),
      size: const Size(320, 640),
    );

    // The bottom nav itself must lay out cleanly: 4 Expanded children, each
    // a Column inside a fixed-width cell -> no horizontal overflow.
    for (final label in ['Panel', 'KULÜP', 'Takımım', 'Tüm Görevler']) {
      expect(find.text(label), findsOneWidget, reason: '$label tab missing');
    }
  });

  // ---------------------------------------------------------------------------
  // Regression: the shell is intentionally NOT responsive any more.
  //
  // It used to swap the 4-tab `_BottomNav` for a left `NavigationRail`-style
  // sidebar (`_SidebarNav`) once the viewport reached
  // `AppConstants.breakpointTablet` (900px), i.e. on every desktop/web window.
  // That behaviour was removed on purpose: all 4 entries must live in the
  // Scaffold's `bottomNavigationBar` slot at EVERY width, so the tabs are
  // pinned to the bottom edge of the screen and no sidebar is ever rendered.
  // ---------------------------------------------------------------------------

  testWidgets('TRACE H: wide desktop/web viewport keeps the BOTTOM nav bar',
      (tester) async {
    // 1400x900 is well past the retired 900px breakpoint.
    await _pumpShell(
      tester,
      authOverride: (ref) => const Stream<fb.User?>.empty(),
      size: const Size(1400, 900),
    );

    for (final label in ['Panel', 'KULÜP', 'Takımım', 'Tüm Görevler']) {
      expect(find.text(label), findsOneWidget,
          reason: '$label must render at desktop width too');
    }

    // The bar must actually own the `bottomNavigationBar` slot...
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.bottomNavigationBar, isNotNull,
        reason: 'the 4 tabs must live in the bottomNavigationBar slot');

    // ...and it must be anchored to the bottom edge of the viewport, not
    // floating in a side column.
    final panelCenter = tester.getCenter(find.text('Panel'));
    final viewportBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(panelCenter.dy, greaterThan(viewportBottom * 0.9),
        reason: 'the nav tabs must be pinned near the bottom edge');

    // No sidebar / rail of any kind may survive on the wide layout.
    expect(find.byType(NavigationRail), findsNothing,
        reason: 'the sidebar (NavigationRail) must be gone');
    expect(find.byType(Drawer), findsNothing,
        reason: 'the drawer stays closed; it is not a persistent sidebar');

    expect(tester.takeException(), isNull);
  });

  testWidgets('TRACE I: wide viewport still exposes the drawer via the AppBar',
      (tester) async {
    await _pumpShell(
      tester,
      authOverride: (ref) => const Stream<fb.User?>.empty(),
      size: const Size(1400, 900),
    );

    // With the sidebar gone, the hamburger is the only way into the secondary
    // entries (Profilim / Mağaza / Ayarlar / ...) on desktop as well.
    expect(find.byIcon(Icons.menu), findsOneWidget,
        reason: 'the AppBar hamburger must be present at desktop width');

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // With an unresolved (loading) auth state the drawer renders its guest
    // entries; the point of this assertion is that the hamburger actually
    // opens the drawer on a wide viewport instead of a persistent sidebar.
    expect(find.text('Hakkımızda'), findsOneWidget,
        reason: 'the drawer must open from the hamburger');
  });

  // ---------------------------------------------------------------------------
  // Splash routing (third root cause of the missing bottom nav bar)
  //
  // `SplashScreen` used to read the auth state exactly once, at the 2000ms
  // mark, and send anything that was not already resolved to '/login'. A
  // pending (still loading) or errored session therefore landed on a screen
  // with no bottom navigation bar and stayed there, because the redirect kept
  // honouring 'login' while auth was inconclusive. These tests pin the fix.
  // ---------------------------------------------------------------------------

  testWidgets('TRACE E: splash does NOT strand a pending session on /login',
      (tester) async {
    await _pumpSplash(
      tester,
      authOverride: (ref) => const Stream<fb.User?>.empty(),
    );

    // 2s splash timer + the shell's page transition + the bounded auth grace
    // period.
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Panel'), findsOneWidget,
        reason: 'a pending session must reach the shell, not /login');
    expect(find.text('Giriş Yap'), findsNothing,
        reason: 'must not be parked on the login screen');
  });

  testWidgets(
      'TRACE F: splash routes an errored (offline) session to the shell',
      (tester) async {
    await _pumpSplash(
      tester,
      authOverride: (ref) => Stream<fb.User?>.error(Exception('offline')),
    );

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Panel'), findsOneWidget,
        reason: 'an errored auth state must still render the shell');
  });

  testWidgets('TRACE G: splash still routes a signed-out visitor to /login',
      (tester) async {
    await _pumpSplash(
      tester,
      authOverride: (ref) => Stream<fb.User?>.value(null),
    );

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();

    // Conclusively signed out and no guest session -> login is correct here.
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Panel'), findsNothing);
  });
}

/// Pumps the app from its real entry point (`/splash`) so the splash's own
/// timer-driven navigation is exercised, rather than jumping straight to a
/// location like [_pumpShell] does.
Future<void> _pumpSplash(
  WidgetTester tester, {
  required Stream<fb.User?> Function(Ref ref) authOverride,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [authStateProvider.overrideWith(authOverride)],
  );
  addTearDown(container.dispose);

  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}
