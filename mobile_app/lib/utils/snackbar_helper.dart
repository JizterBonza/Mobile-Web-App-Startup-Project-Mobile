import 'dart:async';

import 'package:flutter/material.dart';
import '../constants/constants.dart';

/// Utility class for showing consistent snackbars throughout the app
class SnackbarHelper {
  static OverlayEntry? _dialogErrorEntry;
  static Timer? _dialogErrorTimer;

  static void _removeDialogError() {
    _dialogErrorTimer?.cancel();
    _dialogErrorTimer = null;
    _dialogErrorEntry?.remove();
    _dialogErrorEntry?.dispose();
    _dialogErrorEntry = null;
  }

  /// Show a success snackbar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show an error snackbar
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final route = ModalRoute.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (route is DialogRoute && overlay != null) {
      _removeDialogError();

      // The dialog route and its barrier sit above the page's Scaffold. Add
      // this snackbar to the root overlay so it stays in front of both.
      final entry = OverlayEntry(
        builder: (overlayContext) => Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.viewInsetsOf(overlayContext).bottom +
              MediaQuery.paddingOf(overlayContext).bottom,
          child: IgnorePointer(
            child: SnackBar(
              content: Text(message),
              backgroundColor: AppColors.error,
              duration: duration,
              behavior: SnackBarBehavior.floating,
              animation: const AlwaysStoppedAnimation<double>(1),
            ),
          ),
        ),
      );
      _dialogErrorEntry = entry;
      overlay.insert(entry);
      _dialogErrorTimer = Timer(duration, _removeDialogError);
      route.popped.then((_) {
        if (identical(_dialogErrorEntry, entry)) _removeDialogError();
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show an info snackbar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryGreenLight,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a warning snackbar
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a loading snackbar with spinner
  static void showLoading(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.grey[800],
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Hide the current snackbar
  static void hide(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Show a custom snackbar with full control
  static void showCustom(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.grey[800],
        duration: duration,
        behavior: behavior,
        action: action,
      ),
    );
  }
}
