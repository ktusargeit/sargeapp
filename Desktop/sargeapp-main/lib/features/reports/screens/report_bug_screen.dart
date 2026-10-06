import 'package:flutter/material.dart';
import 'package:sarge_depo_app/core/utils/snackbar_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/platform_image.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../team/providers/team_providers.dart';
import '../widgets/report_detail_panel.dart';
import '../widgets/report_list.dart';

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
      builder: (ctx) => ReportDetailView(reportId: id, isAdmin: isAdmin),
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
      TopSnackBar.showSnackBar(
          context,
          const SnackBar(
              content: Text('Başlık zorunludur.'),
              backgroundColor: AppColors.error));
      return;
    }
    setState(() => _sending = true);
    try {
      final repo = ref.read(teamRepositoryProvider);
      final user = ref.read(authStateProvider).valueOrNull;
      String? imageUrl;
      if (_pickedImage != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
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

      await ref.read(notificationServiceProvider).notifyAdmins(
            title: _reportType == 'suggestion'
                ? 'Yeni Öneri'
                : 'Yeni Hata Bildirimi',
            body:
                '${user?.displayName ?? 'Bir kullanıcı'}: ${_titleCtrl.text.trim()}',
            type: 'report',
            relatedId: reportId,
          );

      if (mounted) {
        TopSnackBar.showSnackBar(
            context,
            const SnackBar(
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
        TopSnackBar.showSnackBar(
            context,
            SnackBar(
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
          ReportListTab(isAdmin: isAdmin),
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
              child: ReportTypeOption(
                label: 'Hata',
                icon: Icons.bug_report_outlined,
                selected: _reportType == 'bug',
                color: AppColors.error,
                onTap: () => setState(() => _reportType = 'bug'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ReportTypeOption(
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
          style: TextStyle(color: AppColors.textPrimary),
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
          style: TextStyle(color: AppColors.textPrimary),
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
                    child:
                        const Icon(Icons.close, size: 16, color: Colors.white),
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
