import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../models/about_models.dart';
import '../providers/about_providers.dart';
import 'about_edit_sheet.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(aboutSectionsProvider);
    final membersAsync = ref.watch(aboutMembersProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hakkımızda'),
        backgroundColor: AppColors.surface,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.primaryGreen),
              onPressed: () => showAboutEditSheet(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sectionsAsync.when(
            data: (sections) {
              if (sections.isEmpty) {
                if (isAdmin) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        const Icon(Icons.edit_note,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        const Text(
                            'Henüz hakkımızda içeriği eklenmemiş.',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              showAboutEditSheet(context),
                          icon: const Icon(Icons.edit_outlined,
                              size: 18),
                          label: const Text('İçerik Ekle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                }
                return const Center(
                  child: Text('Henüz içerik eklenmemiş.',
                      style: TextStyle(
                          color: AppColors.textSecondary)),
                );
              }
              return Column(
                children: sections
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: 20),
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(s.title,
                                    style: const TextStyle(
                                        color:
                                            AppColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight:
                                            FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text(s.content,
                                    style: const TextStyle(
                                        color: AppColors
                                            .textSecondary,
                                        fontSize: 14,
                                        height: 1.5)),
                              ]),
                        ))
                    .toList(),
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Hata: $e')),
          ),
          const SizedBox(height: 20),
          const Text('ONURSAL ÜYELERİMİZ',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          membersAsync.when(
            data: (members) {
              final honorary =
                  members.where((m) => m.type == MemberType.honorary).toList();
              if (honorary.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Henüz onursal üye eklenmemiş.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: honorary
                    .map((m) => GestureDetector(
                          onTap: () =>
                              _showHonoraryDetail(context, m),
                          child: Column(children: [
                            CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.surface2,
                                backgroundImage: m.photoUrl != null &&
                                        m.photoUrl!.isNotEmpty
                                    ? NetworkImage(m.photoUrl!)
                                    : null,
                                child: m.photoUrl == null ||
                                        m.photoUrl!.isEmpty
                                    ? const Icon(Icons.person,
                                        color: AppColors.textSecondary)
                                    : null),
                            const SizedBox(height: 4),
                            Text(m.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12)),
                            if (m.role != null)
                              Text(m.role!,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10)),
                          ]),
                        ))
                    .toList(),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ],
      ),
    );
  }
}

/// Shows a detail dialog for the given honorary member.
void _showHonoraryDetail(BuildContext context, AboutMember m) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(m.name,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.photoUrl != null && m.photoUrl!.isNotEmpty)
              Center(
                child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.surface2,
                    backgroundImage: NetworkImage(m.photoUrl!)),
              ),
            if (m.role != null) ...[
              const SizedBox(height: 12),
              const Text('Görevi / Ünvanı',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1)),
              const SizedBox(height: 4),
              Text(m.role!,
                  style:
                      const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat')),
      ],
    ),
  );
}

/// Default content shown when Firestore has no about sections yet.
class _DefaultAboutContent extends StatelessWidget {
  const _DefaultAboutContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SARGE Kulübü',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'SARGE, Savunma ve ArGe Teknolojileri Kulübü olarak '
          'öğrencilerin savunma sanayii, mühendislik ve teknoloji alanlarında '
          'kendilerini geliştirmelerini amaçlayan bir üniversite kulübüdür.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5),
        ),
        const SizedBox(height: 24),
        const Text('Amacımız',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          '• Öğrencileri savunma sanayii ve ArGe konularında bilinçlendirmek\n'
          '• Takım çalışması ve proje yönetimi becerilerini geliştirmek\n'
          '• Üniversite-sanayi iş birliğini güçlendirmek\n'
          '• Öğrencilerin teknik ve sosyal gelişimine katkıda bulunmak',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.6),
        ),
        const SizedBox(height: 24),
        const Text('Vizyonumuz',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Türkiye\'nin savunma sanayii alanında yetişmiş insan gücüne '
          'katkı sağlayan, yenilikçi ve öncü bir öğrenci topluluğu olmak.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('İletişim',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                'E-posta: sarge@edu.tr\n'
                'Adres: Üniversite Kampüsü, Mühendislik Fakültesi\n'
                'Sosyal Medya: @sargekulubu',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}