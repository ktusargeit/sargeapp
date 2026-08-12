import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authStateProvider).value?.uid;
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: AppColors.surface,
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Text('Henüz bildirim yok.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: notifications.length,
            itemBuilder: (_, i) {
              final n = notifications[i];
              final isRead = n['isRead'] as bool? ?? false;
              final type = n['type'] as String?;
              final relatedId = n['relatedId'] as String?;

              return ListTile(
                leading: Icon(
                  isRead
                      ? Icons.notifications_outlined
                      : Icons.notifications_active,
                  color: isRead
                      ? AppColors.textSecondary
                      : AppColors.primaryBlue,
                ),
                title: Text(
                  n['title'] as String? ?? '',
                  style: TextStyle(
                    color: isRead
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  n['body'] as String? ?? '',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: isRead
                    ? null
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                onTap: () async {
                  if (!isRead && uid != null) {
                    await ref
                        .read(firestoreProvider)
                        .collection('notifications')
                        .doc(n['id'] as String)
                        .update({'isRead': true});
                  }
                  if (context.mounted) {
                    if (type == 'task_assigned' && relatedId != null) {
                      // /tasks lives inside ShellRoute; use go() to cross
                      // from the root navigator into the shell navigator.
                      context.go('/tasks');
                    } else if (type == 'announcement' && relatedId != null) {
                      context.go('/dashboard');
                    }
                  }
                },
              );
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text(
                'Bildirimler yüklenirken bir sorun oluştu.\nLütfen tekrar deneyin.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(userNotificationsProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}