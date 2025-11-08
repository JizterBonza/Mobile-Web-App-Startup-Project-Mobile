import 'package:flutter/material.dart';
import '../constants/constants.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final Color? color;

  const StatusBadge({
    super.key,
    required this.status,
    this.color,
  });

  Color _getStatusColor(String status) {
    if (color != null) return color!;

    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange[600]!;
      case 'processing':
        return Colors.blue[600]!;
      case 'shipped':
        return AppColors.mediumGreen;
      case 'delivered':
        return AppColors.mediumGreen;
      default:
        return Colors.grey[500]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );
  }
}


