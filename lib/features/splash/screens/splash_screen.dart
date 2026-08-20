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

  @override
  void initState() {
    super.initState();
    _animTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      final authUser = ref.read(authStateProvider).value;
      final isGuest = ref.read(isGuestProvider);

      if (authUser != null) {
        _navigateAfterStartup();
      } else if (isGuest) {
        _navigateAfterStartup();
      } else {
        context.go('/login');
      }
    });
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