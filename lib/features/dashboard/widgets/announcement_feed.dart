import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/comment_tile.dart';
import '../../../core/widgets/custom_delete_button.dart';
import '../../../core/widgets/pending_message.dart';
import '../../../core/widgets/platform_image.dart';
import '../../announcements/models/announcement_models.dart';
import '../../announcements/providers/announcement_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../team/providers/team_providers.dart';
import '../../../core/utils/safe_date.dart';

Color announcementStatusColor(String status) {
  return switch (status) {
    'Geçti' => AppColors.textSecondary,
    'Çok Yakında' => AppColors.warning,
    'Yakında' => AppColors.success,
    _ => AppColors.textSecondary,
  };
}

class AnnouncementCard extends ConsumerWidget {
  final Announcement announcement;
  final bool isAdmin;

  const AnnouncementCard(
      {super.key, required this.announcement, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = announcement.eventStatus;
    final Color? statusColor = switch (status) {
      'Geçti' => AppColors.textSecondary,
      'Çok Yakında' => AppColors.warning,
      'Yakında' => AppColors.success,
      _ => null,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAnnouncementDetail(context, ref, announcement),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (announcement.imageUrl != null &&
                announcement.imageUrl!.isNotEmpty)
              ClipRRect(
                child: Image.network(
                  announcement.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: AppColors.surface2,
                    child: Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AnnouncementCommentBadge(
                          announcementId: announcement.id),
                      if (status.isNotEmpty && statusColor != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (announcement.eventDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          SafeDate.dayShortMonthYear(announcement.eventDate!),
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    announcement.description,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        announcement.createdByName,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        SafeDate.dayShortMonthYear(announcement.createdAt),
                        style: TextStyle(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 11),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        AppIconButton(
                          icon: Icons.edit_outlined,
                          iconSize: 16,
                          color: AppColors.panelBlue,
                          tooltip: 'Düzenle',
                          onTap: () => editAnnouncement(context, announcement),
                        ),
                        CustomDeleteButton(
                          onPressed: () => deleteAnnouncement(
                              context, ref, announcement),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void openAnnouncementDetail(
      BuildContext context, WidgetRef ref, Announcement announcement) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final isAdminUser = ref.read(isAdminProvider);

    bool canComment = isAdminUser;
    if (!canComment && uid != null) {
      if (announcement.isClubWide) {
        canComment = true;
      } else {
        final teamsAsync = ref.read(clubTeamsProvider);
        final allTeams = teamsAsync.valueOrNull ?? [];
        for (final teamId in announcement.targetTeamIds) {
          try {
            final team = allTeams.firstWhere((t) => t.id == teamId);
            if (team.memberIds.contains(uid)) {
              canComment = true;
              break;
            }
          } catch (_) {}
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AnnouncementDetailSheet(
        announcement: announcement,
        canComment: canComment,
      ),
    );
  }

  static void editAnnouncement(
      BuildContext context, Announcement announcement) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AnnouncementDialog(existing: announcement),
    );
  }

  static void deleteAnnouncement(
      BuildContext context, WidgetRef ref, Announcement announcement) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duyuruyu Sil'),
        content: Text('"${announcement.title}" silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      if (!context.mounted) return;
      final container = ProviderScope.containerOf(context);
      await runDeleteWithFeedback(
        context: context,
        successMessage: 'Duyuru başarıyla silindi.',
        operation: () => container
            .read(announcementRepositoryProvider)
            .deleteAnnouncement(announcement.id),
      );
    });
  }
}

class AnnouncementDialog extends ConsumerStatefulWidget {
  final Announcement? existing;

  const AnnouncementDialog({super.key, this.existing});

  @override
  ConsumerState<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends ConsumerState<AnnouncementDialog> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _descCtrl = TextEditingController(
      text: widget.existing?.description ?? '');
  PickedImage? _pickedImage;
  DateTime? _eventDate;
  bool _notifyAll = false;
  bool _loading = false;
  String _targetType = 'club';
  List<String> _targetTeamIds = const [];

  @override
  void initState() {
    super.initState();
    _eventDate = widget.existing?.eventDate;
    _notifyAll = widget.existing?.notifyAll ?? false;
    _targetType = widget.existing?.targetType ?? 'club';
    _targetTeamIds = widget.existing?.targetTeamIds ?? const [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = picked);
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Başlık ve açıklama zorunludur'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      final repo = ref.read(announcementRepositoryProvider);
      String? imageUrl = widget.existing?.imageUrl;
      if (_pickedImage != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await repo.uploadImage(
          tempId,
          file: _pickedImage!.dartFile,
          bytes: _pickedImage!.bytes,
        );
      }

      if (widget.existing == null) {
        await repo.addAnnouncement(
          title: _titleCtrl.text,
          description: _descCtrl.text,
          imageUrl: imageUrl,
          eventDate: _eventDate,
          createdBy: user?.uid ?? '',
          createdByName: user?.displayName ?? 'Kullanıcı',
          notifyAll: _notifyAll,
          targetType: _targetType,
          targetTeamIds: _targetTeamIds,
        );
      } else {
        await repo.updateAnnouncement(
          widget.existing!.id,
          title: _titleCtrl.text,
          description: _descCtrl.text,
          imageUrl: imageUrl,
          eventDate: _eventDate,
          notifyAll: _notifyAll,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Duyuru' : 'Duyuruyu Düzenle'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Başlık *', hintText: 'Duyuru başlığı'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Açıklama *', hintText: 'Duyuru detayı'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: Text(_pickedImage != null
                          ? 'Görsel Seçildi'
                          : (widget.existing?.imageUrl != null
                              ? 'Görsel Değiştir'
                              : 'Görsel Ekle')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: _pickEventDate,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _eventDate != null
                            ? SafeDate.dayShortMonthYear(_eventDate!)
                            : 'Etkinlik Tarihi',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 8),
              AnnouncementTargetAudienceSelector(
                targetType: _targetType,
                targetTeamIds: _targetTeamIds,
                onChanged: (type, teamIds) => setState(() {
                  _targetType = type;
                  _targetTeamIds = teamIds;
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      size: 18, color: AppColors.panelBlue),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('Herkese bildirim gönder',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 13)),
                  ),
                  Switch(
                    value: _notifyAll,
                    activeThumbColor: AppColors.panelBlue,
                    onChanged: (v) => setState(() => _notifyAll = v),
                  ),
                ],
              ),
              if (_pickedImage != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: PlatformImageFile(
                      bytes: _pickedImage!.bytes,
                      file: _pickedImage!.dartFile,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Yayınla'),
        ),
      ],
    );
  }
}

class AnnouncementTargetAudienceSelector extends ConsumerWidget {
  final String targetType;
  final List<String> targetTeamIds;
  final void Function(String type, List<String> teamIds) onChanged;

  const AnnouncementTargetAudienceSelector({
    super.key,
    required this.targetType,
    required this.targetTeamIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final teams = teamsAsync.valueOrNull ?? [];

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.public, size: 16, color: AppColors.panelBlue),
            const SizedBox(width: 8),
            Text('Hedef Kitle',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: targetType,
                  isDense: true,
                  dropdownColor: AppColors.surface2,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'club', child: Text('Tüm Kulübe')),
                    DropdownMenuItem(
                        value: 'team', child: Text('Belirli Takımlara')),
                  ],
                  onChanged: (v) => onChanged(v ?? 'club', const []),
                ),
              ),
            ),
          ],
        ),
        if (targetType == 'team') ...[
          const SizedBox(height: 8),
          teamsAsync.when(
            data: (_) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: teams
                    .map((t) => FilterChip(
                          label: Text(t.name,
                              style: const TextStyle(fontSize: 11)),
                          selected: targetTeamIds.contains(t.id),
                          selectedColor:
                              AppColors.panelBlue.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.panelBlue,
                          onSelected: (selected) {
                            final newList =
                                List<String>.from(targetTeamIds);
                            if (selected) {
                              newList.add(t.id);
                            } else {
                              newList.remove(t.id);
                            }
                            onChanged('team', newList);
                          },
                        ))
                    .toList(),
              ),
            ),
            loading: () => const SizedBox(
                height: 20,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class AnnouncementCommentBadge extends ConsumerWidget {
  final String announcementId;
  const AnnouncementCommentBadge({super.key, required this.announcementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('announcements')
          .doc(announcementId)
          .collection('comments')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.panelBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.panelBlue.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💬', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text('$count',
                  style: const TextStyle(
                      color: AppColors.panelBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

class AnnouncementDetailSheet extends ConsumerStatefulWidget {
  final Announcement announcement;
  final bool canComment;

  const AnnouncementDetailSheet({
    super.key,
    required this.announcement,
    required this.canComment,
  });

  @override
  ConsumerState<AnnouncementDetailSheet> createState() =>
      _AnnouncementDetailSheetState();
}

class _AnnouncementDetailSheetState
    extends ConsumerState<AnnouncementDetailSheet> {
  final _commentCtrl = TextEditingController();
  List<PickedImage> _commentImages = [];
  Map<String, dynamic>? _replyTo;
  late final PresenceService _presenceService;
  final List<PendingMessage> _pendingComments = [];
  int _pendingCounter = 0;
  final SmartChatScroller _scroller = SmartChatScroller(reverse: false);

  String get _threadKey =>
      threadKeyFor('announcement_comment', widget.announcement.id);

  @override
  void initState() {
    super.initState();
    _presenceService = ref.read(presenceServiceProvider);
    _presenceService.setActiveThread(_threadKey);
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      ref.read(notificationServiceProvider).resetThread(
            uid,
            'announcement_comment',
            widget.announcement.id,
          );
    }
  }

  @override
  void dispose() {
    _presenceService.clearActiveThread(_threadKey);
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty && _commentImages.isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    final uid = user?.uid ?? '';
    final name = user?.displayName ?? 'Kullanıcı';
    final isAdmin = ref.read(isAdminProvider);
    final replyTo = _replyTo;

    final pending = PendingMessage(
      localId:
          'pending_${++_pendingCounter}_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      senderUid: uid,
      senderName: name,
      isAdmin: isAdmin,
      images: _commentImages.map((i) => PendingAttachedImage(i)).toList(),
      replyToId: replyTo?['id'] as String?,
      replyToText: replyTo?['text'] as String?,
      replyToAuthor: replyTo?['senderName'] as String?,
      replyToUid: replyTo?['senderUid'] as String?,
    );

    setState(() {
      _pendingComments.add(pending);
      _commentImages = [];
      _replyTo = null;
    });
    _commentCtrl.clear();

    await _persistPendingComment(pending);
  }

  Future<void> _persistPendingComment(PendingMessage pending) async {
    if (pending.failed) {
      setState(() => pending.failed = false);
    }

    final firestore = ref.read(firestoreProvider);

    try {
      final imageUrls = <String>[];
      for (final attached in pending.images) {
        final img = attached.image;
        final tempId =
            'announcement_comment_${DateTime.now().microsecondsSinceEpoch}';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('announcement_comments/$tempId.jpg');
        final compressed = await img.compressedUploadBytes();
        if (compressed.isNotEmpty) {
          await storageRef.putData(compressed);
        } else if (img.bytes != null) {
          await storageRef.putData(img.bytes!);
        } else if (img.dartFile != null) {
          await storageRef.putFile(img.dartFile!);
        }
        imageUrls.add(await storageRef.getDownloadURL());
      }

      await firestore
          .collection('announcements')
          .doc(widget.announcement.id)
          .collection('comments')
          .add({
        'senderUid': pending.senderUid,
        'senderName': pending.senderName,
        'text': pending.text,
        'imageUrls': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'isAdmin': pending.isAdmin,
        'replyToId': pending.replyToId,
        'replyToText': pending.replyToText,
        'replyToAuthor': pending.replyToAuthor,
        'replyToUid': pending.replyToUid,
      });

      if (mounted) {
        setState(() {
          _pendingComments.remove(pending);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          pending.failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcement = widget.announcement;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final status = announcement.eventStatus;
    final Color? statusColor = switch (status) {
      'Geçti' => AppColors.textSecondary,
      'Çok Yakında' => AppColors.warning,
      'Yakında' => AppColors.success,
      _ => null,
    };

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.9,
      maxChildSize: 1.0,
      expand: true,
      builder: (context, scrollController) {
        _scroller.attach(scrollController);
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (status.isNotEmpty && statusColor != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(announcement.createdByName,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        SafeDate.dayShortMonthYearTime(announcement.createdAt),
                        style: TextStyle(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                    ],
                  ),
                  if (announcement.eventDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.event_outlined,
                            size: 13, color: AppColors.panelBlue),
                        const SizedBox(width: 4),
                        Text(
                          'Etkinlik: ${SafeDate.dayShortMonthYear(announcement.eventDate!)}',
                          style: const TextStyle(
                              color: AppColors.panelBlue, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    announcement.description,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  if (announcement.imageUrl != null &&
                      announcement.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        announcement.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Divider(color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          'Yorumlar',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnnouncementCommentsList(
                    announcementId: announcement.id,
                    currentUid: ref.read(authStateProvider).valueOrNull?.uid,
                    pendingComments: _pendingComments,
                    onRetryPending: (pending) =>
                        _persistPendingComment(pending),
                    onReply: (data) => setState(() => _replyTo = data),
                    onNewMessage: (isMine) =>
                        _scroller.onNewMessage(isMine: isMine),
                  ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    Positioned.fill(
                      child: ChatScrollOverlay(
                        scroller: _scroller,
                        accentColor: AppColors.panelBlue,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.canComment)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyTo != null) ...[
                      ReplyPreviewBar(
                        author:
                            _replyTo!['senderName'] as String? ?? 'Bilinmeyen',
                        text: _replyTo!['text'] as String? ?? '',
                        onClear: () => setState(() => _replyTo = null),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_commentImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _commentImages.asMap().entries.map((e) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: PlatformImageFile(
                                    bytes: e.value.bytes,
                                    file: e.value.dartFile,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _commentImages.removeAt(e.key)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image_outlined, size: 20),
                          color: AppColors.textSecondary,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            final imgs = await PickedImage.pickMultiple();
                            if (imgs.isNotEmpty && mounted) {
                              setState(() => _commentImages = [
                                    ..._commentImages,
                                    ...imgs
                                  ]);
                            }
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            style: TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Yorum yaz...',
                              hintStyle: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                              filled: true,
                              fillColor: AppColors.surface2,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sendComment,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.panelBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnnouncementCommentsList extends ConsumerStatefulWidget {
  final String announcementId;
  final String? currentUid;
  final List<PendingMessage> pendingComments;
  final void Function(PendingMessage) onRetryPending;
  final void Function(Map<String, dynamic>) onReply;
  final void Function(bool isMine)? onNewMessage;
  const AnnouncementCommentsList({
    super.key,
    required this.announcementId,
    this.currentUid,
    this.pendingComments = const [],
    required this.onRetryPending,
    required this.onReply,
    this.onNewMessage,
  });

  @override
  ConsumerState<AnnouncementCommentsList> createState() =>
      _AnnouncementCommentsListState();
}

class _AnnouncementCommentsListState
    extends ConsumerState<AnnouncementCommentsList> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  int? _lastCount;

  @override
  void initState() {
    super.initState();
    _stream = ref
        .read(firestoreProvider)
        .collection('announcements')
        .doc(widget.announcementId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.panelBlue),
            ),
          );
        }
        final comments = snapshot.data?.docs ?? [];
        if (comments.isEmpty && widget.pendingComments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('Henüz yorum yapılmadı.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          );
        }

        final orderedComments = comments.reversed.toList();
        final combined = [...widget.pendingComments, ...orderedComments];

        final totalCount = combined.length;
        final previous = _lastCount;
        if (previous != null && totalCount > previous) {
          final isMine = widget.pendingComments.isNotEmpty ||
              (orderedComments.isNotEmpty &&
                  orderedComments.first.data()['senderUid'] ==
                      widget.currentUid);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onNewMessage?.call(isMine);
          });
        }
        _lastCount = totalCount;

        return ListView.builder(
          reverse: true,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: combined.length,
          itemBuilder: (_, i) {
            final item = combined[i];
            if (item is PendingMessage) {
              return PendingMessageBubble(
                message: item,
                uploading: !item.failed,
                onRetry: () => widget.onRetryPending(item),
              );
            }
            final doc = item as QueryDocumentSnapshot<Map<String, dynamic>>;
            final data = doc.data();
            return CommentTile(
              data: data,
              isMine: data['senderUid'] == widget.currentUid,
              onReply: () => widget.onReply({
                'id': doc.id,
                'text': data['text'] as String? ?? '',
                'senderName': data['senderName'] as String? ?? '',
                'senderUid': data['senderUid'] as String? ?? '',
              }),
            );
          },
        );
      },
    );
  }
}