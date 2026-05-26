import 'package:flutter/material.dart';
import '../constants/constants.dart';
import '../services/api_service.dart';
import 'form_widgets.dart';

Future<void> showSignUpDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const SignUpDialog(),
  );
}

class SignUpDialog extends StatefulWidget {
  const SignUpDialog({super.key});

  @override
  State<SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog> {
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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
      filled: true,
      fillColor: Colors.grey[100],
      prefixIcon: Icon(prefixIcon, color: Colors.grey[600], size: 20),
      suffixIcon: suffixIcon,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.primaryNavy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return Image.asset(
      'assets/images/icons8-google-48-2.png',
      height: 24,
      width: 24,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.g_mobiledata,
          size: 24,
          color: Colors.red[700],
        );
      },
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
        letterSpacing: 0.6,
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to Terms & Conditions'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.register(
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim().isEmpty
            ? null
            : _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Registration successful!',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        _firstNameController.clear();
        _middleNameController.clear();
        _lastNameController.clear();
        _usernameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() => _agreedToTerms = false);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ??
                  'Registration failed. Please try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavyDark,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Create your Klasmeyt account',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: _buildGoogleLogo(),
                label: const Text(
                  'Sign up with Google',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey[300]!, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey[300], thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey[300], thickness: 1),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFieldLabel('FIRST NAME'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your first name';
                            }
                            return null;
                          },
                          decoration: _fieldDecoration(
                            hintText: 'First name',
                            prefixIcon: Icons.person_outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFieldLabel('LAST NAME'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your last name';
                            }
                            return null;
                          },
                          decoration: _fieldDecoration(
                            hintText: 'Last name',
                            prefixIcon: Icons.person_outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildFieldLabel('MIDDLE NAME (OPTIONAL)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _middleNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  hintText: 'Middle name',
                  prefixIcon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel('USERNAME'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _usernameController,
                textCapitalization: TextCapitalization.none,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  if (value.length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Username can only contain letters, numbers, and underscores';
                  }
                  return null;
                },
                decoration: _fieldDecoration(
                  hintText: 'Choose a username',
                  prefixIcon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel('EMAIL'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
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
                decoration: _fieldDecoration(
                  hintText: 'your.email@example.com',
                  prefixIcon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel('PHONE NUMBER'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
                decoration: _fieldDecoration(
                  hintText: 'Enter your phone number',
                  prefixIcon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel('PASSWORD'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                decoration: _fieldDecoration(
                  hintText: 'Create a password',
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel('CONFIRM PASSWORD'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                decoration: _fieldDecoration(
                  hintText: 'Confirm your password',
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TermsCheckbox(
                value: _agreedToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreedToTerms = value ?? false;
                  });
                },
                onTermsPressed: () {},
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavyDark,
                  disabledBackgroundColor:
                      AppColors.primaryNavyDark.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavyDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
