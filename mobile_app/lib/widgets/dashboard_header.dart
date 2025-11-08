import 'package:flutter/material.dart';
import '../constants/constants.dart';

class DashboardHeader extends StatelessWidget {
  final String greeting;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onIconTap;

  const DashboardHeader({
    super.key,
    this.greeting = 'Good Morning!',
    required this.title,
    this.subtitle,
    this.icon = Icons.store,
    this.onIconTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        GestureDetector(
          onTap: onIconTap,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.mediumGreen.withOpacity(0.3)),
            ),
            child: Icon(
              icon,
              color: AppColors.mediumGreen,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}


