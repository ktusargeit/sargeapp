import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/app_colors.dart';
import 'profile_common.dart';

// ---------------------------------------------------------------------------
// CONNECTIONS TAB (big, tappable social links)
// ---------------------------------------------------------------------------

class ProfileConnectionsSection extends StatelessWidget {
  final AppUser user;
  const ProfileConnectionsSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.email.isNotEmpty) ...[
            const ProfileSectionHeader(title: 'İLETİŞİM'),
            ProfileContactCard(email: user.email),
            const SizedBox(height: AppConstants.spacingLg),
          ],
          const ProfileSectionHeader(title: 'BAĞLANTILAR'),
          if (user.links.isEmpty)
            const ProfileEmptyCard(
              'Henüz bağlantı eklenmedi.',
              icon: Icons.hub_outlined,
            )
          else
            ...user.links.map((l) {
              final label = l['label'] as String? ?? '';
              final url = l['url'] as String? ?? '';
              final type = l['type'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ProfileLinkCard(label: label, url: url, type: type),
              );
            }),
        ],
      ),
    );
  }
}

class ProfileContactCard extends StatelessWidget {
  final String email;
  const ProfileContactCard({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => launchProfileUrl('mailto:$email'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryBlueAccent,
                      AppColors.primaryBlue
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mail_outline,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('E-posta',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(email,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileLinkCard extends StatelessWidget {
  final String label;
  final String url;
  final String type;
  const ProfileLinkCard({
    super.key,
    required this.label,
    required this.url,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final visual = profileLinkVisual(type, label);
    final color = visual.$1;
    final icon = visual.$2;
    final displayLabel = label.trim().isNotEmpty ? label.trim() : url.trim();
    final host = profileHostFromUrl(url);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => launchProfileUrl(url),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: 0.12),
                AppColors.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.9), color],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    if (host.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

String profileHostFromUrl(String url) {
  final normalized = profileNormalizeUri(url);
  if (normalized == null) return '';
  return normalized.host.isEmpty ? url.trim() : normalized.host;
}

(Color, IconData) profileLinkVisual(String type, String label) {
  final t = type.toLowerCase();
  final l = label.toLowerCase();

  if (t.contains('github') || l.contains('github')) {
    return (const Color(0xFF6E40C9), Icons.code);
  }
  if (t.contains('linkedin') || l.contains('linkedin')) {
    return (const Color(0xFF0A66C2), Icons.business_center);
  }
  if (t.contains('instagram') || l.contains('instagram')) {
    return (const Color(0xFFE4405F), Icons.camera_alt);
  }
  if (t.contains('twitter') || t.contains('x') || l.contains('twitter')) {
    return (const Color(0xFF1DA1F2), Icons.alternate_email);
  }
  if (t.contains('youtube') || l.contains('youtube')) {
    return (const Color(0xFFFF0000), Icons.play_circle_outline);
  }
  if (t.contains('web') ||
      t.contains('site') ||
      t == 'url' ||
      l.contains('web') ||
      l.contains('site')) {
    return (AppColors.teamAccent, Icons.language);
  }
  if (t.contains('mail') ||
      t.contains('email') ||
      l.contains('mail') ||
      l.contains('email')) {
    return (AppColors.info, Icons.mail_outline);
  }
  if (t.contains('discord') || l.contains('discord')) {
    return (const Color(0xFF5865F2), Icons.forum);
  }
  if (t.contains('phone') ||
      t.contains('tel') ||
      l.contains('phone') ||
      l.contains('tel')) {
    return (AppColors.primaryGreen, Icons.phone_outlined);
  }
  return (AppColors.depoAccent, Icons.link);
}

Uri? profileNormalizeUri(String url) {
  var u = url.trim();
  if (u.isEmpty) return null;
  if (!u.contains('://')) u = 'https://$u';
  return Uri.tryParse(u);
}

Future<void> launchProfileUrl(String url) async {
  final uri = profileNormalizeUri(url);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
