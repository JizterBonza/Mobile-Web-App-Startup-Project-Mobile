import 'package:flutter/material.dart';
import 'signUpScreen.dart';
import 'forgotPasswordScreen.dart';
import '../widgets/form_widgets.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    try {
      final token = await ApiService.getToken();

      if (token != null && token.isNotEmpty) {
        // Token exists, get user type and navigate to appropriate dashboard
        final userType = await ApiService.getUserType();

        if (userType != null && userType.isNotEmpty) {
          // Wait for the widget to be mounted before navigating
          if (mounted) {
            final route = _getDashboardRoute(userType.toLowerCase());
            Navigator.pushReplacementNamed(context, route);
          }
        }
      }
    } catch (e) {
      // If there's an error checking token, just show login screen
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

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            FormHeader(
              icon: Icons.shopping_cart,
              iconSize: 60,
              title: 'Agrify',
              subtitle: 'Your Agricultural Marketplace',
            ),
            FormCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormSectionHeader(
                      title: 'Welcome',
                      description: 'Login to your account',
                    ),
                    CustomTextFormField(
                      controller: _emailOrUsernameController,
                      labelText: 'Email or Username',
                      prefixIcon: Icons.person_outline,
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email or username';
                        }
                        // No email format validation - accepts both email and username
                        return null;
                      },
                    ),
                    SizedBox(height: 15),
                    PasswordField(
                      controller: _passwordController,
                      labelText: 'Password',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    ForgotPasswordLink(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ForgotPasswordScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 10),
                    CustomElevatedButton(
                      text: 'Login',
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          try {
                            // Call login API
                            final result = await ApiService.login(
                              emailOrUsername:
                                  _emailOrUsernameController.text.trim(),
                              password: _passwordController.text,
                            );

                            // Dismiss loading indicator
                            if (context.mounted) {
                              Navigator.pop(context);
                            }

                            // Handle result
                            if (result['success'] == true) {
                              // Get user type from response data
                              // Based on actual response structure: data['user']['user_type']
                              String? userType;
                              if (result['data'] is Map) {
                                final data = result['data'] as Map;

                                // Try to get user_type from various possible locations
                                // Priority: data['user']['user_type'] (actual structure)
                                userType = (data['user'] is Map
                                        ? data['user']['user_type']?.toString()
                                        : null) ??
                                    data['user_type']?.toString() ??
                                    (data['data'] is Map
                                        ? data['data']['user_type']?.toString()
                                        : null) ??
                                    (data['data'] is Map &&
                                            data['data']['user'] is Map
                                        ? data['data']['user']['user_type']
                                            ?.toString()
                                        : null);

                                // If still null, try to get from SharedPreferences (saved by ApiService)
                                if (userType == null || userType.isEmpty) {
                                  userType = await ApiService.getUserType();
                                }

                                // Convert to lowercase for comparison
                                if (userType != null) {
                                  userType = userType.toLowerCase();
                                }
                              }

                              // Validate user type - only allow customer, vendor, or rider
                              final validUserTypes = [
                                'customer',
                                //'vendor',
                                'rider'
                              ];
                              if (userType == null ||
                                  !validUserTypes.contains(userType)) {
                                // Show error message for invalid user type
                                SnackbarHelper.showError(
                                  context,
                                  'Invalid user type. Access denied.',
                                );
                                return;
                              }

                              // Show success message
                              SnackbarHelper.showSuccess(
                                context,
                                result['message'] ?? 'Login successful!',
                              );

                              // Navigate to appropriate dashboard based on user type
                              if (context.mounted) {
                                final route = _getDashboardRoute(userType);
                                Navigator.pushReplacementNamed(context, route);
                              }
                            } else {
                              // Show error message
                              SnackbarHelper.showError(
                                context,
                                result['message'] ??
                                    'Login failed. Please try again.',
                              );
                            }
                          } catch (e) {
                            // Dismiss loading indicator if still showing
                            if (context.mounted) {
                              Navigator.pop(context);
                            }

                            // Show error message
                            SnackbarHelper.showError(
                              context,
                              'An error occurred. Please try again.',
                            );
                          }
                        }
                      },
                    ),
                    // SizedBox(height: 15),
                    // // Divider with OR text
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: Divider(
                    //         color: Colors.grey[300],
                    //         thickness: 1,
                    //       ),
                    //     ),
                    //     Padding(
                    //       padding: EdgeInsets.symmetric(horizontal: 16),
                    //       child: Text(
                    //         'OR',
                    //         style: TextStyle(
                    //           color: Colors.grey[600],
                    //           fontWeight: FontWeight.w500,
                    //           fontSize: 14,
                    //         ),
                    //       ),
                    //     ),
                    //     Expanded(
                    //       child: Divider(
                    //         color: Colors.grey[300],
                    //         thickness: 1,
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // SizedBox(height: 15),
                    // // Google Login Button
                    // OutlinedButton.icon(
                    //   onPressed: () {
                    //     // TODO: Implement Google login functionality
                    //   },
                    //   icon: Image.asset(
                    //     'assets/images/icons8-google-48.png',
                    //     height: 24,
                    //     width: 24,
                    //     errorBuilder: (context, error, stackTrace) {
                    //       // Fallback to icon if image not found
                    //       return Icon(
                    //         Icons.g_mobiledata,
                    //         size: 24,
                    //         color: Colors.red[700],
                    //       );
                    //     },
                    //   ),
                    //   label: Text(
                    //     'Login with Google',
                    //     style: TextStyle(
                    //       fontSize: 16,
                    //       fontWeight: FontWeight.w600,
                    //       color: Colors.grey[800],
                    //     ),
                    //   ),
                    //   style: OutlinedButton.styleFrom(
                    //     padding: EdgeInsets.symmetric(vertical: 16),
                    //     side: BorderSide(
                    //       color: Colors.grey[300]!,
                    //       width: 1.5,
                    //     ),
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     backgroundColor: Colors.white,
                    //   ),
                    // ),
                    // SizedBox(height: 15),
                    NavigationLink(
                      leadingText: "Don't have an account? ",
                      linkText: 'Sign Up',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignUpScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
