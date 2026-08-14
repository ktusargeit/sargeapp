import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/operation_feedback.dart';
import '../models/about_models.dart';
import '../providers/about_providers.dart';

void showAboutEditSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => const AboutEditSheet(),
  );
}

class AboutEditSheet extends ConsumerStatefulWidget {
  const AboutEditSheet({super.key});
  @override
  ConsumerState<AboutEditSheet> createState() => _AboutEditSheetState();
}

class _AboutEditSheetState extends ConsumerState<AboutEditSheet> {
  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(aboutSectionsProvider);
    final membersAsync = ref.watch(aboutMembersProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
      builder: (context, scrollController) {
        return Column(children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
           Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: Row(children: [
            const Icon(Icons.edit_outlined, color: AppColors.primaryGreen, size: 18), const SizedBox(width: 8),
            Text('Hakkımızda Sayfasını Düzenle', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          ])),
           Divider(color: AppColors.border, height: 1),
          Expanded(child: ListView(controller: scrollController, padding: const EdgeInsets.all(AppConstants.spacingMd), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text('METİN BÖLÜMLERİ', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
              TextButton.icon(onPressed: () => _showSectionEditor(context, null), icon: const Icon(Icons.add, size: 16), label: const Text('Ekle')),
            ]),
            const SizedBox(height: 8),
            sectionsAsync.when(
              data: (sections) => Column(children: sections.map((s) => _SectionRow(section: s, onEdit: () => _showSectionEditor(context, s))).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Hata: $e'),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text('TAKIM / ONURSAL ÜYELER', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
              TextButton.icon(onPressed: () => _showMemberEditor(context, null), icon: const Icon(Icons.add, size: 16), label: const Text('Ekle')),
            ]),
            const SizedBox(height: 8),
            membersAsync.when(
              data: (members) => Column(children: members.map((m) => _MemberRow(member: m, onEdit: () => _showMemberEditor(context, m))).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Hata: $e'),
            ),
            const SizedBox(height: 40),
          ])),
        ]);
      },
    );
  }

  void _showSectionEditor(BuildContext context, AboutSection? existing) {
    showDialog(context: context, builder: (_) => _SectionEditorDialog(existing: existing));
  }

  void _showMemberEditor(BuildContext context, AboutMember? existing) {
    showDialog(context: context, builder: (_) => _MemberEditorDialog(existing: existing));
  }
}

class _SectionRow extends ConsumerWidget {
  final AboutSection section;
  final VoidCallback onEdit;
  const _SectionRow({required this.section, required this.onEdit});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Text(section.title, style:  TextStyle(color: AppColors.textPrimary, fontSize: 13))),
        IconButton(icon:  Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary), onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error), onPressed: () => _deleteSection(context, ref)),
      ]));
  }

  Future<void> _deleteSection(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bölümü Sil'),
        content: Text('"${section.title}" silinecek. Onaylıyor musunuz?'),
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
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await runDeleteWithFeedback(
      context: context,
      successMessage: 'Bölüm başarıyla silindi.',
      operation: () =>
          ref.read(aboutRepositoryProvider).deleteSection(section.id),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  final AboutMember member;
  final VoidCallback onEdit;
  const _MemberRow({required this.member, required this.onEdit});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        CircleAvatar(radius: 16, backgroundColor: AppColors.surface3, backgroundImage: member.photoUrl != null && member.photoUrl!.isNotEmpty ? NetworkImage(member.photoUrl!) : null, child: member.photoUrl == null || member.photoUrl!.isEmpty ?  Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary) : null),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(member.name, style:  TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          Text(member.type == MemberType.honorary ? 'Onursal Üye' : 'Takım Üyesi', style:  TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ])),
        IconButton(icon:  Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary), onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error), onPressed: () => _deleteMember(context, ref)),
      ]));
  }

  Future<void> _deleteMember(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üyeyi Sil'),
        content: Text('"${member.name}" silinecek. Onaylıyor musunuz?'),
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
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await runDeleteWithFeedback(
      context: context,
      successMessage: 'Üye başarıyla silindi.',
      operation: () => ref
          .read(aboutRepositoryProvider)
          .deleteMember(member.id, photoUrl: member.photoUrl),
    );
  }
}

class _SectionEditorDialog extends ConsumerStatefulWidget {
  final AboutSection? existing;
  const _SectionEditorDialog({this.existing});
  @override
  ConsumerState<_SectionEditorDialog> createState() => _SectionEditorDialogState();
}

class _SectionEditorDialogState extends ConsumerState<_SectionEditorDialog> {
  late final TextEditingController _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
  bool _saving = false;

  @override
  void dispose() { _titleCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final section = AboutSection(id: widget.existing?.id ?? '', title: _titleCtrl.text.trim(), content: _contentCtrl.text.trim(), order: widget.existing?.order ?? 0);
    await ref.read(aboutRepositoryProvider).upsertSection(section);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Bölüm' : 'Bölümü Düzenle'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _titleCtrl, style:  TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Başlık (örn: Tarihçemiz)')),
        const SizedBox(height: 12),
        TextField(controller: _contentCtrl, maxLines: 6, style:  TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'İçerik metni...')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet')),
      ],
    );
  }
}

class _MemberEditorDialog extends ConsumerStatefulWidget {
  final AboutMember? existing;
  const _MemberEditorDialog({this.existing});
  @override
  ConsumerState<_MemberEditorDialog> createState() => _MemberEditorDialogState();
}

class _MemberEditorDialogState extends ConsumerState<_MemberEditorDialog> {
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _roleCtrl = TextEditingController(text: widget.existing?.role ?? '');
  late MemberType _type = widget.existing?.type ?? MemberType.team;
  PickedImage? _pickedImage;
  bool _saving = false;

  @override
  void dispose() { _nameCtrl.dispose(); _roleCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final repo = ref.read(aboutRepositoryProvider);
    try {
      if (widget.existing == null) {
        final id = const Uuid().v4();
        String? photoUrl;
        if (_pickedImage != null) photoUrl = await repo.uploadMemberPhoto(id, file: _pickedImage!.dartFile, bytes: _pickedImage!.bytes);
        final member = AboutMember(id: id, name: _nameCtrl.text.trim(), role: _roleCtrl.text.trim(), photoUrl: photoUrl, type: _type);
        await repo.addMember(member);
      } else {
        String? photoUrl = widget.existing!.photoUrl;
        if (_pickedImage != null) photoUrl = await repo.uploadMemberPhoto(widget.existing!.id, file: _pickedImage!.dartFile, bytes: _pickedImage!.bytes);
        await repo.updateMember(widget.existing!.id, {'name': _nameCtrl.text.trim(), 'role': _roleCtrl.text.trim(), 'type': _type == MemberType.honorary ? 'honorary' : 'team', 'photoUrl': photoUrl});
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Üye' : 'Üyeyi Düzenle'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(onTap: _pickImage, child: CircleAvatar(radius: 36, backgroundColor: AppColors.surface2,
          backgroundImage: _pickedImage != null ? (kIsWeb ? (_pickedImage!.bytes != null ? MemoryImage(_pickedImage!.bytes!) : null) : (_pickedImage!.dartFile != null ? FileImage(_pickedImage!.dartFile!) : null)) as ImageProvider? : (widget.existing?.photoUrl != null && widget.existing!.photoUrl!.isNotEmpty ? NetworkImage(widget.existing!.photoUrl!) : null),
          child: _pickedImage == null && (widget.existing?.photoUrl == null || widget.existing!.photoUrl!.isEmpty) ?  Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary) : null)),
        const SizedBox(height: 14),
        TextField(controller: _nameCtrl, style:  TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Ad Soyad')),
        const SizedBox(height: 12),
        TextField(controller: _roleCtrl, style:  TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Görev / Rol (örn: Takım Kaptanı)')),
        const SizedBox(height: 12),
        RadioGroup<MemberType>(groupValue: _type, onChanged: (v) => setState(() => _type = v ?? MemberType.team), child: const Row(children: [
          Expanded(child: RadioListTile<MemberType>(dense: true, contentPadding: EdgeInsets.zero, title: Text('Takım Üyesi', style: TextStyle(fontSize: 13)), value: MemberType.team)),
          Expanded(child: RadioListTile<MemberType>(dense: true, contentPadding: EdgeInsets.zero, title: Text('Onursal', style: TextStyle(fontSize: 13)), value: MemberType.honorary)),
        ])),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet')),
      ],
    );
  }
}