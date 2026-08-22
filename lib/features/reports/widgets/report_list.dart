import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/operation_feedback.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/custom_delete_button.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import 'report_detail_panel.dart';

/// Type selector option (Hata / Öneri).
class ReportTypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const ReportTypeOption({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? color : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab showing the bug list with search + person filter.
class ReportListTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  const ReportListTab({super.key, required this.isAdmin});

  @override
  ConsumerState<ReportListTab> createState() => _ReportListTabState();
}

class _ReportListTabState extends ConsumerState<ReportListTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _personFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(bugReportsProvider);
    final allUsers = ref.watch(allUsersProvider).valueOrNull ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ara...',
                    hintStyle: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: AppColors.textSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _personFilter,
                    isDense: true,
                    dropdownColor: AppColors.surface2,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    hint: Text('Kişi',
                        style:
                            TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    items: [
                      if (_personFilter != null)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tümü', style: TextStyle(fontSize: 12)),
                        ),
                      ...allUsers.map((u) => DropdownMenuItem<String?>(
                            value: u.uid,
                            child: Text(u.displayName,
                                style: const TextStyle(fontSize: 12)),
                          )),
                    ],
                    onChanged: (v) => setState(() => _personFilter = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: reportsAsync.when(
            data: (reports) {
              var filtered = reports;
              if (_personFilter != null) {
                filtered = filtered
                    .where((r) => r.submittedBy == _personFilter)
                    .toList();
              }
              if (_query.isNotEmpty) {
                filtered = filtered
                    .where((r) =>
                        (r.title.toLowerCase().contains(_query)) ||
                        (r.message.toLowerCase().contains(_query)) ||
                        (r.submittedByName.toLowerCase().contains(_query)))
                    .toList();
              }
              if (filtered.isEmpty) {
                return Center(
                  child: Text('Kayıt bulunamadı.',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              final sorted = [...filtered]
                ..sort((a, b) => (b.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(a.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0)));
              return ListView.builder(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final report = sorted[i];
                  return ReportCard(
                    key: ValueKey(report.id),
                    report: report,
                    isAdmin: widget.isAdmin,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text('Hata: $e',
                    style: const TextStyle(color: AppColors.error))),
          ),
        ),
      ],
    );
  }
}

/// Standardized bug report card.
class ReportCard extends ConsumerWidget {
  final BugReport report;
  final bool isAdmin;

  const ReportCard({super.key, required this.report, required this.isAdmin});

  Color _statusColor() {
    if (report.isSuggestion) return AppColors.panelBlue;
    switch (report.status) {
      case 'investigating':
        return AppColors.warning;
      case 'done':
        return AppColors.success;
      default:
        return AppColors.error;
    }
  }

  Color _typeColor() {
    return report.isSuggestion ? AppColors.panelBlue : _statusColor();
  }

  IconData _statusIcon() {
    if (report.isSuggestion) return Icons.lightbulb_outline;
    switch (report.status) {
      case 'investigating':
        return Icons.search;
      case 'done':
        return Icons.check_circle;
      default:
        return Icons.bug_report_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replyCount = report.messageCount;
    final statusLabel = report.statusLabel;
    final hasReplyBadge = replyCount > 0;
    final currentUid = ref.read(authStateProvider).value?.uid;
    final isOwner = currentUid != null && report.submittedBy == currentUid;
    final canEdit = isOwner;
    final canDelete = isAdmin || isOwner;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_statusIcon(), size: 18, color: _typeColor()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.title.isEmpty ? report.message : report.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration:
                            report.isResolved ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (canEdit)
                    AppIconButton(
                      icon: Icons.edit_outlined,
                      iconSize: 18,
                      color: AppColors.primaryGreen,
                      tooltip: 'Düzenle',
                      onTap: () => _editReport(context, ref),
                    ),
                  if (canDelete)
                    CustomDeleteButton(
                      onPressed: () => _deleteReport(context, ref),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _typeColor().withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      report.isSuggestion ? 'Öneri' : 'Hata',
                      style: TextStyle(
                        color: _typeColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!report.isSuggestion) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor().withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: _statusColor().withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: _statusColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (hasReplyBadge) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.panelBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.panelBlue.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text('$replyCount',
                              style: const TextStyle(
                                  color: AppColors.panelBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        report.submittedByName,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                      if (report.createdAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm', 'tr_TR')
                              .format(report.createdAt!),
                          style: TextStyle(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.7),
                              fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (report.isResolved &&
                  report.resolvedByName != null &&
                  report.resolvedByName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      '${report.resolvedByName} çözdü',
                      style: const TextStyle(
                          color: AppColors.success, fontSize: 11),
                    ),
                    if (report.resolvedAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM HH:mm', 'tr_TR')
                            .format(report.resolvedAt!),
                        style: TextStyle(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ReportDetailView(
        reportId: report.id,
        isAdmin: isAdmin,
      ),
    );
  }

  void _editReport(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController(text: report.title);
    final msgCtrl = TextEditingController(text: report.message);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildirimi Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Açıklama'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ref
                  .read(firestoreProvider)
                  .collection('reports')
                  .doc(report.id)
                  .update({
                'title': titleCtrl.text.trim(),
                'message': msgCtrl.text.trim(),
              });
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _deleteReport(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildirimi Sil'),
        content: const Text(
            'Bu bildirim kalıcı olarak silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      if (!context.mounted) return;
      await runDeleteWithFeedback(
        context: context,
        successMessage: 'Bildirim başarıyla silindi.',
        operation: () => ref
            .read(firestoreProvider)
            .collection('reports')
            .doc(report.id)
            .delete(),
      );
    });
  }
}