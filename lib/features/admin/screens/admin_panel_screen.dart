import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_providers.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Yönetim')),
        body: const Center(
          child: Text('Bu bölüme erişim yetkiniz yok.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Yönetim'), backgroundColor: AppColors.surface),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(icon: Icons.people_outline, title: 'Kullanıcılar', subtitle: 'Kullanıcıları yönet', color: AppColors.panelBlue, onTap: () => context.push('/admin/users')),
          const SizedBox(height: 12),
          _AdminCard(icon: Icons.groups_outlined, title: 'Takımlar', subtitle: 'Takım oluştur, üye ekle/çıkar', color: AppColors.teamOrange, onTap: () => context.push('/admin/teams')),
          const SizedBox(height: 12),
          _AdminCard(icon: Icons.category_outlined, title: 'Birimler & Kategoriler', subtitle: 'Birim ve kategori yönetimi', color: AppColors.tasksGreen, onTap: () => context.push('/admin/inventory-settings')),
          const SizedBox(height: 12),
          _AdminCard(icon: Icons.task_alt, title: 'Görevler', subtitle: 'Tüm görevleri yönet ve onayla', color: AppColors.tasksGreen, onTap: () => context.push('/tasks')),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _AdminCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.border),
        ]),
      ),
    );
  }
}