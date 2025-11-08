import 'package:flutter/material.dart';
import '../widgets/form_widgets.dart';
import '../services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            FormHeader(
              title: 'Create Account',
              subtitle: 'Join us and start growing',
            ),
            FormCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormSectionHeader(
                      title: 'Sign Up',
                      description: 'Fill in your details to get started',
                    ),
                    // First Name field
                    CustomTextFormField(
                      controller: _firstNameController,
                      labelText: 'First Name',
                      prefixIcon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Middle Name field (optional)
                    CustomTextFormField(
                      controller: _middleNameController,
                      labelText: 'Middle Name (Optional)',
                      prefixIcon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      // No validator - this field is optional
                    ),
                    SizedBox(height: 16),
                    // Last Name field
                    CustomTextFormField(
                      controller: _lastNameController,
                      labelText: 'Last Name',
                      prefixIcon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Username field
                    CustomTextFormField(
                      controller: _usernameController,
                      labelText: 'Username',
                      prefixIcon: Icons.alternate_email,
                      textCapitalization: TextCapitalization.none,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        // Basic validation for username format (alphanumeric and underscores)
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                          return 'Username can only contain letters, numbers, and underscores';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Email field
                    CustomTextFormField(
                      controller: _emailController,
                      labelText: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Phone field
                    CustomTextFormField(
                      controller: _phoneController,
                      labelText: 'Phone Number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Password field
                    PasswordField(
                      controller: _passwordController,
                      labelText: 'Password',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Confirm Password field
                    PasswordField(
                      controller: _confirmPasswordController,
                      labelText: 'Confirm Password',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Terms and conditions checkbox
                    TermsCheckbox(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                      onTermsPressed: () {
                        // Handle terms and conditions
                      },
                    ),
                    SizedBox(height: 24),
                    // Sign up button
                    CustomElevatedButton(
                      text: 'Sign Up',
                      isLoading: _isLoading,
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          if (!_agreedToTerms) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Please agree to Terms & Conditions'),
                                backgroundColor: Colors.red[700],
                              ),
                            );
                            return;
                          }

                          // Set loading state
                          setState(() {
                            _isLoading = true;
                          });

                          try {
                            // Call API to register
                            final result = await ApiService.register(
                              firstName: _firstNameController.text.trim(),
                              middleName:
                                  _middleNameController.text.trim().isEmpty
                                      ? null
                                      : _middleNameController.text.trim(),
                              lastName: _lastNameController.text.trim(),
                              username: _usernameController.text.trim(),
                              email: _emailController.text.trim(),
                              mobileNumber: _phoneController.text.trim(),
                              password: _passwordController.text,
                            );

                            // Reset loading state
                            setState(() {
                              _isLoading = false;
                            });

                            // Show result message
                            if (result['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ??
                                      'Registration successful!'),
                                  backgroundColor: Colors.green[700],
                                ),
                              );

                              // Clear form
                              _firstNameController.clear();
                              _middleNameController.clear();
                              _lastNameController.clear();
                              _usernameController.clear();
                              _emailController.clear();
                              _phoneController.clear();
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                              setState(() {
                                _agreedToTerms = false;
                              });

                              // Navigate back to login screen after a delay
                              Future.delayed(const Duration(seconds: 2), () {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ??
                                      'Registration failed. Please try again.'),
                                  backgroundColor: Colors.red[700],
                                ),
                              );
                            }
                          } catch (e) {
                            // Reset loading state
                            setState(() {
                              _isLoading = false;
                            });

                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('An error occurred: ${e.toString()}'),
                                backgroundColor: Colors.red[700],
                              ),
                            );
                          }
                        }
                      },
                    ),
                    SizedBox(height: 20),
                    // Login link
                    NavigationLink(
                      leadingText: "Already have an account? ",
                      linkText: 'Login',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
