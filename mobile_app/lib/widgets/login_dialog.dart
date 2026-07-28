import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../utils/auth_navigation.dart';
import '../utils/snackbar_helper.dart';
import 'forgot_password_dialog.dart';
import 'login_form_content.dart';
import 'sign_up_dialog.dart';

Future<void> showLoginDialog(
  BuildContext context, {
  VoidCallback? onLoginSuccess,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => LoginDialog(onLoginSuccess: onLoginSuccess),
  );
}

class LoginDialog extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginDialog({super.key, this.onLoginSuccess});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  bool _isLoggingIn = false;
  bool _isGoogleSigningIn = false;

  PostLoginNavigation get _navigation => widget.onLoginSuccess != null
      ? PostLoginNavigation.refreshInPlace
      : PostLoginNavigation.navigateToDashboard;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleSigningIn = true);

    try {
      final result = await GoogleAuthService.signInWithGoogle();

      if (!mounted) return;

      if (result['cancelled'] == true) {
        setState(() => _isGoogleSigningIn = false);
        return;
      }

      if (result['success'] == true) {
        await completeAuthNavigation(
          context: context,
          result: result,
          resetLoading: () {
            if (mounted) setState(() => _isGoogleSigningIn = false);
          },
          onCloseDialog: () => Navigator.of(context).pop(),
          navigation: _navigation,
          onLoginSuccess: widget.onLoginSuccess,
        );
      } else {
        setState(() => _isGoogleSigningIn = false);
        SnackbarHelper.showError(
          context,
          result['message'] ?? 'Google sign-in failed.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleSigningIn = false);
      SnackbarHelper.showError(
        context,
        'An error occurred. Please try again.',
      );
    }
  }

  Future<void> _handleLogin(
    String username,
    String password,
    bool rememberMe,
  ) async {
    setState(() => _isLoggingIn = true);

    try {
      final result = await ApiService.login(
        emailOrUsername: username,
        password: password,
        rememberMe: rememberMe,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await completeAuthNavigation(
          context: context,
          result: result,
          resetLoading: () {
            if (mounted) setState(() => _isLoggingIn = false);
          },
          onCloseDialog: () => Navigator.of(context).pop(),
          navigation: _navigation,
          onLoginSuccess: widget.onLoginSuccess,
        );
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
          isGoogleLoading: _isGoogleSigningIn,
          onGoogleSignIn: _handleGoogleSignIn,
          onLogin: _handleLogin,
          onForgotPassword: () {
            Navigator.of(context).pop();
            showForgotPasswordDialog(
              context,
              onBackToLogin: () => showLoginDialog(
                context,
                onLoginSuccess: widget.onLoginSuccess,
              ),
            );
          },
          onSignUp: () {
            Navigator.of(context).pop();
            showSignUpDialog(
              context,
              onLoginSuccess: widget.onLoginSuccess,
            );
          },
        ),
      ),
    );
  }
}

