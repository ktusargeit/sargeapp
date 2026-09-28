import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';

/// "Kayıt Onayınız Bekleniyor" — the waiting room for a freshly registered user.
///
/// Reached ONLY through the router's approval guard in `app_router.dart`: a
/// signed-in user whose `users/{uid}.approvalStatus` is `'pending'` (or
/// `'rejected'`) can never reach the shell/dashboard. The screen therefore has
/// no back stack, no drawer and no bottom navigation bar — the only two exits
/// are "refresh" and "sign out".
///
/// It also lists EVERYONE else who is still waiting
/// ([pendingApprovalsProvider]) — a product requirement: "kayıtta bekleyen
/// herkes gözüksün".
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final pendingAsync = ref.watch(pendingApprovalsProvider);
    final isRejected = appUser?.isRejected ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.sargeGold,
          // Pull-to-refresh nudges the list; the router's approval guard takes
          // over automatically the moment an admin flips the status.
          onRefresh: () async {
            ref.invalidate(pendingApprovalsProvider);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                children: [
                  const _Logo(),
                  const SizedBox(height: AppConstants.spacingXl),
                  _StatusHeadline(isRejected: isRejected),
                  const SizedBox(height: AppConstants.spacingLg),
                  _InfoCard(user: appUser),
                  const SizedBox(height: AppConstants.spacingLg),
                  _WaitingList(
                      pendingAsync: pendingAsync, currentUid: appUser?.uid),
                  const SizedBox(height: AppConstants.spacingXl),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(pendingApprovalsProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Durumu Yenile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.sargeGold,
                      side: BorderSide(
                          color: AppColors.sargeGold.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(authControllerProvider).signOut();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Çıkış Yap'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    'v${AppConstants.appVersion}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Returns up to two uppercase initials for [name], `'?'` when empty.
String _initialsOf(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// Icon + title + explanatory sentence.
class _StatusHeadline extends StatelessWidget {
  final bool isRejected;
  const _StatusHeadline({required this.isRejected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isRejected ? Icons.gpp_bad_outlined : Icons.hourglass_top_rounded,
          size: 44,
          color: isRejected ? AppColors.error : AppColors.warning,
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text(
          isRejected
              ? 'Kayıt Talebiniz Reddedildi'
              : 'Kayıt Onayınız Bekleniyor',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isRejected
              ? 'Başvurunuz yöneticiler tarafından reddedildi. Bir hata '
                  'olduğunu düşünüyorsanız kulüp yöneticileriyle iletişime geçin.'
              : 'Kayıt Onayınız Bekleniyor. Yöneticiler onayladığında giriş '
                  'yapabileceksiniz.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Shows the registering user's own name / e-mail so they can confirm which
/// account they are waiting on.
class _InfoCard extends StatelessWidget {
  final AppUser? user;
  const _InfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface3,
              border:
                  Border.all(color: AppColors.sargeGold.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              _initialsOf(user?.displayName),
              style: const TextStyle(
                color: AppColors.sargeGold,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Bekleniyor...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Onay bekleyen diğer kişiler" listesi.
///
/// Uses [pendingApprovalsProvider] and highlights the current user, so it is
/// obvious that they are in the queue too.
class _WaitingList extends StatelessWidget {
  final AsyncValue<List<AppUser>> pendingAsync;
  final String? currentUid;

  const _WaitingList({required this.pendingAsync, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final waiting = pendingAsync.valueOrNull ?? const <AppUser>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Onay Bekleyen Diğer Kişiler',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pendingAsync.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (pendingAsync.hasError)
          const _MessageBox(
              text: 'Bekleyen kayıt listesi şu anda görüntülenemiyor.')
        else if (waiting.isEmpty)
          const _MessageBox(
              text: 'Şu anda sizinle birlikte bekleyen başka kimse yok.')
        else
          // Bounded height on purpose: this sits inside a ListView, so an
          // unbounded inner scrollable would be a layout error.
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: waiting.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) =>
                  _WaitingRow(user: waiting[index], isMe: waiting[index].uid == currentUid),
            ),
          ),
      ],
    );
  }
}

/// One waiting user row. The current user is highlighted in gold.
class _WaitingRow extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  const _WaitingRow({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        isMe ? Icons.person_pin_circle : Icons.person_outline,
        size: 20,
        color: isMe ? AppColors.sargeGold : AppColors.textSecondary,
      ),
      title: Text(
        isMe ? '${user.displayName} (siz)' : user.displayName,
        style: TextStyle(
          color: isMe ? AppColors.sargeGold : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Onay bekliyor',
          style: TextStyle(
            color: AppColors.warning,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Simple bordered message box used for the list's empty/error states.
class _MessageBox extends StatelessWidget {
  final String text;
  const _MessageBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

/// Same visual as the login/register logo badge, so the waiting screen feels
/// like part of the auth flow.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.sargeGold.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.sargeGold.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/sarge_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.hexagon_outlined,
                size: 40, color: AppColors.sargeGold),
          ),
        ),
      ),
    );
  }
}
