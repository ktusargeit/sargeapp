import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';

class AdminMemberSectionLabel extends StatelessWidget {
  final String text;
  const AdminMemberSectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class AdminMemberHeaderCard extends StatelessWidget {
  final AppUser user;
  const AdminMemberHeaderCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeAvatar(url: user.photoUrl, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (user.isSuspended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'ASKIDA',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoChip(
                      Icons.badge_outlined,
                      roleLabel(user.role),
                      AppColors.panelBlue,
                    ),
                    const SizedBox(width: 8),
                    if (user.department != null && user.department!.isNotEmpty)
                      _infoChip(
                        Icons.apartment_outlined,
                        user.department!,
                        AppColors.teamAccent,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.stars,
                        size: 16, color: AppColors.sargeGold),
                    const SizedBox(width: 4),
                    Text(
                      '${user.points} puan',
                      style: const TextStyle(
                        color: AppColors.sargeGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${user.weeklyPoints} haftalık',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMemberSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? color;

  const AdminMemberSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: c,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// NOT: Eski `AdminMemberRoleEditor` widget'ı (yalnızca `users/{uid}.role`
// string'ini değiştiren dropdown + "Admin Yap/Çıkar" butonları) KALDIRILDI
// — Çakışma #1. Bu yol `titles` dizisini güncellemediği için ünvanları yetim
// bırakıyordu. Yerine tek merkez: `AdminMemberMultiRoleSheet`
// (`_setGlobalRole` + `showUserTitleManagementSheet`), çünkü onlar hem
// `titles` dizisini günceller hem de `UserTitleService.reconcileRole` ile
// `role` string'ini senkronlar.

class AdminMemberPointsEditor extends ConsumerStatefulWidget {
  final AppUser user;
  final bool canEdit;
  const AdminMemberPointsEditor(
      {super.key, required this.user, required this.canEdit});

  @override
  ConsumerState<AdminMemberPointsEditor> createState() =>
      _AdminMemberPointsEditorState();
}

class _AdminMemberPointsEditorState
    extends ConsumerState<AdminMemberPointsEditor> {
  bool _busy = false;

  Future<void> _editPoints({required bool isAdd}) async {
    final amountCtrl = TextEditingController(text: '1');

    // Teams the target user actually belongs to (for the team selector).
    final allTeams = ref.read(clubTeamsProvider).valueOrNull ?? <ClubTeam>[];
    final userTeams = allTeams
        .where((t) => widget.user.teamIds.contains(t.id))
        .toList();
    String? selectedTeamId =
        userTeams.isNotEmpty ? userTeams.first.id : null;

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isAdd ? 'Puan Ekle' : 'Puan Düş'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.user.displayName} — mevcut puan: ${widget.user.points}.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (userTeams.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedTeamId,
                    isExpanded: true,
                    dropdownColor: AppColors.surface2,
                    decoration: InputDecoration(
                      labelText: 'Takım Seç',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: userTeams
                        .map((t) => DropdownMenuItem<String>(
                              value: t.id,
                              child: Text(t.name,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedTeamId = v),
                  ),
                  const SizedBox(height: 12),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Kullanıcı herhangi bir takımda değil; puan genel olarak eklenecek.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAdd ? 'Eklenecek puan' : 'Düşülecek puan',
                    hintText: 'Miktar girin (pozitif tam sayı)',
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
                onPressed: () => Navigator.pop(ctx, {
                  'amount': amountCtrl.text.trim(),
                  'teamId': selectedTeamId,
                }),
                child: const Text('Uygula'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;
    final amount = result['amount'] ?? '';
    final selectedTeam = result['teamId'];
    final parsed = int.tryParse(amount) ?? 0;
    if (parsed <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Geçerli bir puan miktarı girin.'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    final delta = isAdd ? parsed : -parsed;

    ClubTeam? team;
    if (selectedTeam != null && selectedTeam.isNotEmpty) {
      for (final t in allTeams) {
        if (t.id == selectedTeam) {
          team = t;
          break;
        }
      }
    }

    setState(() => _busy = true);
    try {
      final currentUid = ref.read(authStateProvider).valueOrNull?.uid;
      try {
        await ref.read(firestoreProvider).collection('points_history').add({
          'targetUid': widget.user.uid,
          'targetName': widget.user.displayName,
          'delta': delta,
          'changedBy': currentUid,
          if (team != null) 'teamId': team.id,
          if (team != null) 'teamName': team.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'points': FieldValue.increment(delta),
        'weeklyPoints': FieldValue.increment(delta),
        if (team != null)
          'teamPoints.${team.id}': FieldValue.increment(delta),
      });

      if (mounted) {
        final teamLabel = team != null ? ' (${team.name})' : '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAdd
              ? '$delta puan eklendi$teamLabel.'
              : '${delta.abs()} puan düşüldü$teamLabel.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Puan güncellenemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canEdit) {
      return Text(
        'Puan düzenleme yetkisi admin ve birim sorumlusu rollerindedir.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _editPoints(isAdd: true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Puan Ekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              side: BorderSide(
                  color: AppColors.success.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _editPoints(isAdd: false),
            icon: const Icon(Icons.remove, size: 18),
            label: const Text('Puan Düş'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: BorderSide(
                  color: AppColors.warning.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}