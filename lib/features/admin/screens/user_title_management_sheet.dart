import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../services/user_title_service.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Opens a bottom sheet for managing a user's titles (add / retire / remove).
///
/// This mirrors the existing "Birim Sorumlusu Yap" flow and is intended to be
/// triggered from an admin-only action menu.
Future<void> showUserTitleManagementSheet(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _UserTitleManagementSheet(user: user),
  );
}

class _UserTitleManagementSheet extends ConsumerWidget {
  final AppUser user;
  const _UserTitleManagementSheet({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the live profile so the list updates after add/retire/remove.
    final profileAsync = ref.watch(userProfileProvider(user.uid));
    final liveUser = profileAsync.valueOrNull ?? user;
    final active = liveUser.activeTitles;
    final former = liveUser.formerTitles;

    final service = ref.read(userTitleServiceProvider);

    void invalidate() => ref.invalidate(userProfileProvider(user.uid));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ünvanları Yönet — ${liveUser.displayName}',
                      style:  TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:  Icon(Icons.close,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const _SectionLabel('GÜNCEL ÜNVANLAR'),
                    if (active.isEmpty)
                      const _EmptyText('Güncel ünvan yok.')
                    else
                      ...active.map(
                        (t) => _TitleRow(
                          uid: user.uid,
                          title: t,
                          service: service,
                          onChanged: (_) => invalidate(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (former.isNotEmpty) ...[
                      const _SectionLabel('GEÇMİŞ ÜNVANLAR'),
                      ...former.map(
                        (t) => _TitleRow(
                          uid: user.uid,
                          title: t,
                          service: service,
                          onChanged: (_) => invalidate(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddTitleDialog(
                            context, ref, service),
                        icon: const Icon(Icons.add_circle_outline,
                            size: 18),
                        label: const Text('Ünvan Ekle'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: BorderSide(
                              color: AppColors.primaryGreen
                                  .withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTitleDialog(
    BuildContext context,
    WidgetRef ref,
    UserTitleService service,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
               Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Ünvan Seç',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...UserTitleService.titleOptions.map((option) {
                final type = option['type']!;
                final label = option['label']!;
                return ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined,
                      size: 18, color: AppColors.sargeGold),
                  title: Text(label,
                      style:  TextStyle(
                          color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    String? unitName;
                    if (type == TitleType.unitLead) {
                      unitName = await _promptUnitName(context);
                      if (unitName == null || unitName.trim().isEmpty) {
                        return;
                      }
                    }
                    try {
                      await service.addTitle(
                        uid: user.uid,
                        titleType: type,
                        unitName: unitName?.trim(),
                      );
                      if (context.mounted) {
                        ref.invalidate(userProfileProvider(user.uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ünvan eklendi: $label'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Eklenemedi: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _promptUnitName(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Birim Sorumlusu'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Birim adı (örn: Elektrik)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends ConsumerWidget {
  final String uid;
  final UserTitle title;
  final UserTitleService service;
  final void Function(String?) onChanged;

  const _TitleRow({
    required this.uid,
    required this.title,
    required this.service,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: title.isActive
              ? AppColors.primaryGreen.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.displayLabel,
                  style: TextStyle(
                    color: title.isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_dateFormat.format(title.startDate)}'
                  '${title.endDate != null ? ' → ${_dateFormat.format(title.endDate!)}' : ''}',
                  style:  TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon:  Icon(Icons.more_vert,
                size: 18, color: AppColors.textSecondary),
            onSelected: (action) async {
              switch (action) {
                case 'retire':
                  final confirmed = await _confirm(
                    context,
                    'Ünvanı Eskiye Al',
                    '"${title.displayLabel}" eski ünvan olarak '
                    'işaretlenecek.',
                  );
                  if (confirmed != true) return;
                  try {
                    await service.retireTitle(uid: uid, titleId: title.id);
                    onChanged(title.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('İşlem başarısız: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                  break;
                case 'remove':
                  final confirmed = await _confirm(
                    context,
                    'Ünvanı Sil',
                    '"${title.displayLabel}" tamamen silinecek.',
                  );
                  if (confirmed != true) return;
                  try {
                    await service.removeTitle(uid: uid, titleId: title.id);
                    onChanged(title.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Silinemedi: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                  break;
              }
            },
            itemBuilder: (_) => [
              if (title.isActive)
                const PopupMenuItem(
                  value: 'retire',
                  child: Text('Eskiye Al'),
                ),
              const PopupMenuItem(
                value: 'remove',
                child: Text('Sil',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(
      BuildContext context, String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style:  TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style:  TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }
}