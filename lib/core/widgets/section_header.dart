import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable section header with left accent bar.
class SectionHeader extends StatelessWidget {
  final String title;
  final Color accentColor;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.accentColor = AppColors.primaryBlue,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
