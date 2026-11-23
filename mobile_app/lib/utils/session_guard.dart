import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../provider/provider.dart';
import '../services/api_service.dart';

/// Clears a rejected saved session once and returns the user to login.
class SessionGuard {
  SessionGuard._();

  static GlobalKey<NavigatorState>? navigatorKey;
  static Future<void>? _inFlight;

  static Future<void> forceLogout() {
    final current = _inFlight;
    if (current != null) return current;
    final run = _run();
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  /// A bearer request was rejected. Refresh once, then leave if that fails.
  static Future<void> onBearerRejected() async {
    final refreshed = await ApiService.refreshAccessToken();
    if (!refreshed) await forceLogout();
  }

  static Future<void> _run() async {
    await ApiService.clearLocalSession();
    await _clearProviders();
    _openLogin();
  }

  static Future<void> _clearProviders() async {
    final context = navigatorKey?.currentContext;
    if (context == null) return;
    _try(() => context.read<AddressProvider>().clearCache());
    _try(() => context.read<CategoryProvider>().clearCache());
    _try(() => context.read<ItemsProvider>().clearCache());
    _try(() => context.read<NotificationProvider>().clearCache());
    _try(() => context.read<OrdersProvider>().clearCache());
    _try(() => context.read<ShopsProvider>().clearCache());
    _try(() => context.read<BadgeProvider>().clear());
    _try(() => context.read<MessageProvider>().clear());
    try {
      await context.read<OrderStatusProvider>().clearCache();
    } catch (error) {
      debugPrint('Error clearing order statuses after session rejection: $error');
    }
  }

  static void _try(void Function() action) {
    try {
      action();
    } catch (error) {
      debugPrint('Error clearing session state: $error');
    }
  }

  static void _openLogin() {
    if (navigatorKey == null) return;
    final nav = navigatorKey!.currentState;
    if (nav != null && nav.mounted) {
      _replaceWithLogin(nav);
      return;
    }
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retry = navigatorKey?.currentState;
        if (retry != null && retry.mounted) _replaceWithLogin(retry);
      });
    } catch (error) {
      debugPrint('Error scheduling login after session rejection: $error');
    }
  }

  static void _replaceWithLogin(NavigatorState nav) {
    try {
      var onLogin = false;
      nav.popUntil((route) {
        onLogin = route.settings.name == '/';
        return true;
      });
      if (onLogin) return;
      nav.pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      debugPrint('Error opening login after session rejection: $error');
    }
  }
}
