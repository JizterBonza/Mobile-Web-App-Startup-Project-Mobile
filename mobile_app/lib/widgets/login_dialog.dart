import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../provider/provider.dart';
import 'forgot_password_dialog.dart';
import 'login_form_content.dart';
import 'sign_up_dialog.dart';

Future<void> showLoginDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const LoginDialog(),
  );
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  bool _isLoggingIn = false;

  String _getDashboardRoute(String userType) {
    switch (userType) {
      case 'vendor':
        return '/vendorDashboard';
      case 'rider':
        return '/riderDashboard';
      case 'customer':
      default:
        return '/customerDashboard';
    }
  }

  Future<void> _handleLogin(String username, String password) async {
    setState(() => _isLoggingIn = true);

    try {
      final result = await ApiService.login(
        emailOrUsername: username,
        password: password,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        String? userType;
        if (result['data'] is Map) {
          final data = result['data'] as Map;
          userType = (data['user'] is Map
                  ? data['user']['user_type']?.toString()
                  : null) ??
              data['user_type']?.toString() ??
              (data['data'] is Map
                  ? data['data']['user_type']?.toString()
                  : null);
          if (userType == null || userType.isEmpty) {
            userType = await ApiService.getUserType();
          }
          if (userType != null) userType = userType.toLowerCase();
        }

        const validUserTypes = ['customer', 'rider'];
        if (userType == null || !validUserTypes.contains(userType)) {
          if (!mounted) return;
          setState(() => _isLoggingIn = false);
          SnackbarHelper.showError(
            context,
            'Invalid user type. Access denied.',
          );
          return;
        }

        try {
          final orderStatusProvider =
              Provider.of<OrderStatusProvider>(context, listen: false);
          orderStatusProvider.fetchAndCacheOrderStatuses().catchError((e) {
            print('Error fetching order statuses: $e');
          });
        } catch (e) {
          print('Error accessing OrderStatusProvider: $e');
        }

        SnackbarHelper.showSuccess(
          context,
          result['message'] ?? 'Login successful!',
        );

        final route = _getDashboardRoute(userType);
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacementNamed(route);
      } else {
        setState(() => _isLoggingIn = false);
        SnackbarHelper.showError(
          context,
          result['message'] ?? 'Login failed. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingIn = false);
      SnackbarHelper.showError(
        context,
        'An error occurred. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: LoginFormContent(
          showCloseButton: true,
          onClose: () => Navigator.of(context).pop(),
          isLoading: _isLoggingIn,
          onLogin: _handleLogin,
          onForgotPassword: () {
            Navigator.of(context).pop();
            showForgotPasswordDialog(
              context,
              onBackToLogin: () => showLoginDialog(context),
            );
          },
          onSignUp: () {
            Navigator.of(context).pop();
            showSignUpDialog(context);
          },
        ),
      ),
    );
  }
}
