import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../models/club_info_models.dart';
import '../providers/club_info_providers.dart';

/// Shows the "Onursal Üye Ekle / Yönet" sheet.
void showHonoraryAddSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => const HonoraryAddSheet(),
  );
}

class HonoraryAddSheet extends ConsumerStatefulWidget {
  const HonoraryAddSheet({super.key});
  @override
  ConsumerState<HonoraryAddSheet> createState() => _HonoraryAddSheetState();
}

class _HonoraryAddSheetState extends ConsumerState<HonoraryAddSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final membersAsync = ref.watch(honoraryMembersProvider);
    final allUsers = usersAsync.valueOrNull ?? const <AppUser>[];
    final members = membersAsync.valueOrNull ?? const <HonoraryMember>[];
    final existingIds = members.map((m) => m.userId).toSet();

    final available = allUsers.where((u) {
      if (existingIds.contains(u.uid)) return false;
      if (_query.isEmpty) return true;
      return u.displayName.toLowerCase().contains(_query) ||
          u.email.toLowerCase().contains(_query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Onursal Üyeler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sistemdeki kullanıcılardan seçerek onursal üye ekleyin.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              // Existing honorary members with note edit + remove.
              if (members.isNotEmpty) ...[
                Text('MEVCUT ONURSAL ÜYELER',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1)),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: members
                        .map((m) => _ExistingMemberTile(member: m))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
              ],
              TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Kullanıcı ara...',
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: AppColors.textSecondary),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: usersAsync.when(
                  data: (_) {
                    if (available.isEmpty) {
                      return Center(
                        child: Text('Eklenebilecek kullanıcı yok.',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: available.length,
                      itemBuilder: (_, i) {
                        final user = available[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SafeAvatar(url: user.photoUrl, radius: 16),
                          title: Text(user.displayName,
                              style: TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text(user.email,
                              style: TextStyle(color: AppColors.textSecondary)),
                          trailing: const Icon(Icons.add_circle_outline,
                              size: 20, color: AppColors.primaryGreen),
                          onTap: () =>
                              _promptNoteAndAdd(user, allUsers),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Hata: $e'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _promptNoteAndAdd(
      AppUser user, List<AppUser> allUsers) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Onursal Üye Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${user.displayName} onursal üye olarak eklenecek.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Kısa Not / Sebep',
                hintText: 'Örn: Kulübün kurucusu, 3 yıl kaptanlık yaptı...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
              child: const Text('Ekle')),
        ],
      ),
    );

    if (note == null) return;

    final addedBy = ref.read(currentAppUserProvider).value?.uid;
    final repo = ref.read(clubInfoRepositoryProvider);
    try {
      await repo.addHonoraryMember(
        userId: user.uid,
        note: note,
        addedBy: addedBy ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${user.displayName} onursal üye olarak eklendi.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Eklenemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }
}

class _ExistingMemberTile extends ConsumerWidget {
  final HonoraryMember member;
  const _ExistingMemberTile({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(member.userId));
    final user = userAsync.valueOrNull;
    final name = user?.displayName ?? 'Bilinmiyor';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SafeAvatar(url: user?.photoUrl, radius: 16),
      title: Text(name, style: TextStyle(color: AppColors.textPrimary)),
      subtitle: member.note.isNotEmpty
          ? Text(member.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 17, color: AppColors.textSecondary),
            onPressed: () => _editNote(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 17, color: AppColors.error),
            onPressed: () => _remove(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: member.note);
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notu Düzenle'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (note == null) return;
    await ref
        .read(clubInfoRepositoryProvider)
        .updateHonoraryMember(member.id, note);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Onursal Üyeden Çıkar'),
        content: const Text('Bu kişi onursal üye listesinden çıkarılacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await runDeleteWithFeedback(
      context: context,
      successMessage: 'Onursal üye çıkarıldı.',
      operation: () => ref
          .read(clubInfoRepositoryProvider)
          .removeHonoraryMember(member.id),
    );
  }
}