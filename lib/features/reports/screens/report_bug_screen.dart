import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/platform_image.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';

class ReportBugScreen extends ConsumerStatefulWidget {
  const ReportBugScreen({super.key});

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
        imageUrl = await repo.uploadReportImage(tempId,
            file: _pickedImage!.dartFile, bytes: _pickedImage!.bytes);
      }
      await repo.submitReport(
        title: _titleCtrl.text.trim(),
        message: _descCtrl.text.trim(),
        submittedBy: user?.uid ?? '',
        submittedByName: user?.displayName ?? 'Kullanıcı',
        imageUrl: imageUrl,
        type: _reportType,
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
        const Text('TÜR',
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
        const Text('HATA BAŞLIĞI',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Örn: Depo rafı yanlış görünüyor',
            labelText: 'Başlık *',
          ),
        ),
        const SizedBox(height: 16),
        const Text('AÇIKLAMA',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl,
          maxLines: 5,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Raf 3\'e bastığımda yanlış ürünler geliyor.',
            labelText: 'Açıklama',
          ),
        ),
        const SizedBox(height: 16),
        const Text('FOTOĞRAF (İsteğe Bağlı)',
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
                  side: const BorderSide(color: AppColors.border),
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
                  side: const BorderSide(color: AppColors.border),
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
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ara...',
                    hintStyle: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
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
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    hint: const Text('Kişi',
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
                return const Center(
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

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: const BorderSide(color: AppColors.border)),
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
                      report.isSuggestion ? 'Öneri' : statusLabel,
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
                    style: const TextStyle(
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
  bool _sending = false;

  @override
  void dispose() {
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

    if (newStatus == 'investigating') {
      final reviewedBy = List<Map<String, dynamic>>.from(report.reviewedBy);
      final alreadyReviewing = reviewedBy.any((r) => r['uid'] == uid);
      if (!alreadyReviewing && uid != null) {
        reviewedBy.add({
          'uid': uid,
          'name': currentName,
          'startedAt': Timestamp.now(),
        });
        updates['reviewedBy'] = reviewedBy;
      }
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
                ? 'Yapıldı olarak işaretlendi.'
                : newStatus == 'investigating'
                    ? 'İnceleniyor.'
                    : 'Açıldı.'),
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
    if (_msgCtrl.text.trim().isEmpty && _msgImage == null) return;
    setState(() => _sending = true);
    try {
      final currentUser = ref.read(authStateProvider).value;
      final currentName = currentUser?.displayName ?? 'Kullanıcı';
      final uid = currentUser?.uid ?? '';

      String? imageUrl;
      if (_msgImage != null) {
        final tempId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('report_messages/$tempId.jpg');
        if (kIsWeb && _msgImage!.bytes != null) {
          await storageRef.putData(_msgImage!.bytes!);
        } else if (_msgImage!.dartFile != null) {
          await storageRef.putFile(_msgImage!.dartFile!);
        }
        imageUrl = await storageRef.getDownloadURL();
      }

      final newMsg = {
        'senderUid': uid,
        'senderName': currentName,
        'text': _msgCtrl.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
        'isAdmin': widget.isAdmin,
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
          _msgCtrl.clear();
          _msgImage = null;
          _sending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
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
            builder: (_, __) => const Center(
              child: Text('Bildirim bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        final report = BugReport.fromDoc(snapshot.data!);
        final messages = report.messages;
        final currentUid = ref.read(authStateProvider).value?.uid;

        return DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.9,
          maxChildSize: 1.0,
          expand: false,
          builder: (context, scrollController) => Column(
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
                            style: const TextStyle(
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
                          style: const TextStyle(
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
                            style: const TextStyle(
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
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 8),
                      const Text(
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
                              label: 'Yapıldı',
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
                          if (report.status == 'done' ||
                              report.status == 'investigating')
                            _StatusActionButton(
                              label: 'Yeniden Aç',
                              color: AppColors.textSecondary,
                              icon: Icons.refresh,
                              isFilled: false,
                              onTap: () => _updateStatus(report, 'open'),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Mesajlar (${messages.length})',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Messages
                    if (messages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('Henüz mesaj yok.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                        ),
                      )
                    else
                      ...messages.map((msg) {
                        final isMe = msg['senderUid'] == currentUid;
                        final name = msg['senderName'] as String? ?? '';
                        final text = msg['text'] as String? ?? '';
                        final imgUrl = msg['imageUrl'] as String?;
                        final isMsgAdmin = msg['isAdmin'] as bool? ?? false;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMsgAdmin
                                  ? AppColors.success.withValues(alpha: 0.08)
                                  : AppColors.surface2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isMsgAdmin
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: isMsgAdmin
                                            ? AppColors.success
                                            : AppColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (isMsgAdmin) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: const Text('ADMIN',
                                            style: TextStyle(
                                                color: AppColors.success,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ],
                                ),
                                if (text.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(text,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          height: 1.4)),
                                ],
                                if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _showFullScreen(context, imgUrl),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        imgUrl,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        cacheWidth: 600,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              // Message input
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Row(
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
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Mesaj yazın...',
                            hintStyle: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primaryGreen))
                            : const Icon(Icons.send,
                                size: 20, color: AppColors.primaryGreen),
                        onPressed: _sending ? null : () => _sendMessage(report),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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