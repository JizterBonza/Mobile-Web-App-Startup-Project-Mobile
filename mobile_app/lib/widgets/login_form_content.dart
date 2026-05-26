import 'package:flutter/material.dart';
import '../constants/constants.dart';

class LoginFormContent extends StatefulWidget {
  final Future<void> Function(String username, String password) onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignUp;
  final bool isLoading;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const LoginFormContent({
    super.key,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onSignUp,
    this.isLoading = false,
    this.showCloseButton = false,
    this.onClose,
  });

  @override
  State<LoginFormContent> createState() => LoginFormContentState();
}

class LoginFormContentState extends State<LoginFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  GlobalKey<FormState> get formKey => _formKey;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.isLoading) return;
    await widget.onLogin(
      _usernameController.text.trim(),
      _passwordController.text,
    );
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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavyDark,
                  ),
                ),
              ),
              if (widget.showCloseButton)
                InkWell(
                  onTap: widget.onClose,
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
            'Sign in to continue to Klasmeyt',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[200], height: 1),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: _buildGoogleLogo(),
            label: const Text(
              'Continue with Google',
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
          _buildFieldLabel('USERNAME'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your username';
              }
              return null;
            },
            decoration: _fieldDecoration(
              hintText: 'Enter your username',
              prefixIcon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('PASSWORD'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!widget.isLoading) submit();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
            decoration: _fieldDecoration(
              hintText: 'Enter your password',
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onForgotPassword,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavyDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: widget.isLoading ? null : submit,
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
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Login',
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
                "Don't have an account? ",
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              GestureDetector(
                onTap: widget.onSignUp,
                child: const Text(
                  'Sign Up',
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
    );
  }
}
