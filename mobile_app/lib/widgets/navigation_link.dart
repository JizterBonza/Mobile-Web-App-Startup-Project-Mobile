import 'package:flutter/material.dart';
import '../constants/constants.dart';

class NavigationLink extends StatelessWidget {
  final String leadingText;
  final String linkText;
  final VoidCallback onPressed;
  final MainAxisAlignment alignment;

  const NavigationLink({
    super.key,
    required this.leadingText,
    required this.linkText,
    required this.onPressed,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Text(
          leadingText,
          style: TextStyle(color: Colors.grey[600]),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(
            linkText,
            style: TextStyle(
              color: AppColors.mediumGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
