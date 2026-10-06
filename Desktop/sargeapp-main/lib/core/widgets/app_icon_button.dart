import 'package:flutter/material.dart';

/// A tappable icon button with a guaranteed 44x44 hit area.
///
/// The icon itself stays small (matching surrounding icon buttons), but the
/// tappable region is enlarged and provides hover/press feedback (ink ripple +
/// hover highlight) so it is easy to hit and feels responsive.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double iconSize;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconSize = 18,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: color.withValues(alpha: 0.08),
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.10),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: iconSize,
              color: onTap == null ? color.withValues(alpha: 0.35) : color,
            ),
          ),
        ),
      ),
    );
  }
}
