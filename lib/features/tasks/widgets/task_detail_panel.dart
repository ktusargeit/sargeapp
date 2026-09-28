import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/comment_tile.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/pending_message.dart';
import '../../../core/widgets/platform_image.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../team/providers/team_providers.dart';
import '../models/task_models.dart';
import '../providers/task_providers.dart';
import 'task_list.dart';

class TaskDetailSheet extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailSheet({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  final _commentCtrl = TextEditingController();
  List<PickedImage> _commentImages = [];
  Map<String, dynamic>? _replyTo;
  late final PresenceService _presenceService;
  final List<PendingMessage> _pendingComments = [];
  int _pendingCounter = 0;

  String get _threadKey => threadKeyFor('task_comment', widget.taskId);

  @override
  void initState() {
    super.initState();
    _presenceService = ref.read(presenceServiceProvider);
    _presenceService.setActiveThread(_threadKey);
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      ref.read(notificationServiceProvider).resetThread(
            uid,
            'task_comment',
            widget.taskId,
          );
    }
  }

  @override
  void dispose() {
    _presenceService.clearActiveThread(_threadKey);
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<List<String>> _uploadCommentImages(List<PickedImage> images) async {
    final urls = <String>[];
    for (final img in images) {
      final tempId = 'task_comment_${DateTime.now().microsecondsSinceEpoch}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('task_comments/$tempId.jpg');
      debugPrint(
          '[task-comment-upload] path=${storageRef.fullPath} uid=${ref.read(authStateProvider).valueOrNull?.uid}');
      final compressed = await img.compressedUploadBytes();
      if (compressed.isNotEmpty) {
        await storageRef.putData(compressed);
      } else if (img.bytes != null) {
        await storageRef.putData(img.bytes!);
      } else if (img.dartFile != null) {
        await storageRef.putFile(img.dartFile!);
      }
      urls.add(await storageRef.getDownloadURL());
    }
    return urls;
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
      final imageUrls = await _uploadCommentImages(
          pending.images.map((a) => a.image).toList());

      await firestore
          .collection('tasks')
          .doc(widget.taskId)
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

  Future<void> _updateStatus(TaskStatus newStatus) async {
    try {
      await ref
          .read(firestoreProvider)
          .collection('tasks')
          .doc(widget.taskId)
          .update({'status': newStatus.name});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  bool _computeCanApprove(TaskModel task) {
    final appUser = ref.read(currentAppUserProvider).valueOrNull;
    if (appUser?.isAdmin ?? false) return true;
    if (appUser?.isUnitLead ?? false) return true;
    final uid = appUser?.uid;
    if (uid != null && task.teamId != null) {
      final teams = ref.read(clubTeamsProvider).valueOrNull ?? [];
      try {
        final team = teams.firstWhere((t) => t.id == task.teamId);
        return team.leadUid == uid;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<void> _submitForApproval() async {
    final firestore = ref.read(firestoreProvider);
    try {
      final taskDoc = await firestore.collection('tasks').doc(widget.taskId).get();
      final data = taskDoc.data() ?? {};
      final creatorId = data['assignedBy'] as String?;
      final title = data['title'] as String? ?? 'Görev';
      final assigneeName = data['assignedToName'] as String? ?? 'Kullanıcı';

      await firestore.collection('tasks').doc(widget.taskId).update({
        'status': 'pendingApproval',
        'completedAt': FieldValue.serverTimestamp(),
      });

      try {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (creatorId != null && creatorId.isNotEmpty && creatorId != uid) {
          await ref.read(notificationServiceProvider).send(
                recipientId: creatorId,
                title: 'Görev onaya gönderildi: $title',
                body: '$assigneeName görevi teslim etti, onay bekliyor.',
                type: 'task_submitted',
                relatedId: widget.taskId,
              );
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Görev teslim edildi, onay bekleniyor.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görevi Teslim Et'),
        content: const Text('Görevi teslim etmek istediğinize emin misiniz?\n\n'
            'Teslim edildiğinde görev onay beklemeye alınacaktır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitForApproval();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Evet, teslim et'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.read(authStateProvider).valueOrNull?.uid;
    final taskAsync = ref.watch(taskDocProvider(widget.taskId));

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.9,
      maxChildSize: 1.0,
      expand: true,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: taskAsync.when(
          data: (task) {
            final isAssignee = task.assignedTo == currentUid;
            final canApprove = _computeCanApprove(task);
            return Column(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(task.title,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (task.status == TaskStatus.completed
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(task.statusLabel,
                            style: TextStyle(
                              color: task.status == TaskStatus.completed
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.description.isNotEmpty) ...[
                        Text(task.description,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 10),
                      ],
                      TaskMetaRow(
                          label: 'Atanan',
                          value: task.assignedToName.isNotEmpty ? task.assignedToName : '—'),
                      TaskMetaRow(
                          label: 'Atayan',
                          value: task.assignedByName.isNotEmpty ? task.assignedByName : '—'),
                      TaskMetaRow(label: 'Durum', value: task.statusLabel),
                      if (task.teamName != null) TaskMetaRow(label: 'Takım', value: task.teamName!),
                      if (task.unitName != null) TaskMetaRow(label: 'Birim', value: task.unitName!),
                      TaskMetaRow(label: 'Puan', value: '${task.points}'),
                      if (task.pointsAwarded) const TaskMetaRow(label: 'Puan Durumu', value: 'Verildi ✓'),
                      if (task.imageUrl != null && task.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => openNetworkImageViewer(context, task.imageUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              task.imageUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      if (isAssignee && task.status == TaskStatus.assigned)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus(TaskStatus.inProgress),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Göreve Başla'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.tasksAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (isAssignee && task.status == TaskStatus.inProgress)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmSubmit,
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: const Text('Görevi Teslim Et'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (task.status == TaskStatus.pendingApproval && canApprove) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _approve(false),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reddet'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approve(true),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Onayla'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(color: AppColors.border, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('Yorumlar',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Expanded(
                  child: TaskCommentsList(
                    taskId: widget.taskId,
                    pendingComments: _pendingComments,
                    currentUid: currentUid,
                    onRetryPending: (pending) =>
                        _persistPendingComment(pending),
                    onReply: (data) => setState(() => _replyTo = data),
                  ),
                ),
                TaskCommentInputBar(
                  controller: _commentCtrl,
                  images: _commentImages,
                  replyTo: _replyTo,
                  onClearReply: () => setState(() => _replyTo = null),
                  onPickImages: () async {
                    final imgs = await PickedImage.pickMultiple();
                    if (imgs.isNotEmpty && mounted) {
                      setState(() => _commentImages = [..._commentImages, ...imgs]);
                    }
                  },
                  onRemoveImage: (i) => setState(() => _commentImages.removeAt(i)),
                  onSend: _sendComment,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Görev yüklenemedi: $e')),
        ),
      ),
    );
  }

  Future<void> _approve(bool approve) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final firestore = ref.read(firestoreProvider);
    try {
      final taskDoc = await firestore.collection('tasks').doc(widget.taskId).get();
      final data = taskDoc.data() ?? {};
      final assignedTo = data['assignedTo'] as String? ?? '';
      final assignedToName = data['assignedToName'] as String? ?? '';
      final teamId = data['teamId'] as String?;
      final teamName = data['teamName'] as String?;
      final points = (data['points'] as num?)?.toInt() ?? 0;
      final alreadyAwarded = (data['pointsAwarded'] as bool?) ?? false;

      if (approve) {
        final batch = firestore.batch();
        batch.update(firestore.collection('tasks').doc(widget.taskId), {
          'status': 'completed',
          'approvedBy': uid,
        });
        if (!alreadyAwarded && assignedTo.isNotEmpty) {
          batch.update(firestore.collection('users').doc(assignedTo), {
            'points': FieldValue.increment(points),
            'weeklyPoints': FieldValue.increment(points),
            if (teamId != null && teamId.isNotEmpty)
              'teamPoints.$teamId': FieldValue.increment(points),
          });
          batch.update(firestore.collection('tasks').doc(widget.taskId), {
            'pointsAwarded': true,
          });
        }
        await batch.commit();

        // Best-effort points history (admin-only per rules); non-admin
        // approvers skip this without failing the approval.
        if (!alreadyAwarded && assignedTo.isNotEmpty) {
          try {
            await firestore.collection('points_history').add({
              'targetUid': assignedTo,
              'targetName': assignedToName,
              'delta': points,
              'changedBy': uid,
              if (teamId != null) 'teamId': teamId,
              if (teamName != null) 'teamName': teamName,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Görev onaylandı, puan verildi.'),
              backgroundColor: AppColors.success));
        }
      } else {
        await firestore.collection('tasks').doc(widget.taskId).update({
          'status': 'rejected',
          'approvedBy': uid,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Görev reddedildi.'), backgroundColor: AppColors.warning));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}

class TaskCommentsList extends ConsumerStatefulWidget {
  final String taskId;
  final List<PendingMessage> pendingComments;
  final String? currentUid;
  final void Function(PendingMessage) onRetryPending;
  final void Function(Map<String, dynamic>) onReply;
  const TaskCommentsList({
    super.key,
    required this.taskId,
    this.pendingComments = const [],
    this.currentUid,
    required this.onRetryPending,
    required this.onReply,
  });

  @override
  ConsumerState<TaskCommentsList> createState() => _TaskCommentsListState();
}

class _TaskCommentsListState extends ConsumerState<TaskCommentsList> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  final SmartChatScroller _scroller = SmartChatScroller(reverse: true);
  final ScrollController _scrollController = ScrollController();
  int? _lastCount;

  @override
  void initState() {
    super.initState();
    _stream = ref
        .read(firestoreProvider)
        .collection('tasks')
        .doc(widget.taskId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
    _scroller.attach(_scrollController);
  }

  @override
  void dispose() {
    _scroller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.tasksAccent));
        }
        final comments = snapshot.data?.docs ?? [];
        if (comments.isEmpty && widget.pendingComments.isEmpty) {
          return Center(
              child: Text('Henüz yorum yapılmadı.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)));
        }

        final orderedComments = comments.reversed.toList();
        final totalCount =
            widget.pendingComments.length + orderedComments.length;

        // Detect newly arrived messages and apply smart scroll behaviour.
        final previous = _lastCount;
        if (previous != null && totalCount > previous) {
          final isMine = widget.pendingComments.isNotEmpty ||
              (orderedComments.isNotEmpty &&
                  orderedComments.first.data()['senderUid'] ==
                      widget.currentUid);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scroller.onNewMessage(isMine: isMine);
          });
        }
        _lastCount = totalCount;

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: totalCount,
              itemBuilder: (_, i) {
                if (i < widget.pendingComments.length) {
                  final pending = widget.pendingComments[i];
                  return PendingMessageBubble(
                    message: pending,
                    uploading: !pending.failed,
                    onRetry: () => widget.onRetryPending(pending),
                  );
                }
                final doc = orderedComments[i - widget.pendingComments.length];
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
            ),
            Positioned.fill(
              child: ChatScrollOverlay(
                scroller: _scroller,
                accentColor: AppColors.tasksAccent,
              ),
            ),
          ],
        );
      },
    );
  }
}

class TaskCommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final List<PickedImage> images;
  final VoidCallback onPickImages;
  final void Function(int) onRemoveImage;
  final VoidCallback onSend;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onClearReply;

  const TaskCommentInputBar({
    super.key,
    required this.controller,
    required this.images,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onSend,
    this.replyTo,
    this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyTo != null) ...[
            ReplyPreviewBar(
              author: replyTo!['senderName'] as String? ?? 'Bilinmeyen',
              text: replyTo!['text'] as String? ?? '',
              onClear: onClearReply,
            ),
            const SizedBox(height: 8),
          ],
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: images.asMap().entries.map((e) {
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
                          onTap: () => onRemoveImage(e.key),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                color: AppColors.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
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
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: onPickImages,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
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
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.tasksAccent,
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
    );
  }
}