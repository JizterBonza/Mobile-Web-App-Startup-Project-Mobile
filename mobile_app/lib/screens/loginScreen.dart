import 'package:flutter/material.dart';
import 'signUpScreen.dart';
import 'forgotPasswordScreen.dart';
import '../widgets/form_widgets.dart';
import '../services/api_service.dart';

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
              title: 'AgrifyConnect',
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
                      hintText: 'Enter email or username',
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
                    SizedBox(height: 20),
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
                    SizedBox(height: 15),
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
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      result['message'] ?? 'Login successful!'),
                                  backgroundColor: Colors.green[700],
                                ),
                              );

                              // Navigate to dashboard
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(
                                    context, '/customerDashboard');
                              }
                            } else {
                              // Show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ??
                                      'Login failed. Please try again.'),
                                  backgroundColor: Colors.red[700],
                                ),
                              );
                            }
                          } catch (e) {
                            // Dismiss loading indicator if still showing
                            if (context.mounted) {
                              Navigator.pop(context);
                            }

                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'An error occurred. Please try again.'),
                                backgroundColor: Colors.red[700],
                              ),
                            );
                          }
                        }
                      },
                    ),
                    SizedBox(height: 15),
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
