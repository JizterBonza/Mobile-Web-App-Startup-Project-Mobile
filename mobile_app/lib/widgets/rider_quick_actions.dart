import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'quick_action_button.dart';

class RiderQuickActions extends StatelessWidget {
  final VoidCallback onNewDelivery;
  final VoidCallback onViewAll;
  final VoidCallback onHistory;

  const RiderQuickActions({
    super.key,
    required this.onNewDelivery,
    required this.onViewAll,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                label: 'New Delivery',
                icon: Icons.add_circle_outline,
                color: AppColors.mediumGreen,
                onTap: onNewDelivery,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                label: 'View All',
                icon: Icons.list_alt,
                color: Colors.blue,
                onTap: onViewAll,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                label: 'History',
                icon: Icons.history,
                color: Colors.orange,
                onTap: onHistory,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
