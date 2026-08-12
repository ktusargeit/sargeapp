import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/utils/image_utils.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final currentUser = ref.watch(currentAppUserProvider).value;
    final isOwnProfile = currentUser?.uid == widget.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppColors.surface,
        actions: [
          if (isOwnProfile && currentUser != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.settingsPurple),
              tooltip: 'Profili Düzenle',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileEditScreen(user: currentUser)),
              ),
            ),
        ],
      ),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Kullanıcı bulunamadı.', style: TextStyle(color: AppColors.textSecondary)));
          }
          return Column(children: [
            _ProfileHeader(user: user),
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.sargeGold,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [Tab(text: 'Hakkında'), Tab(text: 'Geçmiş'), Tab(text: 'Anlık')],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AboutTab(user: user, isOwnProfile: isOwnProfile),
                  _HistoryTab(user: user, isOwnProfile: isOwnProfile, userId: widget.userId),
                  _NowTab(user: user),
                ],
              ),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}

class _AboutTab extends ConsumerWidget {
  final AppUser user;
  final bool isOwnProfile;
  const _AboutTab({required this.user, required this.isOwnProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          _SectionCard(title: 'HAKKINDA', children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(user.bio!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4))),
          ]),
          const SizedBox(height: AppConstants.spacingLg),
        ],
        _SectionCard(title: 'BİLGİLER', children: [
          _InfoRow(icon: Icons.person_outline, label: 'Ad Soyad', value: user.displayName),
          _InfoRow(icon: Icons.school_outlined, label: 'Bölüm', value: user.department ?? '—'),
          _InfoRow(icon: Icons.class_outlined, label: 'Sınıf', value: user.className ?? '—'),
          _InfoRow(icon: Icons.mail_outline, label: 'E-posta', value: user.email, isLast: true),
        ]),
        const SizedBox(height: AppConstants.spacingLg),
        _SectionCard(title: 'PUANLAR', children: [
          _InfoRow(icon: Icons.stars_outlined, label: 'Toplam Puan', value: '${user.points}'),
          _InfoRow(icon: Icons.trending_up, label: 'Haftalık Puan', value: '${user.weeklyPoints}', isLast: true),
        ]),
        const SizedBox(height: AppConstants.spacingLg),
        _SectionCard(title: 'SOSYAL BAĞLANTILAR', children: [
          if (user.links.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Henüz bağlantı eklenmemiş.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
          else
            ...user.links.asMap().entries.map((entry) {
              final isLast = entry.key == user.links.length - 1;
              return _InfoRow(icon: Icons.language, label: entry.value['label'] as String? ?? '', value: entry.value['url'] as String? ?? '', isLast: isLast);
            }),
        ]),
      ],
    );
  }
}

class _HistoryTab extends ConsumerStatefulWidget {
  final AppUser user;
  final bool isOwnProfile;
  final String userId;
  const _HistoryTab({required this.user, required this.isOwnProfile, required this.userId});
  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        _SectionCard(title: 'GEÇMİŞ TAKIMLAR', children: [
          if (user.pastTeams.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Geçmiş takım kaydı yok.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
          else
            ...user.pastTeams.map((t) => _InfoRow(icon: Icons.history, label: t['teamName'] as String? ?? '', value: '${t['role'] ?? 'Üye'} (${t['startYear']}${t['endYear'] != null ? ' - ${t['endYear']}' : ''})')),
        ]),
        const SizedBox(height: AppConstants.spacingLg),
        _SectionCard(title: 'KULÜP ROLLERİ', children: [
          if (user.clubRoles.isEmpty && user.unitResponsibilities.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Atanmış rol yok.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
          else ...[
            ...user.clubRoles.map((r) => _InfoRow(icon: Icons.workspace_premium_outlined, label: r['roleName'] as String? ?? '', value: '${r['teamName'] ?? ''}')),
            if (user.unitResponsibilities.isNotEmpty) _InfoRow(icon: Icons.folder_outlined, label: 'Birim Sorumlulukları', value: user.unitResponsibilities.join(', '), isLast: true),
          ],
        ]),
      ],
    );
  }
}

class _NowTab extends ConsumerWidget {
  final AppUser user;
  const _NowTab({required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        _SectionCard(title: 'AKTİF TAKIM & ROL', children: [
          _InfoRow(icon: Icons.groups_outlined, label: 'Aktif Takım', value: user.activeTeamName ?? '—'),
          _InfoRow(icon: Icons.workspace_premium_outlined, label: 'Rol', value: user.roleLabel, isLast: true),
        ]),
      ],
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final AppUser user;
  const _ProfileHeader({required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(children: [
        CircleAvatar(radius: 44, backgroundColor: AppColors.surface2,
          backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty ? NetworkImage(user.photoUrl!) : null,
          child: user.photoUrl == null || user.photoUrl!.isEmpty ? const Icon(Icons.person_outline, size: 40, color: AppColors.textSecondary) : null),
        const SizedBox(height: 12),
        Text(user.displayName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(user.roleLabel, style: TextStyle(color: user.isAdmin ? AppColors.sargeGold : AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        if (user.email.isNotEmpty) ...[const SizedBox(height: 4), Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))],
      ]),
    );
  }
}

class ProfileEditScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const ProfileEditScreen({super.key, required this.user});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _displayNameCtrl = TextEditingController(text: widget.user.displayName);
  late final TextEditingController _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
  late final TextEditingController _departmentCtrl = TextEditingController(text: widget.user.department ?? '');
  late final TextEditingController _classNameCtrl = TextEditingController(text: widget.user.className ?? '');
  PickedImage? _pickedImage;
  bool _saving = false;
  bool _inWorkshop = false;

  // Editable lists
  late List<Map<String, dynamic>> _links;
  late List<Map<String, dynamic>> _clubRoles;
  late List<String> _unitResponsibilities;
  late List<Map<String, dynamic>> _awards;

  @override
  void initState() {
    super.initState();
    _inWorkshop = widget.user.inWorkshop;
    _links = widget.user.links.map((e) => Map<String, dynamic>.from(e)).toList();
    _clubRoles = widget.user.clubRoles.map((e) => Map<String, dynamic>.from(e)).toList();
    _unitResponsibilities = List<String>.from(widget.user.unitResponsibilities);
    _awards = widget.user.awards.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose(); _bioCtrl.dispose(); _departmentCtrl.dispose(); _classNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profili Düzenle'), backgroundColor: AppColors.surface,
        actions: [TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)))]),
      body: ListView(padding: const EdgeInsets.all(AppConstants.spacingMd), children: [
        // Photo
        Center(
          child: GestureDetector(
            onTap: () async {
              final picked = await PickedImage.pick(ImageSource.gallery);
              if (picked != null) setState(() => _pickedImage = picked);
            },
            child: CircleAvatar(radius: 44, backgroundColor: AppColors.surface2,
              backgroundImage: _pickedImage?.bytes != null ? MemoryImage(_pickedImage!.bytes!) : (widget.user.photoUrl != null && widget.user.photoUrl!.isNotEmpty ? NetworkImage(widget.user.photoUrl!) : null) as ImageProvider?,
              child: (_pickedImage == null && (widget.user.photoUrl == null || widget.user.photoUrl!.isEmpty)) ? const Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.textSecondary) : null),
          ),
        ),
        const SizedBox(height: 16),
        // Temel Bilgiler
        _SectionTitle('TEMEL BİLGİLER'),
        const SizedBox(height: 8),
        TextField(controller: _displayNameCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Ad Soyad *')),
        const SizedBox(height: 12),
        TextField(controller: _bioCtrl, maxLines: 3, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Hakkımda / Biyografi')),
        const SizedBox(height: 12),
        TextField(controller: _departmentCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Bölüm')),
        const SizedBox(height: 12),
        TextField(controller: _classNameCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Sınıf')),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Atölyede', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          subtitle: const Text('Şu anda atölyede misin?', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          value: _inWorkshop,
          activeColor: AppColors.primaryGreen,
          onChanged: (v) => setState(() => _inWorkshop = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 20),
        // Sosyal Bağlantılar
        _SectionTitle('SOSYAL BAĞLANTILAR'),
        const SizedBox(height: 8),
        ..._links.asMap().entries.map((entry) {
          final i = entry.key;
          final link = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Etiket (örn: GitHub)', isDense: true),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  controller: TextEditingController(text: link['label'] as String? ?? ''),
                  onChanged: (v) => _links[i]['label'] = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(hintText: 'URL', isDense: true),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  controller: TextEditingController(text: link['url'] as String? ?? ''),
                  onChanged: (v) => _links[i]['url'] = v,
                ),
              ),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20), onPressed: () => setState(() => _links.removeAt(i))),
            ]),
          );
        }),
        TextButton.icon(onPressed: () => setState(() => _links.add({'label': '', 'url': '', 'type': 'other'})), icon: const Icon(Icons.add, size: 16), label: const Text('Bağlantı Ekle'), style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen)),
        const SizedBox(height: 20),
        // Kulüp Rolleri
        _SectionTitle('KULÜP ROLLERİ'),
        const SizedBox(height: 8),
        ..._clubRoles.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: [
              Row(children: [
                Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Rol Adı (örn: Başkan)', isDense: true), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), controller: TextEditingController(text: r['roleName'] as String? ?? ''), onChanged: (v) => _clubRoles[i]['roleName'] = v)),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Takım', isDense: true), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), controller: TextEditingController(text: r['teamName'] as String? ?? ''), onChanged: (v) => _clubRoles[i]['teamName'] = v)),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20), onPressed: () => setState(() => _clubRoles.removeAt(i))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Başlangıç Yılı', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), controller: TextEditingController(text: r['startYear']?.toString() ?? ''), onChanged: (v) => _clubRoles[i]['startYear'] = int.tryParse(v) ?? 0)),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Bitiş Yılı', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), controller: TextEditingController(text: r['endYear']?.toString() ?? ''), onChanged: (v) => _clubRoles[i]['endYear'] = int.tryParse(v))),
              ]),
            ]),
          );
        }),
        TextButton.icon(onPressed: () => setState(() => _clubRoles.add({'roleName': '', 'teamName': null, 'startYear': DateTime.now().year, 'endYear': null})), icon: const Icon(Icons.add, size: 16), label: const Text('Rol Ekle'), style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen)),
        const SizedBox(height: 20),
        // Birim Sorumlulukları
        _SectionTitle('BİRİM SORUMLULUKLARI'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: _unitResponsibilities.asMap().entries.map((entry) {
          return Chip(
            label: Text(entry.value, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => setState(() => _unitResponsibilities.removeAt(entry.key)),
            backgroundColor: AppColors.surface2,
          );
        }).toList()),
        TextField(
          decoration: const InputDecoration(hintText: 'Yeni sorumluluk ekle (örn: Envanter)', isDense: true),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              setState(() => _unitResponsibilities.add(v.trim()));
            }
          },
        ),
        const SizedBox(height: 20),
        // Ödüller
        _SectionTitle('ÖDÜLLER & BAŞARILAR'),
        const SizedBox(height: 8),
        ..._awards.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Ödül Adı', isDense: true),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  controller: TextEditingController(text: a['title'] as String? ?? ''),
                  onChanged: (v) => _awards[i]['title'] = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Açıklama', isDense: true),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  controller: TextEditingController(text: a['description'] as String? ?? ''),
                  onChanged: (v) => _awards[i]['description'] = v,
                ),
              ),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20), onPressed: () => setState(() => _awards.removeAt(i))),
            ]),
          );
        }),
        TextButton.icon(onPressed: () => setState(() => _awards.add({'title': '', 'description': null})), icon: const Icon(Icons.add, size: 16), label: const Text('Ödül Ekle'), style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen)),
        const SizedBox(height: 40),
      ]),
    );
  }

  Future<void> _save() async {
    if (_displayNameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      String? photoUrl = widget.user.photoUrl;
      if (_pickedImage != null) {
        final ref_ = FirebaseStorage.instance.ref().child('profile_photos/${widget.user.uid}.jpg');
        if (kIsWeb && _pickedImage!.bytes != null) {
          await ref_.putData(_pickedImage!.bytes!);
        } else if (_pickedImage!.dartFile != null) {
          await ref_.putFile(_pickedImage!.dartFile!);
        }
        photoUrl = await ref_.getDownloadURL();
      }
      // Clean up empty entries
      final cleanLinks = _links.where((l) => (l['label'] as String? ?? '').isNotEmpty || (l['url'] as String? ?? '').isNotEmpty).toList();
      final cleanRoles = _clubRoles.where((r) => (r['roleName'] as String? ?? '').isNotEmpty).toList();
      final cleanAwards = _awards.where((a) => (a['title'] as String? ?? '').isNotEmpty).toList();
      await ref.read(firestoreProvider).collection('users').doc(widget.user.uid).update({
        'displayName': _displayNameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'department': _departmentCtrl.text.trim().isEmpty ? null : _departmentCtrl.text.trim(),
        'className': _classNameCtrl.text.trim().isEmpty ? null : _classNameCtrl.text.trim(),
        'photoUrl': photoUrl,
        'inWorkshop': _inWorkshop,
        'links': cleanLinks,
        'clubRoles': cleanRoles,
        'unitResponsibilities': _unitResponsibilities.where((s) => s.trim().isNotEmpty).toList(),
        'awards': cleanAwards,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil güncellendi.'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2))),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppConstants.radiusMd), border: Border.all(color: AppColors.border)),
        child: Column(children: children.asMap().entries.map((entry) {
          return Column(children: [entry.value, if (entry.key != children.length - 1) const Divider(height: 1, color: AppColors.border)]);
        }).toList()),
      ),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow({required this.icon, required this.label, required this.value, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
