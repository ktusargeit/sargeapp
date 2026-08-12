import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Hata bildiriminiz alındı, teşekkürler!'),
            backgroundColor: AppColors.success));
        _titleCtrl.clear();
        _descCtrl.clear();
        setState(() {
          _pickedImage = null;
          _sending = false;
        });
        _tabCtrl.animateTo(1); // switch to the list tab
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
        title: const Text('Hata Bildir'),
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
            labelText: 'Hata Başlığı *',
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
                  side: BorderSide(color: AppColors.border),
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
                  side: BorderSide(color: AppColors.border),
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
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMd),
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
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
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

/// Tab showing the public bug list with status management.
class _BugListTab extends ConsumerWidget {
  final bool isAdmin;
  const _BugListTab({required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(bugReportsProvider);

    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(
            child: Text('Henüz bildirilen hata yok.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          itemCount: reports.length,
          itemBuilder: (_, i) {
            final report = reports[i];
            return _BugCard(report: report, isAdmin: isAdmin);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Hata: $e',
              style: const TextStyle(color: AppColors.error))),
    );
  }
}

/// Individual bug report card with status management.
class _BugCard extends ConsumerWidget {
  final BugReport report;
  final bool isAdmin;

  const _BugCard({required this.report, required this.isAdmin});

  Color _statusColor() {
    switch (report.status) {
      case 'investigating':
        return AppColors.warning;
      case 'done':
        return AppColors.success;
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  report.isResolved
                      ? Icons.check_circle
                      : report.status == 'investigating'
                          ? Icons.search
                          : Icons.bug_report,
                  size: 18,
                  color: _statusColor(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(report.title.isEmpty ? report.message : report.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: report.isResolved
                            ? TextDecoration.lineThrough
                            : null,
                      )),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _statusColor().withValues(alpha: 0.4)),
                  ),
                  child: Text(report.statusLabel,
                      style: TextStyle(
                          color: _statusColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (report.message.isNotEmpty &&
                report.message != report.title) ...[
              const SizedBox(height: 6),
              Text(report.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
            if (report.imageUrl != null && report.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showFullScreen(context, report.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    report.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(report.submittedByName,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const Spacer(),
                // Admin status management buttons
                if (isAdmin) ...[
                  if (report.status != 'done')
                    _MiniButton(
                      label: 'Yapıldı',
                      color: AppColors.success,
                      onTap: () => ref
                          .read(teamRepositoryProvider)
                          .updateReportStatus(report.id, 'done'),
                    ),
                  if (report.status == 'open')
                    _MiniButton(
                      label: 'İncele',
                      color: AppColors.warning,
                      onTap: () => ref
                          .read(teamRepositoryProvider)
                          .updateReportStatus(report.id, 'investigating'),
                    ),
                  if (report.status == 'done' || report.status == 'investigating')
                    _MiniButton(
                      label: 'Aç',
                      color: AppColors.textSecondary,
                      onTap: () => ref
                          .read(teamRepositoryProvider)
                          .updateReportStatus(report.id, 'open'),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
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

/// A tiny compact button for admin status actions.
class _MiniButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ),
    );
  }
}