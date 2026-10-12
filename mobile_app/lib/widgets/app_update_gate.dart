import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/app_update_provider.dart';
import 'force_update_dialog.dart';

/// Checks for app updates on launch and resume, and blocks the app with
/// [ForceUpdateDialog] when the backend requires an update.
class AppUpdateGate extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const AppUpdateGate({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  late final AppUpdateProvider _updater;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updater = context.read<AppUpdateProvider>();
    _updater.addListener(_onUpdateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updater.checkForUpdate();
    });
  }

  @override
  void dispose() {
    _updater.removeListener(_onUpdateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updater.checkForUpdate();
    }
  }

  void _onUpdateChanged() {
    if (_updater.isForced && !_isDialogShowing) {
      _showForceUpdateDialog();
    } else if (!_updater.isForced && _isDialogShowing) {
      widget.navigatorKey.currentState?.pop();
    }
  }

  Future<void> _showForceUpdateDialog() async {
    final dialogContext = widget.navigatorKey.currentContext;
    if (dialogContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onUpdateChanged());
      return;
    }

    _isDialogShowing = true;
    await ForceUpdateDialog.show(dialogContext);
    _isDialogShowing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
