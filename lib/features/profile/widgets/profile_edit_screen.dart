import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../about/providers/club_info_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../team/models/team_models.dart';
import 'profile_basic_info.dart';
import 'profile_past_teams.dart';

const List<(String, String)> _linkPlatforms = [
  ('GitHub', 'github'),
  ('LinkedIn', 'linkedin'),
  ('Instagram', 'instagram'),
  ('Twitter / X', 'twitter'),
  ('YouTube', 'youtube'),
  ('Web Sitesi', 'web'),
  ('E-posta', 'email'),
  ('Discord', 'discord'),
  ('Telefon', 'phone'),
  ('Diğer', 'other'),
];

String _normalizeLinkType(String? t) {
  final v = (t ?? '').trim().toLowerCase();
  for (final p in _linkPlatforms) {
    if (p.$2 == v) return v;
  }
  if (v == 'url' || v == 'site') return 'web';
  if (v == 'mail') return 'email';
  if (v == 'tel') return 'phone';
  return 'other';
}

InputDecoration _editInputDecoration({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon != null
        ? Icon(icon, size: 20, color: AppColors.textSecondary)
        : null,
    filled: true,
    fillColor: AppColors.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      borderSide: const BorderSide(color: AppColors.sargeGold, width: 1.4),
    ),
    labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
    floatingLabelStyle: const TextStyle(color: AppColors.sargeGold),
  );
}

class _EditSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  const _EditSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class ProfileEditScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const ProfileEditScreen({super.key, required this.user});
  @override
  ConsumerState<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _displayNameCtrl =
      TextEditingController(text: widget.user.displayName);
  late final TextEditingController _bioCtrl =
      TextEditingController(text: widget.user.bio ?? '');
  late final TextEditingController _departmentCtrl =
      TextEditingController(text: widget.user.department ?? '');
  late final TextEditingController _classNameCtrl =
      TextEditingController(text: widget.user.className ?? '');
  final TextEditingController _unitCtrl = TextEditingController();

  PickedImage? _avatar;
  PickedImage? _cover;
  bool _saving = false;

  late List<Map<String, dynamic>> _links;
  late List<Map<String, dynamic>> _clubRoles;
  late List<String> _unitResponsibilities;
  late List<Map<String, dynamic>> _awards;
  late List<String> _pastTeamIds;

  @override
  void initState() {
    super.initState();
    _links = widget.user.links.map((e) => Map<String, dynamic>.from(e)).toList();
    _clubRoles =
        widget.user.clubRoles.map((e) => Map<String, dynamic>.from(e)).toList();
    _unitResponsibilities = List<String>.from(widget.user.unitResponsibilities);
    _awards =
        widget.user.awards.map((e) => Map<String, dynamic>.from(e)).toList();
    _pastTeamIds = List<String>.from(widget.user.pastTeamIds);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _departmentCtrl.dispose();
    _classNameCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  ImageProvider? _avatarProvider() {
    if (_avatar?.bytes != null) return MemoryImage(_avatar!.bytes!);
    if (_avatar?.dartFile != null) return FileImage(_avatar!.dartFile!);
    if (widget.user.photoUrl != null && widget.user.photoUrl!.isNotEmpty) {
      return NetworkImage(widget.user.photoUrl!);
    }
    return null;
  }

  ImageProvider? _coverProvider() {
    if (_cover?.bytes != null) return MemoryImage(_cover!.bytes!);
    if (_cover?.dartFile != null) return FileImage(_cover!.dartFile!);
    if (widget.user.coverPhotoUrl != null &&
        widget.user.coverPhotoUrl!.isNotEmpty) {
      return NetworkImage(widget.user.coverPhotoUrl!);
    }
    return null;
  }

  Future<void> _pickAvatar() async {
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked != null) setState(() => _avatar = picked);
  }

  Future<void> _pickCover() async {
    final picked = await PickedImage.pick(ImageSource.gallery);
    if (picked != null) setState(() => _cover = picked);
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _avatarProvider();
    final coverProvider = _coverProvider();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profili Düzenle',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sargeGold,
                  disabledBackgroundColor:
                      AppColors.sargeGold.withValues(alpha: 0.5),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black87),
                        ),
                      )
                    : const Text(
                        'Kaydet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditSection(
              icon: Icons.photo_library_outlined,
              color: AppColors.info,
              title: 'Fotoğraflar',
              child: _buildPhotosSection(avatarProvider, coverProvider),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.person_outline,
              color: AppColors.teamAccent,
              title: 'Kişisel Bilgiler',
              child: _buildPersonalSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.notes_outlined,
              color: AppColors.primaryGreen,
              title: 'Hakkında',
              child: _buildAboutSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.link_outlined,
              color: AppColors.depoAccent,
              title: 'Bağlantılar',
              child: _buildLinksSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.badge_outlined,
              color: AppColors.sargeGold,
              title: 'Kulüp Rolleri',
              child: _buildClubRolesSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.assignment_outlined,
              color: AppColors.warning,
              title: 'Birim Sorumlulukları',
              child: _buildUnitsSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.emoji_events_outlined,
              color: AppColors.primaryGreen,
              title: 'Ödüller & Başarılar',
              child: _buildAwardsSection(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _EditSection(
              icon: Icons.history_outlined,
              color: AppColors.depoAccent,
              title: 'Geçmiş Takımlarım',
              child: ProfilePastTeamsSection(
                userId: widget.user.uid,
                selectedIds: _pastTeamIds,
                onToggle: _togglePastTeam,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection(ImageProvider? avatar, ImageProvider? cover) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sargeGold, width: 2),
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.surface2,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Icon(Icons.add_a_photo_outlined,
                          size: 30, color: AppColors.textSecondary)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profil Fotoğrafı',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickAvatar,
                    style: _outlineButtonStyle(AppColors.info),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Fotoğrafı Değiştir'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Kapak Fotoğrafı',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickCover,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover != null
                      ? Image(
                          image: cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ProfileCoverFallback())
                      : const ProfileCoverFallback(),
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickCover,
          style: _outlineButtonStyle(AppColors.teamAccent),
          icon: const Icon(Icons.image_outlined, size: 16),
          label: const Text('Kapağı Değiştir'),
        ),
      ],
    );
  }

  Widget _buildPersonalSection() {
    return Column(
      children: [
        TextFormField(
          controller: _displayNameCtrl,
          style: TextStyle(color: AppColors.textPrimary),
          decoration:
              _editInputDecoration(label: 'Ad Soyad *', icon: Icons.person_outline),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _departmentCtrl,
          style: TextStyle(color: AppColors.textPrimary),
          decoration:
              _editInputDecoration(label: 'Bölüm', icon: Icons.school_outlined),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _classNameCtrl,
          style: TextStyle(color: AppColors.textPrimary),
          decoration:
              _editInputDecoration(label: 'Sınıf', icon: Icons.class_outlined),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return TextFormField(
      controller: _bioCtrl,
      maxLines: 5,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: _editInputDecoration(
          label: 'Hakkımda / Biyografi', icon: Icons.notes_outlined),
    );
  }

  Widget _buildLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._links.asMap().entries.map((entry) {
          final i = entry.key;
          final link = entry.value;
          final type = _normalizeLinkType(link['type'] as String?);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: type,
                        isExpanded: true,
                        dropdownColor: AppColors.surface2,
                        iconEnabledColor: AppColors.textSecondary,
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        decoration: _editInputDecoration(
                            label: 'Platform', icon: Icons.public),
                        items: _linkPlatforms
                            .map((p) => DropdownMenuItem<String>(
                                value: p.$2, child: Text(p.$1)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _links[i]['type'] = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 22),
                        onPressed: () => setState(() => _links.removeAt(i))),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: link['label'] as String? ?? '',
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _editInputDecoration(
                      label: 'Etiket (örn: Kişisel GitHub)'),
                  onChanged: (v) => _links[i]['label'] = v,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: link['url'] as String? ?? '',
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _editInputDecoration(
                      label: 'URL', icon: Icons.link),
                  onChanged: (v) => _links[i]['url'] = v,
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(
                () => _links.add({'label': '', 'url': '', 'type': 'other'})),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni Bağlantı Ekle'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildClubRolesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._clubRoles.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: r['roleName'] as String? ?? '',
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: _editInputDecoration(
                            label: 'Rol Adı (örn: Başkan)'),
                        onChanged: (v) => _clubRoles[i]['roleName'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 22),
                        onPressed: () => setState(() => _clubRoles.removeAt(i))),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: r['teamName'] as String? ?? '',
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _editInputDecoration(
                      label: 'Takım (opsiyonel)', icon: Icons.groups_outlined),
                  onChanged: (v) => _clubRoles[i]['teamName'] =
                      v.trim().isEmpty ? null : v,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: r['startYear']?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: _editInputDecoration(
                            label: 'Başlangıç Yılı'),
                        onChanged: (v) => _clubRoles[i]['startYear'] =
                            int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: r['endYear']?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration:
                            _editInputDecoration(label: 'Bitiş Yılı'),
                        onChanged: (v) => _clubRoles[i]['endYear'] =
                            v.trim().isEmpty ? null : int.tryParse(v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _clubRoles.add({
                  'roleName': '',
                  'teamName': null,
                  'startYear': DateTime.now().year,
                  'endYear': null
                })),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Rol Ekle'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_unitResponsibilities.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _unitResponsibilities.asMap().entries.map((entry) {
              return Chip(
                label: Text(entry.value,
                    style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(
                    () => _unitResponsibilities.removeAt(entry.key)),
                backgroundColor: AppColors.surface2,
                side: BorderSide(color: AppColors.border),
              );
            }).toList(),
          ),
        if (_unitResponsibilities.isNotEmpty) const SizedBox(height: 12),
        TextFormField(
          controller: _unitCtrl,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: _editInputDecoration(
              label: 'Yeni sorumluluk ekle (örn: Envanter)',
              icon: Icons.add_task_outlined),
          onFieldSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              setState(() => _unitResponsibilities.add(v.trim()));
              _unitCtrl.clear();
            }
          },
        ),
      ],
    );
  }

  Widget _buildAwardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._awards.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: a['title'] as String? ?? '',
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: _editInputDecoration(label: 'Ödül Adı'),
                        onChanged: (v) => _awards[i]['title'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 22),
                        onPressed: () => setState(() => _awards.removeAt(i))),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: a['description'] as String? ?? '',
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration:
                      _editInputDecoration(label: 'Açıklama (opsiyonel)'),
                  onChanged: (v) => _awards[i]['description'] =
                      v.trim().isEmpty ? null : v,
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _awards.add({'title': '', 'description': null})),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ödül Ekle'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  Future<void> _togglePastTeam(ClubTeam team, bool value) async {
    final linkService = ref.read(pastTeamLinkServiceProvider);
    try {
      if (value) {
        await linkService.addPastTeam(uid: widget.user.uid, teamId: team.id);
        setState(() {
          if (!_pastTeamIds.contains(team.id)) _pastTeamIds.add(team.id);
        });
      } else {
        await linkService.removePastTeam(
            uid: widget.user.uid, teamId: team.id);
        setState(() => _pastTeamIds.remove(team.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Güncellenemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  ButtonStyle _outlineButtonStyle(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.6)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Future<void> _save() async {
    if (_displayNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ad Soyad boş bırakılamaz.'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoUrl = widget.user.photoUrl;
      if (_avatar != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_photos/${widget.user.uid}.jpg');
        if (kIsWeb && _avatar!.bytes != null) {
          await storageRef.putData(_avatar!.bytes!);
        } else if (_avatar!.dartFile != null) {
          await storageRef.putFile(_avatar!.dartFile!);
        }
        photoUrl = await storageRef.getDownloadURL();
      }

      String? coverUrl = widget.user.coverPhotoUrl;
      if (_cover != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('cover_photos/${widget.user.uid}.jpg');
        if (kIsWeb && _cover!.bytes != null) {
          await storageRef.putData(_cover!.bytes!);
        } else if (_cover!.dartFile != null) {
          await storageRef.putFile(_cover!.dartFile!);
        }
        coverUrl = await storageRef.getDownloadURL();
      }

      final cleanLinks = _links
          .where((l) =>
              (l['label'] as String? ?? '').isNotEmpty ||
              (l['url'] as String? ?? '').isNotEmpty)
          .map((l) => {
                'label': l['label'] as String? ?? '',
                'url': l['url'] as String? ?? '',
                'type': _normalizeLinkType(l['type'] as String?),
              })
          .toList();
      final cleanRoles = _clubRoles
          .where((r) => (r['roleName'] as String? ?? '').isNotEmpty)
          .toList();
      final cleanAwards = _awards
          .where((a) => (a['title'] as String? ?? '').isNotEmpty)
          .toList();

      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'displayName': _displayNameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'department': _departmentCtrl.text.trim().isEmpty
            ? null
            : _departmentCtrl.text.trim(),
        'className': _classNameCtrl.text.trim().isEmpty
            ? null
            : _classNameCtrl.text.trim(),
        'photoUrl': photoUrl,
        'coverPhotoUrl': coverUrl,
        'links': cleanLinks,
        'clubRoles': cleanRoles,
        'unitResponsibilities': _unitResponsibilities
            .where((s) => s.trim().isNotEmpty)
            .toList(),
        'awards': cleanAwards,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profil güncellendi.'),
            backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Kaydedilemedi: $e'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}