import 'package:flutter/material.dart';
import '../constants/constants.dart';

// Export all form widgets for easy importing
export 'gradient_background.dart';
export 'form_card.dart';
export 'custom_text_form_field.dart';
export 'custom_elevated_button.dart';
export 'navigation_link.dart';

/// A comprehensive form header widget with optional icon, title, and subtitle
class FormHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final double iconSize;

  const FormHeader({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = Colors.white,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 40),
        // Icon section (only if icon is provided)
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon!,
              size: iconSize,
              color: iconColor,
            ),
          ),
          SizedBox(height: 20),
        ],
        // Title
        Text(
          title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),
        // Subtitle
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

/// A form section header with title and description
class FormSectionHeader extends StatelessWidget {
  final String title;
  final String description;

  const FormSectionHeader({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.deepForestGreen,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 30),
      ],
    );
  }
}

/// A password field with visibility toggle
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool enabled;

  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.enabled = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_isPasswordVisible,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: Icon(Icons.lock_outline, color: AppColors.mediumGreen),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textSecondaryGrey,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.mediumGreen, width: 2),
        ),
        filled: true,
        fillColor: AppColors.lightGreyBackground,
      ),
      validator: widget.validator,
    );
  }
}

/// A terms and conditions checkbox
class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String termsText;
  final String linkText;
  final VoidCallback? onTermsPressed;

  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.termsText = 'I agree to the ',
    this.linkText = 'Terms & Conditions',
    this.onTermsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.mediumGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Wrap(
            children: [
              Text(
                termsText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              GestureDetector(
                onTap: onTermsPressed,
                child: Text(
                  linkText,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mediumGreen,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A forgot password link
class ForgotPasswordLink extends StatelessWidget {
  final VoidCallback onPressed;

  const ForgotPasswordLink({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          'Forgot Password?',
          style: TextStyle(
            color: AppColors.mediumGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
