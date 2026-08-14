import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Runs an async operation with standardized UX used app-wide:
///
///   1. A blocking loading overlay (spinner) is shown so the screen never
///      looks frozen while a slow Firestore write is in flight.
///   2. On success a green SnackBar with [successMessage] is shown.
///   3. On failure a red SnackBar with the error message is shown.
///
/// Returns `true` when [operation] completed without throwing.
///
/// The loading indicator is pushed on the root navigator so it correctly
/// overlays bottom sheets and nested navigators.
Future<bool> runOperationWithFeedback({
  required BuildContext context,
  required Future<void> Function() operation,
  String loadingMessage = 'İşleniyor...',
  required String successMessage,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(loadingMessage)),
          ],
        ),
      ),
    ),
  );

  try {
    await operation();
    if (!context.mounted) return true;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(successMessage),
      backgroundColor: AppColors.success,
    ));
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('İşlem başarısız: $e'),
      backgroundColor: AppColors.error,
    ));
    return false;
  }
}

/// Convenience wrapper for deletion operations.
Future<bool> runDeleteWithFeedback({
  required BuildContext context,
  required Future<void> Function() operation,
  String successMessage = 'Başarıyla silindi.',
}) {
  return runOperationWithFeedback(
    context: context,
    loadingMessage: 'Siliniyor...',
    successMessage: successMessage,
    operation: operation,
  );
}