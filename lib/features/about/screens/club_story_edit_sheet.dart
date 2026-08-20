import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../models/club_info_models.dart';
import '../providers/club_info_providers.dart';

/// Shows the "Kulüp Hikayesi" editor (story + gallery + contact info).
void showClubStoryEditSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => const ClubStoryEditSheet(),
  );
}

class ClubStoryEditSheet extends ConsumerStatefulWidget {
  const ClubStoryEditSheet({super.key});
  @override
  ConsumerState<ClubStoryEditSheet> createState() =>
      _ClubStoryEditSheetState();
}

class _ClubStoryEditSheetState extends ConsumerState<ClubStoryEditSheet> {
  final _titleCtrl = TextEditingController();
  final _storyCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _socialCtrl = TextEditingController();

  List<String> _gallery = [];
  final List<PickedImage> _newPhotos = [];
  bool _initialized = false;
  bool _saving = false;
  bool _picking = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _storyCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _instagramCtrl.dispose();
    _websiteCtrl.dispose();
    _socialCtrl.dispose();
    super.dispose();
  }

  void _loadFrom(ClubInfo info) {
    if (_initialized) return;
    _initialized = true;
    _titleCtrl.text = info.title ?? '';
    _storyCtrl.text = info.story;
    _emailCtrl.text = info.email ?? '';
    _phoneCtrl.text = info.phone ?? '';
    _addressCtrl.text = info.address ?? '';
    _instagramCtrl.text = info.instagram ?? '';
    _websiteCtrl.text = info.website ?? '';
    _socialCtrl.text = info.socialLinks ?? '';
    _gallery = List<String>.from(info.galleryPhotos);
  }

  Future<void> _pickPhotos() async {
    setState(() => _picking = true);
    try {
      final picked = await PickedImage.pickMultiple();
      if (picked.isNotEmpty) setState(() => _newPhotos.addAll(picked));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_storyCtrl.text.trim().isEmpty &&
        _gallery.isEmpty &&
        _newPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hikaye veya en az bir görsel ekleyin.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final storage = FirebaseStorage.instance;
      final uploadedUrls = <String>[];

      for (var i = 0; i < _newPhotos.length; i++) {
        final photo = _newPhotos[i];
        final id = const Uuid().v4();
        final ref = storage.ref().child('club_info/gallery/$id.jpg');
        if (kIsWeb && photo.bytes != null) {
          await ref.putData(photo.bytes!);
        } else if (photo.dartFile != null) {
          await ref.putFile(photo.dartFile!);
        }
        uploadedUrls.add(await ref.getDownloadURL());
      }

      final info = ClubInfo(
        story: _storyCtrl.text.trim(),
        galleryPhotos: [..._gallery, ...uploadedUrls],
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address:
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim().isEmpty
            ? null
            : _instagramCtrl.text.trim(),
        website:
            _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        socialLinks: _socialCtrl.text.trim().isEmpty
            ? null
            : _socialCtrl.text.trim(),
      );

      await ref.read(clubInfoRepositoryProvider).saveClubInfo(info);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kulüp hikayesi güncellendi.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Kaydedilemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeExistingPhoto(String url) async {
    setState(() => _gallery.remove(url));
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(clubInfoProvider);
    final info = infoAsync.valueOrNull;
    if (info != null) _loadFrom(info);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined,
                      color: AppColors.primaryGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Kulüp Hikayesini Düzenle',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sargeGold,
                      foregroundColor: Colors.black,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Kaydet'),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _field(_titleCtrl, 'Başlık', icon: Icons.title),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _storyCtrl,
                    maxLines: 8,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Kulüp Hikayesi',
                      hintText: 'Kuruluş, amaç, yolculuk...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('GALERİ GÖRSELLERİ',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._gallery.map((url) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 72,
                                    height: 72,
                                    color: AppColors.surface2,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _removeExistingPhoto(url),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )),
                      ..._newPhotos.map((p) {
                        ImageProvider? provider;
                        if (kIsWeb && p.bytes != null) {
                          provider = MemoryImage(p.bytes!);
                        } else if (p.dartFile != null) {
                          provider = FileImage(p.dartFile!);
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: provider != null
                              ? Image(image: provider,
                                  width: 72, height: 72, fit: BoxFit.cover)
                              : Container(
                                  width: 72,
                                  height: 72,
                                  color: AppColors.surface2),
                        );
                      }),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _picking ? null : _pickPhotos,
                    icon: _picking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate_outlined,
                            size: 18),
                    label: const Text('Görsel Ekle'),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('İLETİŞİM BİLGİLERİ',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  _field(_emailCtrl, 'E-posta', icon: Icons.mail_outline),
                  const SizedBox(height: 12),
                  _field(_phoneCtrl, 'Telefon', icon: Icons.phone_outlined),
                  const SizedBox(height: 12),
                  _field(_addressCtrl, 'Adres',
                      icon: Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  _field(_instagramCtrl, 'Instagram',
                      icon: Icons.alternate_email),
                  const SizedBox(height: 12),
                  _field(_websiteCtrl, 'Web Sitesi',
                      icon: Icons.language_outlined),
                  const SizedBox(height: 12),
                  _field(_socialCtrl, 'Diğer Bağlantılar', icon: Icons.link),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _field(TextEditingController ctrl, String label, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: AppColors.textSecondary)
            : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}