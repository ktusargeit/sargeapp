import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/routing/notification_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _animTimer;

  /// How many times we re-checked the auth state while it was still loading.
  int _resolveAttempts = 0;

  @override
  void initState() {
    super.initState();
    _animTimer = Timer(const Duration(milliseconds: 2000), _routeFromSplash);
  }

  /// Decides where to go after the splash animation.
  ///
  /// CRITICAL: this used to check the auth state exactly once, at the 2000ms
  /// mark. When the persisted session (or `authStateChanges()`'s first
  /// emission) had not settled yet — offline, slow token refresh, Firebase still
  /// booting — `authUser` was `null` and the user was sent to `/login`. The
  /// redirect then kept them there because the auth state was still
  /// inconclusive, so a perfectly valid session ended up on a screen that has
  /// no bottom navigation bar.
  ///
  /// Now we wait for the auth state to become conclusive (with a bounded
  /// number of retries) before deciding, and we never route a *pending*
  /// session to `/login`.
  void _routeFromSplash() {
    if (!mounted) return;
    final authState = ref.read(authStateProvider);

    // Auth still resolving: give it a short, bounded grace period instead of
    // assuming "signed out" (which is what used to send valid sessions to
    // /login). 6 x 150ms = 900ms.
    if (authState.isLoading && _resolveAttempts < 6) {
      _resolveAttempts++;
      _animTimer = Timer(const Duration(milliseconds: 150), _routeFromSplash);
      return;
    }

    final authUser = authState.valueOrNull;

    // NOTE: guest sessions were REMOVED in v4.4.0 — there is no `isGuest`
    // branch any more. A signed-in user without a profile document (or with
    // `approvalStatus: 'pending'`) is routed to /pending-approval by the
    // router's guard, so splash only has to answer "is anyone signed in?".
    if (authUser != null) {
      _navigateAfterStartup();
      return;
    }

    // Either auth ended in an error state (offline / permission-denied) or it is
    // STILL loading after the grace period. Both cases go to the shell: the
    // dashboard renders fine for an unknown session, and — critically — the
    // shell is the only place the bottom navigation bar exists. Sending an
    // unresolved session to /login is what stranded users on a bar-less screen.
    if (authState.isLoading || authState.hasError) {
      _navigateAfterStartup();
      return;
    }

    // Conclusively signed out with no guest session -> login is correct.
    context.go('/login');
  }

  void _navigateAfterStartup() {
    final location = pendingNotificationLocation;
    final targetId = pendingNotificationTargetId;
    pendingNotificationLocation = null;
    pendingNotificationTargetId = null;

    if (location != null) {
      context.go(location,
          extra: targetId != null && targetId.isNotEmpty ? targetId : null);
    } else {
      context.go('/dashboard');
    }
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration:  BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [AppColors.surface3, AppColors.background],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.scale(scale: value, child: child),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/sarge_logo.png', width: 120, height: 120, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.surface2, borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.sargeGold.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.hexagon_outlined, size: 60, color: AppColors.sargeGold),
                        )),
                const SizedBox(height: 24),
                 Text('SARGE',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6)),
                const SizedBox(height: 8),
                Text('KULÜP YÖNETİM SİSTEMİ',
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 3)),
                const SizedBox(height: 16),
                Text('v${AppConstants.appVersion}',
                    style: TextStyle(color: AppColors.sargeGold.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}