import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';

/// Admin -> "Kayıt Onayları" sekmesi.
///
/// Lists every user whose `users/{uid}.approvalStatus` is `'pending'` and lets
/// an admin either approve them (-> `'approved'`, they can enter the app) or
/// reject/delete them.
///
/// Both writes go through [AuthController.approveUser] / `.rejectUser` /
/// `.deleteUserDocument`. `firestore.rules` gives `isAdmin()` full update+delete
/// on the users collection, so admins do not depend on the owner-update field
/// whitelist.
class AdminApprovalsTab extends ConsumerWidget {
  const AdminApprovalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingApprovalsProvider);

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Onay bekleyen kayıtlar yüklenemedi.\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ),
      ),
      data: (pending) {
        if (pending.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [_EmptyState()],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${pending.length} kayıt onay bekliyor',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              );
            }
            return _PendingApprovalCard(user: pending[index - 1]);
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 36, color: AppColors.success),
          const SizedBox(height: 12),
          Text(
            'Onay bekleyen kayıt yok',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Yeni bir kullanıcı kayıt olduğunda burada listelenir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Returns up to two uppercase initials for [name], `'?'` when empty.
String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// One pending registration row: avatar, name, e-mail and the
/// "Onayla" / "Reddet & Sil" actions.
class _PendingApprovalCard extends ConsumerWidget {
  final AppUser user;
  const _PendingApprovalCard({required this.user});

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Onaylanıyor...',
      successMessage: '${user.displayName} onaylandı. Artık giriş yapabilir.',
      operation: () => ref.read(authControllerProvider).approveUser(user.uid),
    );
    // No manual refresh needed: `pendingApprovalsProvider` is a live snapshot
    // stream, so the row disappears on its own once the admin has decided.
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı Reddet'),
        content: Text(
          '${user.displayName} adlı kullanıcının kaydı reddedilecek ve profil '
          'kaydı silinecek. Bu kullanıcı uygulamaya giremeyecek.\n\n'
          'Not: Firebase Auth hesabı yalnızca sunucu tarafında silinebilir; '
          'kullanıcı yeniden giriş yaparsa kayıt akışı tekrar başlar.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reddet & Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await runDeleteWithFeedback(
      context: context,
      successMessage: '${user.displayName} adlı kayıt reddedildi.',
      operation: () async {
        // Mark it rejected first so the user stays blocked even if the document
        // delete fails afterwards, then remove the profile document.
        await ref.read(authControllerProvider).rejectUser(user.uid);
        await ref.read(authControllerProvider).deleteUserDocument(user.uid);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface3,
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initialsOf(user.displayName),
                  style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _approve(context, ref),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Onayla'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(context, ref),
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Reddet / Sil'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
