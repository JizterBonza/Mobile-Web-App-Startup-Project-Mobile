import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/login_form_content.dart';
import '../../widgets/forgot_password_dialog.dart';
import '../../widgets/sign_up_dialog.dart';
import '../../services/api_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/auth_flow_helper.dart';
import '../../utils/auth_navigation.dart';
import '../../utils/snackbar_helper.dart';
import '../../provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggingIn = false;
  bool _isGoogleSigningIn = false;

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    try {
      final session = await ApiService.tryRestoreSession();

      if (session['success'] == true) {
        final userType = session['userType']?.toString();

        if (userType != null && userType.isNotEmpty) {
          if (mounted) {
            try {
              final orderStatusProvider =
                  Provider.of<OrderStatusProvider>(context, listen: false);
              orderStatusProvider.fetchAndCacheOrderStatuses().catchError((e) {
                print('Error fetching order statuses: $e');
              });
            } catch (e) {
              print('Error accessing OrderStatusProvider: $e');
            }

            final route =
                AuthFlowHelper.dashboardRouteFor(userType.toLowerCase());
            Navigator.pushReplacementNamed(context, route);
          }
        }
      }
    } catch (e) {
      print('Error checking existing token: $e');
    }
  }

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
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: LoginFormContent(
            showCloseButton: canPop,
            onClose: canPop ? () => Navigator.pop(context) : null,
            isLoading: _isLoggingIn,
            isGoogleLoading: _isGoogleSigningIn,
            onGoogleSignIn: _handleGoogleSignIn,
            onLogin: _handleLogin,
            onForgotPassword: () {
              showForgotPasswordDialog(context);
            },
            onSignUp: () {
              showSignUpDialog(context);
            },
          ),
        ),
      ),
    );
  }
}
