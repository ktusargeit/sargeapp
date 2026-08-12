import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';

/// Firestore'da `contact` koleksiyonunda `info` dokümanı olarak saklanır.
final contactInfoProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('contact')
      .doc('info')
      .snapshots()
      .map((doc) => doc.exists ? doc.data() : null);
});

class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactAsync = ref.watch(contactInfoProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İletişim'),
        backgroundColor: AppColors.surface,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.primaryGreen),
              onPressed: () => _showEditDialog(
                  context, ref, contactAsync.valueOrNull),
            ),
        ],
      ),
      body: contactAsync.when(
        data: (data) {
          if (data == null || data.isEmpty) {
            if (isAdmin) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.contact_mail_outlined,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('Henüz iletişim bilgileri eklenmemiş.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showEditDialog(context, ref, null),
                      icon:
                          const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('İletişim Bilgisi Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const Center(
              child: Text('Henüz iletişim bilgisi eklenmemiş.',
                  style:
                      TextStyle(color: AppColors.textSecondary)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (data['title'] != null)
                Text(data['title'] as String,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              if (data['description'] != null) ...[
                const SizedBox(height: 12),
                Text(data['description'] as String,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5)),
              ],
              const SizedBox(height: 28),
              if (data['email'] != null ||
                  data['phone'] != null ||
                  data['address'] != null) ...[
                const Text('İLETİŞİM BİLGİLERİ',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      if (data['email'] != null)
                        _ContactRow(
                          icon: Icons.email_outlined,
                          label: 'E-posta',
                          value: data['email'] as String,
                        ),
                      if (data['phone'] != null)
                        _ContactRow(
                          icon: Icons.phone_outlined,
                          label: 'Telefon',
                          value: data['phone'] as String,
                        ),
                      if (data['address'] != null)
                        _ContactRow(
                          icon: Icons.location_on_outlined,
                          label: 'Adres',
                          value: data['address'] as String,
                        ),
                    ],
                  ),
                ),
              ],
              if (data['instagram'] != null ||
                  data['website'] != null ||
                  data['socialLinks'] != null) ...[
                const SizedBox(height: 28),
                const Text('SOSYAL MEDYA',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      if (data['instagram'] != null)
                        _ContactRow(
                          icon: Icons.alternate_email,
                          label: 'Instagram',
                          value: data['instagram'] as String,
                        ),
                      if (data['website'] != null)
                        _ContactRow(
                          icon: Icons.language_outlined,
                          label: 'Web Sitesi',
                          value: data['website'] as String,
                        ),
                      if (data['socialLinks'] != null)
                        _ContactRow(
                          icon: Icons.link,
                          label: 'Diğer Bağlantılar',
                          value: data['socialLinks'] as String,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Yüklenemedi: $e',
                style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}

void _showEditDialog(
    BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
  final titleCtrl =
      TextEditingController(text: existing?['title'] as String? ?? '');
  final descCtrl = TextEditingController(
      text: existing?['description'] as String? ?? '');
  final emailCtrl =
      TextEditingController(text: existing?['email'] as String? ?? '');
  final phoneCtrl =
      TextEditingController(text: existing?['phone'] as String? ?? '');
  final addressCtrl =
      TextEditingController(text: existing?['address'] as String? ?? '');
  final instaCtrl =
      TextEditingController(text: existing?['instagram'] as String? ?? '');
  final webCtrl =
      TextEditingController(text: existing?['website'] as String? ?? '');
  final socialCtrl = TextEditingController(
      text: existing?['socialLinks'] as String? ?? '');
  bool saving = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('İletişim Bilgilerini Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(titleCtrl, 'Sayfa Başlığı',
                  'Örn: Bize Ulaşın'),
              const SizedBox(height: 12),
              _buildField(descCtrl, 'Açıklama', 'Kulüp iletişim metni...',
                  maxLines: 3),
              const SizedBox(height: 12),
              _buildField(emailCtrl, 'E-posta', 'ornek@edu.tr'),
              const SizedBox(height: 12),
              _buildField(phoneCtrl, 'Telefon', '+90 ...'),
              const SizedBox(height: 12),
              _buildField(
                  addressCtrl, 'Adres', 'Üniversite Kampüsü...'),
              const SizedBox(height: 12),
              _buildField(
                  instaCtrl, 'Instagram', '@kullaniciadi'),
              const SizedBox(height: 12),
              _buildField(webCtrl, 'Web Sitesi',
                  'https://...'),
              const SizedBox(height: 12),
              _buildField(socialCtrl, 'Diğer Bağlantılar',
                  'Linkler veya metin...',
                  maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    setDialogState(() => saving = true);
                    try {
                      await ref
                          .read(firestoreProvider)
                          .collection('contact')
                          .doc('info')
                          .set({
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'instagram': instaCtrl.text.trim(),
                        'website': webCtrl.text.trim(),
                        'socialLinks': socialCtrl.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setDialogState(() => saving = false);
                    }
                  },
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
}

Widget _buildField(TextEditingController ctrl, String label, String hint,
    {int maxLines = 1}) {
  return TextField(
    controller: ctrl,
    maxLines: maxLines,
    style: const TextStyle(color: AppColors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12),
    ),
  );
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}