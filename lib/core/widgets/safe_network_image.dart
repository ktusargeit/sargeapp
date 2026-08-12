import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Universal safe network image widget. Never crashes on load failure —
/// always shows a placeholder, loading spinner, or error icon gracefully.
class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final double? size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showLoadingIndicator;

  const SafeNetworkImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.size,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.showLoadingIndicator = true,
  });

  bool get _hasUrl => url != null && url!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = size ?? width;
    final effectiveHeight = size ?? height;

    Widget child;
    if (!_hasUrl) {
      child = errorWidget ?? _defaultError();
    } else {
      child = ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Image.network(
          url!,
          width: effectiveWidth,
          height: effectiveHeight,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            if (!showLoadingIndicator) return child;
            return _LoadingBox(
              width: effectiveWidth,
              height: effectiveHeight,
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('SafeNetworkImage error for $url: $error');
            return errorWidget ?? _defaultError();
          },
        ),
      );
    }

    if (borderRadius != null && _hasUrl) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _defaultError() {
    return Container(
      width: size ?? width,
      height: size ?? height,
      color: AppColors.surface2,
      child: const Center(
        child: Icon(Icons.broken_image_outlined,
            size: 24, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Convenience: circular avatar version of SafeNetworkImage.
class SafeAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final IconData fallbackIcon;

  const SafeAvatar({
    super.key,
    this.url,
    this.radius = 20,
    this.fallbackIcon = Icons.person_outline,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surface2,
      backgroundImage:
          url != null && url!.isNotEmpty ? NetworkImage(url!) : null,
      onBackgroundImageError:
          url != null && url!.isNotEmpty ? (_, __) {} : null,
      child: (url == null || url!.isEmpty)
          ? Icon(fallbackIcon,
              size: radius * 0.7, color: AppColors.textSecondary)
          : null,
    );
  }
}

class _LoadingBox extends StatelessWidget {
  final double? width;
  final double? height;

  const _LoadingBox({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface2,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}