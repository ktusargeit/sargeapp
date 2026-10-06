import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import '../theme/app_colors.dart';

class TopSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    bool isError = false,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay != null) {
      showTopSnackBar(
        overlay,
        isError
            ? CustomSnackBar.error(message: message)
            : CustomSnackBar.success(
                message: message, backgroundColor: AppColors.success),
      );
    }
  }

  static void showSnackBar(BuildContext context, SnackBar snackBar) {
    final overlay = Overlay.maybeOf(context);
    if (overlay != null) {
      showSnackBarWithOverlay(overlay, snackBar);
    }
  }

  static void showSnackBarWithOverlay(OverlayState overlay, SnackBar snackBar) {
    String message = '';
    if (snackBar.content is Text) {
      message = (snackBar.content as Text).data ?? '';
    }

    // Determine error based on background color or just default
    bool isError = snackBar.backgroundColor == AppColors.error;

    showTopSnackBar(
      overlay,
      isError
          ? CustomSnackBar.error(message: message)
          : CustomSnackBar.success(
              message: message, backgroundColor: AppColors.success),
    );
  }
}
