import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/platform_image.dart';
import '../../../core/widgets/comment_tile.dart';
import '../../../core/widgets/pending_message.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/custom_delete_button.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';

class ReportBugScreen extends ConsumerStatefulWidget {
  final String? initialReportId;
  const ReportBugScreen({super.key, this.initialReportId});

  @override
  ConsumerState<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends ConsumerState<ReportBugScreen>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  PickedImage? _pickedImage;
  bool _sending = false;
  late TabController _tabCtrl;
  String _reportType = 'bug'; // 'bug' | 'suggestion'

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final targetId = widget.initialReportId;
    if (targetId != null && targetId.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openReport(targetId));
    }
  }

  void _openReport(String id) {
    if (!mounted) return;
    final isAdmin = ref.read(isAdminProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ReportDetailView(reportId: id, isAdmin: isAdmin),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await PickedImage.pick(source);
    if (img != null && mounted) setState(() => _pickedImage = img);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Başlık zorunludur.'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _sending = true);
    try {
      final repo = ref.read(teamRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      String? imageUrl;
      if (_pickedImage != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        // Client-side compression before upload (max-1280px JPEG ~75%).
        final compressed = await _pickedImage!.compressedUploadBytes();
        imageUrl = await repo.uploadReportImage(tempId,
            file: _pickedImage!.dartFile, bytes: compressed);
      }
      final reportId = await repo.submitReport(
        title: _titleCtrl.text.trim(),
        message: _descCtrl.text.trim(),
        submittedBy: user?.uid ?? '',
        submittedByName: user?.displayName ?? 'Kullanıcı',
        imageUrl: imageUrl,
        type: _reportType,
      );

      // Notify admins/unit leads about the new report/suggestion.
      await ref.read(notificationServiceProvider).notifyAdmins(
            title: _reportType == 'suggestion' ? 'Yeni Öneri' : 'Yeni Hata Bildirimi',
            body: '${user?.displayName ?? 'Bir kullanıcı'}: ${_titleCtrl.text.trim()}',
            type: 'report',
            relatedId: reportId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bildiriminiz alındı, teşekkürler!'),
            backgroundColor: AppColors.success));
        _titleCtrl.clear();
        _descCtrl.clear();
        setState(() {
          _pickedImage = null;
          _sending = false;
          _reportType = 'bug';
        });
        _tabCtrl.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hata Bildir / Öneride Bulun'),
        backgroundColor: AppColors.surface,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primaryGreen,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Bildir'),
            Tab(text: 'Bildirilenler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildReportForm(),
          _BugListTab(isAdmin: isAdmin),
        ],
      ),
    );
  }

  Widget _buildReportForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
         Text('TÜR',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TypeOption(
                label: 'Hata',
                icon: Icons.bug_report_outlined,
                selected: _reportType == 'bug',
                color: AppColors.error,
                onTap: () => setState(() => _reportType = 'bug'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TypeOption(
                label: 'Öneri',
                icon: Icons.lightbulb_outline,
                selected: _reportType == 'suggestion',
                color: AppColors.panelBlue,
                onTap: () => setState(() => _reportType = 'suggestion'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
         Text('HATA BAŞLIĞI',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          style:  TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Örn: Depo rafı yanlış görünüyor',
            labelText: 'Başlık *',
          ),
        ),
        const SizedBox(height: 16),
         Text('AÇIKLAMA',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl,
          maxLines: 5,
          style:  TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Raf 3\'e bastığımda yanlış ürünler geliyor.',
            labelText: 'Açıklama',
          ),
        ),
        const SizedBox(height: 16),
         Text('FOTOĞRAF (İsteğe Bağlı)',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Kamera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side:  BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galeri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side:  BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        if (_pickedImage != null) ...[
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: PlatformImageFile(
                    bytes: _pickedImage!.bytes,
                    file: _pickedImage!.dartFile,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _pickedImage = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(_sending ? 'Gönderiliyor...' : 'Gönder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Type selector option (Hata / Öneri).
class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab showing the bug list with search + person filter.
class _BugListTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  const _BugListTab({required this.isAdmin});

  @override
  ConsumerState<_BugListTab> createState() => _BugListTabState();
}

class _BugListTabState extends ConsumerState<_BugListTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _personFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(bugReportsProvider);
    final allUsers = ref.watch(allUsersProvider).valueOrNull ?? [];

    return Column(
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style:  TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ara...',
                    hintStyle:  TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon:  Icon(Icons.search,
                        size: 18, color: AppColors.textSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _personFilter,
                    isDense: true,
                    dropdownColor: AppColors.surface2,
                    style:  TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    hint:  Text('Kişi',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    items: [
                      if (_personFilter != null)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tümü', style: TextStyle(fontSize: 12)),
                        ),
                      ...allUsers.map((u) => DropdownMenuItem<String?>(
                            value: u.uid,
                            child: Text(u.displayName,
                                style: const TextStyle(fontSize: 12)),
                          )),
                    ],
                    onChanged: (v) => setState(() => _personFilter = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: reportsAsync.when(
            data: (reports) {
              var filtered = reports;
              if (_personFilter != null) {
                filtered = filtered
                    .where((r) => r.submittedBy == _personFilter)
                    .toList();
              }
              if (_query.isNotEmpty) {
                filtered = filtered
                    .where((r) =>
                        (r.title.toLowerCase().contains(_query)) ||
                        (r.message.toLowerCase().contains(_query)) ||
                        (r.submittedByName.toLowerCase().contains(_query)))
                    .toList();
              }
              if (filtered.isEmpty) {
                return  Center(
                  child: Text('Kayıt bulunamadı.',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              final sorted = [...filtered]
                ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
              return ListView.builder(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final report = sorted[i];
                  return _BugCard(
                    key: ValueKey(report.id),
                    report: report,
                    isAdmin: widget.isAdmin,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text('Hata: $e',
                    style: const TextStyle(color: AppColors.error))),
          ),
        ),
      ],
    );
  }
}

/// Standardized bug report card.
class _BugCard extends ConsumerWidget {
  final BugReport report;
  final bool isAdmin;

  const _BugCard({super.key, required this.report, required this.isAdmin});

  Color _statusColor() {
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

  Color _typeColor() {
    return report.isSuggestion ? AppColors.panelBlue : _statusColor();
  }

  IconData _statusIcon() {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replyCount = report.messageCount;
    final statusLabel = report.statusLabel;
    final hasReplyBadge = replyCount > 0;
    final currentUid = ref.read(authStateProvider).value?.uid;
    final isOwner = currentUid != null && report.submittedBy == currentUid;
    final canEdit = isOwner;
    final canDelete = isAdmin || isOwner;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side:  BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_statusIcon(), size: 18, color: _typeColor()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.title.isEmpty ? report.message : report.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration:
                            report.isResolved ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (canEdit)
                    AppIconButton(
                      icon: Icons.edit_outlined,
                      iconSize: 18,
                      color: AppColors.primaryGreen,
                      tooltip: 'Düzenle',
                      onTap: () => _editReport(context, ref),
                    ),
                  if (canDelete)
                    CustomDeleteButton(
                      onPressed: () => _deleteReport(context, ref),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _typeColor().withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      report.isSuggestion ? 'Öneri' : 'Hata',
                      style: TextStyle(
                        color: _typeColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!report.isSuggestion) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor().withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: _statusColor().withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: _statusColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (hasReplyBadge) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.panelBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.panelBlue.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text('$replyCount',
                              style: const TextStyle(
                                  color: AppColors.panelBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    report.submittedByName,
                    style:  TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              // Resolver info
              if (report.isResolved &&
                  report.resolvedByName != null &&
                  report.resolvedByName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      '${report.resolvedByName} çözdü',
                      style: const TextStyle(
                          color: AppColors.success, fontSize: 11),
                    ),
                    if (report.resolvedAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM HH:mm', 'tr_TR')
                            .format(report.resolvedAt!),
                        style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ReportDetailView(
        reportId: report.id,
        isAdmin: isAdmin,
      ),
    );
  }

  void _editReport(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController(text: report.title);
    final msgCtrl = TextEditingController(text: report.message);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildirimi Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style:  TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                style:  TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Açıklama'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ref
                  .read(firestoreProvider)
                  .collection('reports')
                  .doc(report.id)
                  .update({
                'title': titleCtrl.text.trim(),
                'message': msgCtrl.text.trim(),
              });
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _deleteReport(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildirimi Sil'),
        content: const Text(
            'Bu bildirim kalıcı olarak silinecek. Onaylıyor musunuz?'),
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
      await runDeleteWithFeedback(
        context: context,
        successMessage: 'Bildirim başarıyla silindi.',
        operation: () => ref
            .read(firestoreProvider)
            .collection('reports')
            .doc(report.id)
            .delete(),
      );
    });
  }
}

/// Full detail view with live stream and full-screen.
class _ReportDetailView extends ConsumerStatefulWidget {
  final String reportId;
  final bool isAdmin;

  const _ReportDetailView({required this.reportId, required this.isAdmin});

  @override
  ConsumerState<_ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends ConsumerState<_ReportDetailView> {
  final _msgCtrl = TextEditingController();
  PickedImage? _msgImage;
  Map<String, dynamic>? _replyTo;
  late final PresenceService _presenceService;

  // Optimistically-rendered outgoing messages (WhatsApp-style): the bubble
  // appears instantly with its local image, then is swapped for the persisted
  // copy once the Firestore stream delivers it.
  final List<PendingMessage> _pendingMessages = [];
  int _pendingCounter = 0;

  // Used to auto-scroll the report conversation to the bottom when a new
  // message arrives (including the user's own). The controller is captured
  // from the DraggableScrollableSheet builder in build().
  ScrollController? _scrollController;
  int _lastMsgCount = 0;

  String get _threadKey =>
      threadKeyFor('report_reply', widget.reportId);

  @override
  void initState() {
    super.initState();
    // Presence: mark this report thread as open.
    _presenceService = ref.read(presenceServiceProvider);
    _presenceService.setActiveThread(_threadKey);
    // Opening the thread resets its unread counter.
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

  Color _statusColor(BugReport report) {
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

  IconData _statusIcon(BugReport report) {
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

  Future<void> _updateStatus(BugReport report, String newStatus) async {
    final firestore = ref.read(firestoreProvider);
    final currentUser = ref.read(authStateProvider).value;
    final currentName = ref.read(currentAppUserProvider).value?.displayName ??
        currentUser?.displayName ??
        '';
    final uid = currentUser?.uid;

    final updates = <String, dynamic>{'status': newStatus};

    if (newStatus == 'investigating' && uid != null) {
      // Use arrayUnion so multiple admins can mark "inceleniyor" concurrently
      // without overwriting each other. This reviewer list is informational
      // only and never acts as a lock.
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

    // Optimistic UI: show the bubble immediately (image visible, spinner on
    // top), then upload + persist in the background.
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

  /// Uploads the pending message's image (if any) and writes the Firestore
  /// message. On failure it flips the bubble into a compact "tekrar dene"
  /// state instead of showing a full-screen error.
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

      // Keep the map null-free: Firestore rejects `null` values inside array
      // elements, which previously crashed members replying to a report.
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

      // Notifications are created server-side by `notifyReportReply` (grouped
      // per thread + presence-aware), so the client only persists the message.

      if (mounted) {
        setState(() => _pendingMessages.remove(pending));
      }
    } catch (_) {
      if (mounted) {
        setState(() => pending.failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportStream = ref
        .watch(firestoreProvider)
        .collection('reports')
        .doc(widget.reportId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: reportStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data == null ||
            !snapshot.data!.exists) {
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.5,
            maxChildSize: 0.5,
            expand: false,
            builder: (_, __) =>  Center(
              child: Text('Bildirim bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        final report = BugReport.fromDoc(snapshot.data!);
        final messages = report.messages;
        final currentUid = ref.read(authStateProvider).value?.uid;

        // Auto-scroll to the bottom (most recent message) whenever the message
        // count increases — either from the user's own send or an incoming
        // reply. This prevents the conversation from jumping to the top when a
        // new message arrives.
        final msgCount = messages.length;
        if (_scrollController != null && msgCount > _lastMsgCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _scrollController == null) return;
            if (_scrollController!.hasClients) {
              _scrollController!
                  .animateTo(
                    _scrollController!.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  )
                  .catchError((_) {});
            }
          });
        }
        _lastMsgCount = msgCount;

        return DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.9,
          maxChildSize: 1.0,
          expand: false,
          builder: (context, scrollController) {
            // Capture the sheet's ListView controller so the message-count
            // watcher above can auto-scroll to the bottom.
            _scrollController = scrollController;
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
              // Content scrollable
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Row(
                      children: [
                        Icon(_statusIcon(report),
                            size: 20, color: _statusColor(report)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report.title.isEmpty ? report.message : report.title,
                            style:  TextStyle(
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
                              color: AppColors.panelBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.panelBlue.withValues(alpha: 0.4)),
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
                              color: _statusColor(report).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _statusColor(report)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              report.statusLabel,
                              style: TextStyle(
                                color: _statusColor(report),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          'Bildiren: ${report.submittedByName}',
                          style:  TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
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
                            style:  TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                height: 1.5)),
                      ),
                    ],
                    if (report.imageUrl != null &&
                        report.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showFullScreen(context, report.imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            report.imageUrl!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                    if (report.reviewedBy.isNotEmpty && report.status != 'done') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: report.reviewedBy.map((r) {
                          final name = r['name'] as String? ?? '';
                          return Chip(
                            label: Text('İnceleyen: $name',
                                style: const TextStyle(fontSize: 10)),
                            backgroundColor: AppColors.warning.withValues(alpha: 0.1),
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
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                              fontSize: 11),
                        ),
                      ],
                    ],

                    // Durum Değiştir section
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
                            _StatusActionButton(
                              label: 'Çözüldü',
                              color: AppColors.success,
                              icon: Icons.check_circle_outline,
                              isFilled: true,
                              onTap: () => _updateStatus(report, 'done'),
                            ),
                          if (report.status == 'open')
                            _StatusActionButton(
                              label: 'İncele',
                              color: AppColors.warning,
                              icon: Icons.search,
                              isFilled: true,
                              onTap: () => _updateStatus(report, 'investigating'),
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
                            style:  TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Messages (WhatsApp-style bubbles with reply support).
                    if (messages.isEmpty && _pendingMessages.isEmpty)
                       Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('Henüz mesaj yok.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
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
                            'senderName': msg['senderName'] as String? ?? '',
                            'senderUid': msg['senderUid'] as String? ?? '',
                          }),
                        );
                      }),
                      // Optimistically rendered outgoing messages (WhatsApp-style).
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
              ),
              // Message input
              Container(
                decoration:  BoxDecoration(
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
                                  author: _replyTo!['senderName'] as String? ?? 'Bilinmeyen',
                                  text: _replyTo!['text'] as String? ?? '',
                                  onClear: () => setState(() => _replyTo = null),
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
                                  onTap: () => setState(() => _msgImage = null),
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
                        icon: const Icon(Icons.image_outlined, size: 22),
                        color: AppColors.textSecondary,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final img = await PickedImage.pick(ImageSource.gallery);
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
                          style:  TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          decoration:  InputDecoration(
                            hintText: 'Mesaj yazın...',
                            hintStyle: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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

void _showFullScreen(BuildContext context, String url) {
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

/// Filled or outlined status action button.
class _StatusActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool isFilled;
  final VoidCallback onTap;

  const _StatusActionButton({
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
  }
}