import 'package:flutter/material.dart';
import '../constants/constants.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const GradientBackground({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.deepForestGreen, // Deep forest green
            AppColors.mediumGreen, // Medium green
            AppColors.freshLeafGreen, // Fresh leaf green
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: child,
              ),
            ),
            if (showBackButton)
              Positioned(
                top: 20,
                left: 24,
                child: IconButton(
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
