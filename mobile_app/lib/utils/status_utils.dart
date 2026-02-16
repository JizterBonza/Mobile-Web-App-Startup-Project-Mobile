import 'package:flutter/material.dart';
import '../constants/constants.dart';

/// Returns the appropriate color for a given order status.
/// This is centralized to ensure consistent status colors across all user types
/// (customer, rider, vendor).
Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'delivered':
    case 'shipped':
      return AppColors.mediumGreen;
    case 'in transit':
    case 'in-transit':
      return Colors.orange[600]!;
    case 'pending':
      return Colors.amber[700]!;
    case 'processing':
      return Colors.blue[600]!;
    case 'cancelled':
    case 'canceled':
      return Colors.red[600]!;
    default:
      return Colors.grey[500]!;
  }
}

/// Returns the appropriate icon for a given order status.
/// Centralized for consistent status icons across all user types.
IconData getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'delivered':
      return Icons.check_circle;
    case 'shipped':
      return Icons.local_shipping;
    case 'in transit':
    case 'in-transit':
      return Icons.local_shipping;
    case 'pending':
      return Icons.schedule;
    case 'processing':
      return Icons.sync;
    case 'cancelled':
    case 'canceled':
      return Icons.cancel;
    default:
      return Icons.receipt_long;
  }
}
