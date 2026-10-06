import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/operation_feedback.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Ayarlar',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ),
            _SettingsSection(title: 'Hesap', children: [
              _SettingsTile(
                  icon: Icons.person_outline,
                  title: appUser?.displayName ?? 'Kullanıcı',
                  subtitle: appUser?.email ?? '',
                  onTap: () {}),
              _SettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'Rol',
                  subtitle: appUser?.isAdmin == true ? 'Admin' : 'Üye',
                  onTap: () {}),
              _SettingsTile(
                  icon: Icons.logout,
                  title: 'Çıkış Yap',
                  subtitle: null,
                  isDestructive: true,
                  onTap: () async {
                    await ref.read(authControllerProvider).signOut();
                    if (context.mounted) context.go('/login');
                  }),
            ]),
            const SizedBox(height: AppConstants.spacingLg),
            _SettingsSection(title: 'Görünüm', children: [
              _SettingsTile(
                icon: Icons.brightness_6_outlined,
                title: 'Tema',
                subtitle: ref.watch(themeModeProvider) == ThemeMode.dark
                    ? 'Koyu (Siyah)'
                    : 'Açık (Beyaz)',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Tema Seçimi'),
                      content:
                          Column(mainAxisSize: MainAxisSize.min, children: [
                        RadioGroup<ThemeMode>(
                          groupValue: ref.watch(themeModeProvider),
                          onChanged: (v) {
                            if (v != null) {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(v);
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadioListTile<ThemeMode>(
                                    title: Text('Koyu (Siyah)'),
                                    value: ThemeMode.dark),
                                RadioListTile<ThemeMode>(
                                    title: Text('Açık (Beyaz)'),
                                    value: ThemeMode.light),
                              ]),
                        ),
                      ]),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('İptal'))
                      ],
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: AppConstants.spacingLg),
            _SettingsSection(title: 'Uygulama', children: [
              _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Hakkında',
                  subtitle: 'SARGE Kulüp Yönetim v${AppConstants.appVersion}',
                  onTap: () {}),
              _SettingsTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Hata Bildir',
                  subtitle: 'Sorun bildirmek için tıklayın',
                  onTap: () => context.push('/report-bug')),
            ]),
            const SizedBox(height: AppConstants.spacingLg),
            _SettingsSection(title: 'Hesap Yönetimi', children: [
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Hesabımı Sil',
                subtitle: 'Hesabınız kalıcı olarak silinir',
                isDestructive: true,
                onTap: () => _confirmDeleteAccount(),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    // Step 1: Warning confirmation dialog.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz. '
          'Tüm puanlarınız, takım üyelikleriniz ve profil bilgileriniz kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Hesabımı Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // Step 2: Password re-authentication dialog.
    final passwordCtrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şifrenizi Girin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Güvenlik için hesabınızı silmeden önce şifrenizi tekrar girmeniz gerekiyor.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                hintText: 'Mevcut şifreniz',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, passwordCtrl.text),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
    passwordCtrl.dispose();
    if (password == null || password.isEmpty) return;
    if (!mounted) return;

    // Step 3: Execute deletion with loading overlay + SnackBar feedback.
    final ok = await runOperationWithFeedback(
      context: context,
      loadingMessage: 'Hesabınız siliniyor...',
      successMessage: 'Hesabınız başarıyla silindi.',
      operation: () =>
          ref.read(authControllerProvider).deleteAccount(password: password),
    );
    if (ok && mounted) {
      context.go('/login');
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2))),
      Container(
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.border)),
          child: Column(
              children: children.asMap().entries.map((entry) {
            return Column(children: [
              entry.value,
              if (entry.key != children.length - 1)
                Divider(height: 1, color: AppColors.border)
            ]);
          }).toList())),
    ]);
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  const _SettingsTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.isDestructive = false});
  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: isDestructive
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDestructive
                              ? AppColors.error.withValues(alpha: 0.3)
                              : AppColors.border)),
                  child: Icon(icon,
                      size: 16,
                      color: isDestructive
                          ? AppColors.error
                          : AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12))
                    ],
                  ])),
              if (!isDestructive)
                Icon(Icons.chevron_right, size: 18, color: AppColors.border),
            ])));
  }
}
