import 'package:flutter/material.dart';
import '../constants/constants.dart';

class DashboardHeader extends StatelessWidget {
  final String greeting;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onIconTap;
  final String? userName;
  final int activeCount;

  const DashboardHeader({
    super.key,
    this.greeting = 'Good Morning!',
    required this.title,
    this.subtitle,
    this.icon = Icons.store,
    this.onIconTap,
    this.userName,
    this.activeCount = 0,
  });

  String _getInitials() {
    if (userName == null || userName!.isEmpty) return 'R';
    final parts = userName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: activeCount > 0
                            ? AppColors.primaryNavy
                            : Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      activeCount > 0
                          ? '$activeCount active delivery${activeCount == 1 ? '' : 'ies'}'
                          : 'No active deliveries',
                      style: TextStyle(
                        fontSize: 13,
                        color: activeCount > 0
                            ? AppColors.primaryNavy
                            : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        GestureDetector(
          onTap: onIconTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
