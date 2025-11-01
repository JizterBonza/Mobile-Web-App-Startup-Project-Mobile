import 'package:flutter/material.dart';
import '../constants/constants.dart';

class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool enabled;

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: AppColors.mediumGreen),
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: Icon(
                  suffixIcon,
                  color: AppColors.textSecondaryGrey,
                ),
                onPressed: onSuffixIconPressed,
              )
            : null,
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
      validator: validator,
    );
  }
}
