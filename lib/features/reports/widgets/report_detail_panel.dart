import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/comment_tile.dart';
import '../../../core/widgets/pending_message.dart';
import '../../../core/widgets/platform_image.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../team/models/team_models.dart';

void showReportImageFullScreen(BuildContext context, String url) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5.0,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

Color reportStatusColor(BugReport report) {
  if (report.isSuggestion) return AppColors.panelBlue;
  switch (report.status) {
    case 'investigating':
      return AppColors.warning;
    case 'done':
      return AppColors.success;
    default:
      return AppColors.error;
  }
}

IconData reportStatusIcon(BugReport report) {
  if (report.isSuggestion) return Icons.lightbulb_outline;
  switch (report.status) {
    case 'investigating':
      return Icons.search;
    case 'done':
      return Icons.check_circle;
    default:
      return Icons.bug_report_outlined;
  }
}

class ReportDetailView extends ConsumerStatefulWidget {
  final String reportId;
  final bool isAdmin;

  const ReportDetailView(
      {super.key, required this.reportId, required this.isAdmin});

  @override
  ConsumerState<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends ConsumerState<ReportDetailView> {
  final _msgCtrl = TextEditingController();
  PickedImage? _msgImage;
  Map<String, dynamic>? _replyTo;
  late final PresenceService _presenceService;
  final List<PendingMessage> _pendingMessages = [];
  int _pendingCounter = 0;
  final SmartChatScroller _scroller = SmartChatScroller(reverse: false);
  int _lastMsgCount = 0;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _reportStream;

  String get _threadKey => threadKeyFor('report_reply', widget.reportId);

  @override
  void initState() {
    super.initState();
    _reportStream = ref
        .read(firestoreProvider)
        .collection('reports')
        .doc(widget.reportId)
        .snapshots();
    _presenceService = ref.read(presenceServiceProvider);
    _presenceService.setActiveThread(_threadKey);
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      ref.read(notificationServiceProvider).resetThread(
            uid,
            'report_reply',
            widget.reportId,
          );
    }
  }

  @override
  void dispose() {
    _presenceService.clearActiveThread(_threadKey);
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(BugReport report, String newStatus) async {
    final firestore = ref.read(firestoreProvider);
    final currentUser = ref.read(authStateProvider).value;
    final currentName = ref.read(currentAppUserProvider).value?.displayName ??
        currentUser?.displayName ??
        '';
    final uid = currentUser?.uid;

    final updates = <String, dynamic>{'status': newStatus};

    if (newStatus == 'investigating' && uid != null) {
      updates['reviewedBy'] = FieldValue.arrayUnion([
        {
          'uid': uid,
          'name': currentName,
          'startedAt': Timestamp.now(),
        },
      ]);
    }

    if (newStatus == 'done') {
      updates['resolvedBy'] = uid;
      updates['resolvedByName'] = currentName;
      updates['resolvedAt'] = FieldValue.serverTimestamp();
    }

    try {
      await firestore
          .collection('reports')
          .doc(widget.reportId)
          .update(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'done'
                ? 'Çözüldü olarak işaretlendi.'
                : newStatus == 'investigating'
                    ? 'İnceleniyor.'
                    : 'Yeni durumuna alındı.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _sendMessage(BugReport report) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _msgImage == null) return;

    final currentUser = ref.read(authStateProvider).value;
    final currentName = currentUser?.displayName ?? 'Kullanıcı';
    final uid = currentUser?.uid ?? '';
    final replyTo = _replyTo;

    final pending = PendingMessage(
      localId:
          'pending_${++_pendingCounter}_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      senderUid: uid,
      senderName: currentName,
      isAdmin: widget.isAdmin,
      images: _msgImage != null ? [PendingAttachedImage(_msgImage!)] : const [],
      replyToId: replyTo?['id'] as String?,
      replyToText: replyTo?['text'] as String?,
      replyToAuthor: replyTo?['senderName'] as String?,
      replyToUid: replyTo?['senderUid'] as String?,
    );

    setState(() {
      _pendingMessages.add(pending);
      _msgCtrl.clear();
      _msgImage = null;
      _replyTo = null;
    });

    await _persistPending(pending);
  }

  Future<void> _persistPending(PendingMessage pending) async {
    if (pending.failed) {
      setState(() => pending.failed = false);
    }

    String? imageUrl;
    try {
      if (pending.images.isNotEmpty) {
        final img = pending.images.first.image;
        final tempId = 'msg_${DateTime.now().microsecondsSinceEpoch}';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('report_messages/$tempId.jpg');
        final compressed = await img.compressedUploadBytes();
        if (compressed.isNotEmpty) {
          await storageRef.putData(compressed);
        } else if (img.dartFile != null) {
          await storageRef.putFile(img.dartFile!);
        } else if (img.bytes != null) {
          await storageRef.putData(img.bytes!);
        }
        imageUrl = await storageRef.getDownloadURL();
      }

      final newMsg = <String, dynamic>{
        'id': 'msg_${DateTime.now().microsecondsSinceEpoch}',
        'senderUid': pending.senderUid,
        'senderName': pending.senderName,
        'text': pending.text,
        'createdAt': Timestamp.now(),
        'isAdmin': widget.isAdmin,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (pending.replyToId != null) 'replyToId': pending.replyToId,
        if (pending.replyToText != null) 'replyToText': pending.replyToText,
        if (pending.replyToAuthor != null)
          'replyToAuthor': pending.replyToAuthor,
      };

      await ref
          .read(firestoreProvider)
          .collection('reports')
          .doc(widget.reportId)
          .update({
        'messages': FieldValue.arrayUnion([newMsg]),
      });

      if (mounted) {
        setState(() {
          _pendingMessages.remove(pending);
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _reportStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data == null ||
            !snapshot.data!.exists) {
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.5,
            maxChildSize: 0.5,
            expand: false,
            builder: (_, __) => Center(
              child: Text('Bildirim bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        final report = BugReport.fromDoc(snapshot.data!);
        final messages = report.messages;
        final currentUid = ref.read(authStateProvider).value?.uid;

        final msgCount = messages.length + _pendingMessages.length;
        if (msgCount > _lastMsgCount) {
          final isMine = _pendingMessages.isNotEmpty ||
              (messages.isNotEmpty &&
                  messages.last['senderUid'] == currentUid);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scroller.onNewMessage(isMine: isMine);
          });
        }
        _lastMsgCount = msgCount;

        return DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.9,
          maxChildSize: 1.0,
          expand: false,
          builder: (context, scrollController) {
            _scroller.attach(scrollController);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                      Row(
                        children: [
                          Icon(reportStatusIcon(report),
                              size: 20, color: reportStatusColor(report)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              report.title.isEmpty
                                  ? report.message
                                  : report.title,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (report.isSuggestion)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.panelBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColors.panelBlue
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'Öneri',
                                style: TextStyle(
                                  color: AppColors.panelBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: reportStatusColor(report)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: reportStatusColor(report)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                report.statusLabel,
                                style: TextStyle(
                                  color: reportStatusColor(report),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            'Bildiren: ${report.submittedByName}',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                          if (report.createdAt != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.schedule,
                                size: 12,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.7)),
                            const SizedBox(width: 2),
                            Text(
                              DateFormat('dd MMM yyyy, HH:mm', 'tr_TR')
                                  .format(report.createdAt!),
                              style: TextStyle(
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.7),
                                  fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                      if (report.message.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(report.message,
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  height: 1.5)),
                        ),
                      ],
                      if (report.imageUrl != null &&
                          report.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => showReportImageFullScreen(
                              context, report.imageUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              report.imageUrl!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              cacheWidth: 800,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                      if (report.reviewedBy.isNotEmpty &&
                          report.status != 'done') ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: report.reviewedBy.map((r) {
                            final name = r['name'] as String? ?? '';
                            return Chip(
                              label: Text('İnceleyen: $name',
                                  style: const TextStyle(fontSize: 10)),
                              backgroundColor:
                                  AppColors.warning.withValues(alpha: 0.1),
                              side: BorderSide.none,
                              avatar: const Icon(Icons.person_outline,
                                  size: 12, color: AppColors.warning),
                            );
                          }).toList(),
                        ),
                      ],
                      if (report.resolvedByName != null &&
                          report.resolvedByName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text('${report.resolvedByName} tarafından çözüldü',
                                style: const TextStyle(
                                    color: AppColors.success, fontSize: 12)),
                          ],
                        ),
                        if (report.resolvedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Çözüm: ${DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(report.resolvedAt!)}',
                            style: TextStyle(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.7),
                                fontSize: 11),
                          ),
                        ],
                      ],
                      if (widget.isAdmin) ...[
                        const SizedBox(height: 12),
                        Divider(color: AppColors.border),
                        const SizedBox(height: 8),
                        Text(
                          'DURUM DEĞİŞTİR',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (report.status != 'done')
                              ReportStatusActionButton(
                                label: 'Çözüldü',
                                color: AppColors.success,
                                icon: Icons.check_circle_outline,
                                isFilled: true,
                                onTap: () => _updateStatus(report, 'done'),
                              ),
                            if (report.status == 'open')
                              ReportStatusActionButton(
                                label: 'İncele',
                                color: AppColors.warning,
                                icon: Icons.search,
                                isFilled: true,
                                onTap: () =>
                                    _updateStatus(report, 'investigating'),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Divider(color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Mesajlar (${messages.length})',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (messages.isEmpty && _pendingMessages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('Henüz mesaj yok.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ),
                        )
                      else ...[
                        ...messages.map((msg) {
                          final data = Map<String, dynamic>.from(msg);
                          return ChatBubble(
                            data: data,
                            isMine: msg['senderUid'] == currentUid,
                            onReply: () => setState(() => _replyTo = {
                              'id': msg['id'] as String? ?? '',
                              'text': msg['text'] as String? ?? '',
                              'senderName':
                                  msg['senderName'] as String? ?? '',
                              'senderUid': msg['senderUid'] as String? ?? '',
                            }),
                          );
                        }),
                        ..._pendingMessages.map((pending) {
                          return PendingMessageBubble(
                            message: pending,
                            uploading: !pending.failed,
                            onRetry: () => _persistPending(pending),
                          );
                        }),
                      ],
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
              Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_replyTo != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ReplyPreviewBar(
                                    author: _replyTo!['senderName'] as String? ??
                                        'Bilinmeyen',
                                    text: _replyTo!['text'] as String? ?? '',
                                    onClear: () =>
                                        setState(() => _replyTo = null),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_msgImage != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: PlatformImageFile(
                                        bytes: _msgImage!.bytes,
                                        file: _msgImage!.dartFile,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _msgImage = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: AppColors.error,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close,
                                              size: 10, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            IconButton(
                              icon:
                                  const Icon(Icons.image_outlined, size: 22),
                              color: AppColors.textSecondary,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final img =
                                    await PickedImage.pick(ImageSource.gallery);
                                if (img != null && mounted) {
                                  setState(() => _msgImage = img);
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                maxLines: 4,
                                minLines: 1,
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Mesaj yazın...',
                                  hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                  border: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(20)),
                                    borderSide:
                                        BorderSide(color: AppColors.border),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 9),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.send,
                                  size: 20, color: AppColors.primaryGreen),
                              onPressed: () => _sendMessage(report),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ReportStatusActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool isFilled;
  final VoidCallback onTap;

  const ReportStatusActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.isFilled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return isFilled
        ? ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
  }
}