import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/routing/notification_router.dart';
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
            return  Center(
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
              final relatedId = targetIdOfMap(n);
              final count = (n['count'] as num?)?.toInt() ?? 0;
              final hasCounter = !isRead && count > 0;

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
                  hasCounter
                      ? '${n['body']} ($count yeni mesaj)'
                      : (n['body'] as String? ?? ''),
                  style:  TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: isRead
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasCounter ? '$count' : '•',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                onTap: () async {
                  final notificationId = n['id'] as String;
                  if (!isRead && uid != null) {
                    await ref
                        .read(notificationServiceProvider)
                        .markRead(notificationId);
                  }
                  if (context.mounted) {
                    final location =
                        locationForNotificationType(type, relatedId: relatedId);
                    context.go(location,
                        extra: relatedId != null && relatedId.isNotEmpty
                            ? relatedId
                            : null);
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
               Icon(Icons.error_outline,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
               Text(
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