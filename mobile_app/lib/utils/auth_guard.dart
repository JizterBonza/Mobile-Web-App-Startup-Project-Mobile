import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/login_dialog.dart';

/// Returns true if the user has a stored auth token.
Future<bool> isLoggedIn() async {
  final token = await ApiService.getToken();
  return token != null && token.isNotEmpty;
}

/// If not logged in, shows [showLoginDialog] and returns false.
/// Otherwise returns true so the caller can proceed.
Future<bool> requireAuth(BuildContext context) async {
  if (await isLoggedIn()) return true;
  if (context.mounted) {
    await showLoginDialog(context);
  }
  return false;
}

/// Synchronous guard when guest state is already known (e.g. dashboard).
bool requireAuthOrShowLogin(BuildContext context, {required bool isGuest}) {
  if (!isGuest) return true;
  showLoginDialog(context);
  return false;
}
