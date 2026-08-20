import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Runs an async operation with standardized UX used app-wide:
///
///   1. A blocking loading overlay (spinner) is shown so the screen never
///      looks frozen while a slow Firestore write is in flight.
///   2. On success a green SnackBar with [successMessage] is shown.
///   3. On failure a red SnackBar with the error message is shown.
///   4. If the operation exceeds [timeout] it is abandoned and the user sees
///      a "taking too long" message instead of a forever-spinning overlay.
///
/// Returns `true` when [operation] completed without throwing.
///
/// The loading indicator is pushed on the root navigator so it correctly
/// overlays bottom sheets and nested navigators. Crucially, the root navigator
/// and the root [ScaffoldMessengerState] are captured BEFORE the operation
/// runs, so even when the widget that started the operation is unmounted by a
/// stream rebuild (the exact "Siliniyor..." stuck-delete bug), the overlay is
/// still dismissed and the SnackBar still shows.
Future<bool> runOperationWithFeedback({
  required BuildContext context,
  required Future<void> Function() operation,
  String loadingMessage = 'İşleniyor...',
  required String successMessage,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);

  showDialog<void>(
    context: context,
    useRootNavigator: true,
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

  void closeOverlay() {
    // `canPop` guards against popping an unrelated route in edge cases.
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  try {
    await operation().timeout(timeout);
    closeOverlay();
    messenger?.showSnackBar(SnackBar(
      content: Text(successMessage),
      backgroundColor: AppColors.success,
    ));
    return true;
  } on TimeoutException {
    closeOverlay();
    messenger?.showSnackBar(const SnackBar(
      content: Text('İşlem uzun sürüyor, lütfen tekrar deneyin.'),
      backgroundColor: AppColors.warning,
    ));
    return false;
  } catch (e) {
    closeOverlay();
    messenger?.showSnackBar(SnackBar(
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