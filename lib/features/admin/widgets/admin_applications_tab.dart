import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../team/providers/team_providers.dart';

class AdminApplicationsTab extends ConsumerWidget {
  const AdminApplicationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(teamApplicationsProvider);

    return appsAsync.when(
      data: (apps) {
        final pending = apps.where((a) => a['status'] == 'pending').toList();
        if (pending.isEmpty) {
          return Center(
            child: Text('Bekleyen başvuru yok.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pending.length,
          itemBuilder: (_, i) {
            final app = pending[i];
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app['applicantName'] as String? ?? 'Bilinmiyor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Takım: ${app['teamName'] ?? ''}',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final teamId = app['teamId'] as String?;
                            final uid = app['applicantUid'] as String?;
                            if (teamId != null && uid != null) {
                              await ref
                                  .read(firestoreProvider)
                                  .collection('teams')
                                  .doc(teamId)
                                  .update({
                                'memberIds': FieldValue.arrayUnion([uid]),
                              });
                            }
                            await ref
                                .read(firestoreProvider)
                                .collection('teamApplications')
                                .doc(app['id'] as String)
                                .update({'status': 'approved'});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Onaylandı.'),
                                    backgroundColor: AppColors.success),
                              );
                            }
                          },
                          icon: const Icon(Icons.check,
                              size: 16, color: AppColors.success),
                          label: const Text('Onayla',
                              style: TextStyle(color: AppColors.success)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await ref
                                .read(firestoreProvider)
                                .collection('teamApplications')
                                .doc(app['id'] as String)
                                .update({'status': 'rejected'});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Reddedildi.'),
                                    backgroundColor: AppColors.warning),
                              );
                            }
                          },
                          icon: const Icon(Icons.close,
                              size: 16, color: AppColors.error),
                          label: const Text('Reddet',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}