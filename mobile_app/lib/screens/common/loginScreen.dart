import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/login_form_content.dart';
import '../../widgets/forgot_password_dialog.dart';
import '../../widgets/sign_up_dialog.dart';
import '../../services/api_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    try {
      final token = await ApiService.getToken();

      if (token != null && token.isNotEmpty) {
        final userType = await ApiService.getUserType();

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

            final route = _getDashboardRoute(userType.toLowerCase());
            Navigator.pushReplacementNamed(context, route);
          }
        }
      }
    } catch (e) {
      print('Error checking existing token: $e');
    }
  }

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
                  : null) ??
              (data['data'] is Map && data['data']['user'] is Map
                  ? data['data']['user']['user_type']?.toString()
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

        if (mounted) {
          final route = _getDashboardRoute(userType);
          Navigator.pushReplacementNamed(context, route);
        }
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
