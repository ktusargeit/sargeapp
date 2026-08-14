import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// App-wide shared delete button.
///
/// Guarantees a 44x44 tappable area (Material touch-target guideline) while
/// keeping the icon itself small, and provides ripple + hover + highlight
/// press feedback so the tap always feels responsive.
///
/// Two usage modes:
///  * Supply [onPressed] to fully control the action (e.g. a screen already
///    shows its own confirmation dialog).
///  * Supply [onConfirm] to get a built-in confirmation dialog + async delete.
class CustomDeleteButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Future<void> Function()? onConfirm;
  final String confirmTitle;
  final String confirmMessage;
  final double iconSize;
  final String? tooltip;

  const CustomDeleteButton({
    super.key,
    this.onPressed,
    this.onConfirm,
    this.confirmTitle = 'Sil',
    this.confirmMessage =
        'Bu öğe kalıcı olarak silinecek. Onaylıyor musunuz?',
    this.iconSize = 18,
    this.tooltip = 'Sil',
  });

  Future<void> _handleTap(BuildContext context) async {
    if (onPressed != null) {
      onPressed!();
      return;
    }
    if (onConfirm == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmMessage),
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
    );
    if (confirmed == true) {
      await onConfirm!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? 'Sil',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.error.withValues(alpha: 0.08),
          splashColor: AppColors.error.withValues(alpha: 0.18),
          highlightColor: AppColors.error.withValues(alpha: 0.12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.delete_outline,
              size: iconSize,
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }
}