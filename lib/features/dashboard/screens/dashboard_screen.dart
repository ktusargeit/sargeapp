import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../announcements/models/announcement_models.dart';
import '../../announcements/providers/announcement_providers.dart';
import '../widgets/announcement_feed.dart';
import '../widgets/dashboard_summary_cards.dart';

/// Home / Panel screen - kulüp merkezli dashboard.
class DashboardScreen extends ConsumerStatefulWidget {
  final String? initialAnnouncementId;
  const DashboardScreen({super.key, this.initialAnnouncementId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final targetId = widget.initialAnnouncementId;
    if (targetId != null && targetId.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openAnnouncement(targetId));
    }
  }

  Future<void> _openAnnouncement(String id) async {
    if (!mounted) return;
    final announcements = ref.read(announcementsProvider).valueOrNull ?? [];
    Announcement? found;
    for (final a in announcements) {
      if (a.id == id) {
        found = a;
        break;
      }
    }
    if (found == null || !mounted) return;
    final target = found;

    // Reuse the same "can comment" resolution used by AnnouncementCard.
    AnnouncementCard.openAnnouncementDetail(context, ref, target);
  }

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(announcementsProvider);
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final isAdmin = appUser?.isAdmin ?? false;
    final authState = ref.watch(authStateProvider);
    // CRITICAL: `.valueOrNull`, never `.value`.
    //
    // `DashboardScreen` is the body of the `ShellRoute`. When the auth provider
    // is in an ERROR state, `AsyncError.value` RETHROWS (riverpod
    // common.dart:495). Throwing here aborts the whole `AppShell` Scaffold build
    // — including its `bottomNavigationBar` — so the bottom navigation bar
    // silently disappears. `.valueOrNull` degrades to "not signed in".
    final isGuest = authState.valueOrNull == null;

    return Scaffold(
      backgroundColor: AppColors.panelBg,
      body: Column(
        children: [
          DashboardHeader(
              userName: appUser?.displayName,
              isAdmin: isAdmin,
              isGuest: isGuest),
          if (isGuest) const DashboardGuestBanner(),
          const Divider(height: 1, color: Color(0xFF1E3A5F)),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.panelBlue,
              onRefresh: () async =>
                  ref.refresh(announcementsProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'HAFTALIK LİDERLİK TABLOSU',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const DashboardLeaderboardCard(),
                  const SizedBox(height: AppConstants.spacingLg),
                  if (!isGuest && appUser != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'GÖREVLERİM',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const DashboardMyTasksCard(),
                    const SizedBox(height: AppConstants.spacingLg),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'DUYURULAR & ETKİNLİKLER',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  announcements.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return EmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'Henüz duyuru yok',
                          subtitle: isAdmin
                              ? 'İlk duyuruyu siz oluşturun!'
                              : 'Yeni duyurular burada görünecek.',
                          actionLabel: isAdmin ? 'Duyuru Oluştur' : null,
                          onAction: isAdmin ? _showAnnouncementDialog : null,
                        );
                      }
                      return Column(
                        children: items
                            .take(5)
                            .map((a) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12),
                                  child: AnnouncementCard(
                                    announcement: a,
                                    isAdmin: isAdmin,
                                  ),
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(
                            color: AppColors.panelBlue),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                            'Duyurular yüklenemedi: $e',
                            style:
                                const TextStyle(color: AppColors.error)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isGuest) const DashboardJoinCtaCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAnnouncementDialog,
              backgroundColor: AppColors.panelBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Duyuru',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            )
          : null,
    );
  }

  void _showAnnouncementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AnnouncementDialog(),
    );
  }
}